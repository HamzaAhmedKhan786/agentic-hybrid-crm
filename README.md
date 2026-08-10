# Orbit — Agentic Hybrid CRM

Orbit is an independent, multi-workspace CRM connected to Autonomous Sales Prospector (ASP). PostgreSQL is the operational source of truth. Groq agents retrieve context and propose structured actions; deterministic PostgreSQL policies, human approvals and immutable audits control mutations.

## Product surface

- Responsive web app: dashboard, accounts, contacts, leads, pipeline, activities, sequences, agents, approvals, knowledge, integrations, team, audit/privacy and settings.
- Session authentication, organization memberships and workspace context.
- CRM assistant plus qualification, research, pipeline-risk, email, data-quality and MCP agent modes.
- PostgreSQL RAG ingestion, overlap chunking, full-text retrieval and citations.
- MCP JSON-RPC endpoint with tool discovery/calls and approval boundaries for writes.
- CRM records, workflows, sequences, notifications, jobs, usage, audit and GDPR storage.
- Idempotent ASP ingestion, bounded bulk import, transactional outbox and Snowflake-ready semantic views.

## Local setup

```powershell
npm install
Copy-Item .env.example .env
npm run db:migrate
npm run db:seed
npm run dev
```

Run `npm run worker` separately and open `http://localhost:4100`.

Synthetic login: `maya.chen@example.test`; password is `BOOTSTRAP_ADMIN_PASSWORD`, or `ChangeMe123!` when omitted for local development. Change it before exposing the service. Never commit `.env`.

## Important endpoints

- `POST /api/v1/auth/login`
- `GET /api/v1/dashboard` and `GET /api/v1/{resource}`
- `POST /api/v1/agents/run`
- `POST /api/v1/agent/recommendations/:id/{approve|reject|execute}`
- `POST /api/v1/knowledge/documents`, `GET /api/v1/knowledge/search`
- `POST /api/v1/mcp`
- `POST /api/v1/asp/prospects`, `POST /api/v1/bulk/prospects`
- `POST /api/v1/privacy/requests`

All CRM routes require a session token or API key and organization context. ASP uses its shared secret.

## Validation

```powershell
npm run build
npm test
npm run db:check
```

See [architecture](docs/architecture.md), [agents](docs/agents.md), [API guide](docs/api.md), [security](docs/security.md) and [runbook](docs/runbook.md).
