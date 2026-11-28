// ตัวกลางของ AI ของแอป: ตรวจผู้ใช้ → ตรวจขนาด → หักโควตา → เรียกผู้ให้บริการ → บันทึกยอดใช้
// ห้ามเก็บหรือ log พรอมต์ รูป และคำตอบ (log ได้แค่รหัสผลลัพธ์)

import type { Image, Model, ModelErrorCode, Outcome, Prompt } from "./models.ts";

export const limits = {
  /** system + user (ตัวอักษร) */
  chars: 24_000,
  images: 4,
  /** รูปจากแอปย่อแล้ว (ด้านยาว 1600px) เผื่อกรณี PNG หลายรูป */
  bodyBytes: 8 * 1024 * 1024,
};

const imageTypes = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);
const base64 = /^[A-Za-z0-9+/]+={0,2}$/;

export type Config = {
  supabaseUrl: string;
  publishableKey: string;
  secretKey: string;
  /** จำนวนคำขอต่อวันของทุกคนรวมกัน */
  globalDailyCap: number;
  /** null = ยังไม่ได้ตั้งค่าผู้ให้บริการ */
  model: Model | null;
};

export type Deps = Config & {
  fetch?: typeof fetch;
  log?: (message: string) => void;
};

type Quota =
  | { allowed: true; usage_id: number }
  | { allowed: false; code: string; plan: string; reset_at: string };

class HttpError extends Error {
  constructor(readonly status: number, readonly code: string) {
    super(code);
  }
}

const reply = (status: number, body: unknown) => Response.json(body, { status });
const failure = (status: number, code: string, extra: Record<string, unknown> = {}) =>
  reply(status, { error: { code, message: code, ...extra } });

const modelStatus: Record<ModelErrorCode, number> = {
  refused: 422,
  answer_too_long: 422,
  empty_answer: 422,
  bad_input: 422,
  provider_error: 502,
};

