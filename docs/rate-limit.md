# แผน: rate limit และโควตาของ Free / Member

สถานะ (28 พ.ย. 2026):

- เฟส 1: apply กับโปรเจกต์ `anything` แล้ว (version `20261127162906`)
- เฟส 2: deploy `ai-generate` แล้ว ใช้ **Gemini** (`AI_PROVIDER`, `GEMINI_API_KEY`) เรียกจริงจากแอปสำเร็จ 1 ครั้ง (input 1,740 / output 126 token ≈ $0.0008) ตรวจ `manual_until` บนระบบจริงแล้ว (เพดานที่แอปอ่านได้เปลี่ยนเป็น Member; หักโควตาต่อนาทีได้ 10 ครั้งเทียบกับ Free 3 ครั้ง) — เกณฑ์จบของเฟส 2 ครบ
- เฟส 3: apply migration (version `20261128030217`) และ deploy `purge-photos` แล้ว เรียกผ่านคำสั่งของ cron ได้ 200 (ลบ 0 ไฟล์ เพราะยังไม่มีรูปครบกำหนด) **ยังไม่เคยลบไฟล์จริง และยังไม่ได้ลองพื้นที่เต็มจากแอป**
- เฟส 4: เขียนโค้ดและทดสอบในเครื่องแล้ว build ผ่านทั้ง Android และ iOS simulator; apply migration (version `20261128032012`) และ deploy `subscription` แล้ว ตั้ง secret `REVENUECAT_API_KEY` และ `REVENUECAT_WEBHOOK_AUTH` แล้ว **ยังไม่ได้ยืนยันด้วย test event จาก RevenueCat และยังไม่เคยซื้อจริง**
- เฟส 5: ปุ่มลบบัญชีและการล้าง `ai_usage` ทดสอบในเครื่องแล้ว apply migration (version `20261128034216`) และ deploy `delete-account` แล้ว **ยังไม่เคยลบบัญชีจริง** งานที่เหลือและเอกสารความเป็นส่วนตัว (ร่าง) ดู [launch-checklist.md](launch-checklist.md)

## 1. ขอบเขต

ตกลงแล้ว:

- จำกัด **AI ที่แอปให้บริการเอง** (ใหม่) และ **พื้นที่เก็บรูป**
- จ่ายเงินผ่าน **IAP + RevenueCat**
- AI แบบใส่ API key เอง และ Gemma ในเครื่อง **ไม่จำกัด** เพราะเราไม่เสียค่าใช้จ่าย

หลักการ:

1. บังคับที่ server เท่านั้น แอปแค่แสดงผล
2. ตัวเลขโควตาอยู่ในฐานข้อมูล แก้ได้โดยไม่ต้องออกแอปใหม่
3. ไม่เก็บเนื้อหาบันทึกในตารางนับการใช้งาน
4. ลดระดับหรือเกินโควตาแล้ว **ไม่ลบข้อมูล** แค่เพิ่มของใหม่ไม่ได้

## 2. โควตาที่เสนอ

| | Free | Member |
|---|---|---|
| AI ต่อนาที | 3 | 10 |
| AI ต่อวัน | 5 | 40 |
| AI ต่อเดือน | 30 | 500 |
| พื้นที่เก็บรูป | 100 MB | 5 GB |
| BYOK / ในเครื่อง | ไม่จำกัด | ไม่จำกัด |

เพดานรวมทั้งระบบ: จำนวนคำขอ AI ต่อวันของทุกคนรวมกัน (เริ่มที่ 2,000) กันค่าใช้จ่ายบานปลาย

กติกาการนับ:

- 1 การเรียก AI = 1 ครั้ง (ส่งครั้งแรก, ตอบต่อ, ลองใหม่ นับแยกกัน) มีรูปหรือไม่มีก็เท่ากัน
- คืนโควตาเมื่อผู้ให้บริการไม่ได้ประมวลผล (ตอบ error หรือหมดเวลา) — ขีดจำกัดต่อนาทียังนับ
- ผู้ให้บริการตอบแล้วแต่ใช้ไม่ได้ (ปฏิเสธ ยาวเกินเพดาน ว่าง) **ยังนับ** เพราะเสียค่า AI แล้ว
- ผู้ใช้กดยกเลิกเอง **ยังนับ** เพราะเสียค่า AI ไปแล้ว
- วันและเดือนตัดตามเวลา `Asia/Bangkok` (ไม่เชื่อเขตเวลาจากเครื่อง)

