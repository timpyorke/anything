import type { Config } from "./handler.ts";
import { modelFromEnv } from "./models.ts";

export const defaultGlobalDailyCap = 2000;

export function configFromEnv(env: (name: string) => string | undefined): Config {
  /** key แบบใหม่เป็น JSON `{"default": "..."}` ส่วนแบบเดิมเป็นข้อความ (เลิกใช้สิ้นปี 2026) */
  const key = (dictionary: string, legacy: string) => {
    try {
      const value = JSON.parse(env(dictionary) ?? "{}")?.default;
      if (typeof value === "string" && value) return value;
    } catch {
      // อ่านไม่ได้ → ใช้แบบเดิม
    }
    return env(legacy) ?? "";
  };
  const cap = env("AI_GLOBAL_DAILY_CAP");
  return {
    supabaseUrl: env("SUPABASE_URL") ?? "",
    publishableKey: key("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY"),
    secretKey: key("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY"),
    // ตั้งค่าผิดรูปแบบ = 0 คือปิดไว้ก่อน ดีกว่าปล่อยค่าใช้จ่ายไม่จำกัด
    globalDailyCap: !cap ? defaultGlobalDailyCap : /^\d+$/.test(cap) ? Number(cap) : 0,
    model: modelFromEnv(env),
  };
}
