// ลบรูปของรายการที่ถูกลบเกินกำหนด: ลบไฟล์ก่อน แล้วจึงลบแถว
// ถ้าพังกลางทาง รอบถัดไปจะเจอแถวเดิมและทำซ้ำได้ (ลบไฟล์ที่ไม่มีแล้วไม่ถือว่าผิด)

import type { SupabaseClient } from "@supabase/supabase-js";

export const bucket = "entry-photos";
export const batchSize = 100;
/** ต่อการเรียก 1 ครั้ง ที่เหลือทำในรอบถัดไป */
export const maxBatches = 20;

export type Deps = {
  /** client ที่ใช้ secret key (ข้าม RLS) */
  db: SupabaseClient;
  log?: (message: string) => void;
};

const failure = (status: number, code: string) => Response.json({ error: { code } }, { status });

export function createHandler({ db, log = console.log }: Deps): (req: Request) => Promise<Response> {
  async function rpc(name: string, args: Record<string, unknown>) {
    const { data, error } = await db.rpc(name, args);
    if (error) throw new Error(`${name}: ${error.message}`);
    return data;
  }

  return async (req) => {
    if (req.method !== "POST") return failure(405, "method_not_allowed");
    const token = req.headers.get("x-purge-token");
    if (!token) return failure(401, "unauthorized");
    let removed = 0;
    try {
      if (await rpc("check_purge_token", { p_token: token }) !== true) return failure(401, "unauthorized");
      for (let batch = 0; batch < maxBatches; batch++) {
        const paths: string[] = await rpc("purgeable_photos", { p_limit: batchSize });
        if (paths.length > 0) {
          const { error } = await db.storage.from(bucket).remove(paths);
          if (error) throw new Error(`storage: ${error.message}`);
          await rpc("forget_photos", { p_paths: paths });
          removed += paths.length;
        }
        if (paths.length < batchSize) {
          log(`purge-photos: removed ${removed}`);
          return Response.json({ removed, done: true });
        }
      }
      log(`purge-photos: removed ${removed}, more remain`);
      return Response.json({ removed, done: false });
    } catch (e) {
      // ข้อความมีได้แค่ชื่อขั้นตอนกับ error ของ Supabase ไม่มี path ของไฟล์
      log(`purge-photos: failed after ${removed}: ${(e as Error).message}`);
      return failure(500, "internal");
    }
  };
}