## 3. ต้นทุน

สมมติต่อคำขอ: ข้อความ 5,000 token, คำตอบ 800 token (รวม thinking), รูปละ ~1,100 token (Gemini) / ~2,500 token (Claude)
ตัวเลข token เป็น **ค่าประมาณ** จากความยาวพรอมต์ใน `recorder.dart` ต้องวัดจริงก่อนตั้งราคา

| โมเดล | ราคา input / output ต่อ 1M token | ต่อคำขอ ไม่มีรูป / 4 รูป | Free เต็มโควตา/เดือน | Member เต็มโควตา/เดือน |
|---|---|---|---|---|
| `claude-haiku-5-5` | $0.10 / $0.50 | $0.0009 / $0.0019 | $0.03–0.06 | $0.45–0.95 |
| `gemini-3.5-flash-lite` | $0.30 / $2.50 | $0.0035 / $0.0048 | $0.11–0.14 | $1.75–2.41 |

- ตอนนี้ใช้ `gemini-3.5-flash-lite` ก่อน (ตัดสินใจ 28 พ.ย. 2026) ส่วน `claude-haiku-5-5` ถูกกว่าตามราคาประกาศ ต้องเทียบคุณภาพภาษาไทยและ JSON กับชุดข้อความตัวอย่างก่อนเลือกจริง ผู้ให้บริการและโมเดลเป็น secret ของ Edge Function (`AI_PROVIDER`, `AI_MODEL`) เปลี่ยนได้ทันที
- ต้องใช้ API แบบเสียเงิน (Gemini แบบฟรีนำข้อมูลไปปรับปรุงผลิตภัณฑ์) และตรวจเงื่อนไขการใช้ข้อมูลของผู้ให้บริการที่เลือกก่อนเปิดใช้
- ผู้ใช้ที่ดัดแปลง client ส่งคำขอใหญ่สุดตามเพดานในข้อ 6 ทุกครั้ง (สมมติไม่เกิน 1 token ต่อตัวอักษร): Member เสียสูงสุดราว $2.7 (Haiku) / $6.8 (Flash-Lite) ต่อเดือน
- รายได้อ้างอิง: ราคา ฿99/เดือน ≈ $2.4 หลังหักค่าสโตร์ 15% (สมมติ ฿35/$ และได้อัตรา 15%, ยังไม่หักภาษี) RevenueCat ฟรีจนรายได้ถึง $2,500/เดือน จากนั้น 1%
- รูป: Supabase Free ให้ Storage รวม 1 GB ทั้งโปรเจกต์ จึง **ต้องขึ้น Pro ($25/เดือน, 100 GB, ส่วนเกิน $0.0213/GB) ก่อนเปิดจริง**

## 4. สถาปัตยกรรม

```
แอป ──(JWT)──> Edge Function ai-generate ──> consume_ai_quota()  [Postgres, atomic]
                        │                          └─ เกิน → 429
                        └──(key ของเรา)──> ผู้ให้บริการ AI ──> บันทึก token / คืนโควตา

แอป ──ซื้อ──> App Store / Play ──> RevenueCat ──webhook──> Edge Function subscription ──> subscriptions
แอป ──(JWT) หลังซื้อ/กู้การซื้อ───────────────────────────> /subscription/sync
แอป ──อัปโหลดรูป──> Storage (policy ตรวจพื้นที่ที่เหลือ)
```

ใช้ Postgres นับโควตาอย่างเดียว ไม่เพิ่ม Redis — ปริมาณระดับนี้ index บน `(user_id, created_at)` พอ

## 5. ฐานข้อมูล

อยู่ใน `supabase/migrations/20261127162906_rate_limit.sql`

