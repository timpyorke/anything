// สัญญาร่วมของผู้ให้บริการ AI และการเลือกตัวที่ใช้จากค่า secret

import { anthropicModel } from "./anthropic.ts";
import { geminiModel } from "./gemini.ts";

export type Image = { mime: string; data: string };
export type Prompt = { system: string; user: string; images: Image[] };
export type Usage = { inputTokens: number | null; outputTokens: number | null };

export type ModelErrorCode =
  | "refused"
  | "answer_too_long"
  | "empty_answer"
  | "bad_input"
  | "provider_error";

/**
 * มี `usage` = ผู้ให้บริการประมวลผลแล้ว (เสียเงินแล้ว) จึงนับโควตา
 * ไม่มี = เรียกไม่สำเร็จ ต้องคืนโควตา
 * `detail` ใช้ลง log เท่านั้น ห้ามมีเนื้อหาของผู้ใช้
 */
export type Outcome =
  | { text: string; usage: Usage }
  | { error: ModelErrorCode; usage?: Usage; detail?: string };

export interface Model {
  name: string;
  generate(prompt: Prompt): Promise<Outcome>;
}

/** เวลาที่รอผู้ให้บริการ — ต้องสั้นกว่าที่แอปรอ (70 วินาที) */
export const providerTimeoutMs = 55_000;

export type ModelOptions = {
  apiKey: string;
  model: string;
  fetch?: typeof fetch;
};

const providers = {
  anthropic: { keyName: "ANTHROPIC_API_KEY", defaultModel: "claude-haiku-5-5", create: anthropicModel },
  gemini: { keyName: "GEMINI_API_KEY", defaultModel: "gemini-3.5-flash-lite", create: geminiModel },
};

/** `AI_PROVIDER` (anthropic | gemini), `AI_MODEL` (ไม่บังคับ) และ API key — null = ตั้งค่าไม่ครบ */
export function modelFromEnv(
  env: (name: string) => string | undefined,
  fetcher?: typeof fetch,
): Model | null {
  const name = env("AI_PROVIDER") || "anthropic";
  if (!Object.hasOwn(providers, name)) return null;
  const p = providers[name as keyof typeof providers];
  const apiKey = env(p.keyName);
  if (!apiKey) return null;
  return p.create({ apiKey, model: env("AI_MODEL") || p.defaultModel, fetch: fetcher });
}
