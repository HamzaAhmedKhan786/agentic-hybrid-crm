import { z } from "zod";

export const config=z.object({
  DATABASE_URL:z.string().min(1), HOST:z.string().default("127.0.0.1"), PORT:z.coerce.number().default(4100), API_KEY:z.string().min(24), ASP_SHARED_SECRET:z.string().min(24),
  GROQ_API_KEY:z.string().optional(), GROQ_MODEL:z.string().default("openai/gpt-oss-120b"), GROQ_BASE_URL:z.string().url().default("https://api.groq.com/openai/v1"),
  TAVILY_API_KEY:z.string().optional(), TAVILY_API_URL:z.string().url().default("https://api.tavily.com/search"),
  EMAIL_API_KEY:z.string().optional(), EMAIL_API_URL:z.string().url().default("https://api.resend.com/emails"),
  APP_URL:z.string().url().default("http://localhost:4100"), SESSION_TTL_HOURS:z.coerce.number().int().positive().default(24),
  AGENT_ACTIONS_REQUIRE_APPROVAL:z.enum(["true","false"]).default("true"), AGENT_MAX_ACTIONS_PER_RUN:z.coerce.number().int().min(1).max(100).default(10),
  OUTBOX_POLL_INTERVAL_MS:z.coerce.number().int().min(500).default(5000)
}).parse(process.env);
