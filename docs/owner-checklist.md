# Production owner checklist

## Must be supplied or decided by the owner

- [ ] Production domain, cloud provider, region and data residency
- [ ] Managed PostgreSQL and tested backup/restore policy
- [ ] Long random `API_KEY` and `ASP_SHARED_SECRET`; identical shared secret configured in ASP
- [ ] Groq and Tavily production keys, quotas, data-use settings and approved models
- [ ] Email domain, SPF, DKIM, DMARC, provider key, unsubscribe and bounce/reply webhooks
- [ ] Licensed profile-data provider and documented lawful basis for prospecting
- [ ] Snowflake/HubSpot credentials only if those integrations are enabled
- [ ] Privacy notice, retention periods, processor agreements and deletion owner
- [ ] Named human approvers for agent actions and outbound messages
- [ ] Monitoring/error-tracking destination and on-call contact
- [ ] Branding, legal entity, support address and terms

## Launch gate

- [ ] Change all bootstrap/demo passwords and remove synthetic records
- [ ] Disable public signup unless intentionally offered
- [ ] Confirm `HOST=0.0.0.0`, `APP_URL=https://...`, secure TLS and proxy headers
- [ ] Run migrations and a smoke test in staging
- [ ] Complete tenant-isolation, authorization, dependency and penetration testing
- [ ] Exercise rollback, database restore and privacy deletion
- [ ] Set provider spend limits and alert thresholds
- [ ] Obtain security/privacy/legal approval

