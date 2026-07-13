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

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

  if (!serviceAccountJson) {
    return new Response(
      JSON.stringify({ ok: false, error: "FIREBASE_SERVICE_ACCOUNT not set" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(supabaseUrl, serviceKey);
  const serviceAccount = JSON.parse(serviceAccountJson);
  const now = new Date();
  const today = now.toISOString().split("T")[0];
  const currentHour = now.getUTCHours();
  const currentMinute = now.getUTCMinutes();
  const results: Record<string, number> = {};

  try {
    const accessToken = await getFirebaseAccessToken(serviceAccount);

    // Fetch all active report lists that have at least one notification rule
    const { data: reportLists, error: listsError } = await supabase
      .from("report_lists")
      .select(`
        id, title, time_end, time_all_day, schedule_type,
        schedule_day_of_week, schedule_day_of_month, schedule_month, schedule_date,
        notification_rules,
        report_list_assignments!inner(user_id, is_active)
      `)
      .eq("is_active", true)
      .not("notification_rules", "is", null)
      .neq("notification_rules", "[]");

    if (listsError) throw listsError;
    if (!reportLists?.length) {
      return new Response(
        JSON.stringify({ ok: true, message: "No report lists with notification rules", results }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    for (const list of reportLists) {
      const rules = Array.isArray(list.notification_rules)
        ? (list.notification_rules as Array<{ type: string; enabled: boolean; config: Record<string, unknown> }>)
        : [];

      const assignedUserIds: string[] = (
        list.report_list_assignments as Array<{ user_id: string; is_active: boolean }>
      )
        .filter((a) => a.is_active)
        .map((a) => a.user_id);

      if (!assignedUserIds.length) continue;

      // Who already submitted today?
      const { data: submissions } = await supabase
        .from("report_list_responses")
        .select("user_id")
        .eq("report_list_id", list.id)
        .eq("response_date", today);

      const submittedSet = new Set<string>(
        (submissions ?? []).map((s: { user_id: string }) => s.user_id),
      );
      const unsubmittedIds = assignedUserIds.filter((uid) => !submittedSet.has(uid));

      for (const rule of rules) {
        if (!rule.enabled) continue;

        switch (rule.type) {
          // ── Daily reminder at a fixed time ───────────────────────────────────
          case "dailyReminder": {
            const timeStr = (rule.config?.time as string) ?? "09:00";
            const [rH, rM] = timeStr.split(":").map(Number);
            if (currentHour === rH && currentMinute === rM) {
              const count = await sendBulk(
                supabase, serviceAccount.project_id, accessToken,
                unsubmittedIds,
                "تذكير يومي 📋",
                `لديك تقرير لم يتم تقديمه: ${list.title}`,
                { type: "daily_reminder", report_list_id: String(list.id) },
              );
              results["dailyReminder"] = (results["dailyReminder"] ?? 0) + count;
            }
            break;
          }

          // ── N minutes before the end of the submission window ─────────────
          case "beforeDeadline": {
            if (list.time_all_day || !list.time_end) break;
            const minutesBefore = Number(rule.config?.minutes_before ?? 30);
            const [eH, eM] = (list.time_end as string).split(":").map(Number);
            const deadlineMin = eH * 60 + eM;
            const nowMin = currentHour * 60 + currentMinute;
            const diff = deadlineMin - nowMin;
            if (diff >= minutesBefore - 1 && diff <= minutesBefore + 1) {
              const count = await sendBulk(
                supabase, serviceAccount.project_id, accessToken,
                unsubmittedIds,
                `تذكير: ${minutesBefore} دقيقة على انتهاء الوقت ⏰`,
                `يرجى تقديم تقرير "${list.title}" قبل انتهاء الوقت`,
                { type: "before_deadline", report_list_id: String(list.id) },
              );
              results["beforeDeadline"] = (results["beforeDeadline"] ?? 0) + count;
            }
            break;
          }

          // ── End-of-window reminder for missed submission ───────────────────
          case "missedSubmission": {
            let tH = 23, tM = 0;
            if (!list.time_all_day && list.time_end) {
              [tH, tM] = (list.time_end as string).split(":").map(Number);
            }
            if (currentHour === tH && currentMinute === tM) {
              const count = await sendBulk(
                supabase, serviceAccount.project_id, accessToken,
                unsubmittedIds,
                "فاتك تقديم التقرير اليومي ⚠️",
                `لم يتم تقديم "${list.title}" اليوم`,
                { type: "missed_submission", report_list_id: String(list.id) },
              );
              results["missedSubmission"] = (results["missedSubmission"] ?? 0) + count;
            }
            break;
          }

          // ── Remind after a draft sits idle for N hours ────────────────────
          case "afterPartialFill": {
            const hoursAfter = Number(rule.config?.hours_after ?? 2);
            const cutoff = new Date(now.getTime() - hoursAfter * 3_600_000).toISOString();
            const { data: staleDrafts } = await supabase
              .from("report_list_drafts")
              .select("user_id")
              .eq("report_list_id", list.id)
              .eq("draft_date", today)
              .in("user_id", unsubmittedIds)
              .lt("updated_at", cutoff);

            if (staleDrafts?.length) {
              const ids = staleDrafts.map((d: { user_id: string }) => d.user_id);
              const count = await sendBulk(
                supabase, serviceAccount.project_id, accessToken,
                ids,
                "أكمل تقريرك الناقص 📝",
                `لديك تقرير "${list.title}" غير مكتمل، يرجى إكماله وتقديمه`,
                { type: "partial_fill_reminder", report_list_id: String(list.id) },
              );
              results["afterPartialFill"] = (results["afterPartialFill"] ?? 0) + count;
            }
            break;
          }

          // ── Fire when the report's own schedule date/day arrives ──────────
          case "scheduleStart": {
            const timeStr = (rule.config?.time as string) ?? "08:00";
            const [rH, rM] = timeStr.split(":").map(Number);
            if (currentHour !== rH || currentMinute !== rM) break;

            const scheduleType = list.schedule_type as string;
            const todayDow = now.getUTCDay(); // 0=Sun … 6=Sat
            const todayDom = now.getUTCDate();
            const todayMonth = now.getUTCMonth() + 1; // 1-based

            let isDue = false;
            switch (scheduleType) {
              case "daily":
                isDue = true;
                break;
              case "weekly":
                isDue = todayDow === Number(list.schedule_day_of_week ?? 0);
                break;
              case "monthly":
                isDue = todayDom === Number(list.schedule_day_of_month ?? 1);
                break;
              case "yearly":
                isDue =
                  todayMonth === Number(list.schedule_month ?? 1) &&
                  todayDom === Number(list.schedule_day_of_month ?? 1);
                break;
              case "specific_date":
                isDue = list.schedule_date === today;
                break;
              default:
                isDue = false;
            }

            if (isDue) {
              const count = await sendBulk(
                supabase, serviceAccount.project_id, accessToken,
                unsubmittedIds,
                "حان موعد تقريرك 📅",
                `يرجى البدء في ملء قائمة التقارير: ${list.title}`,
                { type: "schedule_start", report_list_id: String(list.id) },
              );
              results["scheduleStart"] = (results["scheduleStart"] ?? 0) + count;
            }
            break;
          }

          // ── Remind when a draft was saved but app was exited (30 min idle) ─
          case "exitWithoutSubmit": {
            const cutoff = new Date(now.getTime() - 30 * 60_000).toISOString();
            const { data: abandonedDrafts } = await supabase
              .from("report_list_drafts")
              .select("user_id")
              .eq("report_list_id", list.id)
              .eq("draft_date", today)
              .in("user_id", unsubmittedIds)
              .lt("updated_at", cutoff);

            if (abandonedDrafts?.length) {
              const ids = abandonedDrafts.map((d: { user_id: string }) => d.user_id);
              const count = await sendBulk(
                supabase, serviceAccount.project_id, accessToken,
                ids,
                "نسيت تقديم تقريرك 🔔",
                `يوجد لديك تقرير "${list.title}" محفوظ كمسودة، يرجى إكماله وتقديمه`,
                { type: "exit_without_submit", report_list_id: String(list.id) },
              );
              results["exitWithoutSubmit"] = (results["exitWithoutSubmit"] ?? 0) + count;
            }
            break;
          }
        }
      }
    }

    return new Response(
      JSON.stringify({ ok: true, results }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("auto-report-notifications error:", err);
    return new Response(
      JSON.stringify({ ok: false, error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function sendBulk(
  supabase: ReturnType<typeof createClient>,
  projectId: string,
  accessToken: string,
  userIds: string[],
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<number> {
  if (!userIds.length) return 0;
  const tokenMap = await fetchTokenMap(supabase, userIds);
  let sent = 0;
  for (const uid of userIds) {
    const token = tokenMap.get(uid);
    if (!token) continue;
    const ok = await sendFcm(accessToken, projectId, token, { title, body, data });
    if (ok) sent++;
  }
  return sent;
}

async function fetchTokenMap(
  supabase: ReturnType<typeof createClient>,
  userIds: string[],
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
  payload: { title: string; body: string; data?: Record<string, string> },
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
              notification: {
                title: payload.title,
                body: payload.body,
                icon: "/icons/Icon-192.png",
                dir: "rtl",
                lang: "ar",
              },
              fcm_options: { link: "/" },
            },
            android: {
              notification: {
                title: payload.title,
                body: payload.body,
                icon: "ic_launcher",
                color: "#135467",
                sound: "default",
              },
            },
          },
        }),
      },
    );
    if (!res.ok) console.error(`FCM failed (${res.status}):`, await res.text());
    return res.ok;
  } catch (e) {
    console.error("FCM error:", e);
    return false;
  }
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

async function getFirebaseAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64url(
    JSON.stringify({
      iss: sa.client_email,
      sub: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );

  const signingInput = `${header}.${payload}`;
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );
  const jwt = `${signingInput}.${base64url(sig)}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  if (!tokenRes.ok) throw new Error(`OAuth2 exchange failed: ${await tokenRes.text()}`);
  const { access_token } = await tokenRes.json();
  return access_token as string;
}

function base64url(input: string | ArrayBuffer): string {
  const bytes =
    typeof input === "string" ? new TextEncoder().encode(input) : new Uint8Array(input);
  const b64 = btoa(String.fromCharCode(...bytes));
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(b64);
  const buf = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) buf[i] = binary.charCodeAt(i);
  return buf.buffer;
}
