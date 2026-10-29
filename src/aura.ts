import {Annotation,MemorySaver,START,END,StateGraph} from "@langchain/langgraph";
import {guardCrmObjective,safeAgentContext} from "./guardrails.js";
import {orchestrate} from "./orchestrator.js";
import {jevRouteCrm} from "./jev.js";
import {runAgent} from "./agents.js";

const AuraState=Annotation.Root({organizationId:Annotation<string>(),userId:Annotation<string|undefined>(),objective:Annotation<string>(),context:Annotation<Record<string,unknown>|undefined>(),route:Annotation<string|undefined>(),plan:Annotation<Record<string,unknown>|undefined>(),result:Annotation<Record<string,unknown>|undefined>(),evaluation:Annotation<Record<string,unknown>|undefined>()});
const auraGraph=new StateGraph(AuraState)
 .addNode("guard",async state=>({objective:guardCrmObjective(state.objective),context:safeAgentContext(state.context||{}) as Record<string,unknown>}))
 .addNode("supervise",async state=>{const deterministic=orchestrate(state.objective);const decision=await jevRouteCrm(state.objective,deterministic.primary);if(!decision.domainAllowed)throw new Error("AURA rejected an out-of-domain request.");return{route:decision.route,plan:{...orchestrate(state.objective),primary:decision.route,decisionLayer:decision}}})
 .addNode("execute",async state=>({result:await runAgent({organizationId:state.organizationId,userId:state.userId,agentType:state.route||"assistant",objective:state.objective,context:state.context})}))
 .addNode("evaluate",async state=>{const result=state.result as any;const grounded=Array.isArray(result?.citations)&&Array.isArray(result?.grounding);return{evaluation:{passed:Boolean(result?.answer)&&grounded,policy:"schema + citation + approval boundary",requiresHuman:Boolean((state.plan as any)?.requiresApproval)}}})
 .addEdge(START,"guard").addEdge("guard","supervise").addEdge("supervise","execute").addEdge("execute","evaluate").addEdge("evaluate",END)
 .compile({checkpointer:new MemorySaver()});

export async function runAura(input:{organizationId:string;userId?:string;objective:string;context?:Record<string,unknown>;threadId?:string}){return auraGraph.invoke(input,{configurable:{thread_id:input.threadId||crypto.randomUUID()}})}
