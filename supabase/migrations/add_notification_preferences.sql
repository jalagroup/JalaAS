-- ============================================================
-- ADD notification_preferences COLUMN TO users TABLE
-- Run this in: Supabase Dashboard → SQL Editor
-- ============================================================

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS notification_preferences JSONB
DEFAULT '{
  "all_notifications": true,
  "hourly_reminders": true,
  "morning_reminders": true,
  "task_assigned": true,
  "task_list_notifications": true,
  "quality_issue_assigned": true,
  "quality_group_assigned": true,
  "quality_issue_resolved": true
}'::jsonb;

-- Backfill existing rows that have NULL
UPDATE public.users
SET notification_preferences = '{
  "all_notifications": true,
  "hourly_reminders": true,
  "morning_reminders": true,
  "task_assigned": true,
  "task_list_notifications": true,
  "quality_issue_assigned": true,
  "quality_group_assigned": true,
  "quality_issue_resolved": true
}'::jsonb
WHERE notification_preferences IS NULL;

-- ─────────────────────────────────────────────────────────────
-- UPDATE TRIGGER: notify_task_checklist_assigned
-- Check user's task_assigned preference before sending
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_task_checklist_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_title      text;
  v_by_name    text;
  v_prefs      jsonb;
  v_all_on     boolean;
  v_pref_on    boolean;
BEGIN
  SELECT notification_preferences INTO v_prefs
    FROM public.users WHERE id = NEW.user_id::uuid;

  v_all_on  := COALESCE((v_prefs->>'all_notifications')::boolean, true);
  v_pref_on := COALESCE((v_prefs->>'task_assigned')::boolean, true);

  IF NOT v_all_on OR NOT v_pref_on THEN
    RETURN NEW;
  END IF;

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

-- ─────────────────────────────────────────────────────────────
-- UPDATE TRIGGER: notify_quality_issue_assigned
-- Check user's quality_issue_assigned preference
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_quality_issue_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_by_name text;
  v_prefs   jsonb;
  v_all_on  boolean;
  v_pref_on boolean;
BEGIN
  SELECT notification_preferences INTO v_prefs
    FROM public.users WHERE id = NEW.assigned_to::uuid;

  v_all_on  := COALESCE((v_prefs->>'all_notifications')::boolean, true);
  v_pref_on := COALESCE((v_prefs->>'quality_issue_assigned')::boolean, true);

  IF NOT v_all_on OR NOT v_pref_on THEN
    RETURN NEW;
  END IF;

  SELECT username INTO v_by_name FROM public.users WHERE id = NEW.assigned_by::uuid;

  IF (TG_OP = 'INSERT') THEN
    PERFORM public.send_push_notification(
      ARRAY[NEW.assigned_to::text],
      'تم تعيين مشكلة جودة لك ⚠️',
      format('قام %s بتعيين مشكلة جودة لك', COALESCE(v_by_name, 'مسؤول')),
      jsonb_build_object('type', 'quality_issue_assigned', 'issue_id', NEW.id::text)
    );
  ELSIF (TG_OP = 'UPDATE' AND OLD.assigned_to IS DISTINCT FROM NEW.assigned_to AND NEW.assigned_to IS NOT NULL) THEN
    PERFORM public.send_push_notification(
      ARRAY[NEW.assigned_to::text],
      'تم إعادة تعيين مشكلة جودة لك ⚠️',
      format('قام %s بإعادة تعيين مشكلة جودة لك', COALESCE(v_by_name, 'مسؤول')),
      jsonb_build_object('type', 'quality_issue_assigned', 'issue_id', NEW.id::text)
    );
  END IF;
  RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- UPDATE TRIGGER: notify_quality_issue_resolved
-- Check user's quality_issue_resolved preference
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_quality_issue_resolved()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_prefs   jsonb;
  v_all_on  boolean;
  v_pref_on boolean;
BEGIN
  IF (OLD.status IS NOT DISTINCT FROM NEW.status) OR NEW.status != 'resolved' THEN
    RETURN NEW;
  END IF;

  -- Notify the reporter
  IF NEW.reported_by IS NOT NULL THEN
    SELECT notification_preferences INTO v_prefs
      FROM public.users WHERE id = NEW.reported_by::uuid;

    v_all_on  := COALESCE((v_prefs->>'all_notifications')::boolean, true);
    v_pref_on := COALESCE((v_prefs->>'quality_issue_resolved')::boolean, true);

    IF v_all_on AND v_pref_on THEN
      PERFORM public.send_push_notification(
        ARRAY[NEW.reported_by::text],
        'تم حل مشكلة الجودة ✅',
        'تم حل المشكلة التي أبلغت عنها',
        jsonb_build_object('type', 'quality_issue_resolved', 'issue_id', NEW.id::text)
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- UPDATE TRIGGER: notify_quality_group_assigned
-- Check user's quality_group_assigned preference
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_quality_group_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_group_name text;
  v_prefs      jsonb;
  v_all_on     boolean;
  v_pref_on    boolean;
BEGIN
  SELECT notification_preferences INTO v_prefs
    FROM public.users WHERE id = NEW.user_id::uuid;

  v_all_on  := COALESCE((v_prefs->>'all_notifications')::boolean, true);
  v_pref_on := COALESCE((v_prefs->>'quality_group_assigned')::boolean, true);

  IF NOT v_all_on OR NOT v_pref_on THEN
    RETURN NEW;
  END IF;

  SELECT name INTO v_group_name FROM public.quality_groups WHERE id = NEW.group_id;

  PERFORM public.send_push_notification(
    ARRAY[NEW.user_id::text],
    'تمت إضافتك إلى مجموعة جودة 👥',
    format('تمت إضافتك إلى مجموعة: %s', COALESCE(v_group_name, 'مجموعة جديدة')),
    jsonb_build_object('type', 'quality_group_assigned', 'group_id', NEW.group_id::text)
  );
  RETURN NEW;
END;
$$;
