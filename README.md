# Agentic Hybrid CRM

An independent CRM service designed to connect with Autonomous Sales Prospector (ASP). PostgreSQL is the operational system of record. Deterministic rules control mutations; LLM agents may recommend actions but cannot bypass validation or approval policies.

## Initial scope

- Organizations, users, memberships, roles and API clients
- Accounts, contacts, leads, pipelines, opportunities and activities
- Versioned deterministic rules and workflow execution records
- Agent runs, evidence, recommendations and approvals
- Immutable audit records and transactional outbox events
- Idempotent ASP ingestion API
- Snowflake-ready semantic export views and checkpoints

## Local setup

```powershell
npm install
Copy-Item .env.example .env
npm run db:migrate
npm run db:seed
npm run dev
```

The API listens on `http://localhost:4100` by default.

## Trust boundary

Agents propose structured actions. `crm.execute_approved_agent_action` and deterministic policies validate organization scope, approval status, action allowlists, and optimistic version checks before a CRM mutation is applied.
