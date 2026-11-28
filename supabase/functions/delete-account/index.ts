// แอปเรียกด้วย JWT ของผู้ใช้ ลบได้เฉพาะบัญชีของตัวเอง
// secret ที่ใช้ถ้ามี: REVENUECAT_API_KEY
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

Deno.serve(createHandler({ db, revenueCatKey: env("REVENUECAT_API_KEY") }));
