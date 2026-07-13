-- ============================================================
-- ADD positions TABLE & position_id TO users
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. positions table
CREATE TABLE IF NOT EXISTS public.positions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.positions ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read positions
CREATE POLICY "positions: authenticated read"
  ON public.positions FOR SELECT
  TO authenticated USING (true);

-- Only service_role (admin functions) can insert/update/delete
-- (Flutter uses service-role key for admin writes, so anon selects are enough)
CREATE POLICY "positions: admin write"
  ON public.positions FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- 2. Add position_id column to users
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS position_id uuid REFERENCES public.positions(id) ON DELETE SET NULL;
