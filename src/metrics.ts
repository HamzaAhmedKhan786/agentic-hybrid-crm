import {collectDefaultMetrics,Counter,Histogram,Registry} from "prom-client";
export const metricsRegistry=new Registry();collectDefaultMetrics({register:metricsRegistry,prefix:"orbit_"});
export const agentRuns=new Counter({name:"orbit_agent_runs_total",help:"Governed agent runs",labelNames:["agent","status"] as const,registers:[metricsRegistry]});
export const agentLatency=new Histogram({name:"orbit_agent_duration_seconds",help:"Governed agent run duration",labelNames:["agent"] as const,buckets:[.1,.25,.5,1,2,5,10,30,60],registers:[metricsRegistry]});
