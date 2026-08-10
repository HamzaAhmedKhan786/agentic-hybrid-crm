# Architecture

```mermaid
flowchart LR
  U["CRM users"] --> UI["Orbit web app"]
  ASP["Autonomous Sales Prospector"] --> API["Fastify API"]
  UI --> API
  API --> PG[("PostgreSQL 18")]
  API --> GROQ["Groq models"]
  API --> TAVILY["Tavily research"]
  API --> MCP["MCP tools"]
  PG --> W["Job and outbox worker"]
  W --> EMAIL["Email provider"]
  W --> SF["Snowflake / analytics"]
```

ASP owns external research and draft generation. CRM owns customer truth, pipeline, activity, governance and workflow execution. Snowflake is analytical and never on the transactional write path.

## Governed agent flow

```mermaid
sequenceDiagram
  actor User
  participant API
  participant DB as PostgreSQL
  participant LLM as Groq
  User->>API: Objective and agent type
  API->>DB: Create run and retrieve scoped evidence
  API->>LLM: Policy, facts and untrusted evidence
  LLM-->>API: Answer and recommendations
  API->>DB: Store steps, usage and pending actions
  API-->>User: Grounded answer and citations
  User->>API: Approve
  API->>DB: Execute allowlisted procedure, audit, outbox
```

## RAG and MCP

```mermaid
flowchart TD
  D["Document"] --> C["Normalize and chunk"] --> K[("knowledge.chunks")]
  Q["Question"] --> R["Workspace retrieval"]
  K --> R --> P["Grounded prompt"] --> A["Answer + citations"]
  M["MCP tools/list or tools/call"] --> T["Tool registry"]
  T --> READ["Scoped read"]
  T --> WRITE["Recommendation + approval"]
```

Agents never receive database credentials, emit direct SQL or execute arbitrary writes. Write tools become recommendations; stored procedures enforce the allowlist.
