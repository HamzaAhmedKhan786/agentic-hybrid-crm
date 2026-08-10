import { z } from "zod";
export const config=z.object({DATABASE_URL:z.string().min(1),PORT:z.coerce.number().default(4100),API_KEY:z.string().min(24),ASP_SHARED_SECRET:z.string().min(24)}).parse(process.env);
