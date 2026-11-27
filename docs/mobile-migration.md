# แผนย้าย anything - diary's ไปเป็นแอปมือถือ (Flutter + Supabase)

## ภาพรวม

| | ระบบเดิม | ระบบใหม่ (phase 1) |
|---|---|---|
| หน้าจอ | `dashboard.html` (เว็บไฟล์เดียว) | แอป Flutter (`app/`) iOS + Android |
| ฐานข้อมูล | ไฟล์ markdown (`data/*.md`) | Supabase Postgres + RLS (`supabase/migrations/`) |
| หมวด/metric | `config.json` | ตาราง `categories`, `metric_defs` (มี foreign key บังคับ) |
| AI | Claude Code + `CLAUDE.md` + `life.py` | ในแอป: **Gemma 4 E2B บนเครื่อง** หรือ **Google AI Studio** (ผู้ใช้ใส่ API key เอง) |
| ตัวกันความผิดพลาด | `life.py add` + `build.py --check` | `validateEntry` ในแอป + CHECK constraint ในฐานข้อมูล |
| ตรวจสอบย้อนหลัง | git history | ตาราง `ai_logs` (AI เสนออะไร ผู้ใช้รับหรือไม่) + soft delete |

## หลักการออกแบบที่คงไว้จากระบบเดิม
- **AI เสนอ ผู้ใช้ยืนยัน** — AI แปลงข้อความเป็น action (สร้าง / แก้ / ติ๊ก checklist / เพิ่ม metric) ทุก action ผ่านการตรวจก่อนแสดง ที่ผิดจะแสดงพร้อมเหตุผลแต่เลือกบันทึกไม่ได้
- **คำศัพท์ควบคุม** — AI ใช้ได้เฉพาะหมวด/metric ที่มีอยู่; metric ใหม่ต้องเป็น action แยกให้ผู้ใช้อนุมัติ
- **AI อ้างอิงรายการด้วยรหัสสั้น (R1, R2…)** ไม่เห็น uuid จริง จึงอ้าง id มั่วไม่ได้
- **รายการที่เกิดซ้ำ** เก็บเป็นแถวเดียว (`every`, `times`, `until`) คำนวณแต่ละครั้งในแอป — ผลเหมือน `build.py` (มี unit test เทียบ)
- **บันทึกรายวัน** มีได้หลายแถวต่อวัน (1 เรื่อง = 1 รายการ) แก้ตัวเลขที่บันทึกแล้วด้วย action แก้ไขรายการเดิม

## Schema (สรุป)
```
categories(user_id, key, label, color, description, sort)          PK (user_id, key)
metric_defs(user_id, key, label, unit, description)                PK (user_id, key)
entries(id, user_id, kind[event|daily], date, end_date, category→categories,
        title, body(markdown), every, times, until, source[manual|ai|import],
        legacy_ref, created_at, updated_at, deleted_at)
metric_values(id, user_id, entry_id→entries, key→metric_defs, value, unit)   UNIQUE (entry_id, key)
ai_logs(id, user_id, provider, model, input, output jsonb, status, error, created_at)  — insert/select เท่านั้น
```
ทุกตารางเปิด RLS: `user_id = auth.uid()` · แอปใช้ publishable key เท่านั้น (ไม่มี service key ในแอป)

---

## Phase 1 — ย้ายข้อมูลและเริ่มใช้แอป (โค้ดพร้อมแล้ว)

### 1. ตั้ง Supabase
1. สร้างโปรเจกต์ (แนะนำ region Singapore `ap-southeast-1` ใกล้ไทยที่สุด)
2. รัน migration: `supabase link --project-ref <ref>` แล้ว `supabase db push`
   (หรือวางไฟล์ใน `supabase/migrations/` ใน SQL Editor ทีละไฟล์ตามลำดับชื่อ)
3. Authentication → Email: เลือกว่าจะบังคับยืนยันอีเมลหรือไม่ (ใช้คนเดียวปิดได้ แต่ควรปิดการสมัครใหม่หลังสร้างบัญชีตัวเองแล้ว)
4. ตรวจ Security Advisor ว่าไม่มีตารางที่ไม่ได้เปิด RLS

### 2. รันแอป
```
cd app
cp env.example.json env.json        # ใส่ SUPABASE_URL และ SUPABASE_PUBLISHABLE_KEY
flutter run --dart-define-from-file=env.json
```
สมัครบัญชี → แอปสร้างหมวดและ metric เริ่มต้นให้ (`seed_defaults()`)

### 3. ย้ายข้อมูลเดิม
ไฟล์ข้อมูลเดิม export ไว้แล้วที่ `life-export.json` (root ของโปรเจกต์, อยู่ใน .gitignore — 6 รายการ 9 หมวด 8 metric)
ส่งไฟล์เข้ามือถือ (AirDrop / Files) → แอป: ตั้งค่า → นำเข้าจากระบบเดิม
- นำเข้าซ้ำได้: ข้ามรายการที่ `legacy_ref` ตรงกับที่เคยนำเข้า
- หมายเหตุ `<!-- ... -->` ในไฟล์ markdown ไม่ถูกนำเข้า (เช่นหมายเหตุสมมติงวดแรกค่างวดรถ)
- ถ้าไฟล์สูญหาย: `git checkout a4b6d1d -- legacy && python3 legacy/life.py export > life-export.json`

