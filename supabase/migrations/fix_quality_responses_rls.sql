-- Fix RLS SELECT policy on quality_responses.
-- The old policy only allowed 'admin' and 'quality_controller' users.
-- This extends it to also include 'quality_control_admin', 'quality_control_inspector',
-- and any user with can_see_all_quality_forms = true.
-- Run in: Supabase Dashboard → SQL Editor

-- ─── Helper: check if current user can see ALL quality responses ───────────────
CREATE OR REPLACE FUNCTION public.can_view_all_quality_responses()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND (
        user_type IN ('admin', 'quality_control_admin')
        OR can_see_all_quality_forms = true
      )
  )
$$;

-- ─── Helper: check if current user is a quality reviewer (own rows only) ───────
CREATE OR REPLACE FUNCTION public.is_quality_reviewer()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND user_type IN ('quality_controller', 'quality_control_inspector')
  )
$$;

-- ─── Drop old policies ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "quality_responses: select"           ON public.quality_responses;
DROP POLICY IF EXISTS "quality_responses: authenticated read" ON public.quality_responses;
DROP POLICY IF EXISTS "quality_responses_select_policy"     ON public.quality_responses;
DROP POLICY IF EXISTS "Users can view quality responses"    ON public.quality_responses;
DROP POLICY IF EXISTS "Admins can view all quality responses" ON public.quality_responses;
DROP POLICY IF EXISTS "Quality controllers can view own responses" ON public.quality_responses;

-- ─── New SELECT policy ─────────────────────────────────────────────────────────
-- Admins / quality_control_admin / can_see_all_quality_forms → see everything
-- quality_controller / quality_control_inspector → see only their own rows
CREATE POLICY "quality_responses: select"
  ON public.quality_responses
  FOR SELECT
  TO authenticated
  USING (
    public.can_view_all_quality_responses()
    OR (public.is_quality_reviewer() AND user_id = auth.uid())
  );

-- ─── Also fix related tables that admins need to read ─────────────────────────

-- quality_images
DROP POLICY IF EXISTS "quality_images: select"             ON public.quality_images;
DROP POLICY IF EXISTS "quality_images: authenticated read" ON public.quality_images;
CREATE POLICY "quality_images: select"
  ON public.quality_images
  FOR SELECT
  TO authenticated
  USING (
    public.can_view_all_quality_responses()
    OR (public.is_quality_reviewer() AND EXISTS (
      SELECT 1 FROM public.quality_responses qr
      WHERE qr.id = quality_images.response_id
        AND qr.user_id = auth.uid()
    ))
  );

-- quality_checkpoint_images
DROP POLICY IF EXISTS "quality_checkpoint_images: select"             ON public.quality_checkpoint_images;
DROP POLICY IF EXISTS "quality_checkpoint_images: authenticated read" ON public.quality_checkpoint_images;
CREATE POLICY "quality_checkpoint_images: select"
  ON public.quality_checkpoint_images
  FOR SELECT
  TO authenticated
  USING (
    public.can_view_all_quality_responses()
    OR (public.is_quality_reviewer() AND EXISTS (
      SELECT 1 FROM public.quality_responses qr
      WHERE qr.id = quality_checkpoint_images.response_id
        AND qr.user_id = auth.uid()
    ))
  );

-- quality_checkpoint_issues
DROP POLICY IF EXISTS "quality_checkpoint_issues: select"             ON public.quality_checkpoint_issues;
DROP POLICY IF EXISTS "quality_checkpoint_issues: authenticated read" ON public.quality_checkpoint_issues;
CREATE POLICY "quality_checkpoint_issues: select"
  ON public.quality_checkpoint_issues
  FOR SELECT
  TO authenticated
  USING (
    public.can_view_all_quality_responses()
    OR (public.is_quality_reviewer() AND EXISTS (
      SELECT 1 FROM public.quality_responses qr
      WHERE qr.id = quality_checkpoint_issues.response_id
        AND qr.user_id = auth.uid()
    ))
    OR assigned_to = auth.uid()
  );
