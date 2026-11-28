# แผน: rate limit และโควตาของ Free / Member

สถานะ (28 พ.ย. 2026):

- เฟส 1: apply กับโปรเจกต์ `anything` แล้ว (version `20261127162906`)
- เฟส 2: เขียนโค้ดและทดสอบในเครื่องแล้ว **ยังไม่ได้ deploy `ai-generate`** และยังไม่เคยเรียกผู้ให้บริการ AI จริง
- เฟส 3–5: ยังไม่เริ่ม (หน้าตั้งค่าแสดงพื้นที่ที่ใช้แล้ว เหลือข้อความตอนพื้นที่เต็ม)

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

- เริ่มทดลองด้วย `claude-haiku-5-5` เพราะถูกกว่า แต่ต้องเทียบคุณภาพภาษาไทยและ JSON กับชุดข้อความตัวอย่างก่อนเลือกจริง ผู้ให้บริการและโมเดลเป็น secret ของ Edge Function (`AI_PROVIDER`, `AI_MODEL`) เปลี่ยนได้ทันที
- ต้องใช้ API แบบเสียเงิน (Gemini แบบฟรีนำข้อมูลไปปรับปรุงผลิตภัณฑ์) และตรวจเงื่อนไขการใช้ข้อมูลของผู้ให้บริการที่เลือกก่อนเปิดใช้
- ผู้ใช้ที่ดัดแปลง client ส่งคำขอใหญ่สุดตามเพดานในข้อ 6 ทุกครั้ง (สมมติไม่เกิน 1 token ต่อตัวอักษร): Member เสียสูงสุดราว $2.7 (Haiku) / $6.8 (Flash-Lite) ต่อเดือน
- รายได้อ้างอิง: ราคา ฿99/เดือน ≈ $2.4 หลังหักค่าสโตร์ 15% (สมมติ ฿35/$ และได้อัตรา 15%, ยังไม่หักภาษี) RevenueCat ฟรีจนรายได้ถึง $2,500/เดือน จากนั้น 1%
- รูป: Supabase Free ให้ Storage รวม 1 GB ทั้งโปรเจกต์ จึง **ต้องขึ้น Pro ($25/เดือน, 100 GB, ส่วนเกิน $0.0213/GB) ก่อนเปิดจริง**

## 4. สถาปัตยกรรม

```
แอป ──(JWT)──> Edge Function ai-generate ──> consume_ai_quota()  [Postgres, atomic]
                        │                          └─ เกิน → 429
                        └──(key ของเรา)──> ผู้ให้บริการ AI ──> บันทึก token / คืนโควตา

แอป ──ซื้อ──> App Store / Play ──> RevenueCat ──webhook──> Edge Function rc-webhook ──> subscriptions
แอป ──อัปโหลดรูป──> Storage (policy ตรวจพื้นที่ที่เหลือ)
```

ใช้ Postgres นับโควตาอย่างเดียว ไม่เพิ่ม Redis — ปริมาณระดับนี้ index บน `(user_id, created_at)` พอ

## 5. ฐานข้อมูล

อยู่ใน `supabase/migrations/20261127162906_rate_limit.sql`

| ของใหม่ | หน้าที่ | ใครใช้ได้ |
|---|---|---|
| `plans` | เพดานของ `free` / `pro` | ผู้ใช้อ่าน, `service_role` แก้ |
| `subscriptions` | `expires_at` (RevenueCat), `manual_until` (ให้สิทธิ์เอง) — ไม่มีแถว = free | ผู้ใช้อ่านของตัวเอง, `service_role` เขียน |
| `ai_usage` | 1 แถวต่อการเรียก AI: `reserved` → `ok` / `refunded` | ผู้ใช้อ่านของตัวเอง, `service_role` เขียน |
| `consume_ai_quota(user, global_cap)` | ตรวจและหักโควตาแบบ atomic | `service_role` |
| `get_my_usage()` | แผน ยอดใช้/เพดานของ AI รายวัน รายเดือน และพื้นที่ | ผู้ใช้ที่ล็อกอิน |
| policy `entry_photos_insert` | ปฏิเสธการอัปโหลดเมื่อพื้นที่เต็ม | — |
| `ai_logs.provider` | รับ `managed` เพิ่ม | — |

ข้อจำกัดที่ยอมรับ:

- เพดานรวมทั้งระบบเป็นแบบ soft (คำขอพร้อมกันของหลายคนเกินได้เล็กน้อย) และถ้าไม่ได้ส่ง `global_cap` จะปฏิเสธทุกคำขอ
- เพดานพื้นที่เป็นแบบ soft: ตอน policy ทำงานยังไม่รู้ขนาดไฟล์ใหม่ จึงเกินได้ราว 1 ไฟล์ (≤ 5 MB) และมากกว่านั้นถ้าอัปโหลดขนานกัน
- เพดานพื้นที่มีผลแล้ว แต่แอปจะแสดงข้อความที่เข้าใจง่ายเมื่อพื้นที่เต็มหลังทำเฟส 3

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

### `rc-webhook` และ `sync-subscription`

- `rc-webhook`: ตรวจลายเซ็น HMAC (`X-RevenueCat-Webhook-Signature`) หรืออย่างน้อย Authorization header แบบ constant-time
- ไม่ตีความ event ทีละชนิด: ดึงสถานะล่าสุดจาก REST API ของ RevenueCat แล้ว upsert `expires_at` — ส่งซ้ำหรือมาผิดลำดับก็ได้ผลเดิม
- `TRANSFER`: sync ทุก id ใน `transferred_from` และ `transferred_to`
- ข้าม id ที่ไม่ใช่ผู้ใช้ในระบบ; ตอบ 200 เมื่อรับสำเร็จ (RevenueCat ลองใหม่ 5 ครั้งในราว 80 นาที)
- `sync-subscription`: แอปเรียกหลังซื้อ/กู้การซื้อ หรือเมื่อ SDK บอกว่าเป็นสมาชิกแต่ server บอกว่า free — ทำงานเดียวกันกับ id จาก JWT และจำกัดความถี่

