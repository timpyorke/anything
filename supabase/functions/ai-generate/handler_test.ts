// รัน: cd supabase/functions/ai-generate && deno task test
// ไม่ต่อเครือข่าย — Supabase และผู้ให้บริการ AI ถูกแทนด้วย fetch ปลอม
// deno-lint-ignore-file no-explicit-any

import { configFromEnv, defaultGlobalDailyCap } from "./config.ts";
import { anthropicMaxTokens, anthropicModel } from "./anthropic.ts";
import { geminiMaxTokens, geminiModel } from "./gemini.ts";
import { createHandler, type Deps, limits } from "./handler.ts";
import { type Model, modelFromEnv, type Outcome, type Prompt } from "./models.ts";

function equal(actual: unknown, expected: unknown) {
  const a = JSON.stringify(actual), b = JSON.stringify(expected);
  if (a !== b) throw new Error(`expected ${b}\n     got ${a}`);
}
function check(condition: unknown, message = "check failed"): asserts condition {
  if (!condition) throw new Error(message);
}

type Call = { url: string; method: string; headers: Headers; body: any };
/** fetch ปลอมที่จดทุกคำขอไว้ */
function fakeFetch(route: (call: Call) => Response | Promise<Response>) {
  const calls: Call[] = [];
  const fetcher = (async (input: any, init?: RequestInit) => {
    const request = new Request(input, init);
    const text = await request.text();
    const call = {
      url: request.url,
      method: request.method,
      headers: request.headers,
      body: text ? JSON.parse(text) : null,
    };
    calls.push(call);
    return await route(call);
  }) as typeof fetch;
  return { fetch: fetcher, calls };
}

const prompt: Prompt = { system: "ระบบ", user: "ไปวิ่งมา", images: [] };
const secretWords = ["ระบบ", "ไปวิ่งมา", "คำตอบลับ"];

function setup(options: {
  outcome?: Outcome;
  quota?: unknown;
  user?: unknown;
  authStatus?: number;
  patchStatus?: number;
  config?: Partial<Deps>;
} = {}) {
  const prompts: Prompt[] = [];
  const logs: string[] = [];
  const model: Model = {
    name: "test-model",
    generate: (p) => {
      prompts.push(p);
      return Promise.resolve(options.outcome ?? { text: "คำตอบลับ", usage: { inputTokens: 10, outputTokens: 2 } });
    },
  };
  const net = fakeFetch(({ url, method }) => {
    if (url.endsWith("/auth/v1/user")) {
      return Response.json(options.user ?? { id: "user-1" }, { status: options.authStatus ?? 200 });
    }
    if (url.endsWith("/rpc/consume_ai_quota")) {
      return Response.json(options.quota ?? { allowed: true, usage_id: 7 });
    }
    if (url.includes("/rest/v1/ai_usage") && method === "PATCH") {
      return new Response(null, { status: options.patchStatus ?? 204 });
    }
    throw new Error(`unexpected ${url}`);
  });
  const handler = createHandler({
    supabaseUrl: "http://supabase",
    publishableKey: "pub",
    secretKey: "sb_secret_x",
    globalDailyCap: 99,
    model,
    fetch: net.fetch,
    log: (m) => logs.push(m),
    ...options.config,
  });
  const send = async (body: unknown = prompt, headers: Record<string, string> = { authorization: "Bearer jwt" }) => {
    const res = await handler(
      new Request("http://fn/ai-generate", {
        method: "POST",
        headers,
        body: typeof body === "string" ? body : JSON.stringify(body),
      }),
    );
    return { status: res.status, body: await res.json() };
  };
  const consumed = () => net.calls.filter((c) => c.url.includes("consume_ai_quota"));
  const recorded = () => net.calls.filter((c) => c.method === "PATCH").map((c) => c.body);
  return { handler, send, calls: net.calls, prompts, logs, consumed, recorded };
}

