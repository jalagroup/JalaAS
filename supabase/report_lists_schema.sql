-- ============================================================
--  REPORT LISTS – Supabase SQL Schema
--  Run this in the Supabase SQL Editor (once)
-- ============================================================

-- ── 1. Groups ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.report_list_groups (
  id                   BIGSERIAL PRIMARY KEY,
  title                TEXT        NOT NULL,
  description          TEXT,
  is_active            BOOLEAN     NOT NULL DEFAULT TRUE,
  can_edit_submissions BOOLEAN     NOT NULL DEFAULT FALSE,
  created_by           UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 2. Report Lists ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.report_lists (
  id                   BIGSERIAL PRIMARY KEY,
  group_id             BIGINT      REFERENCES public.report_list_groups(id) ON DELETE CASCADE,
  title                TEXT        NOT NULL,
  description          TEXT,
  selector_option_value TEXT,
  -- JSON arrays stored as jsonb for fast querying
  determinants         JSONB       NOT NULL DEFAULT '[]',
  fields               JSONB       NOT NULL DEFAULT '[]',
  is_active            BOOLEAN     NOT NULL DEFAULT TRUE,
  can_edit_submissions BOOLEAN     NOT NULL DEFAULT FALSE,
  created_by           UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  -- Scheduling
  schedule_type        TEXT        NOT NULL DEFAULT 'anytime'
                         CHECK (schedule_type IN ('anytime','daily','weekly','monthly','yearly','specific_date')),
  schedule_day_of_week  SMALLINT   CHECK (schedule_day_of_week BETWEEN 0 AND 6),
  schedule_day_of_month SMALLINT   CHECK (schedule_day_of_month BETWEEN 1 AND 31),
  schedule_month        SMALLINT   CHECK (schedule_month BETWEEN 1 AND 12),
  schedule_date         DATE,
  -- Time window
  time_all_day         BOOLEAN     NOT NULL DEFAULT TRUE,
  time_start           TIME,
  time_end             TIME,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 3. Assignments ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.report_list_assignments (
  id             BIGSERIAL PRIMARY KEY,
  report_list_id BIGINT      NOT NULL REFERENCES public.report_lists(id) ON DELETE CASCADE,
  user_id        UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_by    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  assigned_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (report_list_id, user_id)
);

-- ── 4. Responses ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.report_list_responses (
  id               BIGSERIAL PRIMARY KEY,
  report_list_id   BIGINT      NOT NULL REFERENCES public.report_lists(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  response_date    DATE        NOT NULL DEFAULT CURRENT_DATE,
  determinant_values JSONB     NOT NULL DEFAULT '{}',
  field_responses  JSONB       NOT NULL DEFAULT '{}',
  submitted_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Indexes ───────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_report_lists_group_id
  ON public.report_lists(group_id);

CREATE INDEX IF NOT EXISTS idx_report_list_assignments_report_list_id
  ON public.report_list_assignments(report_list_id);

CREATE INDEX IF NOT EXISTS idx_report_list_assignments_user_id
  ON public.report_list_assignments(user_id);

CREATE INDEX IF NOT EXISTS idx_report_list_responses_report_list_id
  ON public.report_list_responses(report_list_id);

CREATE INDEX IF NOT EXISTS idx_report_list_responses_user_id
  ON public.report_list_responses(user_id);

CREATE INDEX IF NOT EXISTS idx_report_list_responses_date
  ON public.report_list_responses(response_date DESC);

-- ── updated_at triggers ───────────────────────────────────────
-- Reuse the moddatetime extension if already installed, or use this function:
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_report_list_groups_updated_at
  BEFORE UPDATE ON public.report_list_groups
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER trg_report_lists_updated_at
  BEFORE UPDATE ON public.report_lists
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER trg_report_list_assignments_updated_at
  BEFORE UPDATE ON public.report_list_assignments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER trg_report_list_responses_updated_at
  BEFORE UPDATE ON public.report_list_responses
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE public.report_list_groups       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_lists             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_list_assignments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_list_responses    ENABLE ROW LEVEL SECURITY;

-- Quality Control Admin: full access
CREATE POLICY "admin_all_report_list_groups" ON public.report_list_groups
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND user_type = 'quality_control_admin')
  );

CREATE POLICY "admin_all_report_lists" ON public.report_lists
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND user_type = 'quality_control_admin')
  );

CREATE POLICY "admin_all_report_list_assignments" ON public.report_list_assignments
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND user_type = 'quality_control_admin')
  );

CREATE POLICY "admin_all_report_list_responses" ON public.report_list_responses
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND user_type = 'quality_control_admin')
  );

-- Quality Controller: read groups/lists they are assigned to; write own responses
CREATE POLICY "controller_read_assigned_report_lists" ON public.report_lists
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.report_list_assignments rla
      WHERE rla.report_list_id = id
        AND rla.user_id = auth.uid()
        AND rla.is_active = TRUE
    )
  );

CREATE POLICY "controller_read_report_list_groups" ON public.report_list_groups
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM public.report_list_assignments rla
      JOIN public.report_lists rl ON rl.id = rla.report_list_id
      WHERE rl.group_id = report_list_groups.id
        AND rla.user_id = auth.uid()
        AND rla.is_active = TRUE
    )
  );

CREATE POLICY "controller_own_responses_insert" ON public.report_list_responses
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "controller_own_responses_select" ON public.report_list_responses
  FOR SELECT USING (user_id = auth.uid());

-- Allow edit within 48 hours when can_edit_submissions is TRUE on the parent list
CREATE POLICY "controller_own_responses_update" ON public.report_list_responses
  FOR UPDATE USING (
    user_id = auth.uid()
    AND submitted_at > NOW() - INTERVAL '48 hours'
    AND EXISTS (
      SELECT 1 FROM public.report_lists rl
      WHERE rl.id = report_list_id AND rl.can_edit_submissions = TRUE
    )
  );

-- ── Helper view for the app ───────────────────────────────────
-- Returns groups with their nested report_lists as a JSON array
CREATE OR REPLACE VIEW public.report_list_groups_with_lists AS
SELECT
  g.*,
  COALESCE(
    (
      SELECT jsonb_agg(rl ORDER BY rl.created_at)
      FROM public.report_lists rl
      WHERE rl.group_id = g.id
    ),
    '[]'
  ) AS report_lists
FROM public.report_list_groups g;
