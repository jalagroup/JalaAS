import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const type = url.searchParams.get("type") ?? "all";

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

  const supabase = createClient(supabaseUrl, serviceKey);
  const today = new Date().toISOString().split("T")[0];
  const results: string[] = [];

  try {
    if (!serviceAccountJson) throw new Error("FIREBASE_SERVICE_ACCOUNT env variable is not set");
    const serviceAccount = JSON.parse(serviceAccountJson);

    // ── Direct push: called by DB triggers (replaces send-push function) ──────
    if (type === "direct") {
      const body = await req.json() as {
        user_ids: string[] | string;
        title: string;
        body: string;
        data?: Record<string, string>;
      };
      const userIds = Array.isArray(body.user_ids) ? body.user_ids : [body.user_ids];
      if (!userIds.length || !body.title || !body.body) {
        return new Response(
          JSON.stringify({ error: "user_ids, title, and body are required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const tokenMap = await fetchTokenMap(supabase, userIds);
      const accessToken = await getFirebaseAccessToken(serviceAccount);
      let sent = 0;
      for (const uid of userIds) {
        const token = tokenMap.get(uid);
        if (!token) continue;
        const ok = await sendFcm(accessToken, serviceAccount.project_id, token, {
          title: body.title,
          body: body.body,
          data: body.data ?? {},
        });
        if (ok) sent++;
      }
      return new Response(
        JSON.stringify({ ok: true, sent }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get one OAuth token and reuse it for all FCM calls
    const accessToken = await getFirebaseAccessToken(serviceAccount);

    // Shared set to prevent the same (user, checklist) from being notified twice
    // in a single invocation (relevant when type=all runs both morning and hourly)
    const notifiedTaskPairs = new Set<string>();

    if (type === "morning" || type === "all") {
      const qualityCount = await remindOpenQualityIssues(supabase, serviceAccount.project_id, accessToken);
      results.push(`quality_issues: ${qualityCount} notifications sent`);

      const taskCount = await remindDueTaskChecklists(supabase, serviceAccount.project_id, accessToken, today, notifiedTaskPairs);
      results.push(`due_tasks: ${taskCount} notifications sent`);
    }

    if (type === "hourly" || type === "all") {
      const hourlyCount = await remindNextIncompleteTask(supabase, serviceAccount.project_id, accessToken, today, notifiedTaskPairs);
      results.push(`hourly_tasks: ${hourlyCount} notifications sent`);
    }

    return new Response(
      JSON.stringify({ ok: true, type, results }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("scheduled-notifications error:", err);
    return new Response(
      JSON.stringify({ ok: false, error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// ─── Morning: open quality issues ────────────────────────────────────────────

async function remindOpenQualityIssues(
  supabase: ReturnType<typeof createClient>,
  projectId: string,
  accessToken: string
): Promise<number> {
  const { data: issues, error } = await supabase
    .from("quality_checkpoint_issues")
    .select("assigned_to, check_point_title, id")
    .in("status", ["open", "in_progress"])
    .not("assigned_to", "is", null);

  if (error || !issues?.length) return 0;

  // Fetch FCM tokens for all affected users at once
  const userIds = Array.from(new Set(issues.map((i: { assigned_to: string }) => i.assigned_to))) as string[];
  const tokenMap = await fetchTokenMap(supabase, userIds);

  // Group by user
  const byUser = new Map<string, typeof issues>();
  for (const issue of issues) {
    const list = byUser.get(issue.assigned_to) ?? [];
    list.push(issue);
    byUser.set(issue.assigned_to, list);
  }

  let sent = 0;
  for (const [userId, userIssues] of byUser.entries()) {
    const token = tokenMap.get(userId);
    if (!token) continue;

    const body = userIssues.length === 1
      ? `لديك مشكلة جودة معلقة: ${userIssues[0].check_point_title}`
      : `لديك ${userIssues.length} مشاكل جودة معلقة تحتاج إلى متابعة`;

    const ok = await sendFcm(accessToken, projectId, token, {
      title: "تذكير: مشاكل الجودة",
      body,
      data: { type: "quality_reminder", issue_id: String(userIssues[0].id) },
    });
    if (ok) sent++;
  }
  return sent;
}

// ─── Morning: task checklists due today ──────────────────────────────────────

async function remindDueTaskChecklists(
  supabase: ReturnType<typeof createClient>,
  projectId: string,
  accessToken: string,
  today: string,
  notifiedPairs: Set<string>
): Promise<number> {
  const { data: responses, error } = await supabase
    .from("task_checklist_responses")
    .select("user_id, checklist_id, status, task_checklists(title)")
    .eq("scheduled_date", today)
    .in("status", ["pending", "in_progress"]);

  const startedPairsDue = new Set<string>(
    (responses ?? []).map((r: { user_id: string; checklist_id: number | string }) =>
      `${r.user_id}:${r.checklist_id}`
    )
  );

  const userIds = Array.from(new Set((responses ?? []).map((r: { user_id: string }) => r.user_id))) as string[];
  const tokenMap = await fetchTokenMap(supabase, userIds);

  let sent = 0;
  if (!error && responses?.length) {
    for (const resp of responses) {
      const pairKey = `${resp.user_id}:${resp.checklist_id}`;
      if (notifiedPairs.has(pairKey)) continue;
      const token = tokenMap.get(resp.user_id);
      if (!token) continue;
      const listTitle = (resp.task_checklists as { title?: string } | null)?.title ?? "قائمة مهام";
      const isPending = resp.status === "pending";

      const ok = await sendFcm(accessToken, projectId, token, {
        title: isPending ? "قائمة مهام جديدة تنتظرك 📋" : "مهمة اليوم لم تكتمل بعد",
        body: isPending
          ? `لم تبدأ بعد في قائمة مهام اليوم: ${listTitle}`
          : `لديك قائمة مهام لم تكتمل اليوم: ${listTitle}`,
        data: { type: "task_due_today", checklist_id: String(resp.checklist_id) },
      });
      if (ok) { sent++; notifiedPairs.add(pairKey); }
    }
  }

  // Also notify for assigned checklists that have no response row at all today
  const unstarted = await fetchUnstartedAssignments(supabase, startedPairsDue);
  const unstartedTokenMap = await fetchTokenMap(supabase, Array.from(new Set(unstarted.map((u) => u.user_id))));
  for (const item of unstarted) {
    const pairKey = `${item.user_id}:${item.checklist_id}`;
    if (notifiedPairs.has(pairKey)) continue;
    const token = unstartedTokenMap.get(item.user_id);
    if (!token) continue;
    const ok = await sendFcm(accessToken, projectId, token, {
      title: "قائمة مهام تنتظرك 📋",
      body: `لم تبدأ بعد في قائمة المهام: ${item.title}`,
      data: { type: "task_due_today", checklist_id: item.checklist_id },
    });
    if (ok) { sent++; notifiedPairs.add(pairKey); }
  }

  return sent;
}

// ─── Hourly: next incomplete task ────────────────────────────────────────────

interface TaskItem { id: string; title: string; order?: number; }
interface TaskResponse { task_id: string; is_done: boolean; }

async function remindNextIncompleteTask(
  supabase: ReturnType<typeof createClient>,
  projectId: string,
  accessToken: string,
  today: string,
  notifiedPairs: Set<string>
): Promise<number> {
  const { data: responses, error } = await supabase
    .from("task_checklist_responses")
    .select("user_id, checklist_id, status, task_responses, task_checklists(title, tasks)")
    .eq("scheduled_date", today)
    .in("status", ["pending", "in_progress"]);

  const userIds = Array.from(new Set((responses ?? []).map((r: { user_id: string }) => r.user_id))) as string[];
  const tokenMap = await fetchTokenMap(supabase, userIds);

  let sent = 0;
  for (const resp of (error ? [] : responses ?? [])) {
    const pairKey = `${resp.user_id}:${resp.checklist_id}`;
    if (notifiedPairs.has(pairKey)) continue;
    const token = tokenMap.get(resp.user_id);
    if (!token) continue;

    const checklist = resp.task_checklists as { title?: string; tasks?: TaskItem[] } | null;
    const listTitle = checklist?.title ?? "قائمة مهام";

    // Not started at all — remind to begin
    if (resp.status === "pending") {
      const ok = await sendFcm(accessToken, projectId, token, {
        title: "تذكير: لم تبدأ قائمة مهامك بعد ⏰",
        body: `يرجى البدء في قائمة المهام: ${listTitle}`,
        data: { type: "task_reminder", checklist_id: String(resp.checklist_id) },
      });
      if (ok) { sent++; notifiedPairs.add(pairKey); }
      continue;
    }

    // In progress — remind about the next incomplete task
    const allTasks: TaskItem[] = checklist?.tasks ?? [];
    const taskResponses: TaskResponse[] = (resp.task_responses as TaskResponse[]) ?? [];
    const sorted = [...allTasks].sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
    const nextTask = sorted.find((task) => {
      const tr = taskResponses.find((r) => r.task_id === task.id);
      return !tr?.is_done;
    });
    if (!nextTask) continue; // All tasks done

    const ok = await sendFcm(accessToken, projectId, token, {
      title: "تذكير: المهمة التالية",
      body: `المهمة التالية في ${listTitle}: ${nextTask.title}`,
      data: { type: "task_reminder", checklist_id: String(resp.checklist_id), task_id: nextTask.id },
    });
    if (ok) { sent++; notifiedPairs.add(pairKey); }
  }

  // Also remind for assigned checklists that have no response row at all today
  const startedPairsHourly = new Set<string>(
    (responses ?? []).map((r: { user_id: string; checklist_id: number | string }) =>
      `${r.user_id}:${r.checklist_id}`
    )
  );
  const unstarted = await fetchUnstartedAssignments(supabase, startedPairsHourly);
  const unstartedTokenMap = await fetchTokenMap(supabase, Array.from(new Set(unstarted.map((u) => u.user_id))));
  for (const item of unstarted) {
    const pairKey = `${item.user_id}:${item.checklist_id}`;
    if (notifiedPairs.has(pairKey)) continue;
    const token = unstartedTokenMap.get(item.user_id);
    if (!token) continue;
    const ok = await sendFcm(accessToken, projectId, token, {
      title: "تذكير: لم تبدأ قائمة مهامك بعد ⏰",
      body: `يرجى البدء في قائمة المهام: ${item.title}`,
      data: { type: "task_reminder", checklist_id: item.checklist_id },
    });
    if (ok) { sent++; notifiedPairs.add(pairKey); }
  }

  return sent;
}

// ─── Unstarted assignments (assigned but no response row today) ───────────────

interface UnstartedItem { user_id: string; checklist_id: string; title: string; }

async function fetchUnstartedAssignments(
  supabase: ReturnType<typeof createClient>,
  startedPairs: Set<string>  // "user_id:checklist_id" pairs already known to have a response today
): Promise<UnstartedItem[]> {
  const { data: assignments } = await supabase
    .from("task_checklist_assignments")
    .select("user_id, checklist_id, task_checklists(title)");

  if (!assignments?.length) return [];

  return assignments
    .filter((a: { user_id: string; checklist_id: number | string }) =>
      !startedPairs.has(`${a.user_id}:${a.checklist_id}`)
    )
    .map((a: { user_id: string; checklist_id: number | string; task_checklists: unknown }) => ({
      user_id: String(a.user_id),
      checklist_id: String(a.checklist_id),
      title: (a.task_checklists as { title?: string } | null)?.title ?? "قائمة مهام",
    }));
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function fetchTokenMap(
  supabase: ReturnType<typeof createClient>,
  userIds: string[]
): Promise<Map<string, string>> {
  const { data } = await supabase
    .from("users")
    .select("id, fcm_token")
    .in("id", userIds)
    .not("fcm_token", "is", null);

  const map = new Map<string, string>();
  for (const row of data ?? []) {
    if (row.fcm_token) map.set(row.id, row.fcm_token);
  }
  return map;
}

async function sendFcm(
  accessToken: string,
  projectId: string,
  token: string,
  payload: { title: string; body: string; data?: Record<string, string> }
): Promise<boolean> {
  try {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: payload.title, body: payload.body },
            data: payload.data ?? {},
            webpush: {
              notification: { title: payload.title, body: payload.body, icon: "/icons/Icon-192.png", dir: "rtl", lang: "ar" },
              fcm_options: { link: "/" },
            },
            android: {
              notification: { title: payload.title, body: payload.body, icon: "ic_launcher", color: "#135467", sound: "default" },
            },
          },
        }),
      }
    );
    if (!res.ok) {
      console.error(`FCM send failed (${res.status}):`, await res.text());
    }
    return res.ok;
  } catch (e) {
    console.error("FCM send error:", e);
    return false;
  }
}

// ─── Firebase OAuth2 JWT ──────────────────────────────────────────────────────

interface ServiceAccount { client_email: string; private_key: string; project_id: string; }

async function getFirebaseAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64url(JSON.stringify({
    iss: sa.client_email, sub: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now, exp: now + 3600,
  }));

  const signingInput = `${header}.${payload}`;
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", cryptoKey, new TextEncoder().encode(signingInput));
  const jwt = `${signingInput}.${base64url(signature)}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  if (!tokenRes.ok) throw new Error(`OAuth2 token exchange failed: ${await tokenRes.text()}`);
  const { access_token } = await tokenRes.json();
  return access_token as string;
}

function base64url(input: string | ArrayBuffer): string {
  let bytes: Uint8Array;
  if (typeof input === "string") bytes = new TextEncoder().encode(input);
  else bytes = new Uint8Array(input);
  const b64 = btoa(String.fromCharCode(...bytes));
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----BEGIN PRIVATE KEY-----/, "").replace(/-----END PRIVATE KEY-----/, "").replace(/\s/g, "");
  const binary = atob(b64);
  const buffer = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) buffer[i] = binary.charCodeAt(i);
  return buffer.buffer;
}
