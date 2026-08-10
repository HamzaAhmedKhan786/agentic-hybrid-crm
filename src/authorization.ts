import { z } from "zod";

export const roles = ["analyst", "seller", "manager", "admin", "owner"] as const;
export type Role = (typeof roles)[number];
export type Actor = { user_id: string; organization_id: string; role: Role };

const roleRank: Record<Role, number> = {
  analyst: 0,
  seller: 1,
  manager: 2,
  admin: 3,
  owner: 4,
};

/** Service API keys may select an organization; users are always confined to their membership. */
export function resolveOrganization(actor: Actor | undefined, requested: unknown, service = false) {
  const requestedId = requested === undefined ? undefined : z.string().uuid().parse(requested);
  if (actor) {
    if (requestedId && requestedId !== actor.organization_id) throw new AuthorizationError("organization_mismatch", 403);
    return z.string().uuid().parse(actor.organization_id);
  }
  if (service && requestedId) return requestedId;
  throw new AuthorizationError("organization_required", 403);
}

export function requireRole(actor: Actor | undefined, minimum: Role) {
  if (!actor) throw new AuthorizationError("user_session_required", 403);
  if (roleRank[actor.role] < roleRank[minimum]) throw new AuthorizationError("insufficient_role", 403);
  return actor;
}

export class AuthorizationError extends Error {
  constructor(public readonly code: string, public readonly statusCode = 403) { super(code); }
}
