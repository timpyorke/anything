// รัน: cd supabase/functions/delete-account && deno task test
// ไม่ต่อเครือข่าย — ใช้ supabase-js ตัวจริง ส่วน Supabase และ RevenueCat ถูกแทนด้วย fetch ปลอม
import { createClient } from "@supabase/supabase-js";

import { createHandler, maxPages, pageSize } from "./handler.ts";

function equal(actual: unknown, expected: unknown) {
  const a = JSON.stringify(actual), b = JSON.stringify(expected);
  if (a !== b) throw new Error(`expected ${b}\n     got ${a}`);
}

const me = "00000000-0000-4000-8000-00000000000a";

type Options = {
  files?: number;
  user?: Record<string, unknown> | null;
  authStatus?: number;
  rcStatus?: number;
  rcKey?: string;
  removeStatus?: number;
  deleteStatus?: number;
  /** ไฟล์ที่ถูกอัปโหลดแทรกเข้ามาระหว่างลบผู้ใช้ */
  late?: number;
  stuck?: boolean;
};

function setup(options: Options = {}) {
  let files = Array.from({ length: options.files ?? 0 }, (_, i) => `${i}.jpg`);
  const steps: string[] = [];
  const removed: string[] = [];
  const logs: string[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    const text = await request.text();
    const body = text ? JSON.parse(text) : {};
    if (url.host === "api.revenuecat.com") {
      equal([request.method, url.pathname], ["DELETE", `/v1/subscribers/${me}`]);
      steps.push("revenuecat");
      return Response.json({}, { status: options.rcStatus ?? 200 });
    }
    if (url.pathname === "/auth/v1/user") {
      const user = options.user === undefined ? { id: me } : options.user;
      const status = options.authStatus ?? (user ? 200 : 401);
      return Response.json(status === 200 ? user : { message: "bad" }, { status });
    }
    if (url.pathname.endsWith("/object/list/entry-photos")) {
      equal(body.prefix, me);
      steps.push("list");
      return Response.json(files.slice(0, body.limit).map((name) => ({ name })));
    }
    if (url.pathname.endsWith("/object/entry-photos") && request.method === "DELETE") {
      steps.push("remove");
      if (options.removeStatus) return Response.json({ message: "storage down" }, { status: options.removeStatus });
      removed.push(...body.prefixes);
      if (!options.stuck) files = files.filter((f) => !body.prefixes.includes(`${me}/${f}`));
      return Response.json([]);
    }
    // supabase-js อ่านข้อมูลผู้ใช้ก่อนลบ
    if (url.pathname === `/auth/v1/admin/users/${me}` && request.method === "GET") return Response.json({ id: me });
    if (url.pathname === `/auth/v1/admin/users/${me}` && request.method === "DELETE") {
      steps.push("delete-user");
      if (options.deleteStatus) return Response.json({ message: "no" }, { status: options.deleteStatus });
      files.push(...Array.from({ length: options.late ?? 0 }, (_, i) => `late-${i}.jpg`));
      return Response.json({});
    }
    throw new Error(`unexpected ${request.method} ${url.pathname}`);
  };
  const db = createClient("http://supabase.test", "sb_secret_x", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: fetcher },
  });
  const handler = createHandler({
    db,
    revenueCatKey: options.rcKey ?? "rc-key",
    fetch: fetcher,
    log: (m) => logs.push(m),
  });
  const send = async (
    body: unknown = { confirm: "delete" },
    headers: Record<string, string> = { authorization: "Bearer jwt" },
  ) => {
    const res = await handler(
      new Request("http://fn/delete-account", { method: "POST", headers, body: JSON.stringify(body) }),
    );
    return { status: res.status, body: await res.json() };
  };
  return { handler, send, steps, removed, logs, left: () => files.length };
}

Deno.test("deletes billing data, then every photo, then the user", async () => {
  const t = setup({ files: pageSize + 1 });
  equal(await t.send(), { status: 200, body: { deleted: true } });
  equal(t.steps, ["revenuecat", "list", "remove", "list", "remove", "list", "delete-user", "list"]);
  equal([t.removed.length, t.left()], [pageSize + 1, 0]);
  equal(t.removed[0], `${me}/0.jpg`);
});

Deno.test("only the caller can be deleted, whatever the body says", async () => {
  const t = setup();
  equal((await t.send({ confirm: "delete", user_id: "someone-else" })).status, 200);
  equal(t.steps.filter((s) => s === "delete-user").length, 1);
});

Deno.test("without a valid user or the confirmation nothing happens", async () => {
  const cases: [Options, unknown, Record<string, string> | undefined, number][] = [
    [{}, undefined, {}, 401],
    [{ user: null }, undefined, undefined, 401],
    [{ authStatus: 500 }, undefined, undefined, 500],
    [{}, {}, undefined, 400],
    [{}, { confirm: "yes" }, undefined, 400],
    [{}, null, undefined, 400],
  ];
  for (const [options, body, headers, status] of cases) {
    const t = setup({ files: 2, ...options });
    equal((await t.send(body === undefined ? { confirm: "delete" } : body, headers)).status, status);
    equal([t.steps, t.left()], [[], 2]);
  }
  const t = setup();
  const res = await t.handler(new Request("http://fn/delete-account"));
  equal(res.status, 405);
  await res.body?.cancel();
});

Deno.test("if billing data cannot be deleted, nothing else is touched", async () => {
  const t = setup({ files: 2, rcStatus: 500 });
  equal((await t.send()).status, 500);
  equal([t.steps, t.left()], [["revenuecat"], 2]);
});

Deno.test("an unknown billing customer is fine, and without a key billing is skipped", async () => {
  equal((await setup({ rcStatus: 404 }).send()).status, 200);
  const t = setup({ rcKey: "" });
  equal((await t.send()).status, 200);
  equal(t.steps.includes("revenuecat"), false);
});

Deno.test("the account stays when photos cannot be removed", async () => {
  for (const options of [{ removeStatus: 500 }, { stuck: true }]) {
    const t = setup({ files: 2, ...options });
    equal((await t.send()).status, 500);
    equal(t.steps.includes("delete-user"), false);
  }
  const t = setup({ files: 1, stuck: true });
  await t.send();
  equal(t.steps.filter((s) => s === "remove").length, maxPages);
});

Deno.test("a failed user deletion is reported, and files uploaded meanwhile are swept", async () => {
  equal((await setup({ deleteStatus: 500 }).send()).status, 500);
  const t = setup({ files: 1, late: 2 });
  equal((await t.send()).status, 200);
  equal(t.left(), 0);
});

Deno.test("logs never name the user or a file", async () => {
  for (const options of [{ files: 2 }, { files: 2, removeStatus: 500 }, { rcStatus: 500 }]) {
    const t = setup(options);
    await t.send();
    equal(t.logs.some((l) => l.includes(me) || l.includes(".jpg")), false);
  }
});