Deno.test("success: quota is consumed for the token's user, usage is recorded, text is returned", async () => {
  const t = setup();
  const res = await t.send({ ...prompt, p_user: "someone-else" });
  equal(res, { status: 200, body: { text: "คำตอบลับ" } });
  equal(t.prompts, [prompt]);
  equal(t.calls[0].headers.get("authorization"), "Bearer jwt");
  equal(t.calls[0].headers.get("apikey"), "pub");
  equal(t.consumed()[0].body, { p_user: "user-1", p_global_cap: 99 });
  // key แบบใหม่ส่งทาง apikey อย่างเดียว
  equal(t.consumed()[0].headers.get("apikey"), "sb_secret_x");
  equal(t.consumed()[0].headers.get("authorization"), null);
  equal(t.calls.at(-1)!.url, "http://supabase/rest/v1/ai_usage?id=eq.7");
  equal(t.recorded(), [{ status: "ok", model: "test-model", input_tokens: 10, output_tokens: 2 }]);
});

Deno.test("a legacy service_role key is also sent as a bearer token", async () => {
  const t = setup({ config: { secretKey: "eyJabc" } });
  await t.send();
  equal(t.consumed()[0].headers.get("authorization"), "Bearer eyJabc");
});

Deno.test("requests without a valid user never reach the quota or the model", async () => {
  const cases = [
    { t: setup(), headers: {} as Record<string, string> },
    { t: setup({ authStatus: 401 }), headers: undefined },
    { t: setup({ authStatus: 403 }), headers: undefined },
    { t: setup({ user: { id: "anon", is_anonymous: true } }), headers: undefined },
  ];
  for (const { t, headers } of cases) {
    const res = await t.send(prompt, headers);
    equal([res.status, res.body.error.code], [401, "unauthorized"]);
    equal([t.consumed().length, t.prompts.length], [0, 0]);
  }
});

Deno.test("an auth outage is an internal error, not a sign-out", async () => {
  const t = setup({ authStatus: 500 });
  equal((await t.send()).status, 500);
  equal(t.consumed().length, 0);
});

Deno.test("only POST is accepted", async () => {
  const t = setup();
  const res = await t.handler(new Request("http://fn/ai-generate"));
  equal(res.status, 405);
  await res.body?.cancel();
});

Deno.test("invalid or oversized input is rejected before any quota is used", async () => {
  const image = { mime: "image/jpeg", data: "aGk=" };
  const cases: [unknown, number][] = [
    ["not json", 400],
    ["null", 400],
    [{ system: "s" }, 400],
    [{ system: "s", user: "" }, 400],
    [{ system: "s", user: "u", images: "x" }, 400],
    [{ system: "s", user: "u", images: [{ mime: "text/html", data: "aGk=" }] }, 400],
    [{ system: "s", user: "u", images: [{ mime: "image/png", data: "http://x" }] }, 400],
    [{ system: "s".repeat(limits.chars), user: "u" }, 413],
    [{ system: "s", user: "u", images: Array(limits.images + 1).fill(image) }, 413],
    ["x".repeat(limits.bodyBytes + 1), 413],
  ];
  for (const [body, status] of cases) {
    const t = setup();
    equal((await t.send(body)).status, status);
    equal([t.consumed().length, t.prompts.length], [0, 0]);
  }
  const t = setup();
  const largest = { system: "s".repeat(limits.chars - 1), user: "u", images: Array(limits.images).fill(image) };
  equal((await t.send(largest)).status, 200);
});

Deno.test("a missing provider or secret key uses no quota", async () => {
  for (const config of [{ model: null }, { secretKey: "" }]) {
    const t = setup({ config });
    const res = await t.send();
    equal([res.status, res.body.error.code], [500, "not_configured"]);
    equal(t.consumed().length, 0);
  }
});

Deno.test("over quota: 429 (503 when the whole service is capped) and the model is not called", async () => {
  for (
    const [code, status] of [["quota_minute", 429], ["quota_day", 429], ["quota_month", 429], ["service_busy", 503]]
  ) {
    const reset_at = "2026-11-29T00:00:00+07:00";
    const t = setup({ quota: { allowed: false, code, plan: "free", reset_at } });
    equal(await t.send(), { status, body: { error: { code, message: code, plan: "free", reset_at } } });
    equal([t.prompts.length, t.recorded().length], [0, 0]);
  }
});

Deno.test("a failed provider call is refunded; a billed one counts", async () => {
  const usage = { inputTokens: 5, outputTokens: 1 };
  const cases: [Outcome, number, string][] = [
    [{ error: "provider_error" }, 502, "refunded"],
    [{ error: "bad_input" }, 422, "refunded"],
    [{ error: "refused", usage }, 422, "ok"],
    [{ error: "answer_too_long", usage }, 422, "ok"],
    [{ error: "empty_answer", usage }, 422, "ok"],
  ];
  for (const [outcome, status, recordedAs] of cases) {
    const t = setup({ outcome });
    const res = await t.send();
    equal([res.status, t.recorded()[0].status], [status, recordedAs]);
  }
});

