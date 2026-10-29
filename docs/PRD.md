# Orbit CRM AI Product Requirements

## Product outcome

Orbit is the governed revenue system of record. AURA helps authenticated workspace members understand CRM data and prepare recommendations without bypassing permissions, approvals, consent, or audits.

## Governed AI architecture

- **LangGraph state machine:** guard request → choose bounded workflow → retrieve tenant context → invoke a specialist → evaluate the result.
- **JEV TypeSafe model:** optional typed domain and routing decisions. A deterministic local classifier remains the fallback and final security authority.
- **Supervisor and specialist handoffs:** AURA routes to research, qualification, pipeline-risk, email, data-quality, or MCP specialists.
- **Agentic RAG:** retrieval is workspace-scoped; source text is untrusted evidence and must be cited.
- **Evaluator/optimizer:** structured results are checked before a recommendation is returned.
- **Memory and HITL:** checkpoints support recovery; consequential writes require explicit approval.
- **MCP server:** read tools return tenant-scoped context. Write recommendations remain approval-gated.

Groq performs bounded language generation after authorization and retrieval. It is never the authorization layer.

## Safety and observability

Prompt-injection screening, secret stripping, tenant filters, schema validation, rate limits, audit records, Langfuse traces, Prometheus metrics, and Grafana dashboards provide defense in depth. No assistant may reveal credentials, access another workspace, send email, delete data, or execute a CRM mutation from chat.

## Acceptance criteria

1. AURA answers only CRM and revenue-workflow questions.
2. Every data query is scoped to the authenticated organization.
3. Suggested mutations enter the approval workflow and are audited.
4. JEV, Groq, or telemetry outages fail safely or use deterministic behavior.
5. Operators can correlate requests, agent runs, metrics, traces, and audit entries.
