BEGIN;

CREATE OR REPLACE FUNCTION crm.normalize_linkedin_url(value text) RETURNS text LANGUAGE sql IMMUTABLE STRICT AS $$
  SELECT lower(regexp_replace(regexp_replace(value, '[?#].*$', ''), '/$', ''))
$$;

CREATE OR REPLACE FUNCTION crm.touch_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at=now(); NEW.version=OLD.version+1; RETURN NEW; END $$;
CREATE TRIGGER account_touch BEFORE UPDATE ON crm.accounts FOR EACH ROW EXECUTE FUNCTION crm.touch_version();
CREATE TRIGGER contact_touch BEFORE UPDATE ON crm.contacts FOR EACH ROW EXECUTE FUNCTION crm.touch_version();
CREATE TRIGGER opportunity_touch BEFORE UPDATE ON crm.opportunities FOR EACH ROW EXECUTE FUNCTION crm.touch_version();

CREATE OR REPLACE FUNCTION integration.enqueue_event(p_org uuid,p_type text,p_id uuid,p_event text,p_payload jsonb,p_correlation text DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE event_id uuid:=gen_random_uuid(); BEGIN
  INSERT INTO integration.outbox_events(id,organization_id,aggregate_type,aggregate_id,event_type,payload,correlation_id) VALUES(event_id,p_org,p_type,p_id,p_event,p_payload,p_correlation);
  RETURN event_id;
END $$;

CREATE OR REPLACE FUNCTION crm.move_opportunity_stage(p_org uuid,p_opportunity uuid,p_stage uuid,p_expected_version integer,p_actor text,p_correlation text DEFAULT NULL) RETURNS crm.opportunities LANGUAGE plpgsql AS $$
DECLARE current_row crm.opportunities; target crm.pipeline_stages; BEGIN
  SELECT * INTO current_row FROM crm.opportunities WHERE id=p_opportunity AND organization_id=p_org FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'opportunity_not_found'; END IF;
  IF current_row.version<>p_expected_version THEN RAISE EXCEPTION 'version_conflict'; END IF;
  SELECT * INTO target FROM crm.pipeline_stages WHERE id=p_stage AND pipeline_id=current_row.pipeline_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid_pipeline_stage'; END IF;
  UPDATE crm.opportunities SET stage_id=p_stage WHERE id=p_opportunity RETURNING * INTO current_row;
  INSERT INTO governance.audit_log(organization_id,actor_type,actor_id,action,entity_type,entity_id,before_data,after_data,correlation_id) VALUES(p_org,'api',p_actor,'opportunity.stage_changed','opportunity',p_opportunity::text,jsonb_build_object('stage_id',current_row.stage_id),to_jsonb(current_row),p_correlation);
  PERFORM integration.enqueue_event(p_org,'opportunity',p_opportunity,'opportunity.stage_changed',to_jsonb(current_row),p_correlation);
  RETURN current_row;
END $$;

CREATE OR REPLACE FUNCTION crm.upsert_asp_prospect(p_org uuid,p_payload jsonb,p_actor text,p_correlation text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE account_row crm.accounts; contact_row crm.contacts; lead_row crm.leads; linkedin text; BEGIN
  linkedin:=crm.normalize_linkedin_url(p_payload->>'linkedin_url');
  SELECT * INTO account_row FROM crm.accounts WHERE organization_id=p_org AND (domain=NULLIF(lower(p_payload->>'company_domain'),'')::citext OR normalized_name=lower(trim(p_payload->>'company')) ) LIMIT 1;
  IF NOT FOUND THEN INSERT INTO crm.accounts(organization_id,name,normalized_name,domain,source) VALUES(p_org,p_payload->>'company',lower(trim(p_payload->>'company')),NULLIF(p_payload->>'company_domain','')::citext,'asp') RETURNING * INTO account_row; END IF;
  SELECT * INTO contact_row FROM crm.contacts WHERE organization_id=p_org AND normalized_linkedin_url=linkedin LIMIT 1;
  IF NOT FOUND THEN
    INSERT INTO crm.contacts(organization_id,account_id,first_name,last_name,title,linkedin_url,normalized_linkedin_url,source)
    VALUES(p_org,account_row.id,coalesce(p_payload->>'first_name','Unknown'),coalesce(p_payload->>'last_name',''),p_payload->>'title',p_payload->>'linkedin_url',linkedin,'asp') RETURNING * INTO contact_row;
  ELSE UPDATE crm.contacts SET account_id=account_row.id,title=coalesce(p_payload->>'title',contact_row.title) WHERE id=contact_row.id RETURNING * INTO contact_row; END IF;
  SELECT * INTO lead_row FROM crm.leads WHERE organization_id=p_org AND contact_id=contact_row.id AND status NOT IN ('converted','disqualified') LIMIT 1;
  IF NOT FOUND THEN INSERT INTO crm.leads(organization_id,contact_id,source,score,score_explanation) VALUES(p_org,contact_row.id,'asp',coalesce((p_payload->>'score')::integer,0),coalesce(p_payload->'score_explanation','{}')) RETURNING * INTO lead_row; END IF;
  PERFORM integration.enqueue_event(p_org,'lead',lead_row.id,'asp.prospect_ingested',jsonb_build_object('account_id',account_row.id,'contact_id',contact_row.id,'lead_id',lead_row.id),p_correlation);
  INSERT INTO governance.audit_log(organization_id,actor_type,actor_id,action,entity_type,entity_id,after_data,correlation_id) VALUES(p_org,'integration',p_actor,'asp.prospect_ingested','lead',lead_row.id::text,p_payload,p_correlation);
  RETURN jsonb_build_object('account_id',account_row.id,'contact_id',contact_row.id,'lead_id',lead_row.id);
END $$;

CREATE OR REPLACE FUNCTION agent.execute_approved_action(p_org uuid,p_recommendation uuid,p_actor uuid) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE recommendation agent.recommendations; result jsonb; BEGIN
  SELECT * INTO recommendation FROM agent.recommendations WHERE id=p_recommendation AND organization_id=p_org FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'recommendation_not_found'; END IF;
  IF recommendation.status<>'approved' THEN RAISE EXCEPTION 'recommendation_not_approved'; END IF;
  CASE recommendation.action_type
    WHEN 'update_lead_score' THEN
      UPDATE crm.leads SET score=greatest(0,least(100,(recommendation.payload->>'score')::integer)),score_explanation=recommendation.payload->'explanation',updated_at=now() WHERE id=recommendation.target_id AND organization_id=p_org;
      result:=jsonb_build_object('lead_id',recommendation.target_id,'score',recommendation.payload->>'score');
    WHEN 'create_task' THEN
      INSERT INTO activity.activities(organization_id,contact_id,type,subject,body,created_by) VALUES(p_org,recommendation.target_id,'task',recommendation.payload->>'subject',recommendation.payload->>'body',p_actor) RETURNING jsonb_build_object('activity_id',id) INTO result;
    ELSE RAISE EXCEPTION 'action_type_not_allowed';
  END CASE;
  UPDATE agent.recommendations SET status='executed' WHERE id=p_recommendation;
  INSERT INTO governance.audit_log(organization_id,actor_type,actor_id,action,entity_type,entity_id,after_data) VALUES(p_org,'user',p_actor::text,'agent.action_executed','recommendation',p_recommendation::text,result);
  RETURN result;
END $$;

CREATE OR REPLACE VIEW analytics.crm_semantic_accounts AS
SELECT a.organization_id,a.id account_id,a.name,a.domain,a.industry,a.employee_count,
  count(DISTINCT c.id) contact_count,count(DISTINCT o.id) opportunity_count,
  coalesce(sum(o.amount) FILTER (WHERE ps.is_closed=false),0) open_pipeline_value,
  max(act.occurred_at) last_activity_at
FROM crm.accounts a LEFT JOIN crm.contacts c ON c.account_id=a.id LEFT JOIN crm.opportunities o ON o.account_id=a.id
LEFT JOIN crm.pipeline_stages ps ON ps.id=o.stage_id LEFT JOIN activity.activities act ON act.account_id=a.id GROUP BY a.organization_id,a.id;

CREATE OR REPLACE VIEW analytics.crm_semantic_pipeline AS
SELECT o.organization_id,o.id opportunity_id,o.name opportunity_name,a.id account_id,a.name account_name,p.name pipeline,ps.name stage,ps.probability,o.amount,o.currency,o.expected_close_date,o.owner_user_id,o.updated_at
FROM crm.opportunities o JOIN crm.accounts a ON a.id=o.account_id JOIN crm.pipelines p ON p.id=o.pipeline_id JOIN crm.pipeline_stages ps ON ps.id=o.stage_id;

COMMIT;