### 4. ตรวจว่าย้ายครบ
| ตรวจ | ค่าที่ควรเห็น |
|---|---|
| จำนวนรายการ | ภาพรวม → รายการทั้งหมด = 6 |
| ค่างวดรถ | การ์ดเดียว ครั้งที่ 19/72 · สะสม 396,432 บาท · คงเหลือ 1,189,296 บาท |
| checklist ทริปปักกิ่ง | 0/3 |
| ตัวเลขล่าสุด | น้ำหนัก 75 kg, ส่วนสูง 179 cm |

### 5. หลังย้ายเสร็จ
- **แอปเป็นแหล่งความจริงเดียว** — ระบบ markdown เดิม (`legacy/`) ถูกลบออกจาก repo แล้ว (กู้ได้จาก git commit `a4b6d1d`)
- ข้อมูลใหม่บันทึกผ่านแอปเท่านั้น

### การเลือก AI ในแอป
| | Gemma 4 E2B บนเครื่อง | Google AI Studio |
|---|---|---|
| ข้อมูลออกจากเครื่อง | ไม่ | ใช่ (ไปที่ Google) |
| ต้องใช้เน็ต | ครั้งแรกเพื่อดาวน์โหลด 2.6 GB | ทุกครั้ง |
| ความแม่นยำภาษาไทย/การตัดสินใจ | พอใช้ | ดีกว่า (Gemini) |
| เครื่องที่ต้องการ | RAM ≥ 6 GB, iOS 15+/Android 11+ arm64 | ทุกเครื่อง |
| ค่าใช้จ่าย | ฟรี | ตามโควตา/ราคาของ AI Studio |
- API key เก็บใน Keychain/Keystore ของเครื่อง ไม่ส่งขึ้น Supabase และไม่อยู่ในโค้ด
- ⚠ ข้อมูลที่ส่งผ่าน AI Studio แบบไม่เสียเงินอาจถูก Google นำไปใช้ปรับปรุงบริการ (ตรวจเงื่อนไขปัจจุบันของ Google) — ข้อมูลอ่อนไหว (สุขภาพ การเงิน) ควรใช้ Gemma บนเครื่องหรือแพ็กเกจที่เสียเงิน
- Gemma บน GPU แบบ half precision อาจคัดลอกตัวเลข/วันที่ผิด แอปจึงใช้ float32 บน iOS และ CPU บน Android และทุก action ยังผ่านการตรวจวันที่/ตัวเลขอีกชั้น

---

## Phase 2 — ใช้งานจริงทุกวัน
1. **Offline-first**: cache ในเครื่อง (SQLite/drift) + คิวการเขียนตอนไม่มีเน็ต แล้ว sync ภายหลัง (ตอนนี้ต้องออนไลน์)
2. **แจ้งเตือน**: ค่างวด/นัดหมายล่วงหน้า 1 วัน, checklist ที่ค้างใกล้วันเดินทาง (local notifications จากรายการที่เกิดซ้ำ)
3. **ทบทวนรายสัปดาห์ในแอป** (แทน `/review`): AI สรุปและเสนอ "สิ่งที่ควรทำ" บันทึกเป็นหมวด `review`
4. **ส่งออก/สำรองข้อมูล** เป็น JSON รูปแบบ life-dashboard-export เดียวกับที่นำเข้า (ย้ายกลับหรือย้ายไปที่อื่นได้เสมอ)
5. **จัดการหมวด/metric ในแอป** (เพิ่ม/แก้สี/ชื่อ) แทนการแก้ SQL
6. **Claude Code อ่านฐานข้อมูลเดียวกัน** ผ่าน Supabase MCP เพื่อวิเคราะห์เชิงลึกบนคอมพิวเตอร์

## Phase 3 — ต่อยอด
- ค้นหาด้วยความหมาย (EmbeddingGemma บนเครื่อง + pgvector)
- บันทึกด้วยเสียง (Gemma 4 รับเสียงได้) และรูปใบเสร็จ
- Flutter web (ถ้าอยากดูบนคอมพิวเตอร์)

## ความเสี่ยงและวิธีรับมือ
| ความเสี่ยง | วิธีรับมือ |
|---|---|
| ข้อมูลส่วนตัวอยู่บนคลาวด์ | RLS ทุกตาราง, ไม่มี service key ในแอป, ปิดการสมัครใหม่, ตรวจ Security Advisor |
| AI บันทึกผิด | ผู้ใช้ยืนยันทุกครั้ง, ตรวจก่อนแสดง + CHECK constraint, `ai_logs`, soft delete + เลิกทำ |
| โมเดลบนเครื่องใหญ่/ช้าบนมือถือเก่า | เลือก AI Studio ได้, ดาวน์โหลดเฉพาะเมื่อผู้ใช้เลือก, ลบโมเดลได้ในหน้าตั้งค่า |
| ย้ายข้อมูลไม่ครบ | นำเข้าซ้ำได้ (legacy_ref), ตารางตรวจข้อ 4, `life-export.json` + กู้ markdown เดิมจาก git ได้ |
| ล็อกอยู่กับ Supabase | เป็น Postgres มาตรฐาน + export JSON (phase 2) |
