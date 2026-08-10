BEGIN;
CREATE SCHEMA IF NOT EXISTS support;
CREATE TABLE IF NOT EXISTS support.tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  created_by uuid REFERENCES identity.users(id) ON DELETE SET NULL, category text NOT NULL CHECK(category IN ('issue','complaint','feedback','privacy','billing')),
  subject text NOT NULL, description text NOT NULL, severity text NOT NULL DEFAULT 'normal' CHECK(severity IN ('low','normal','high','critical')),
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','investigating','resolved','closed')), app_version text NOT NULL,
  page_url text, metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS support_tickets_org_status_idx ON support.tickets(organization_id,status,created_at DESC);
COMMIT;
