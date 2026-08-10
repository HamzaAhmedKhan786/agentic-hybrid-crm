BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE SCHEMA IF NOT EXISTS knowledge;

ALTER TABLE identity.users ADD COLUMN IF NOT EXISTS password_hash text;
CREATE TABLE IF NOT EXISTS identity.sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  token_hash text UNIQUE NOT NULL, expires_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), last_seen_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS knowledge.documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  title text NOT NULL, source_uri text, mime_type text NOT NULL DEFAULT 'text/plain', content text NOT NULL,
  status text NOT NULL DEFAULT 'ready' CHECK(status IN ('processing','ready','failed')), metadata jsonb NOT NULL DEFAULT '{}',
  created_by uuid REFERENCES identity.users(id), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS knowledge.chunks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  document_id uuid NOT NULL REFERENCES knowledge.documents(id) ON DELETE CASCADE, chunk_index integer NOT NULL, content text NOT NULL,
  search_vector tsvector GENERATED ALWAYS AS (to_tsvector('english', content)) STORED, metadata jsonb NOT NULL DEFAULT '{}',
  UNIQUE(document_id,chunk_index)
);
CREATE INDEX IF NOT EXISTS chunks_search_idx ON knowledge.chunks USING gin(search_vector);

CREATE TABLE IF NOT EXISTS agent.tool_registry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid REFERENCES identity.organizations(id) ON DELETE CASCADE,
  name text NOT NULL, description text NOT NULL, input_schema jsonb NOT NULL DEFAULT '{}', risk_level text NOT NULL DEFAULT 'read' CHECK(risk_level IN ('read','write','external')),
  enabled boolean NOT NULL DEFAULT true, handler text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE NULLS NOT DISTINCT(organization_id,name)
);
CREATE TABLE IF NOT EXISTS agent.run_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), run_id uuid NOT NULL REFERENCES agent.runs(id) ON DELETE CASCADE,
  step_order integer NOT NULL, kind text NOT NULL CHECK(kind IN ('plan','retrieve','tool','model','recommendation','final')),
  tool_name text, input jsonb NOT NULL DEFAULT '{}', output jsonb, status text NOT NULL DEFAULT 'completed', duration_ms integer, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(run_id,step_order)
);
CREATE TABLE IF NOT EXISTS agent.jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  job_type text NOT NULL, payload jsonb NOT NULL, status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','running','completed','failed','dead')),
  attempts integer NOT NULL DEFAULT 0, max_attempts integer NOT NULL DEFAULT 3, available_at timestamptz NOT NULL DEFAULT now(), locked_at timestamptz,
  last_error text, created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz
);
CREATE INDEX IF NOT EXISTS agent_jobs_ready_idx ON agent.jobs(available_at) WHERE status='queued';
CREATE TABLE IF NOT EXISTS agent.usage_events (
  id bigserial PRIMARY KEY, organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE, run_id uuid REFERENCES agent.runs(id) ON DELETE SET NULL,
  provider text NOT NULL, model text NOT NULL, input_tokens integer NOT NULL DEFAULT 0, output_tokens integer NOT NULL DEFAULT 0,
  latency_ms integer NOT NULL DEFAULT 0, estimated_cost numeric(12,6) NOT NULL DEFAULT 0, created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS integration.connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  provider text NOT NULL, display_name text NOT NULL, status text NOT NULL DEFAULT 'disconnected', config jsonb NOT NULL DEFAULT '{}', secret_ref text,
  last_sync_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(organization_id,provider)
);
CREATE TABLE IF NOT EXISTS automation.sequences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  name text NOT NULL, status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','active','paused','archived')), created_by uuid REFERENCES identity.users(id),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS automation.sequence_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), sequence_id uuid NOT NULL REFERENCES automation.sequences(id) ON DELETE CASCADE,
  step_order integer NOT NULL, channel text NOT NULL DEFAULT 'email', delay_minutes integer NOT NULL DEFAULT 0, subject_template text, body_template text NOT NULL,
  UNIQUE(sequence_id,step_order)
);
CREATE TABLE IF NOT EXISTS automation.enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), sequence_id uuid NOT NULL REFERENCES automation.sequences(id) ON DELETE CASCADE,
  contact_id uuid NOT NULL REFERENCES crm.contacts(id) ON DELETE CASCADE, status text NOT NULL DEFAULT 'active', current_step integer NOT NULL DEFAULT 0,
  next_action_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(sequence_id,contact_id)
);
CREATE TABLE IF NOT EXISTS activity.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES identity.users(id) ON DELETE CASCADE, title text NOT NULL, body text, read_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS governance.retention_policies (
  organization_id uuid PRIMARY KEY REFERENCES identity.organizations(id) ON DELETE CASCADE, prospect_days integer NOT NULL DEFAULT 365,
  activity_days integer NOT NULL DEFAULT 730, audit_days integer NOT NULL DEFAULT 2555, updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO agent.tool_registry(name,description,input_schema,risk_level,handler) VALUES
('search_crm','Search accounts, contacts, leads and activities','{"type":"object","properties":{"query":{"type":"string"}}}','read','searchCrm'),
('retrieve_knowledge','Retrieve grounded knowledge chunks with citations','{"type":"object","properties":{"query":{"type":"string"}}}','read','retrieveKnowledge'),
('create_task','Propose a follow-up task for a contact','{"type":"object","properties":{"contactId":{"type":"string"},"subject":{"type":"string"},"body":{"type":"string"}}}','write','createTask'),
('update_lead_score','Propose a deterministic lead-score update','{"type":"object","properties":{"leadId":{"type":"string"},"score":{"type":"number"}}}','write','updateLeadScore')
ON CONFLICT DO NOTHING;
COMMIT;
