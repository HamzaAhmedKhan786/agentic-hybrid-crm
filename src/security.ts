import { createHash, randomBytes, scryptSync, timingSafeEqual } from "node:crypto";

export const hashToken=(value:string)=>createHash("sha256").update(value).digest("hex");
export function hashPassword(password:string){const salt=randomBytes(16).toString("hex");return `${salt}:${scryptSync(password,salt,64).toString("hex")}`;}
export function verifyPassword(password:string,stored:string){const [salt,key]=stored.split(":");if(!salt||!key)return false;const actual=scryptSync(password,salt,64);const expected=Buffer.from(key,"hex");return actual.length===expected.length&&timingSafeEqual(actual,expected);}
export const newToken=()=>randomBytes(32).toString("base64url");
