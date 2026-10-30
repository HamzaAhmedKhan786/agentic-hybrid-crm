type SqlClient={
  (strings:TemplateStringsArray,...values:unknown[]):Promise<any[]>;
  json(value:unknown):unknown;
};

const stages=[['Discovery',1,15],['Qualified',2,35],['Proposal',3,65],['Negotiation',4,85],['Closed Won',5,100],['Closed Lost',6,0]] as const;
const companies=[['HelioGrid Systems','heliogrid.example','Energy software',420,125000,2],['Kestrel Robotics','kestrelrobotics.example','Industrial automation',180,86000,1],['LumenPay','lumenpay.example','Financial technology',760,210000,3],['Harbor Health AI','harborhealth.example','Healthcare technology',310,148000,4]] as const;

export async function seedStarterData(tx:SqlClient,organizationId:string){
  const [{count}]=await tx`select count(*)::int count from crm.accounts where organization_id=${organizationId}`;
  if(count>0)return{created:false};
  const [pipeline]=await tx`insert into crm.pipelines(organization_id,name,is_default) values(${organizationId},'New Business',true) on conflict(organization_id,name) do update set is_default=true returning id`;
  for(const[name,order,probability]of stages)await tx`insert into crm.pipeline_stages(pipeline_id,name,stage_order,probability,is_closed,is_won) values(${pipeline.id},${name},${order},${probability},${order>=5},${order===5}) on conflict(pipeline_id,stage_order) do update set name=excluded.name,probability=excluded.probability`;
  for(const[name,domain,industry,employees,amount,stageOrder]of companies){
    const[a]=await tx`insert into crm.accounts(organization_id,name,normalized_name,domain,industry,employee_count,source) values(${organizationId},${name},${name.toLowerCase()},${domain},${industry},${employees},'synthetic_starter') on conflict(organization_id,domain) where domain is not null do update set industry=excluded.industry returning id`;
    const first=name.split(' ')[0];
    const[c]=await tx`insert into crm.contacts(organization_id,account_id,first_name,last_name,email,title,linkedin_url,normalized_linkedin_url,source) values(${organizationId},${a.id},${first},'Decision Maker',${`buyer@${domain}`},'VP Revenue',${`https://linkedin.com/in/${first.toLowerCase()}-buyer`},${`https://linkedin.com/in/${first.toLowerCase()}-buyer`},'synthetic_starter') on conflict(organization_id,email) where email is not null do update set title=excluded.title returning id`;
    await tx`insert into crm.leads(organization_id,contact_id,status,score,score_explanation,source) select ${organizationId},${c.id},'working',72,${tx.json({synthetic:true,signals:['growth','new-market']})},'synthetic_starter' where not exists(select 1 from crm.leads where organization_id=${organizationId} and contact_id=${c.id})`;
    await tx`insert into crm.opportunities(organization_id,account_id,primary_contact_id,pipeline_id,stage_id,name,amount,expected_close_date) select ${organizationId},${a.id},${c.id},${pipeline.id},ps.id,${`${name} Expansion`},${amount},current_date+(${stageOrder*18}||' days')::interval from crm.pipeline_stages ps where ps.pipeline_id=${pipeline.id} and ps.stage_order=${stageOrder} and not exists(select 1 from crm.opportunities where organization_id=${organizationId} and account_id=${a.id} and name=${`${name} Expansion`})`;
  }
  return{created:true};
}
