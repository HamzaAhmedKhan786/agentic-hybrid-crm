BEGIN;
ALTER TABLE crm.accounts DROP CONSTRAINT IF EXISTS accounts_organization_id_domain_key;
ALTER TABLE crm.contacts DROP CONSTRAINT IF EXISTS contacts_organization_id_email_key;
ALTER TABLE crm.contacts DROP CONSTRAINT IF EXISTS contacts_organization_id_normalized_linkedin_url_key;
CREATE UNIQUE INDEX IF NOT EXISTS accounts_org_domain_unique ON crm.accounts(organization_id,domain) WHERE domain IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS contacts_org_email_unique ON crm.contacts(organization_id,email) WHERE email IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS contacts_org_linkedin_unique ON crm.contacts(organization_id,normalized_linkedin_url) WHERE normalized_linkedin_url IS NOT NULL;
COMMIT;
