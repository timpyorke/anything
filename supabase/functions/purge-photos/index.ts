// เรียกโดย cron วันละครั้ง (ดู migration purge_deleted_photos) — ตรวจ x-purge-token กับค่าใน Vault เอง
import { createClient } from "@supabase/supabase-js";

import { createHandler } from "./handler.ts";

/** key แบบใหม่เป็น JSON `{"default": "..."}` ส่วนแบบเดิมเป็นข้อความ (เลิกใช้สิ้นปี 2026) */
function secretKey(): string {
  try {
    const value = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}").default;
    if (typeof value === "string" && value) return value;
  } catch {
    // อ่านไม่ได้ → ใช้แบบเดิม
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
}

const db = createClient(Deno.env.get("SUPABASE_URL")!, secretKey(), {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(createHandler({ db }));