Deno.test("a model that throws is refunded", async () => {
  const t = setup({ config: { model: { name: "m", generate: () => Promise.reject(new Error("ไปวิ่งมา")) } } });
  equal((await t.send()).status, 502);
  equal(t.recorded()[0].status, "refunded");
  check(!t.logs.join().includes("ไปวิ่งมา"), "error message reached the log");
});

Deno.test("a failed usage record still returns the answer", async () => {
  const t = setup({ patchStatus: 500 });
  equal((await t.send()).status, 200);
  check(t.logs.some((l) => l.includes("record usage 7 failed")));
});

Deno.test("logs never contain the prompt or the answer", async () => {
  const logs: string[] = [];
  for (const options of [{}, { patchStatus: 500 }, { outcome: { error: "provider_error" as const } }]) {
    const t = setup(options);
    await t.send();
    logs.push(...t.logs);
  }
  const t = setup();
  await t.send('{"system":"ระบบ" ไปวิ่งมา');
  logs.push(...t.logs);
  for (const word of secretWords) check(!logs.join().includes(word), `logged ${word}`);
});

// ---------- ผู้ให้บริการ ----------

const withImage: Prompt = { ...prompt, images: [{ mime: "image/png", data: "aGk=" }] };

const claudeMessage = (stop_reason: string, text = '{"reply":"ok"}') => ({
  id: "msg_1",
  type: "message",
  role: "assistant",
  model: "claude-haiku-5-5",
  content: [{ type: "thinking", thinking: "", signature: "s" }, { type: "text", text }],
  stop_reason,
  stop_sequence: null,
  usage: { input_tokens: 11, output_tokens: 3 },
});

Deno.test("anthropic: request shape and text answer", async () => {
  const net = fakeFetch(() => Response.json(claudeMessage("end_turn")));
  const model = anthropicModel({ apiKey: "k", model: "claude-haiku-5-5", fetch: net.fetch });
  equal(await model.generate(withImage), { text: '{"reply":"ok"}', usage: { inputTokens: 11, outputTokens: 3 } });
  const call = net.calls[0];
  equal(call.url, "https://api.anthropic.com/v1/messages");
  equal(call.headers.get("authorization"), "Bearer k");
  equal(call.body, {
    model: "claude-haiku-5-5",
    max_tokens: anthropicMaxTokens,
    output_config: { effort: "low" },
    system: "ระบบ",
    messages: [{
      role: "user",
      content: [
        { type: "image", source: { type: "base64", media_type: "image/png", data: "aGk=" } },
        { type: "text", text: "ไปวิ่งมา" },
      ],
    }],
  });
});

Deno.test("anthropic: stop reasons are billed errors", async () => {
  const usage = { inputTokens: 11, outputTokens: 3 };
  for (
    const [stop, text, error] of [
      ["refusal", "", "refused"],
      ["max_tokens", "{", "answer_too_long"],
      ["end_turn", " ", "empty_answer"],
    ]
  ) {
    const net = fakeFetch(() => Response.json(claudeMessage(stop, text)));
    const out = await anthropicModel({ apiKey: "k", model: "m", fetch: net.fetch }).generate(prompt);
    check("error" in out);
    equal([out.error, out.usage], [error, usage]);
  }
});

Deno.test("anthropic: API errors are refundable and are not retried", async () => {
  for (
    const [status, error] of [[400, "bad_input"], [401, "provider_error"], [429, "provider_error"], [
      529,
      "provider_error",
    ]] as const
  ) {
    const net = fakeFetch(() => Response.json({ type: "error", error: { type: "x", message: "ไปวิ่งมา" } }, { status }));
    const out = await anthropicModel({ apiKey: "k", model: "m", fetch: net.fetch }).generate(prompt);
    check("error" in out);
    equal([out.error, out.usage, net.calls.length], [error, undefined, 1]);
    check(!out.detail?.includes("ไปวิ่งมา"), "provider message in detail");
  }
});

