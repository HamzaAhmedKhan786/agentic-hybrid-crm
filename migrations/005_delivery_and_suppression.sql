BEGIN;
CREATE TABLE IF NOT EXISTS governance.suppressions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  email citext NOT NULL, reason text NOT NULL DEFAULT 'opt_out', source text NOT NULL DEFAULT 'manual', created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(organization_id,email)
);
CREATE TABLE IF NOT EXISTS automation.delivery_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  enrollment_id uuid REFERENCES automation.enrollments(id) ON DELETE SET NULL, step_id uuid REFERENCES automation.sequence_steps(id) ON DELETE SET NULL,
  event_type text NOT NULL CHECK(event_type IN ('queued','sent','delivered','bounced','complained','failed','suppressed')),
  recipient citext NOT NULL, provider_id text, detail jsonb NOT NULL DEFAULT '{}', occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS delivery_events_org_time_idx ON automation.delivery_events(organization_id,occurred_at DESC);
COMMIT;
