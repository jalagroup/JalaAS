-- Fix: drop all overloaded versions of assign_users_to_quality_group
-- and recreate a single canonical one with the correct table reference.
-- Run in: Supabase Dashboard → SQL Editor

DROP FUNCTION IF EXISTS public.assign_users_to_quality_group(bigint, uuid[], uuid);
DROP FUNCTION IF EXISTS public.assign_users_to_quality_group(integer, text[], uuid);
DROP FUNCTION IF EXISTS public.assign_users_to_quality_group(bigint, text[], uuid);
DROP FUNCTION IF EXISTS public.assign_users_to_quality_group(integer, uuid[], uuid);

CREATE OR REPLACE FUNCTION public.assign_users_to_quality_group(
  p_group_id    bigint,
  p_user_ids    text[],
  p_assigned_by uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only admins may assign users
  IF (SELECT user_type FROM public.users WHERE id = p_assigned_by)
       NOT IN ('admin', 'quality_control_admin') THEN
    RAISE EXCEPTION 'Only administrators can assign users to groups';
  END IF;

  -- Verify the group exists
  IF NOT EXISTS (
    SELECT 1 FROM public.quality_checklist_groups WHERE id = p_group_id
  ) THEN
    RAISE EXCEPTION 'Quality checklist group % does not exist', p_group_id;
  END IF;

  -- Replace all assignments for this group
  DELETE FROM public.quality_group_assignments WHERE group_id = p_group_id;

  INSERT INTO public.quality_group_assignments (group_id, user_id, assigned_by)
  SELECT p_group_id, unnest(p_user_ids)::uuid, p_assigned_by
  WHERE array_length(p_user_ids, 1) > 0;
END;
$$;
