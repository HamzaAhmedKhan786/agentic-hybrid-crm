# Security and privacy

- Salted scrypt password hashes and hashed, expiring session tokens.
- Organization-scoped operational queries; provider secrets remain server-side.
- Retrieved evidence is treated as untrusted data.
- Human approval and stored-procedure allowlists protect agent mutations.
- ASP idempotency, optimistic versions and immutable audits.
- GDPR requests and retention policies are first-class records.

Before production add TLS, edge rate limiting, managed secrets/PostgreSQL, backups/PITR, SSO/MFA and independent security testing. Rotate credentials exposed in logs or chat.
