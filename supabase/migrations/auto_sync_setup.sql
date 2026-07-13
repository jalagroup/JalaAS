-- Table to track server-side sync history
CREATE TABLE IF NOT EXISTS sync_logs (
  id bigserial PRIMARY KEY,
  synced_at timestamptz NOT NULL DEFAULT now(),
  contacts_count integer DEFAULT 0,
  items_count integer DEFAULT 0,
  warehouses_count integer DEFAULT 0,
  fuel_contacts_count integer DEFAULT 0,
  status text NOT NULL DEFAULT 'success',
  error_message text,
  CONSTRAINT sync_logs_status_check CHECK (status IN ('success', 'error'))
);

-- Keep only the last 100 rows to avoid table bloat
CREATE OR REPLACE FUNCTION trim_sync_logs()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM sync_logs
  WHERE id NOT IN (
    SELECT id FROM sync_logs ORDER BY synced_at DESC LIMIT 100
  );
  RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trim_sync_logs_trigger
AFTER INSERT ON sync_logs
EXECUTE FUNCTION trim_sync_logs();

-- Allow authenticated users to read sync_logs (admin dashboard display)
ALTER TABLE sync_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read sync_logs"
  ON sync_logs FOR SELECT
  USING (auth.role() = 'authenticated');

-- ─── pg_cron schedule ────────────────────────────────────────────────────────
-- Run auto-sync every 3 hours via pg_net → Edge Function
-- Replace YOUR_PROJECT_REF with your Supabase project ref
-- Replace YOUR_ANON_KEY with your Supabase anon key
-- (Or set up via Supabase Dashboard → Database → Cron Jobs)
--
-- SELECT cron.schedule(
--   'auto-sync-data',
--   '0 */3 * * *',
--   $$
--   SELECT net.http_post(
--     url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-sync',
--     headers := jsonb_build_object(
--       'Content-Type', 'application/json',
--       'Authorization', 'Bearer YOUR_ANON_KEY'
--     ),
--     body := '{}'::jsonb
--   );
--   $$
-- );