const geminiBody = (finishReason: string, text = '{"reply":"ok"}') => ({
  candidates: [{ finishReason, content: { parts: [{ text: "คิด", thought: true }, { text }] } }],
  usageMetadata: { promptTokenCount: 11, candidatesTokenCount: 3, thoughtsTokenCount: 2 },
});

Deno.test("gemini: request shape, thoughts are dropped from the text and counted as output", async () => {
  const net = fakeFetch(() => Response.json(geminiBody("STOP")));
  const model = geminiModel({ apiKey: "k", model: "gemini-3.5-flash-lite", fetch: net.fetch });
  equal(await model.generate(withImage), { text: '{"reply":"ok"}', usage: { inputTokens: 11, outputTokens: 5 } });
  const call = net.calls[0];
  check(call.url.endsWith("/models/gemini-3.5-flash-lite:generateContent"));
  equal(call.headers.get("x-goog-api-key"), "k");
  equal(call.body.generationConfig, {
    responseMimeType: "application/json",
    maxOutputTokens: geminiMaxTokens,
    thinkingConfig: { thinkingLevel: "MINIMAL" },
  });
  equal(call.body.contents[0].parts, [{ inlineData: { mimeType: "image/png", data: "aGk=" } }, { text: "ไปวิ่งมา" }]);
});

Deno.test("gemini: stop reasons are billed, HTTP and network errors are refundable", async () => {
  const run = async (route: () => Response) => {
    const out = await geminiModel({ apiKey: "k", model: "m", fetch: fakeFetch(route).fetch }).generate(prompt);
    check("error" in out);
    return [out.error, !!out.usage];
  };
  equal(await run(() => Response.json(geminiBody("MAX_TOKENS"))), ["answer_too_long", true]);
  equal(await run(() => Response.json(geminiBody("SAFETY"))), ["refused", true]);
  equal(await run(() => Response.json(geminiBody("STOP", ""))), ["empty_answer", true]);
  equal(await run(() => Response.json({ promptFeedback: { blockReason: "OTHER" } })), ["refused", true]);
  equal(await run(() => new Response("{}", { status: 400 })), ["bad_input", false]);
  equal(await run(() => new Response("{}", { status: 503 })), ["provider_error", false]);
  equal(await run(() => new Response("<html>")), ["provider_error", false]);
  equal(
    await run(() => {
      throw new TypeError("offline");
    }),
    ["provider_error", false],
  );
});

// ---------- การตั้งค่า ----------

const env = (values: Record<string, string>) => (name: string) => values[name];

Deno.test("config: provider and model come from secrets", () => {
  equal(modelFromEnv(env({ ANTHROPIC_API_KEY: "a" }))?.name, "claude-haiku-5-5");
  equal(modelFromEnv(env({ AI_PROVIDER: "gemini", GEMINI_API_KEY: "g" }))?.name, "gemini-3.5-flash-lite");
  equal(modelFromEnv(env({ ANTHROPIC_API_KEY: "a", AI_MODEL: "other" }))?.name, "other");
  equal(modelFromEnv(env({ AI_PROVIDER: "gemini", ANTHROPIC_API_KEY: "a" })), null);
  equal(modelFromEnv(env({ AI_PROVIDER: "toString", ANTHROPIC_API_KEY: "a" })), null);
  equal(modelFromEnv(env({})), null);
});

Deno.test("config: new key dictionaries win, legacy keys still work", () => {
  const both = configFromEnv(env({
    SUPABASE_SECRET_KEYS: '{"default":"sb_secret_n"}',
    SUPABASE_SERVICE_ROLE_KEY: "eyJold",
    SUPABASE_ANON_KEY: "eyJanon",
  }));
  equal([both.secretKey, both.publishableKey], ["sb_secret_n", "eyJanon"]);
  equal(
    configFromEnv(env({ SUPABASE_SECRET_KEYS: "broken", SUPABASE_SERVICE_ROLE_KEY: "eyJold" })).secretKey,
    "eyJold",
  );
});

Deno.test("config: the global cap has a default and fails closed when malformed", () => {
  const cap = (value?: string) =>
    configFromEnv(env(value === undefined ? {} : { AI_GLOBAL_DAILY_CAP: value })).globalDailyCap;
  equal([cap(), cap("50"), cap("0"), cap("-1"), cap("2,000")], [defaultGlobalDailyCap, 50, 0, 0, 0]);
});
