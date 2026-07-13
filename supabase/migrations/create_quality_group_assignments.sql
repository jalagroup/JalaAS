-- Create quality_group_assignments table and fix related functions.
-- Run in: Supabase Dashboard → SQL Editor

-- 1. Create the assignments table
CREATE TABLE IF NOT EXISTS public.quality_group_assignments (
  id          bigserial PRIMARY KEY,
  group_id    bigint NOT NULL REFERENCES public.quality_checklist_groups(id) ON DELETE CASCADE,
  user_id     uuid   NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  assigned_by uuid   REFERENCES public.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (group_id, user_id)
);

-- 2. Enable RLS
ALTER TABLE public.quality_group_assignments ENABLE ROW LEVEL SECURITY;

-- 3. Policies
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

-- 4. Fix get_quality_group_assigned_user_ids to use the correct table
CREATE OR REPLACE FUNCTION public.get_quality_group_assigned_user_ids(p_group_id bigint)
RETURNS TABLE(user_id uuid)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT user_id FROM public.quality_group_assignments WHERE group_id = p_group_id;
$$;
