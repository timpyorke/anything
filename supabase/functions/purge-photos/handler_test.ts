// รัน: cd supabase/functions/purge-photos && deno task test
// ไม่ต่อเครือข่าย — ใช้ supabase-js ตัวจริงกับ fetch ปลอม
import { createClient } from "@supabase/supabase-js";

import { batchSize, createHandler, maxBatches } from "./handler.ts";

function equal(actual: unknown, expected: unknown) {
  const a = JSON.stringify(actual), b = JSON.stringify(expected);
  if (a !== b) throw new Error(`expected ${b}\n     got ${a}`);
}

const paths = (n: number, from = 0) => Array.from({ length: n }, (_, i) => `user/${from + i}.jpg`);

/** [waiting] = รูปที่ครบกำหนดลบอยู่ในฐานข้อมูล */
function setup(options: { waiting?: string[]; storageStatus?: number; forgetStatus?: number } = {}) {
  let waiting = options.waiting ?? [];
  const calls: { method: string; path: string; body: Record<string, unknown> }[] = [];
  const logs: string[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    const path = new URL(request.url).pathname;
    const text = await request.text();
    const body = text ? JSON.parse(text) : {};
    calls.push({ method: request.method, path, body });
    if (path.endsWith("/check_purge_token")) return Response.json(body.p_token === "right");
    if (path.endsWith("/purgeable_photos")) return Response.json(waiting.slice(0, body.p_limit));
    if (path.endsWith("/object/entry-photos")) {
      const status = options.storageStatus ?? 200;
      return Response.json(status === 200 ? [] : { message: "storage down" }, { status });
    }
    if (path.endsWith("/forget_photos")) {
      if (options.forgetStatus) return Response.json({ message: "db down" }, { status: options.forgetStatus });
      waiting = waiting.filter((p) => !body.p_paths.includes(p));
      return new Response(null, { status: 204 });
    }
    throw new Error(`unexpected ${path}`);
  };
  const db = createClient("http://supabase.test", "sb_secret_x", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: fetcher },
  });
  const handler = createHandler({ db, log: (m) => logs.push(m) });
  const send = async (token: string | null = "right", method = "POST") => {
    const res = await handler(
      new Request("http://fn/purge-photos", { method, headers: token ? { "x-purge-token": token } : {} }),
    );
    return { status: res.status, body: await res.json() };
  };
  const removals = () => calls.filter((c) => c.path.endsWith("/object/entry-photos"));
  const forgotten = () => calls.filter((c) => c.path.endsWith("/forget_photos"));
  return { send, calls, logs, removals, forgotten, left: () => waiting.length };
}

Deno.test("without the right token nothing is listed or removed", async () => {
  for (const [token, queries] of [[null, 0], ["wrong", 1]] as const) {
    const t = setup({ waiting: paths(3) });
    equal(await t.send(token), { status: 401, body: { error: { code: "unauthorized" } } });
    equal([t.calls.length, t.left()], [queries, 3]);
  }
  const t = setup();
  equal((await t.send("right", "GET")).status, 405);
});

Deno.test("files are removed before their rows, in batches until none are left", async () => {
  const t = setup({ waiting: paths(batchSize + 2) });
  equal(await t.send(), { status: 200, body: { removed: batchSize + 2, done: true } });
  equal(t.removals().map((c) => [c.method, c.body]), [
    ["DELETE", { prefixes: paths(batchSize) }],
    ["DELETE", { prefixes: paths(2, batchSize) }],
  ]);
  equal(t.forgotten().map((c) => c.body), [{ p_paths: paths(batchSize) }, { p_paths: paths(2, batchSize) }]);
  const order = t.calls.map((c) => c.path.split("/").at(-1));
  equal(order.slice(1, 4), ["purgeable_photos", "entry-photos", "forget_photos"]);
  equal(t.left(), 0);
});

Deno.test("nothing to purge touches no files", async () => {
  const t = setup();
  equal(await t.send(), { status: 200, body: { removed: 0, done: true } });
  equal(t.removals().length, 0);
});

Deno.test("one call stops after the batch limit", async () => {
  const t = setup({ waiting: paths(batchSize * maxBatches + 1) });
  equal(await t.send(), { status: 200, body: { removed: batchSize * maxBatches, done: false } });
  equal(t.left(), 1);
});

Deno.test("rows stay when the files cannot be removed, so the next run retries", async () => {
  const t = setup({ waiting: paths(3), storageStatus: 500 });
  equal((await t.send()).status, 500);
  equal([t.forgotten().length, t.left()], [0, 3]);
});

Deno.test("a database failure is reported without file paths in the log", async () => {
  const t = setup({ waiting: paths(3), forgetStatus: 500 });
  equal((await t.send()).status, 500);
  equal(t.logs.some((l) => l.includes("user/")), false);
  equal(t.logs.some((l) => l.includes("forget_photos")), true);
});
