import { config } from "./config.js";
import { sql } from "./db.js";
import { retrieveKnowledge } from "./rag.js";
import { parseAgentResponse, readProviderError } from "./agent-response.js";
import { AURA_SYSTEM_PROMPT } from "./prompts.js";
import { guardCrmObjective,safeAgentContext } from "./guardrails.js";
import {agentLatency,agentRuns} from "./metrics.js";

type AgentInput={organizationId:string;userId?:string;agentType:string;objective:string;context?:Record<string,unknown>};
const agentGuidance:Record<string,string>={assistant:"Answer CRM questions with grounded evidence and concise next steps.",qualification:"Assess fit, intent, timing and data quality. Propose a lead score; never execute it.",research:"Build an account brief from supplied CRM and knowledge evidence.",pipeline:"Identify deal risk and propose next-best actions.",email:"Draft a factual, low-pressure email grounded in context.",data_quality:"Find duplicates and incomplete records; recommend safe corrections.",mcp:"Select registered tools but never bypass approval policies."};

async function crmContext(org:string,objective:string){
  const accounts=await sql`select account_id,name,domain,industry,contact_count,open_pipeline_value,last_activity_at from analytics.crm_semantic_accounts where organization_id=${org} and (name ilike ${'%'+objective.slice(0,80)+'%'} or ${objective.length<3}) limit 8`;
  const pipeline=await sql`select opportunity_id,opportunity_name,account_name,stage,probability,amount,currency,expected_close_date from analytics.crm_semantic_pipeline where organization_id=${org} order by amount desc limit 12`;
  return{accounts,pipeline};
}

export async function runAgent(input:AgentInput){
  input={...input,objective:guardCrmObjective(input.objective),context:safeAgentContext(input.context||{}) as Record<string,unknown>};
  const model=config.GROQ_MODEL;
  const [run]=await sql`insert into agent.runs(organization_id,agent_type,model,objective,status) values(${input.organizationId},${input.agentType},${model},${input.objective},'running') returning id,started_at`;
  const started=Date.now();
  try{
    const knowledge=await retrieveKnowledge(input.organizationId,input.objective);
    const crm=await crmContext(input.organizationId,input.objective);
    await sql`insert into agent.run_steps(run_id,step_order,kind,input,output) values(${run.id},1,'retrieve',${sql.json({query:input.objective})},${sql.json({knowledge,crm})})`;
    if(!config.GROQ_API_KEY)throw new Error("GROQ_API_KEY is not configured");
    const response=await fetch(`${config.GROQ_BASE_URL}/chat/completions`,{
      method:"POST",headers:{authorization:`Bearer ${config.GROQ_API_KEY}`,"content-type":"application/json"},
      body:JSON.stringify({model,messages:[{role:"system",content:`${AURA_SYSTEM_PROMPT}\nSpecialist policy: ${agentGuidance[input.agentType]||agentGuidance.assistant}\nReturn JSON with keys answer, recommendations (array of {actionType,targetType,targetId,payload,confidence,rationale}), and citations (array of chunk ids).`},{role:"user",content:JSON.stringify({objective:input.objective,context:input.context||{},crm,knowledge})}],response_format:{type:"json_object"},temperature:0.2}),
      signal:AbortSignal.timeout(45_000)
    });
    if(!response.ok)throw new Error(await readProviderError(response));
    const payload:any=await response.json();
    const usage=payload.usage||{};
    const parsed=parseAgentResponse(payload.choices?.[0]?.message?.content);
    await sql.begin(async tx=>{
      await tx`insert into agent.run_steps(run_id,step_order,kind,input,output,duration_ms) values(${run.id},2,'model',${tx.json({model})},${tx.json(parsed as never)},${Date.now()-started})`;
      for(const item of parsed.recommendations.slice(0,config.AGENT_MAX_ACTIONS_PER_RUN))await tx`insert into agent.recommendations(run_id,organization_id,action_type,target_type,target_id,payload,confidence,rationale,requires_human) values(${run.id},${input.organizationId},${item.actionType},${item.targetType},${item.targetId||null},${tx.json(item.payload as never)},${item.confidence},${item.rationale},${config.AGENT_ACTIONS_REQUIRE_APPROVAL==='true'})`;
      await tx`update agent.runs set status='completed',input_tokens=${usage.prompt_tokens||0},output_tokens=${usage.completion_tokens||0},completed_at=now() where id=${run.id}`;
      await tx`insert into agent.usage_events(organization_id,run_id,provider,model,input_tokens,output_tokens,latency_ms) values(${input.organizationId},${run.id},'groq',${model},${usage.prompt_tokens||0},${usage.completion_tokens||0},${Date.now()-started})`;
    });
    agentRuns.inc({agent:input.agentType,status:"completed"});agentLatency.observe({agent:input.agentType},(Date.now()-started)/1000);
    return{runId:run.id,...parsed,grounding:knowledge};
  }catch(error){
    agentRuns.inc({agent:input.agentType,status:"failed"});agentLatency.observe({agent:input.agentType},(Date.now()-started)/1000);
    await sql`update agent.runs set status='failed',error=${error instanceof Error?error.message:String(error)},completed_at=now() where id=${run.id}`;
    throw error;
  }
}