| ของใหม่ | หน้าที่ | ใครใช้ได้ |
|---|---|---|
| `plans` | เพดานของ `free` / `pro` | ผู้ใช้อ่าน, `service_role` แก้ |
| `subscriptions` | `expires_at` (RevenueCat), `manual_until` (ให้สิทธิ์เอง) — ไม่มีแถว = free | ผู้ใช้อ่านของตัวเอง, `service_role` เขียน |
| `ai_usage` | 1 แถวต่อการเรียก AI: `reserved` → `ok` / `refunded` · ลบบัญชีแล้วแถวยังอยู่โดย `user_id` ว่าง (ยังนับเพดานรวม) · cron ลบแถวเก่ากว่า 90 วัน | ผู้ใช้อ่านของตัวเอง, `service_role` เขียน |
| `consume_ai_quota(user, global_cap)` | ตรวจและหักโควตาแบบ atomic | `service_role` |
| `get_my_usage()` | แผน ยอดใช้/เพดานของ AI รายวัน รายเดือน และพื้นที่ | ผู้ใช้ที่ล็อกอิน |
| policy `entry_photos_insert` | ปฏิเสธการอัปโหลดเมื่อพื้นที่เต็ม | — |
| `ai_logs.provider` | รับ `managed` เพิ่ม | — |

ข้อจำกัดที่ยอมรับ:

- เพดานรวมทั้งระบบเป็นแบบ soft (คำขอพร้อมกันของหลายคนเกินได้เล็กน้อย) และถ้าไม่ได้ส่ง `global_cap` จะปฏิเสธทุกคำขอ
- เพดานพื้นที่เป็นแบบ soft: ตอน policy ทำงานยังไม่รู้ขนาดไฟล์ใหม่ จึงเกินได้ราว 1 ไฟล์ (≤ 5 MB) และมากกว่านั้นถ้าอัปโหลดขนานกัน

### คืนพื้นที่จากรายการที่ลบแล้ว

รูปของรายการที่ soft delete เกิน 30 วันถูกลบถาวร ข้อความของรายการยังอยู่
(`supabase/migrations/20261128030217_purge_deleted_photos.sql`)

```
pg_cron (ทุกวัน 03:17 เวลาไทย) ──x-purge-token──> Edge Function purge-photos
  └─ purgeable_photos() → ลบไฟล์ผ่าน Storage API → forget_photos()   (ครั้งละ 100 ไม่เกิน 2,000 ต่อรอบ)
```

- `purge_token` สุ่มขึ้นใน Vault ตอน apply migration ไม่ต้องตั้งเอง
- ต้องเพิ่ม URL ของโปรเจกต์ครั้งเดียวต่อโปรเจกต์ (`anything` ตั้งแล้ว): `select vault.create_secret('https://<ref>.supabase.co', 'project_url');` ถ้าไม่มี cron จะไม่เรียกอะไร
- deploy: `supabase functions deploy purge-photos` (`verify_jwt = false`)
- ตรวจว่าทำงาน: ตาราง `net._http_response` และ log ของฟังก์ชัน
- แอปบอกเรื่อง 30 วันตอนลบรายการที่มีรูป; แอปเวอร์ชันเก่าไม่บอก แต่รูปถูกลบตามกำหนดเหมือนกัน

## 6. Edge Functions

### `ai-generate`

โค้ดอยู่ใน `supabase/functions/ai-generate/`

1. ตรวจ token กับ Supabase Auth เอา user id จากผลนั้น (ไม่รับจาก body) ไม่รับบัญชีนิรนาม — `verify_jwt = false` เพราะการตรวจของ platform รองรับเฉพาะ key แบบเดิม
2. ตรวจขนาดและรูปแบบ **ก่อนหักโควตา**: `system` + `user` ≤ 24,000 ตัวอักษร, รูป ≤ 4, body รวม ≤ 8 MB → เกินตอบ 413
3. `consume_ai_quota` → ไม่ผ่านตอบ 429 (`service_busy` ตอบ 503)
4. เรียกผู้ให้บริการ ไม่ retry, timeout 55 วินาที
   - Claude: `claude-haiku-5-5`, effort `low`, คำตอบรวมการคิด ≤ 4,096 token
   - Gemini: `gemini-3.5-flash-lite`, thinking `MINIMAL`, ≤ 2,048 token
