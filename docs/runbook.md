# Operations runbook

1. Run `npm run db:check`, `npm run db:migrate`, then `npm run db:seed`.
2. Run API (`npm run dev`) and worker (`npm run worker`) separately.
3. Verify `/health`, login, dashboard, knowledge ingestion and an assistant run.
4. Inspect `agent.runs`, `agent.run_steps`, `agent.usage_events`, `governance.audit_log`, `agent.jobs` and `integration.outbox_events` during incidents.
5. Failed jobs retry with backoff and become `dead` at their attempt budget.
6. Back up before migrations and verify backups daily in production.
7. Rotate Groq, Tavily, email, ASP and API credentials independently.
