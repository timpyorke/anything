// Edge Function ของ AI ของแอป (แผน: docs/rate-limit.md)
// secret ที่ต้องตั้ง: ANTHROPIC_API_KEY หรือ GEMINI_API_KEY
// ไม่บังคับ: AI_PROVIDER (anthropic | gemini), AI_MODEL, AI_GLOBAL_DAILY_CAP
import { configFromEnv } from "./config.ts";
import { createHandler } from "./handler.ts";

Deno.serve(createHandler(configFromEnv((name) => Deno.env.get(name))));
