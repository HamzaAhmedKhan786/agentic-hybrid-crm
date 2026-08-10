# Configuration reference

| Variable | Required | Purpose |
|---|---:|---|
| `DATABASE_URL` | yes | PostgreSQL connection URI; require TLS in production |
| `HOST` / `PORT` | yes | Bind address and API port (`0.0.0.0:4100` in containers) |
| `APP_URL` | yes | Canonical public HTTPS origin |
| `API_KEY` | yes | Long admin/service credential for protected setup/service calls |
| `ASP_SHARED_SECRET` | for ASP | Bearer secret shared only with ASP |
| `SESSION_TTL_HOURS` | yes | Server-session lifetime |
| `BOOTSTRAP_ADMIN_PASSWORD` | bootstrap only | Initial provisioning; remove after setup |
| `GROQ_API_KEY`, `GROQ_MODEL`, `GROQ_BASE_URL` | for AI | Model provider configuration |
| `TAVILY_API_KEY`, `TAVILY_API_URL` | for web research | Search provider configuration |
| `AGENT_ACTIONS_REQUIRE_APPROVAL` | yes | Keep `true` in production unless an action has a separately approved policy |
| `AGENT_MAX_ACTIONS_PER_RUN` | yes | Hard bound on an agent run |
| `OUTBOX_POLL_INTERVAL_MS` | worker | Delivery-worker polling interval |
| `SNOWFLAKE_*` | optional | Analytics destination; omit until enabled |

Generate secrets with a cryptographic random generator (at least 32 bytes). Do not use `${VARIABLE}` interpolation inside Node env files; inject the final value. URL-encode reserved password characters in connection URIs. Validate startup with `/health` and never print the effective configuration.

