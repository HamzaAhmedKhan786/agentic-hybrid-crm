import { describe, expect, it } from "vitest";
import { requireRole, resolveOrganization } from "../src/authorization.js";

const org="11111111-1111-4111-8111-111111111111";
const other="22222222-2222-4222-8222-222222222222";
const actor={user_id:"33333333-3333-4333-8333-333333333333",organization_id:org,role:"seller" as const};

describe("organization authorization",()=>{
  it("uses the membership organization",()=>expect(resolveOrganization(actor,undefined)).toBe(org));
  it("rejects cross-workspace headers",()=>expect(()=>resolveOrganization(actor,other)).toThrow("organization_mismatch"));
  it("permits explicit organizations only for service callers",()=>{
    expect(resolveOrganization(undefined,org,true)).toBe(org);
    expect(()=>resolveOrganization(undefined,org,false)).toThrow("organization_required");
  });
  it("enforces minimum roles",()=>{
    expect(requireRole(actor,"seller")).toBe(actor);
    expect(()=>requireRole(actor,"admin")).toThrow("insufficient_role");
  });
});
