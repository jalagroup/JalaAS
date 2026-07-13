-- ============================================================
-- NOTIFICATION TRIGGERS & CRON JOBS
-- Run this entire file in: Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_net  WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA cron;

-- ─────────────────────────────────────────────────────────────
-- 2. Helper: send push via Edge Function
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_push_notification(
  p_user_ids  text[],
  p_title     text,
  p_body      text,
  p_data      jsonb DEFAULT '{}'
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'https://ykwnsmyvkwjctidhoqib.supabase.co/functions/v1/scheduled-notifications?type=direct'::text,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlrd25zbXl2a3dqY3RpZGhvcWliIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTE5OTMzNiwiZXhwIjoyMDY2Nzc1MzM2fQ.dssd3cFyN_0WyFeXc04Z4iQ1EUFpZnWHJsbvIli95do'
    ),
    body    := jsonb_build_object(
      'user_ids', p_user_ids,
      'title',    p_title,
      'body',     p_body,
      'data',     p_data
    )
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'send_push_notification failed: %', SQLERRM;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 3. TRIGGER: task checklist assigned to user
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_task_checklist_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_title   text;
  v_by_name text;
BEGIN
  SELECT title    INTO v_title   FROM public.task_checklists WHERE id = NEW.checklist_id;
  SELECT username INTO v_by_name FROM public.users           WHERE id = NEW.assigned_by::uuid;

  PERFORM public.send_push_notification(
    ARRAY[NEW.user_id::text],
    'تم تكليفك بقائمة مهام 📋',
    format('قام %s بتكليفك بـ: %s',
      COALESCE(v_by_name, 'مسؤول'),
      COALESCE(v_title,   'قائمة مهام جديدة')),
    jsonb_build_object(
      'type',         'task_assigned',
      'checklist_id', NEW.checklist_id::text
    )
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_task_checklist_assigned ON public.task_checklist_assignments;
CREATE TRIGGER trg_task_checklist_assigned
  AFTER INSERT ON public.task_checklist_assignments
  FOR EACH ROW EXECUTE FUNCTION public.notify_task_checklist_assigned();

-- ─────────────────────────────────────────────────────────────
-- 4. TRIGGER: quality issue assigned / reassigned
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_quality_issue_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_by_name text;
BEGIN
  IF NEW.assigned_to IS NULL THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.assigned_to IS NOT DISTINCT FROM NEW.assigned_to THEN
    RETURN NEW;
  END IF;

  SELECT username INTO v_by_name FROM public.users WHERE id = NEW.assigned_by::uuid;

  PERFORM public.send_push_notification(
    ARRAY[NEW.assigned_to::text],
    'تم تكليفك بمشكلة جودة ⚠️',
    format('قام %s بتكليفك بمشكلة: %s',
      COALESCE(v_by_name, 'مسؤول'),
      NEW.check_point_title),
    jsonb_build_object(
      'type',     'quality_issue_assigned',
      'issue_id', NEW.id::text
    )
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_quality_issue_assigned ON public.quality_checkpoint_issues;
CREATE TRIGGER trg_quality_issue_assigned
  AFTER INSERT OR UPDATE OF assigned_to ON public.quality_checkpoint_issues
  FOR EACH ROW EXECUTE FUNCTION public.notify_quality_issue_assigned();

-- ─────────────────────────────────────────────────────────────
-- 5. TRIGGER: quality issue resolved → notify assigner
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_quality_issue_resolved()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_resolver_name text;
BEGIN
  IF NEW.status = 'resolved' AND OLD.status <> 'resolved'
     AND NEW.assigned_by IS NOT NULL THEN

    SELECT username INTO v_resolver_name
      FROM public.users WHERE id = NEW.assigned_to::uuid;

    PERFORM public.send_push_notification(
      ARRAY[NEW.assigned_by::text],
      'تم حل مشكلة الجودة ✅',
      format('قام %s بحل المشكلة: %s',
        COALESCE(v_resolver_name, 'المستخدم'),
        NEW.check_point_title),
      jsonb_build_object(
        'type',     'quality_issue_resolved',
        'issue_id', NEW.id::text
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_quality_issue_resolved ON public.quality_checkpoint_issues;
CREATE TRIGGER trg_quality_issue_resolved
  AFTER UPDATE OF status ON public.quality_checkpoint_issues
  FOR EACH ROW EXECUTE FUNCTION public.notify_quality_issue_resolved();

-- ─────────────────────────────────────────────────────────────
-- 6. TRIGGER: quality group assignment → notify assigned user
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_quality_group_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_group_name text;
  v_by_name    text;
BEGIN
  SELECT title INTO v_group_name FROM public.quality_checklist_groups WHERE id = NEW.group_id;
  SELECT username INTO v_by_name FROM public.users WHERE id = NEW.assigned_by::uuid;

  PERFORM public.send_push_notification(
    ARRAY[NEW.user_id::text],
    'تمت إضافتك لمجموعة جودة 🔍',
    format('قام %s بإضافتك إلى: %s',
      COALESCE(v_by_name,    'مسؤول'),
      COALESCE(v_group_name, 'مجموعة جودة')),
    jsonb_build_object('type', 'quality_group_assigned')
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_quality_group_assigned ON public.quality_group_assignments;
CREATE TRIGGER trg_quality_group_assigned
  AFTER INSERT ON public.quality_group_assignments
  FOR EACH ROW EXECUTE FUNCTION public.notify_quality_group_assigned();

-- ─────────────────────────────────────────────────────────────
-- 7. CRON: 8:00 AM daily (UTC+3 = 05:00 UTC)
--    Morning quality-issue reminder + task-checklists due today
-- ─────────────────────────────────────────────────────────────
DO $$
BEGIN
  PERFORM cron.unschedule('morning-notifications');
EXCEPTION WHEN OTHERS THEN NULL;
END;
$$;

SELECT cron.schedule(
  'morning-notifications',
  '0 5 * * *',
  $$
  SELECT net.http_post(
    url     := 'https://ykwnsmyvkwjctidhoqib.supabase.co/functions/v1/scheduled-notifications?type=morning',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlrd25zbXl2a3dqY3RpZGhvcWliIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTE5OTMzNiwiZXhwIjoyMDY2Nzc1MzM2fQ.dssd3cFyN_0WyFeXc04Z4iQ1EUFpZnWHJsbvIli95do"}'::jsonb,
    body    := '{}'
  );
  $$
);

-- ─────────────────────────────────────────────────────────────
-- 8. CRON: every hour 8 AM–6 PM (05:00–15:00 UTC)
--    Reminds each user of their next incomplete task today
-- ─────────────────────────────────────────────────────────────
DO $$
BEGIN
  PERFORM cron.unschedule('hourly-task-reminder');
EXCEPTION WHEN OTHERS THEN NULL;
END;
$$;

SELECT cron.schedule(
  'hourly-task-reminder',
  '0 6-15 * * *',
  $$
  SELECT net.http_post(
    url     := 'https://ykwnsmyvkwjctidhoqib.supabase.co/functions/v1/scheduled-notifications?type=hourly',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlrd25zbXl2a3dqY3RpZGhvcWliIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTE5OTMzNiwiZXhwIjoyMDY2Nzc1MzM2fQ.dssd3cFyN_0WyFeXc04Z4iQ1EUFpZnWHJsbvIli95do"}'::jsonb,
    body    := '{}'
  );
  $$
);

-- ─────────────────────────────────────────────────────────────
-- Verify:
--   SELECT * FROM cron.job;
--   SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE tgname LIKE 'trg_%';
-- ─────────────────────────────────────────────────────────────
