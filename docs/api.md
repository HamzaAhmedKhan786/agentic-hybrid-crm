# API guide

All request and response bodies are JSON. CRM calls use `Authorization: Bearer <session-or-api-key>` and `x-organization-id`. ASP calls use the shared-secret bearer token plus `idempotency-key`.

## Agent run

```json
POST /api/v1/agents/run
{"agentType":"pipeline","objective":"Find deals at risk"}
```

The response contains `runId`, `answer`, `citations`, `recommendations` and `grounding`. Recommendations remain pending until approved.

## MCP

```json
POST /api/v1/mcp
{"jsonrpc":"2.0","id":1,"method":"tools/list"}
```

```json
POST /api/v1/mcp
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"retrieve_knowledge","arguments":{"query":"security requirements"}}}
```

## ASP prospect ingestion

`POST /api/v1/asp/prospects` accepts identity, company, score and cited evidence. Reusing an idempotency key with the same payload returns the original response; reusing it with different content returns `409`.

## Errors

Validation errors return `400`; authentication errors `401`; conflicts `409`; rate limiting `429`; unexpected errors `500`. Production responses omit internal exception details.
