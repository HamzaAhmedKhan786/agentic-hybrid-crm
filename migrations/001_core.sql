BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS crm;
CREATE SCHEMA IF NOT EXISTS activity;
CREATE SCHEMA IF NOT EXISTS automation;
CREATE SCHEMA IF NOT EXISTS agent;
CREATE SCHEMA IF NOT EXISTS integration;
CREATE SCHEMA IF NOT EXISTS governance;
CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE identity.organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, slug text UNIQUE NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','suspended','deleted')),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE identity.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email citext UNIQUE NOT NULL, display_name text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','disabled')), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE identity.memberships (
  organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK(role IN ('owner','admin','manager','seller','analyst')),
  created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(organization_id,user_id)
);
CREATE TABLE identity.api_clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  name text NOT NULL, key_hash text UNIQUE NOT NULL, scopes text[] NOT NULL DEFAULT '{}', last_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), revoked_at timestamptz
);

CREATE TABLE crm.accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  name text NOT NULL, normalized_name text NOT NULL, domain citext, industry text, employee_count integer,
  annual_revenue numeric(18,2), owner_user_id uuid REFERENCES identity.users(id), source text NOT NULL DEFAULT 'manual',
  external_ids jsonb NOT NULL DEFAULT '{}', version integer NOT NULL DEFAULT 1, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE NULLS NOT DISTINCT(organization_id,domain)
);
CREATE TABLE crm.contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  account_id uuid REFERENCES crm.accounts(id) ON DELETE SET NULL, first_name text NOT NULL, last_name text NOT NULL,
  email citext, phone text, title text, linkedin_url text, normalized_linkedin_url text, owner_user_id uuid REFERENCES identity.users(id),
  consent_status text NOT NULL DEFAULT 'unknown' CHECK(consent_status IN ('unknown','legitimate_interest','consented','opted_out')),
  source text NOT NULL DEFAULT 'manual', external_ids jsonb NOT NULL DEFAULT '{}', version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE NULLS NOT DISTINCT(organization_id,email), UNIQUE NULLS NOT DISTINCT(organization_id,normalized_linkedin_url)
);
CREATE TABLE crm.leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  contact_id uuid NOT NULL REFERENCES crm.contacts(id) ON DELETE CASCADE, status text NOT NULL DEFAULT 'new' CHECK(status IN ('new','working','qualified','disqualified','converted')),
  score integer NOT NULL DEFAULT 0 CHECK(score BETWEEN 0 AND 100), score_explanation jsonb NOT NULL DEFAULT '{}', owner_user_id uuid REFERENCES identity.users(id),
  source text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE crm.pipelines (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE, name text NOT NULL, is_default boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(organization_id,name));
CREATE TABLE crm.pipeline_stages (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), pipeline_id uuid NOT NULL REFERENCES crm.pipelines(id) ON DELETE CASCADE, name text NOT NULL, stage_order integer NOT NULL, probability numeric(5,2) NOT NULL CHECK(probability BETWEEN 0 AND 100), is_closed boolean NOT NULL DEFAULT false, is_won boolean NOT NULL DEFAULT false, UNIQUE(pipeline_id,stage_order));
CREATE TABLE crm.opportunities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  account_id uuid NOT NULL REFERENCES crm.accounts(id), primary_contact_id uuid REFERENCES crm.contacts(id), pipeline_id uuid NOT NULL REFERENCES crm.pipelines(id), stage_id uuid NOT NULL REFERENCES crm.pipeline_stages(id),
  name text NOT NULL, amount numeric(18,2) NOT NULL DEFAULT 0, currency char(3) NOT NULL DEFAULT 'USD', expected_close_date date,
  owner_user_id uuid REFERENCES identity.users(id), version integer NOT NULL DEFAULT 1, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE activity.activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  account_id uuid REFERENCES crm.accounts(id) ON DELETE CASCADE, contact_id uuid REFERENCES crm.contacts(id) ON DELETE CASCADE, opportunity_id uuid REFERENCES crm.opportunities(id) ON DELETE CASCADE,
  type text NOT NULL CHECK(type IN ('note','email','call','meeting','task','research')), subject text, body text, occurred_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES identity.users(id), metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE automation.rule_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid REFERENCES identity.organizations(id) ON DELETE CASCADE,
  key text NOT NULL, name text NOT NULL, version integer NOT NULL, trigger_type text NOT NULL, conditions jsonb NOT NULL, actions jsonb NOT NULL,
  enabled boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE NULLS NOT DISTINCT(organization_id,key,version)
);
CREATE TABLE automation.executions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  rule_id uuid REFERENCES automation.rule_definitions(id), trigger_event_id uuid, status text NOT NULL CHECK(status IN ('running','succeeded','failed','skipped')),
  input jsonb NOT NULL, output jsonb, error text, started_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz
);

