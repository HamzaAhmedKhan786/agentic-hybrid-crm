import { config } from "./config.js";

export type OutboundEmail={to:string;subject:string;html:string;text?:string};
export async function sendEmail(message:OutboundEmail){if(!config.EMAIL_API_KEY||!config.EMAIL_FROM)throw new Error("Email provider is not configured");const response=await fetch(config.EMAIL_API_URL,{method:"POST",headers:{authorization:`Bearer ${config.EMAIL_API_KEY}`,"content-type":"application/json"},body:JSON.stringify({from:config.EMAIL_FROM,to:[message.to],subject:message.subject,html:message.html,text:message.text}),signal:AbortSignal.timeout(20_000)});if(!response.ok)throw new Error(`Email provider returned ${response.status}: ${(await response.text()).slice(0,500)}`);const body=await response.json() as {id?:string};return{id:body.id||"unknown"};}
