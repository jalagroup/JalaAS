-- Fix notify_quality_group_assigned: wrong table (quality_groups → quality_checklist_groups)
-- and wrong column (name → title).
-- Run in: Supabase Dashboard → SQL Editor

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

  SELECT title INTO v_group_name
    FROM public.quality_checklist_groups WHERE id = NEW.group_id;

  PERFORM public.send_push_notification(
    ARRAY[NEW.user_id::text],
    'تمت إضافتك إلى مجموعة جودة 👥',
    format('تمت إضافتك إلى مجموعة: %s', COALESCE(v_group_name, 'مجموعة جديدة')),
    jsonb_build_object('type', 'quality_group_assigned', 'group_id', NEW.group_id::text)
  );
  RETURN NEW;
END;
$$;