CREATE TABLE agent.runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE,
  agent_type text NOT NULL, model text NOT NULL, objective text NOT NULL, status text NOT NULL CHECK(status IN ('running','completed','failed','cancelled')),
  input_tokens integer NOT NULL DEFAULT 0, output_tokens integer NOT NULL DEFAULT 0, started_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz, error text
);
CREATE TABLE agent.evidence (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), run_id uuid NOT NULL REFERENCES agent.runs(id) ON DELETE CASCADE, source_type text NOT NULL, source_uri text, content_hash text NOT NULL, excerpt text NOT NULL, metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE agent.recommendations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), run_id uuid NOT NULL REFERENCES agent.runs(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE, action_type text NOT NULL,
  target_type text NOT NULL, target_id uuid, payload jsonb NOT NULL, confidence numeric(5,4) CHECK(confidence BETWEEN 0 AND 1),
  rationale text NOT NULL, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected','executed','failed')),
  requires_human boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(), decided_at timestamptz, decided_by uuid REFERENCES identity.users(id)
);

CREATE TABLE integration.idempotency_keys (organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE, source text NOT NULL, key text NOT NULL, request_hash text NOT NULL, response_status integer, response_body jsonb, created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL, PRIMARY KEY(organization_id,source,key));
CREATE TABLE integration.outbox_events (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id) ON DELETE CASCADE, aggregate_type text NOT NULL, aggregate_id uuid NOT NULL, event_type text NOT NULL, payload jsonb NOT NULL, correlation_id text, created_at timestamptz NOT NULL DEFAULT now(), published_at timestamptz, attempts integer NOT NULL DEFAULT 0, last_error text);
CREATE TABLE integration.sync_checkpoints (destination text NOT NULL, stream text NOT NULL, cursor_value text NOT NULL, updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(destination,stream));

CREATE TABLE governance.audit_log (id bigserial PRIMARY KEY, organization_id uuid, actor_type text NOT NULL, actor_id text, action text NOT NULL, entity_type text NOT NULL, entity_id text, before_data jsonb, after_data jsonb, correlation_id text, occurred_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE governance.data_requests (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES identity.organizations(id), subject_type text NOT NULL, subject_identifier text NOT NULL, request_type text NOT NULL CHECK(request_type IN ('access','export','rectification','deletion')), status text NOT NULL DEFAULT 'open', requested_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz, result jsonb);

CREATE INDEX accounts_org_name_idx ON crm.accounts(organization_id,normalized_name);
CREATE INDEX contacts_org_account_idx ON crm.contacts(organization_id,account_id);
CREATE INDEX activities_org_time_idx ON activity.activities(organization_id,occurred_at DESC);
CREATE INDEX outbox_unpublished_idx ON integration.outbox_events(created_at) WHERE published_at IS NULL;
CREATE INDEX recommendations_pending_idx ON agent.recommendations(organization_id,created_at) WHERE status='pending';
COMMIT;
