import { z } from "zod";
const condition=z.object({field:z.string(),operator:z.enum(["eq","neq","gt","gte","lt","lte","in","exists"]),value:z.unknown().optional()});
const definition=z.object({all:z.array(condition).default([]),any:z.array(condition).default([])});
const get=(facts:Record<string,unknown>,path:string)=>path.split(".").reduce<unknown>((value,key)=>typeof value==="object"&&value!==null?(value as Record<string,unknown>)[key]:undefined,facts);
function match(facts:Record<string,unknown>,c:z.infer<typeof condition>){const actual=get(facts,c.field);switch(c.operator){case"eq":return actual===c.value;case"neq":return actual!==c.value;case"gt":return Number(actual)>Number(c.value);case"gte":return Number(actual)>=Number(c.value);case"lt":return Number(actual)<Number(c.value);case"lte":return Number(actual)<=Number(c.value);case"in":return Array.isArray(c.value)&&c.value.includes(actual);case"exists":return actual!==undefined&&actual!==null;}}
export function evaluateRule(input:unknown,facts:Record<string,unknown>){const rule=definition.parse(input);return rule.all.every(c=>match(facts,c))&&(rule.any.length===0||rule.any.some(c=>match(facts,c)));}
