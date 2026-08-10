import { describe, expect, it } from "vitest";
import { parseAgentResponse, readProviderError } from "../src/agent-response.js";

describe("agent provider boundary",()=>{
  it("accepts a grounded mocked provider response",()=>{
    const result=parseAgentResponse(JSON.stringify({answer:"Grounded answer",recommendations:[],citations:["11111111-1111-4111-8111-111111111111"]}));
    expect(result.answer).toBe("Grounded answer");
  });
  it("rejects malformed, excessive, and unknown model output",()=>{
    expect(()=>parseAgentResponse("not json")).toThrow("invalid_agent_response");
    expect(()=>parseAgentResponse(JSON.stringify({answer:"x",recommendations:[],citations:[],escape:true}))).toThrow("invalid_agent_response");
    expect(()=>parseAgentResponse("x".repeat(250_001))).toThrow("invalid_agent_response");
  });
  it("does not disclose provider response bodies",async()=>{
    const message=await readProviderError(new Response("prompt and secret",{status:429}));
    expect(message).toBe("provider_request_failed_429_with_body");
    expect(message).not.toContain("secret");
  });
});
