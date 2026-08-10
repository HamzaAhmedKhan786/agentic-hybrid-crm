# Architecture

## System boundaries

- ASP owns external prospect research, evidence gathering and personalized draft generation.
- CRM owns customer identity, account/contact truth, pipelines, activities, assignments and workflow execution.
- Snowflake receives asynchronous analytical copies; it is never on the transactional write path.

## Hybrid decision model

1. Events enter the transactional outbox in the same PostgreSQL transaction as the domain mutation.
2. Deterministic rules evaluate typed facts and produce allowed actions.
3. Agents may produce recommendations with evidence and confidence, never direct SQL.
4. Approval policy decides whether a recommendation can be auto-approved, needs human review or must be rejected.
5. A guarded stored procedure executes only an approved, allowlisted action.

## Integration

ASP uses `POST /api/v1/asp/prospects` with an organization ID, idempotency key, correlation ID and shared-secret authentication. CRM returns stable account/contact/lead identifiers. Replays return the original result.

Snowflake integration consumes `integration.outbox_events` or CDC. Semantic views expose organization-scoped account, pipeline, activity and agent-effectiveness facts.
