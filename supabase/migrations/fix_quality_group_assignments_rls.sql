-- Allow authenticated admins to manage quality_group_assignments directly.
-- Run in: Supabase Dashboard → SQL Editor

-- Enable RLS if not already enabled
ALTER TABLE public.quality_group_assignments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "quality_group_assignments: authenticated read" ON public.quality_group_assignments;
DROP POLICY IF EXISTS "quality_group_assignments: admin write" ON public.quality_group_assignments;

-- Allow all authenticated users to read assignments
CREATE POLICY "quality_group_assignments: authenticated read"
  ON public.quality_group_assignments FOR SELECT
  TO authenticated USING (true);

-- Allow admins to insert/update/delete assignments
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
