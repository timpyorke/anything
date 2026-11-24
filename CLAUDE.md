# anything - diary's

บันทึกชีวิตด้วย AI — แอปมือถือ Flutter + Supabase

## โครงสร้าง
```
app/        แอป Flutter (iOS/Android) — flutter analyze && flutter test ต้องผ่านเสมอ
supabase/   migrations ของฐานข้อมูล (schema + RLS)
docs/       แผนและเอกสาร (mobile-migration.md)
.vscode/    launch.json (รัน/ดีบัก), tasks.json, settings.json
```

## กฎ
- กฎการตัดสินใจของ AI ในแอปอยู่ที่ `app/lib/features/assistant/recorder.dart` (พรอมต์ + ตรวจทุก action ก่อนแสดงผู้ใช้) — ถ้าแก้ ต้องแก้ test ใน `app/test/features/assistant/recorder_test.dart` ให้ตรง
- ระบบ markdown เดิม (`legacy/`) ถูกลบแล้ว กู้ได้จาก git: `git show a4b6d1d:legacy/...` หรือ `git checkout a4b6d1d -- legacy`
- ห้าม commit `app/env.json` และ `life-export*.json` (มีข้อมูลส่วนตัว/คีย์ — อยู่ใน .gitignore แล้ว)
- ห้ามส่งข้อมูลส่วนตัวออกไปบริการภายนอกนอกจากที่ผู้ใช้เลือกในแอป (AI Studio ด้วย API key ของผู้ใช้เอง)
