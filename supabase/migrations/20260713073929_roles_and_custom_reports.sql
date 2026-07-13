-- ── Roles ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS roles (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar        TEXT        NOT NULL,
  description    TEXT,
  interface_type TEXT        NOT NULL DEFAULT 'user'
                             CHECK (interface_type IN ('admin', 'user')),
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Role features (many features per role) ────────────────────────────────────
CREATE TABLE IF NOT EXISTS role_features (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id     UUID        NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  feature_key TEXT        NOT NULL,
  config      JSONB       NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (role_id, feature_key)
);

-- ── Custom reports ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS custom_reports (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar       TEXT        NOT NULL,
  description   TEXT,
  report_config JSONB       NOT NULL DEFAULT '{}',
  is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
  created_by    UUID        REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Link users to a role ──────────────────────────────────────────────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS role_id UUID REFERENCES roles(id);

-- ── Auto-update updated_at ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER roles_updated_at
  BEFORE UPDATE ON roles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER custom_reports_updated_at
  BEFORE UPDATE ON custom_reports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Row Level Security ────────────────────────────────────────────────────────
ALTER TABLE roles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_features  ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_reports ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read roles and features (needed at login)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'roles' AND policyname = 'read roles'
  ) THEN
    CREATE POLICY "read roles" ON roles FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'role_features' AND policyname = 'read role_features'
  ) THEN
    CREATE POLICY "read role_features" ON role_features FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'custom_reports' AND policyname = 'read custom_reports'
  ) THEN
    CREATE POLICY "read custom_reports" ON custom_reports FOR SELECT TO authenticated USING (is_active = true);
  END IF;
END $$;

-- Super admins (salesman = '0') can write everything
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'roles' AND policyname = 'admin write roles'
  ) THEN
    CREATE POLICY "admin write roles" ON roles FOR ALL TO authenticated
      USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND salesman = '0'))
      WITH CHECK (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND salesman = '0'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'role_features' AND policyname = 'admin write role_features'
  ) THEN
    CREATE POLICY "admin write role_features" ON role_features FOR ALL TO authenticated
      USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND salesman = '0'))
      WITH CHECK (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND salesman = '0'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'custom_reports' AND policyname = 'admin write custom_reports'
  ) THEN
    CREATE POLICY "admin write custom_reports" ON custom_reports FOR ALL TO authenticated
      USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND salesman = '0'))
      WITH CHECK (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND salesman = '0'));
  END IF;
END $$;
