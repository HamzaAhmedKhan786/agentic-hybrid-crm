# System flows

## ASP to CRM

```mermaid
sequenceDiagram
  autonumber
  actor Rep
  participant ASP
  participant ASPDB as ASP SQLite
  participant Providers as Profile/Tavily/Groq
  participant Bridge as Orbit ingestion API
  participant DB as PostgreSQL
  Rep->>ASP: Research prospect
  ASP->>Providers: Enrich, research, draft
  Providers-->>ASP: Grounded result
  ASP->>ASPDB: Store prospect, evidence, draft and run
  ASP-->>Rep: Evidence + editable draft
  Rep->>ASP: Sync approved prospect
  ASP->>Bridge: POST prospect + shared secret + idempotency key
  Bridge->>Bridge: Authenticate tenant + validate schema
  Bridge->>DB: Deduplicate and upsert account/contact/lead
  Bridge->>DB: Store evidence activities, audit and outbox
  DB-->>Bridge: Account/contact/lead IDs
  Bridge-->>ASP: IDs + status
  ASP->>ASPDB: Persist provider, lead ID and synced time
  ASP-->>Rep: Synced to Orbit CRM
```

### Shared data contract

| ASP field | Orbit destination | Behavior |
| --- | --- | --- |
| LinkedIn URL | Contact identity key | Workspace-scoped duplicate detection |
| Name and role | Contact | Updated through the ingestion procedure |
| Company | Account | Reused when the normalized company matches |
| Score and explanation | Lead | Preserves the research origin |
| Evidence title, URL and summary | Research activity | Source remains inspectable |
| Correlation and idempotency keys | Integration/audit records | Safe retries without duplicate CRM records |

## Governed agent action

```mermaid
flowchart TD
  Q["User objective"] --> R["Deterministic agent router"]
  R --> K[RAG retrieval]
  R --> C[CRM context]
  K --> L[Groq generation]
  C --> L
  L --> V[Schema and deterministic policy validation]
  V -->|read-only| O[Return cited answer]
  V -->|state change| P[Pending recommendation]
  P --> H{Human decision}
  H -->|reject| A[Audit rejection]
  H -->|approve| X[Execute allowlisted tool or stored procedure]
  X --> D[(PostgreSQL + outbox)]
```

## RAG and MCP

```mermaid
flowchart LR
  D[Document] --> I[Validate and chunk]
  I --> S[(Knowledge store)]
  Q[Question] --> RET[Tenant-scoped retrieval]
  S --> RET
  RET --> GEN[LLM answer]
  GEN --> CIT[Answer + citations]
  MCP[MCP client] --> AUTH[Auth + organization boundary]
  AUTH --> REG[Tool registry]
  REG --> READ[Read tools]
  REG --> WRITE[Write recommendation]
  WRITE --> APPROVE[Approval boundary]
```

