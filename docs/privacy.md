# Privacy and data governance runbook

This runbook supports engineering controls; it is not legal advice. The data controller must document lawful basis, notices, processor agreements and regional requirements before launch.

## Data inventory

CRM identity and sales records contain names, business contact details, activities, AI prompts/outputs, knowledge documents, usage records and audit events. Groq, Tavily, email, enrichment, hosting, monitoring and Snowflake vendors may become processors or sub-processors depending on configuration.

## Required controls

- Collect only fields needed for the documented sales purpose; prohibit sensitive-category inference.
- Show source and timestamp for researched evidence and keep generated text distinguishable from verified facts.
- Require human approval for external communications and state-changing agent tools.
- Restrict organization data by membership and role; test cross-tenant denial on every release.
- Encrypt transport and storage, rotate secrets, redact authorization headers and personal content from logs.
- Configure retention per data class and run deletion jobs on a documented schedule.
- Record access, rectification, export and deletion requests; verify identity before fulfillment.
- Apply deletion across CRM, ASP, knowledge chunks, provider systems, exports and backups according to policy.

## Data-subject request procedure

1. Record the request in the privacy request API and assign an owner and deadline.
2. Verify identity without collecting excessive additional data.
3. Search identity, CRM, activity, knowledge, agent, integration and audit schemas plus ASP.
4. Export in a readable structured format or execute approved rectification/deletion.
5. Notify downstream processors and record exceptions/retention obligations.
6. Close with evidence in the audit trail; never place secrets in the case record.

## Incident procedure

Contain access, preserve relevant audit evidence, rotate affected credentials, determine subjects/data/time window, consult the privacy owner about notification deadlines, remediate, and record a blameless post-incident review.

