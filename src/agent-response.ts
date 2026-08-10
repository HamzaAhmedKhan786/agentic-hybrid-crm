import { z } from "zod";

const recommendation = z.object({
  actionType: z.string().trim().min(1).max(80),
  targetType: z.string().trim().min(1).max(80),
  targetId: z.string().uuid().nullable().optional(),
  payload: z.record(z.unknown()).default({}),
  confidence: z.coerce.number().min(0).max(1).default(0),
  rationale: z.string().trim().min(1).max(2_000),
}).strict();

export const agentResponseSchema = z.object({
  answer: z.string().max(50_000).default(""),
  recommendations: z.array(recommendation).max(100).default([]),
  citations: z.array(z.string().uuid()).max(100).default([]),
}).strict();

export function parseAgentResponse(content: unknown) {
  if (typeof content !== "string" || content.length > 250_000) throw new Error("invalid_agent_response");
  try { return agentResponseSchema.parse(JSON.parse(content)); }
  catch { throw new Error("invalid_agent_response"); }
}

export async function readProviderError(response: Response) {
  const text = await response.text();
  // Provider bodies may contain prompts or credentials. Never propagate them to clients/logs.
  return `provider_request_failed_${response.status}${text ? "_with_body" : ""}`;
}