5. ผู้ให้บริการประมวลผลแล้ว → `ok` + จำนวน token; ไม่ได้ประมวลผล → `refunded`
6. ห้าม log พรอมต์ รูป หรือคำตอบ

| คำตอบ | `error.code` |
|---|---|
| 200 | — (`{"text": "..."}`) |
| 401 | `unauthorized` |
| 400 / 413 | `bad_request` / `too_large` |
| 429 | `quota_minute`, `quota_day`, `quota_month` (มี `plan`, `reset_at`) |
| 503 | `service_busy` (มี `plan`, `reset_at`) |
| 422 | `refused`, `answer_too_long`, `empty_answer`, `bad_input` |
| 500 / 502 | `not_configured`, `internal` / `provider_error` |

secret:

| ชื่อ | ค่า |
|---|---|
| `ANTHROPIC_API_KEY` | ต้องมีเมื่อใช้ Claude (ค่าเริ่มต้น) |
| `GEMINI_API_KEY` | ต้องมีเมื่อ `AI_PROVIDER=gemini` — ใช้ key แบบเสียเงิน |
| `AI_PROVIDER` | `anthropic` (ค่าเริ่มต้น) หรือ `gemini` |
| `AI_MODEL` | ไม่บังคับ (ฝั่ง Gemini ต้องเป็นรุ่น 3.x) |
| `AI_GLOBAL_DAILY_CAP` | ค่าเริ่มต้น 2000; ตั้งผิดรูปแบบ = ปิดรับทุกคำขอ |

deploy: ตั้ง secret ใน Dashboard (Edge Functions → Secrets) แล้ว `supabase functions deploy ai-generate`
ทดสอบ: `cd supabase/functions/ai-generate && deno task test`

พรอมต์ยังสร้างใน `recorder.dart` ตามเดิม ผลคือคนที่ดัดแปลง client ใช้ proxy ถามเรื่องอื่นได้ แต่ค่าใช้จ่ายถูกจำกัดด้วยโควตาและเพดานขนาด ถ้าพบการใช้ผิดค่อยย้ายส่วนกฎของพรอมต์ไป server
ผู้ใช้ที่มี checklist ค้างยาวมากอาจเกิน 24,000 ตัวอักษรและได้ `too_large` ตลอด ถ้าพบให้ตัดบริบทใน `recorder.dart`

ขีดจำกัดของ Edge Function: เวลา 150 วินาที (Free) / 400 วินาที (จ่ายเงิน), CPU 2 วินาที, memory 256 MB

### `subscription`

โค้ดอยู่ใน `supabase/functions/subscription/` (`verify_jwt = false` ตรวจผู้เรียกเอง) migration คือ `20261128032012_subscription_sync.sql`

| เส้นทาง | ผู้เรียก | ตรวจอะไร |
|---|---|---|
| `POST /subscription/webhook` | RevenueCat | Authorization header และ/หรือลายเซ็น HMAC (อายุไม่เกิน 5 นาที) |
| `POST /subscription/sync` | แอป | JWT ของผู้ใช้ (ไม่รับบัญชีนิรนาม) ได้ครั้งละ 5 วินาที |

- ทั้งสองทางถาม `GET /v1/subscribers/{id}` แล้วเรียก `apply_subscription` — ไม่ตีความ event ทีละชนิด ส่งซ้ำหรือมาผิดลำดับก็ได้ผลเดิม (คำตอบที่เก่ากว่าที่เก็บอยู่ถูกทิ้ง)
- สิทธิ์ถึง = วันหมดอายุหรือ grace period แล้วแต่อันไหนช้ากว่า; ไม่มีวันหมดอายุ = ตลอดไป; ไม่แตะ `manual_until`
- webhook ถามเฉพาะ id ที่เป็นผู้ใช้ในระบบ (การถามด้วย id อื่นจะสร้างลูกค้าเปล่าใน RevenueCat) รวมทั้ง `transferred_from` / `transferred_to`
- RevenueCat ตอบผิดปกติ → ตอบ 502 โดยไม่แก้สถานะ แล้ว RevenueCat ส่ง webhook ซ้ำเอง (5 ครั้งในราว 80 นาที)
- **การซื้อแบบ sandbox (รวม TestFlight) เปิดสิทธิ์จริง** จำเป็นสำหรับการทดสอบและการรีวิวของ Apple แต่ผู้ทดสอบจะได้โควตา Member ฟรี