export function createHandler(deps: Deps): (req: Request) => Promise<Response> {
  const send = deps.fetch ?? fetch;
  const log = deps.log ?? console.log;

  /** secret key แบบใหม่ส่งทาง apikey อย่างเดียว ส่วน service_role แบบเดิม (JWT) ต้องส่ง Authorization ด้วย */
  const adminHeaders = (): Record<string, string> => ({
    apikey: deps.secretKey,
    "content-type": "application/json",
    ...(deps.secretKey.startsWith("eyJ") ? { authorization: `Bearer ${deps.secretKey}` } : {}),
  });

  /** id ของผู้ใช้จาก token เท่านั้น ไม่รับจาก body */
  async function userId(req: Request): Promise<string> {
    const token = req.headers.get("authorization")?.match(/^Bearer (\S+)$/i)?.[1];
    if (!token) throw new HttpError(401, "unauthorized");
    const res = await send(`${deps.supabaseUrl}/auth/v1/user`, {
      headers: { apikey: deps.publishableKey, authorization: `Bearer ${token}` },
    });
    if (!res.ok) {
      await res.body?.cancel();
      if (res.status === 401 || res.status === 403) throw new HttpError(401, "unauthorized");
      throw new Error(`auth ${res.status}`);
    }
    const user = await res.json();
    // บัญชีนิรนามสร้างได้ไม่จำกัด จึงไม่ให้โควตา
    if (typeof user?.id !== "string" || user.is_anonymous) throw new HttpError(401, "unauthorized");
    return user.id;
  }

  async function consume(user: string): Promise<Quota> {
    const res = await send(`${deps.supabaseUrl}/rest/v1/rpc/consume_ai_quota`, {
      method: "POST",
      headers: adminHeaders(),
      body: JSON.stringify({ p_user: user, p_global_cap: deps.globalDailyCap }),
    });
    if (!res.ok) {
      await res.body?.cancel();
      throw new Error(`consume_ai_quota ${res.status}`);
    }
    return await res.json();
  }

  /** บันทึกผลไม่สำเร็จไม่ควรทิ้งคำตอบที่ได้มาแล้ว (แถวค้างเป็น reserved ซึ่งยังนับโควตา) */
  async function record(id: number, model: string, outcome: Outcome) {
    try {
      const res = await send(`${deps.supabaseUrl}/rest/v1/ai_usage?id=eq.${id}`, {
        method: "PATCH",
        headers: adminHeaders(),
        body: JSON.stringify({
          status: outcome.usage ? "ok" : "refunded",
          model,
          input_tokens: outcome.usage?.inputTokens ?? null,
          output_tokens: outcome.usage?.outputTokens ?? null,
        }),
      });
      await res.body?.cancel();
      if (!res.ok) log(`ai-generate: record usage ${id} failed (${res.status})`);
    } catch (e) {
      log(`ai-generate: record usage ${id} failed (${(e as Error).name})`);
    }
  }

  return async (req) => {
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed");
      const user = await userId(req);
      const prompt = parsePrompt(await readBody(req));
      const model = deps.model;
      // ตั้งค่าไม่ครบต้องไม่หักโควตา
      if (!model || !deps.secretKey) throw new HttpError(500, "not_configured");

      const quota = await consume(user);
      if (!quota.allowed) {
        return failure(quota.code === "service_busy" ? 503 : 429, quota.code, {
          plan: quota.plan,
          reset_at: quota.reset_at,
        });
      }

      let outcome: Outcome;
      try {
        outcome = await model.generate(prompt);
      } catch (e) {
        outcome = { error: "provider_error", detail: (e as Error).name };
      }
      await record(quota.usage_id, model.name, outcome);
      if ("text" in outcome) return reply(200, { text: outcome.text });
      log(`ai-generate: ${outcome.error} usage=${quota.usage_id} ${outcome.detail ?? ""}`.trim());
      return failure(modelStatus[outcome.error], outcome.error);
    } catch (e) {
      if (e instanceof HttpError) {
        if (e.status >= 500) log(`ai-generate: ${e.code}`);
        return failure(e.status, e.code);
      }
      log(`ai-generate: internal ${(e as Error).message}`);
      return failure(500, "internal");
    }
  };
}

/** อ่าน body โดยหยุดทันทีที่เกินเพดาน (ไม่เชื่อ content-length อย่างเดียว) */
async function readBody(req: Request): Promise<string> {
  const tooLarge = () => new HttpError(413, "too_large");
  if (Number(req.headers.get("content-length") ?? 0) > limits.bodyBytes) throw tooLarge();
  const decoder = new TextDecoder();
  let text = "";
  let size = 0;
  const reader = req.body?.getReader();
  while (reader) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limits.bodyBytes) {
      await reader.cancel();
      throw tooLarge();
    }
    text += decoder.decode(value, { stream: true });
  }
  return text + decoder.decode();
}

/** ข้อความ error จากการอ่าน JSON อาจมีเนื้อหาของผู้ใช้ จึงทิ้งไป */
function parsePrompt(body: string): Prompt {
  const bad = () => new HttpError(400, "bad_request");
  let json: unknown;
  try {
    json = JSON.parse(body);
  } catch {
    throw bad();
  }
  const { system, user, images = [] } = (json ?? {}) as Record<string, unknown>;
  if (typeof system !== "string" || typeof user !== "string" || !user || !Array.isArray(images)) throw bad();
  if (system.length + user.length > limits.chars || images.length > limits.images) {
    throw new HttpError(413, "too_large");
  }
  return {
    system,
    user,
    images: images.map((image): Image => {
      const { mime, data } = (image ?? {}) as Record<string, unknown>;
      if (typeof mime !== "string" || !imageTypes.has(mime) || typeof data !== "string" || !base64.test(data)) {
        throw bad();
      }
      return { mime, data };
    }),
  };
}
