// POST /subscription/webhook (RevenueCat) และ /subscription/sync (แอป) — ตรวจผู้เรียกเอง
// secret ที่ต้องตั้ง: REVENUECAT_API_KEY และ REVENUECAT_WEBHOOK_AUTH หรือ REVENUECAT_WEBHOOK_SECRET
// ไม่บังคับ: REVENUECAT_ENTITLEMENT (ค่าเริ่มต้น pro)
import { createClient } from "@supabase/supabase-js";

import { createHandler } from "./handler.ts";

const env = (name: string) => Deno.env.get(name) ?? "";

/** key แบบใหม่เป็น JSON `{"default": "..."}` ส่วนแบบเดิมเป็นข้อความ (เลิกใช้สิ้นปี 2026) */
function secretKey(): string {
  try {
    const value = JSON.parse(env("SUPABASE_SECRET_KEYS")).default;
    if (typeof value === "string" && value) return value;
  } catch {
    // ไม่มีหรืออ่านไม่ได้ → ใช้แบบเดิม
  }
  return env("SUPABASE_SERVICE_ROLE_KEY");
}

const db = createClient(env("SUPABASE_URL"), secretKey(), {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(createHandler({
  db,
  apiKey: env("REVENUECAT_API_KEY"),
  webhookAuth: env("REVENUECAT_WEBHOOK_AUTH"),
  webhookSecret: env("REVENUECAT_WEBHOOK_SECRET"),
  entitlement: env("REVENUECAT_ENTITLEMENT") || "pro",
}));
