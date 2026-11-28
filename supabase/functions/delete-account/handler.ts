// ลบบัญชีของผู้ที่เรียก: ข้อมูลลูกค้าที่ RevenueCat → รูปใน Storage → ผู้ใช้ (ตารางที่เหลือลบตาม cascade)
// พังกลางทาง บัญชียังอยู่และสั่งซ้ำได้

import type { SupabaseClient } from "@supabase/supabase-js";

export const bucket = "entry-photos";
export const pageSize = 100;
/** กันวนไม่จบ (20,000 ไฟล์) — เกินนี้ตอบว่าไม่สำเร็จ สั่งซ้ำเพื่อลบต่อ */
export const maxPages = 200;
/** ค่าที่แอปต้องส่งมา กันการเรียกโดยไม่ตั้งใจ */
export const confirmation = "delete";

export type Deps = {
  /** client ที่ใช้ secret key (ข้าม RLS) */
  db: SupabaseClient;
  /** secret API key (v1) ของ RevenueCat (ว่าง = ไม่ได้ขาย จึงไม่มีข้อมูลที่นั่น) */
  revenueCatKey: string;
  fetch?: typeof fetch;
  log?: (message: string) => void;
};

const failure = (status: number, code: string) => Response.json({ error: { code } }, { status });

export function createHandler({ db, revenueCatKey, fetch: send = fetch, log = console.log }: Deps) {
  async function forgetCustomer(user: string) {
    if (!revenueCatKey) return;
    const res = await send(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(user)}`, {
      method: "DELETE",
      headers: { authorization: `Bearer ${revenueCatKey}` },
      signal: AbortSignal.timeout(10_000),
    });
    await res.body?.cancel();
    // 404 = ไม่เคยมีข้อมูลหรือลบไปแล้ว
    if (!res.ok && res.status !== 404) throw new Error(`revenuecat ${res.status}`);
  }

  /** ลบทุกไฟล์ในโฟลเดอร์ของผู้ใช้ รวมไฟล์ที่ไม่มีแถวอ้างถึง */
  async function removePhotos(user: string) {
    const files = db.storage.from(bucket);
    for (let page = 0; page < maxPages; page++) {
      const listed = await files.list(user, { limit: pageSize });
      if (listed.error) throw new Error(`storage list: ${listed.error.message}`);
      if (listed.data.length === 0) return;
      const removed = await files.remove(listed.data.map((f) => `${user}/${f.name}`));
      if (removed.error) throw new Error(`storage remove: ${removed.error.message}`);
    }
    throw new Error("storage: too many files");
  }

  return async (req: Request): Promise<Response> => {
    try {
      if (req.method !== "POST") return failure(405, "method_not_allowed");
      const token = req.headers.get("authorization")?.match(/^Bearer (\S+)$/i)?.[1];
      if (!token) return failure(401, "unauthorized");
      const { data, error } = await db.auth.getUser(token);
      if (error && (error.status ?? 500) >= 500) throw new Error(`auth ${error.status}`);
      if (!data.user) return failure(401, "unauthorized");
      const body = await req.json().catch(() => null);
      if (body?.confirm !== confirmation) return failure(400, "confirmation_required");
      const user = data.user.id;

      // ขั้นที่ยังไม่ทำลายข้อมูลของผู้ใช้ทำก่อน: พังตรงนี้คือยังไม่มีอะไรหาย
      await forgetCustomer(user);
      await removePhotos(user);
      const deleted = await db.auth.admin.deleteUser(user);
      if (deleted.error) throw new Error(`delete user: ${deleted.error.message}`);
      // token เดิมยังใช้ได้จนหมดอายุ อุปกรณ์อื่นอาจอัปโหลดแทรกเข้ามา เก็บกวาดอีกรอบ
      await removePhotos(user).catch((e) => log(`delete-account: leftover files (${(e as Error).message})`));
      log("delete-account: done");
      return Response.json({ deleted: true });
    } catch (e) {
      // log ไม่มี id ของผู้ใช้หรือชื่อไฟล์
      log(`delete-account: failed: ${(e as Error).message}`);
      return failure(500, "internal");
    }
  };
}