secret: `REVENUECAT_API_KEY` (secret key แบบ **v1**), `REVENUECAT_WEBHOOK_AUTH` หรือ `REVENUECAT_WEBHOOK_SECRET` (อย่างน้อยหนึ่งอย่าง), `REVENUECAT_ENTITLEMENT` (ไม่บังคับ ค่าเริ่มต้น `pro`)

### ตั้งค่าที่ต้องทำเอง (ก่อนซื้อจริงได้)

1. App Store Connect และ Google Play Console: ลงนามสัญญาแบบเสียเงินและข้อมูลภาษี แล้วสร้างสินค้า subscription (เช่น รายเดือน ฿99)
2. RevenueCat: สร้างโปรเจกต์ เชื่อมทั้งสองสโตร์ สร้าง entitlement ชื่อ `pro` ผูกสินค้า และตั้ง offering ปัจจุบัน
3. RevenueCat → Webhooks: URL `https://<ref>.supabase.co/functions/v1/subscription/webhook` ตั้งค่า Authorization header เป็นข้อความสุ่มยาวๆ (และ/หรือเปิด HMAC signing) แล้วกด test event ต้องได้ 200
4. Supabase → Edge Functions → Secrets: ใส่ secret ข้างบน
5. `app/env.json`: `REVENUECAT_APPLE_KEY`, `REVENUECAT_GOOGLE_KEY` (public SDK key), `TERMS_URL`, `PRIVACY_URL` — Apple บังคับให้หน้าสมัครมีสองลิงก์หลัง
6. Xcode: เปิด capability In-App Purchase ของ Runner
7. ทดสอบด้วยบัญชี sandbox / license tester บนเครื่องจริง: ซื้อ ต่ออายุ ยกเลิก หมดอายุ คืนเงิน กู้การซื้อ และสลับบัญชี

## 7. แอป

| ส่วน | งาน | สถานะ |
|---|---|---|
| `ai/managed_provider.dart` | เรียก `ai-generate` ด้วย access token, แปลง error, โควตาเต็ม = `AiQuotaException` | ทำแล้ว |
| `ai/ai_settings.dart` | `AiProviderKind.managed` และความยินยอมแยกตามบัญชี | ทำแล้ว |
| `domain/` + `data/` | `UsageSummary`, `UsageRepository` | ทำแล้ว |
| `features/assistant/` | ถามความยินยอมก่อนส่งครั้งแรก; โควตาเต็ม → บอกเวลาที่ใช้ได้อีก และปุ่ม "ใช้ AI อื่น" | ทำแล้ว |
| `features/settings/` | แสดงแผน การใช้ AI และพื้นที่; ยินยอม/ถอนความยินยอม | ทำแล้ว |
| อัปโหลดรูป | พื้นที่เต็ม → `StorageFullException` พร้อมข้อความ ทั้งหน้าแก้ไขและผลจาก AI; ดูและเอารูปออกได้ตามปกติ | ทำแล้ว |
| ลบรายการ | บอกว่ารูปจะถูกลบถาวรหลัง 30 วัน | ทำแล้ว |
| บันทึกจาก AI พังบางรายการ | เอารายการที่บันทึกแล้วออกจากชุด กดอีกครั้งไม่เกิดรายการซ้ำ | ทำแล้ว |
| `features/subscription/` | paywall, กู้การซื้อ, ลิงก์จัดการการสมัคร ข้อกำหนด และความเป็นส่วนตัว; ปุ่มสมัครในหน้าตั้งค่าและตอนโควตาของแผน Free เต็ม | ทำแล้ว |
| RevenueCat | `purchases_flutter` 12 (ต้องใช้ Swift Package Manager); ผูกตามบัญชีที่ล็อกอิน ส่งแค่ UUID — แพลตฟอร์มที่ไม่ได้ใส่ key จะไม่แสดงปุ่มสมัคร | ทำแล้ว |

