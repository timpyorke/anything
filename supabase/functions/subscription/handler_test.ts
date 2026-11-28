// รัน: cd supabase/functions/subscription && deno task test
// ไม่ต่อเครือข่าย — ใช้ supabase-js ตัวจริง ส่วน Supabase และ RevenueCat ถูกแทนด้วย fetch ปลอม
import { createClient } from "@supabase/supabase-js";

import { createHandler, type Deps, forever, sign, signatureToleranceSeconds } from "./handler.ts";

function equal(actual: unknown, expected: unknown) {
  const a = JSON.stringify(actual), b = JSON.stringify(expected);
  if (a !== b) throw new Error(`expected ${b}\n     got ${a}`);
}

const A = "00000000-0000-4000-8000-00000000000a";
const B = "00000000-0000-4000-8000-00000000000b";
const nobody = "00000000-0000-4000-8000-0000000000ff";
const nowMs = Date.parse("2026-11-28T00:00:00Z");

type Options = {
  entitlements?: Record<string, unknown>;
  rcStatus?: number;
  rcBody?: unknown;
  claim?: boolean;
  user?: Record<string, unknown> | null;
  authStatus?: number;
  config?: Partial<Deps>;
};

function setup(options: Options = {}) {
  const asked: string[] = [];
  const applied: Record<string, unknown>[] = [];
  const rpcs: string[] = [];
  const logs: string[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    if (url.host === "api.revenuecat.com") {
      equal(request.headers.get("authorization"), "Bearer rc-key");
      asked.push(url.pathname.split("/").at(-1)!);
      if (options.rcStatus) return new Response("{}", { status: options.rcStatus });
      return Response.json(
        options.rcBody ?? { request_date_ms: nowMs, subscriber: { entitlements: options.entitlements ?? {} } },
      );
    }
    if (url.pathname === "/auth/v1/user") {
      const user = options.user === undefined ? { id: A } : options.user;
      const status = options.authStatus ?? (user ? 200 : 401);
      return Response.json(status === 200 ? user : { message: "bad" }, { status });
    }
    const name = url.pathname.split("/").at(-1)!;
    const body = await request.json();
    rpcs.push(name);
    if (name === "existing_users") return Response.json(body.p_ids.filter((id: string) => id !== nobody));
    if (name === "claim_subscription_sync") return Response.json(options.claim ?? true);
    if (name === "apply_subscription") {
      applied.push(body);
      return Response.json(body.p_expires !== null && Date.parse(body.p_expires) > nowMs);
    }
    throw new Error(`unexpected ${url.pathname}`);
  };
  const db = createClient("http://supabase.test", "sb_secret_x", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: fetcher },
  });
  const handler = createHandler({
    db,
    apiKey: "rc-key",
    webhookAuth: "Bearer hook",
    webhookSecret: "",
    entitlement: "pro",
    fetch: fetcher,
    now: () => nowMs,
    log: (m) => logs.push(m),
    ...options.config,
  });
  const post = async (path: string, body = "", headers: Record<string, string> = {}) => {
    const res = await handler(new Request(`http://fn/subscription${path}`, { method: "POST", headers, body }));
    return { status: res.status, body: await res.json() };
  };
  const webhook = (event: unknown, headers: Record<string, string> = { authorization: "Bearer hook" }) =>
    post("/webhook", JSON.stringify({ api_version: "1.0", event }), headers);
  const userSync = (headers: Record<string, string> = { authorization: "Bearer jwt" }) => post("/sync", "", headers);
  return { handler, post, webhook, userSync, asked, applied, rpcs, logs };
}

const pro = (expires: string | null, grace: string | null = null) => ({
  pro: { expires_date: expires, grace_period_expires_date: grace },
});

Deno.test("only POST to a known route is served", async () => {
  const t = setup();
  equal((await t.post("/other")).status, 404);
  const res = await t.handler(new Request("http://fn/subscription/sync"));
  equal(res.status, 405);
  await res.body?.cancel();
});

Deno.test("sync stores the latest expiry from RevenueCat for the signed-in user", async () => {
  const t = setup({ entitlements: pro("2026-12-28T00:00:00Z") });
  equal(await t.userSync(), { status: 200, body: { member: true } });
  equal(t.asked, [A]);
  equal(t.applied, [{ p_user: A, p_expires: "2026-12-28T00:00:00Z", p_checked_at: "2026-11-28T00:00:00.000Z" }]);
});

Deno.test("expiry: the later of expiry and grace period; no date means forever; other entitlements are ignored", async () => {
  const cases: [Record<string, unknown>, string | null, boolean][] = [
    [pro("2026-11-27T00:00:00Z", "2026-12-05T00:00:00Z"), "2026-12-05T00:00:00Z", true],
    [pro("2026-12-09T00:00:00Z", "2026-12-05T00:00:00Z"), "2026-12-09T00:00:00Z", true],
    [pro("2026-11-01T00:00:00Z"), "2026-11-01T00:00:00Z", false],
    [pro(null), forever, true],
    [{}, null, false],
    [{ other: { expires_date: null } }, null, false],
  ];
  for (const [entitlements, expires, member] of cases) {
    const t = setup({ entitlements });
    equal([(await t.userSync()).body, t.applied[0].p_expires], [{ member }, expires]);
  }
});