## 7. แอป

| ส่วน | งาน | สถานะ |
|---|---|---|
| `ai/managed_provider.dart` | เรียก `ai-generate` ด้วย access token, แปลง error, โควตาเต็ม = `AiQuotaException` | ทำแล้ว |
| `ai/ai_settings.dart` | `AiProviderKind.managed` และความยินยอมแยกตามบัญชี | ทำแล้ว |
| `domain/` + `data/` | `UsageSummary`, `UsageRepository` | ทำแล้ว |
| `features/assistant/` | ถามความยินยอมก่อนส่งครั้งแรก; โควตาเต็ม → บอกเวลาที่ใช้ได้อีก และปุ่ม "ใช้ AI อื่น" | ทำแล้ว |
| `features/settings/` | แสดงแผน การใช้ AI และพื้นที่; ยินยอม/ถอนความยินยอม | ทำแล้ว |
| อัปโหลดรูป | พื้นที่เต็ม → domain exception พร้อมข้อความ ไม่ใช่ error ดิบจาก Storage | เฟส 3 |
| `features/subscription/` (ใหม่) | paywall, ปุ่มสมัครตอนโควตาเต็ม, กู้การซื้อ, ลิงก์จัดการการสมัคร ข้อกำหนด และความเป็นส่วนตัว | เฟส 4 |
| RevenueCat | `purchases_flutter`; `logIn(userId)` / `logOut` ตามบัญชี ส่งแค่ UUID ไม่ส่งอีเมล | เฟส 4 |

ผู้ให้บริการเริ่มต้น: คนที่ยังไม่เคยเลือกและไม่มี key บันทึกไว้เริ่มที่ AI ของแอป คนที่มี key อยู่แล้วใช้ AI Studio ต่อ

**ต้อง deploy `ai-generate` ก่อนออกแอปเวอร์ชันนี้** ไม่งั้นผู้ใช้ใหม่จะเรียก AI ไม่ได้

### ความเป็นส่วนตัว

- กฎใน `CLAUDE.md` แก้ให้รวม AI ของแอปแล้ว (RevenueCat ต้องเพิ่มในเฟส 4)
- ครั้งแรกที่ใช้ AI ของแอปต้องกดยินยอม ข้อความระบุข้อมูลที่ส่งและบริษัทที่รับ
- ก่อนเปิดจริง: อัปเดตนโยบายความเป็นส่วนตัวและแบบฟอร์มข้อมูลของ App Store / Play

## 8. ลำดับงาน

| เฟส | งาน | เสร็จเมื่อ |
|---|---|---|
| 1 | migration: ตาราง ฟังก์ชัน policy | ยิงพร้อมกัน 20 คำขอที่เพดาน 3 ผ่านแค่ 3; client เขียน `subscriptions` และเรียก `consume_ai_quota` ไม่ได้ |
| 2 | `ai-generate` + `managed` ในแอป + แสดงการใช้งาน | ให้สิทธิ์ด้วย `manual_until` แล้วโควตาเปลี่ยนตาม; `flutter analyze && flutter test` ผ่าน |
| 3 | พื้นที่เก็บรูปในแอป | เต็มแล้วเพิ่มรูปไม่ได้ แต่ดูและลบได้ |
| 4 | RevenueCat + paywall + webhook | sandbox: ซื้อ ต่ออายุ หมดอายุ คืนเงิน ย้ายบัญชี ถูกต้อง |
| 5 | ก่อนเปิดจริง | Supabase Pro, ตั้งเพดานงบกับผู้ให้บริการ AI, แจ้งเตือนค่าใช้จ่าย, ลบ `ai_usage` เก่ากว่า 90 วัน, เอกสารความเป็นส่วนตัว |

## 9. เรื่องที่ยังต้องตัดสินใจ

1. ตัวเลขโควตาและราคาสมาชิก
2. โมเดลของ AI ในแอป — โค้ดรองรับทั้งสองค่าย เริ่มที่ Haiku ต้องทดสอบภาษาไทยก่อนเลือกจริง
3. รายการที่ลบแบบ soft delete ยังเก็บรูปไว้และกินพื้นที่ ตอนนี้แอปไม่มีลบถาวร — จะลบถาวรอัตโนมัติหลัง 30 วัน, เพิ่มปุ่มลบถาวร หรือปล่อยให้นับ
4. การสมัครหลายบัญชีเพื่อเอาโควตาฟรี: รอบแรกพึ่งเพดานรวม ถ้าเจอปัญหาค่อยเพิ่ม App Attest / Play Integrity

## อ้างอิง (ตรวจเมื่อ 27 พ.ย. 2026)

- [ราคา Claude Haiku 5.5](https://platform.claude.com/docs/en/models/haiku-5-5/overview)
- [ราคา Gemini](https://aistudio.google.com/docs/pricing) · [กำหนดปิดโมเดล Gemini](https://aistudio.google.com/docs/deprecations)
- [ขีดจำกัด Edge Functions](https://supabase.com/docs/guides/functions/limits) · [ราคา Supabase](https://supabase.com/pricing)
- [RevenueCat webhooks](https://www.revenuecat.com/docs/integrations/webhooks) · [ราคา RevenueCat](https://www.revenuecat.com/pricing)