ผู้ให้บริการเริ่มต้น: คนที่ยังไม่เคยเลือกและไม่มี key บันทึกไว้เริ่มที่ AI ของแอป คนที่มี key อยู่แล้วใช้ AI Studio ต่อ

**ต้อง deploy `ai-generate` ก่อนออกแอปเวอร์ชันนี้** ไม่งั้นผู้ใช้ใหม่จะเรียก AI ไม่ได้

### ความเป็นส่วนตัว

- กฎใน `CLAUDE.md` รวม AI ของแอปและ RevenueCat แล้ว (SDK ของ RevenueCat เก็บข้อมูลเครื่องบางอย่างเอง ต้องระบุในนโยบายและแบบฟอร์มของสโตร์)
- ครั้งแรกที่ใช้ AI ของแอปต้องกดยินยอม ข้อความระบุข้อมูลที่ส่งและบริษัทที่รับ
- ก่อนเปิดจริง: อัปเดตนโยบายความเป็นส่วนตัวและแบบฟอร์มข้อมูลของ App Store / Play

## 8. ลำดับงาน

| เฟส | งาน | เสร็จเมื่อ |
|---|---|---|
| 1 | migration: ตาราง ฟังก์ชัน policy | ยิงพร้อมกัน 20 คำขอที่เพดาน 3 ผ่านแค่ 3; client เขียน `subscriptions` และเรียก `consume_ai_quota` ไม่ได้ |
| 2 | `ai-generate` + `managed` ในแอป + แสดงการใช้งาน | ให้สิทธิ์ด้วย `manual_until` แล้วโควตาเปลี่ยนตาม; `flutter analyze && flutter test` ผ่าน |
| 3 | พื้นที่เก็บรูปในแอป | เต็มแล้วเพิ่มรูปไม่ได้ แต่ดูและลบได้ |
| 4 | RevenueCat + paywall + webhook | sandbox: ซื้อ ต่ออายุ หมดอายุ คืนเงิน ย้ายบัญชี ถูกต้อง |
| 5 | ก่อนเปิดจริง | ปุ่มลบบัญชีในแอป (สโตร์กำหนดสำหรับแอปที่สมัครบัญชีได้), Supabase Pro, ตั้งเพดานงบกับผู้ให้บริการ AI, แจ้งเตือนค่าใช้จ่าย, ลบ `ai_usage` เก่ากว่า 90 วัน, เอกสารความเป็นส่วนตัว |

## 9. เรื่องที่ยังต้องตัดสินใจ

1. ตัวเลขโควตาและราคาสมาชิก
2. โมเดลของ AI ในแอป — โค้ดรองรับทั้งสองค่าย ตอนนี้ใช้ Gemini ก่อน ต้องทดสอบภาษาไทยก่อนเลือกจริง
3. ~~รูปของรายการที่ลบแล้วกินพื้นที่~~ — ตัดสินแล้ว (28 พ.ย. 2026): ลบรูปถาวรหลัง 30 วัน ส่วนไฟล์กำพร้า (อัปโหลดแล้วไม่มีแถวอ้างถึง) ยังนับพื้นที่อยู่
4. การสมัครหลายบัญชีเพื่อเอาโควตาฟรี: รอบแรกพึ่งเพดานรวม ถ้าเจอปัญหาค่อยเพิ่ม App Attest / Play Integrity

## อ้างอิง (ตรวจเมื่อ 27 พ.ย. 2026)

- [ราคา Claude Haiku 5.5](https://platform.claude.com/docs/en/models/haiku-5-5/overview)
- [ราคา Gemini](https://aistudio.google.com/docs/pricing) · [กำหนดปิดโมเดล Gemini](https://aistudio.google.com/docs/deprecations)
- [ขีดจำกัด Edge Functions](https://supabase.com/docs/guides/functions/limits) · [ราคา Supabase](https://supabase.com/pricing)
- [RevenueCat webhooks](https://www.revenuecat.com/docs/integrations/webhooks) · [ราคา RevenueCat](https://www.revenuecat.com/pricing)