Deno.test("sync needs a real signed-in user", async () => {
  for (
    const [options, headers, status] of [
      [{}, {}, 401],
      [{ user: null }, undefined, 401],
      [{ user: { id: A, is_anonymous: true } }, undefined, 401],
      [{ authStatus: 500 }, undefined, 500],
    ] as const
  ) {
    const t = setup(options);
    equal((await t.userSync(headers)).status, status);
    equal([t.asked, t.rpcs], [[], []]);
  }
});

Deno.test("sync is throttled before RevenueCat is asked", async () => {
  const t = setup({ claim: false });
  equal(await t.userSync(), { status: 429, body: { error: { code: "too_many_requests" } } });
  equal(t.asked, []);
});

Deno.test("an unreadable RevenueCat answer never ends a membership", async () => {
  for (const options of [{ rcStatus: 500 }, { rcStatus: 401 }, { rcBody: {} }, { rcBody: { subscriber: {} } }]) {
    const t = setup(options);
    equal((await t.userSync()).status, 502);
    equal((await t.webhook({ type: "RENEWAL", app_user_id: A })).status, 502);
    equal(t.applied, []);
  }
});

Deno.test("webhook syncs every known user the event names, once each", async () => {
  const t = setup();
  const res = await t.webhook({
    type: "RENEWAL",
    app_user_id: A.toUpperCase(),
    original_app_user_id: "$RCAnonymousID:abc",
    aliases: [A, nobody, "$RCAnonymousID:abc"],
  });
  equal(res, { status: 200, body: { synced: 1 } });
  equal(t.asked, [A]);

  const transfer = setup();
  equal((await transfer.webhook({ type: "TRANSFER", transferred_from: [A], transferred_to: [B] })).body, { synced: 2 });
  equal(transfer.asked, [A, B]);
});

Deno.test("webhook accepts events that name nobody we know, including the dashboard test", async () => {
  const t = setup();
  equal(await t.webhook({ type: "TEST", app_user_id: "test-user" }), { status: 200, body: { synced: 0 } });
  equal([t.asked, t.rpcs], [[], []]);
  equal((await t.webhook({ type: "NEW_KIND", app_user_id: nobody })).body, { synced: 0 });
  equal(t.asked, []);
});

Deno.test("webhook rejects a wrong or missing authorization header", async () => {
  for (const headers of [{}, { authorization: "Bearer nope" }, { authorization: "Bearer hook2" }]) {
    const t = setup();
    equal((await t.webhook({ app_user_id: A }, headers as Record<string, string>)).status, 401);
    equal(t.rpcs, []);
  }
});

Deno.test("webhook verifies the signature over the raw body, with a time limit", async () => {
  const body = JSON.stringify({ event: { type: "RENEWAL", app_user_id: A } });
  const now = nowMs / 1000;
  const signed = async (time: number, text = body, secret = "s") => ({
    "x-revenuecat-webhook-signature": `t=${time},v1=${await sign(secret, `${time}.${text}`)}`,
  });
  const config = { webhookAuth: "", webhookSecret: "s" };
  equal((await setup({ config }).post("/webhook", body, await signed(now))).status, 200);
  for (
    const headers of [
      {},
      await signed(now - signatureToleranceSeconds - 1),
      await signed(now + signatureToleranceSeconds + 1),
      await signed(now, body + " "),
      await signed(now, body, "other"),
      { "x-revenuecat-webhook-signature": "t=x,v1=00" },
    ]
  ) {
    equal((await setup({ config }).post("/webhook", body, headers as Record<string, string>)).status, 401);
  }
  // ตั้งทั้งสองอย่างต้องผ่านทั้งสองอย่าง
  const both = { webhookSecret: "s" };
  equal((await setup({ config: both }).post("/webhook", body, await signed(now))).status, 401);
  equal(
    (await setup({ config: both }).post("/webhook", body, { ...await signed(now), authorization: "Bearer hook" }))
      .status,
    200,
  );
});

Deno.test("missing configuration fails closed", async () => {
  const open = setup({ config: { webhookAuth: "", webhookSecret: "" } });
  equal((await open.webhook({ app_user_id: A }, {})).status, 500);
  equal(open.rpcs, []);
  const noKey = setup({ config: { apiKey: "" } });
  equal((await noKey.webhook({ app_user_id: A })).status, 500);
  equal((await noKey.userSync()).status, 500);
  equal(noKey.rpcs, []);
});

Deno.test("webhook rejects a body that is not an event", async () => {
  for (const body of ["nope", "{}", '{"event":1}']) {
    equal((await setup().post("/webhook", body, { authorization: "Bearer hook" })).status, 400);
  }
});
