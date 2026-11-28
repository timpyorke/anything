// สถานะสมาชิก: webhook ของ RevenueCat และคำสั่ง sync จากแอป ใช้ทางเดียวกัน คือถามสถานะล่าสุดจาก RevenueCat
// แล้วบันทึก จึงไม่ต้องตีความ event ทีละชนิด ส่งซ้ำหรือมาผิดลำดับก็ได้ผลเดิม

import type { SupabaseClient } from "@supabase/supabase-js";

export type Deps = {
  /** client ที่ใช้ secret key (ข้าม RLS) */
  db: SupabaseClient;
  /** secret API key (v1) ของ RevenueCat */
  apiKey: string;
  /** ค่า Authorization header ที่ตั้งไว้ใน webhook (ว่าง = ไม่ตรวจ) */
  webhookAuth: string;
  /** signing secret ของ HMAC (ว่าง = ไม่ตรวจ) — ต้องตั้งอย่างน้อยหนึ่งในสองอย่าง */
  webhookSecret: string;
  entitlement: string;
  fetch?: typeof fetch;
  now?: () => number;
  log?: (message: string) => void;
};

/** ลายเซ็นที่เก่ากว่านี้ถือว่าถูกส่งซ้ำโดยคนอื่น */
export const signatureToleranceSeconds = 300;
const maxWebhookBytes = 256 * 1024;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** สิทธิ์ที่ไม่มีวันหมดอายุ */
export const forever = "9999-12-31T00:00:00.000Z";

const failure = (status: number, code: string) => Response.json({ error: { code } }, { status });

const encoder = new TextEncoder();

/** เทียบโดยใช้เวลาเท่ากันไม่ว่าจะผิดตรงไหน (เทียบ digest จึงไม่บอกความยาวด้วย) */
async function same(a: string, b: string): Promise<boolean> {
  const [x, y] = await Promise.all(
    [a, b].map(async (s) => new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(s)))),
  );
  return x.reduce((diff, byte, i) => diff | (byte ^ y[i]), 0) === 0;
}

export async function sign(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, [
    "sign",
  ]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(message)));
  return Array.from(mac, (b) => b.toString(16).padStart(2, "0")).join("");
}

type Subscriber = {
  request_date_ms: number;
  subscriber: {
    entitlements?: Record<string, { expires_date: string | null; grace_period_expires_date?: string | null }>;
  };
};

export function createHandler(deps: Deps): (req: Request) => Promise<Response> {
  const send = deps.fetch ?? fetch;
  const now = deps.now ?? Date.now;
  const log = deps.log ?? console.log;

  async function rpc(name: string, args: Record<string, unknown>) {
    const { data, error } = await deps.db.rpc(name, args);
    if (error) throw new Error(`${name}: ${error.message}`);
    return data;
  }

  /** ถาม RevenueCat แล้วบันทึก คืน true ถ้าเป็นสมาชิก */
  async function sync(user: string): Promise<boolean> {
    const res = await send(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(user)}`, {
      headers: { authorization: `Bearer ${deps.apiKey}` },
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) {
      await res.body?.cancel();
      throw new UpstreamError(res.status);
    }
    const { request_date_ms, subscriber }: Subscriber = await res.json();
    // รูปแบบผิดต้องล้มเหลว ไม่ใช่ถือว่าหมดสมาชิก
    if (typeof request_date_ms !== "number" || typeof subscriber !== "object") throw new UpstreamError(res.status);
    const found = subscriber.entitlements?.[deps.entitlement];
    let expires: string | null = null;
    if (found) {
      const dates = [found.expires_date, found.grace_period_expires_date].filter((d): d is string => !!d);
      expires = found.expires_date === null ? forever : dates.sort((a, b) => Date.parse(b) - Date.parse(a))[0] ?? null;
    }
    return await rpc("apply_subscription", {
      p_user: user,
      p_expires: expires,
      p_checked_at: new Date(request_date_ms).toISOString(),
    }) === true;
  }

  async function authentic(req: Request, body: string): Promise<boolean> {
    if (deps.webhookAuth && !await same(req.headers.get("authorization") ?? "", deps.webhookAuth)) return false;
    if (deps.webhookSecret) {
      const header = req.headers.get("x-revenuecat-webhook-signature") ?? "";
      const [, time, signature] = header.match(/^t=(\d+),v1=([0-9a-f]+)$/) ?? [];
      if (!time || Math.abs(now() / 1000 - Number(time)) > signatureToleranceSeconds) return false;
      if (!await same(signature, await sign(deps.webhookSecret, `${time}.${body}`))) return false;
    }
    return true;
  }

  async function webhook(req: Request): Promise<Response> {
    if (!deps.apiKey || (!deps.webhookAuth && !deps.webhookSecret)) {
      log("subscription: not_configured");
      return failure(500, "not_configured");
    }
    if (Number(req.headers.get("content-length") ?? 0) > maxWebhookBytes) return failure(413, "too_large");
    const body = await req.text();
    if (body.length > maxWebhookBytes) return failure(413, "too_large");
    if (!await authentic(req, body)) return failure(401, "unauthorized");
    let event: Record<string, unknown>;
    try {
      event = JSON.parse(body).event;
      if (typeof event !== "object" || event === null) throw new Error();
    } catch {
      return failure(400, "bad_request");
    }
    // ผู้ใช้คนเดียวอาจมีหลาย id ส่วน TRANSFER บอกทั้งต้นทางและปลายทาง
    const ids = [
      event.app_user_id,
      event.original_app_user_id,
      ...[event.aliases, event.transferred_from, event.transferred_to].flatMap((v) => Array.isArray(v) ? v : []),
    ].filter((id): id is string => typeof id === "string" && uuid.test(id)).map((id) => id.toLowerCase());
    const users: string[] = ids.length ? await rpc("existing_users", { p_ids: [...new Set(ids)] }) : [];
    for (const user of users) await sync(user);
    log(`subscription: webhook ${event.type} synced ${users.length}`);
    return Response.json({ synced: users.length });
  }

  async function userSync(req: Request): Promise<Response> {
    const token = req.headers.get("authorization")?.match(/^Bearer (\S+)$/i)?.[1];
    if (!token) return failure(401, "unauthorized");
    const { data, error } = await deps.db.auth.getUser(token);
    if (error && (error.status ?? 500) >= 500) throw new Error(`auth ${error.status}`);
    if (!data.user || data.user.is_anonymous) return failure(401, "unauthorized");
    if (!deps.apiKey) {
      log("subscription: not_configured");
      return failure(500, "not_configured");
    }
    if (await rpc("claim_subscription_sync", { p_user: data.user.id }) !== true) {
      return failure(429, "too_many_requests");
    }
    return Response.json({ member: await sync(data.user.id) });
  }

  return async (req) => {
    try {
      if (req.method !== "POST") return failure(405, "method_not_allowed");
      const path = new URL(req.url).pathname;
      if (path.endsWith("/webhook")) return await webhook(req);
      if (path.endsWith("/sync")) return await userSync(req);
      return failure(404, "not_found");
    } catch (e) {
      // ตอบไม่สำเร็จ RevenueCat จะส่ง webhook ซ้ำเอง
      if (e instanceof UpstreamError) {
        log(`subscription: revenuecat ${e.status}`);
        return failure(502, "billing_unavailable");
      }
      log(`subscription: internal ${(e as Error).message}`);
      return failure(500, "internal");
    }
  };
}

class UpstreamError extends Error {
  constructor(readonly status: number) {
    super(`revenuecat ${status}`);
  }
}
