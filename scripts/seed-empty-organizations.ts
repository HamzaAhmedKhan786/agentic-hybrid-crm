import postgres from "postgres";
import {seedStarterData} from "../src/starter-data.js";
const url=process.env.DATABASE_URL;if(!url)throw new Error("DATABASE_URL is required.");const sql=postgres(url,{max:1});let seeded=0;
for(const organization of await sql`select id from identity.organizations order by created_at`)await sql.begin(async tx=>{const result=await seedStarterData(tx as never,organization.id);if(result.created)seeded++;});
console.log(`Starter data applied to ${seeded} empty organization(s).`);await sql.end();
