-- Diagnose what still references quality_groups, then fix it.
-- Run in: Supabase Dashboard → SQL Editor

-- STEP 1: See what references quality_groups
SELECT
  n.nspname || '.' || p.proname AS function_name,
  p.prosrc
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prosrc ILIKE '%quality_groups%';

-- STEP 2: Drop any existing quality_group_assignments table or view that may
--         have been created with a wrong FK, then recreate it cleanly.

DROP TABLE IF EXISTS public.quality_group_assignments CASCADE;

CREATE TABLE public.quality_group_assignments (
  id          bigserial PRIMARY KEY,
  group_id    bigint NOT NULL REFERENCES public.quality_checklist_groups(id) ON DELETE CASCADE,
  user_id     uuid   NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  assigned_by uuid   REFERENCES public.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (group_id, user_id)
);

ALTER TABLE public.quality_group_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "quality_group_assignments: authenticated read" ON public.quality_group_assignments;
DROP POLICY IF EXISTS "quality_group_assignments: admin write" ON public.quality_group_assignments;

CREATE POLICY "quality_group_assignments: authenticated read"
  ON public.quality_group_assignments FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "quality_group_assignments: admin write"
  ON public.quality_group_assignments FOR ALL
  TO authenticated
  USING (
    (SELECT user_type FROM public.users WHERE id = auth.uid())
    IN ('admin', 'quality_control_admin')
  )
  WITH CHECK (
    (SELECT user_type FROM public.users WHERE id = auth.uid())
    IN ('admin', 'quality_control_admin')
  );

-- STEP 3: Drop all overloads of the broken RPC (references quality_groups)
DROP FUNCTION IF EXISTS public.assign_users_to_quality_group(bigint, uuid[], uuid);
DROP FUNCTION IF EXISTS public.assign_users_to_quality_group(bigint, text[], uuid);
DROP FUNCTION IF EXISTS public.assign_users_to_quality_group(integer, text[], uuid);
DROP FUNCTION IF EXISTS public.assign_users_to_quality_group(integer, uuid[], uuid);

-- STEP 4: Fix get_quality_group_assigned_user_ids
CREATE OR REPLACE FUNCTION public.get_quality_group_assigned_user_ids(p_group_id bigint)
RETURNS TABLE(user_id uuid)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT user_id FROM public.quality_group_assignments WHERE group_id = p_group_id;
$$;

-- STEP 5: Recreate the notification trigger on the new table
DROP TRIGGER IF EXISTS trg_quality_group_assigned ON public.quality_group_assignments;
CREATE TRIGGER trg_quality_group_assigned
  AFTER INSERT ON public.quality_group_assignments
  FOR EACH ROW EXECUTE FUNCTION public.notify_quality_group_assigned();
