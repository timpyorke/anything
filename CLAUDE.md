# anything - diary's

บันทึกชีวิตด้วย AI — แอปมือถือ Flutter + Supabase

## โครงสร้าง
```
app/        แอป Flutter (iOS/Android) — flutter analyze && flutter test ต้องผ่านเสมอ
supabase/   migrations ของฐานข้อมูล (schema + RLS) และ Edge Functions (functions/)
docs/       แผนและเอกสาร (mobile-migration.md, rate-limit.md, launch-checklist.md, legal/)
.vscode/    launch.json (รัน/ดีบัก), tasks.json, settings.json
```

## สถาปัตยกรรม (app/lib) — Clean Architecture + MVVM, Riverpod + freezed
- `domain/` entity (freezed, immutable) + `repositories/` (interface) + กฎ validate — ไม่รู้จัก Flutter UI/Supabase
- `data/` implement repository (Supabase) + `mappers/` แปลงแถว DB ↔ entity
- `app/providers.dart` provider ระดับ infrastructure (Supabase client, repository, storage, auth)
- `features/<ชื่อ>/` = View (`*_page.dart`, ConsumerWidget) + ViewModel (`*_view_model.dart`, Notifier) + State (freezed) — View แค่ watch state แล้วเรียกเมธอดของ ViewModel
- ข้อมูลของผู้ใช้ (diary, ตัวกรอง) ผูกกับ `currentUserIdProvider` จึงถูกสร้างใหม่เมื่อเปลี่ยนบัญชี
- ทดสอบ ViewModel โดย override `diaryRepositoryProvider` ด้วย `test/support/fake_diary_repository.dart`
- แก้ไฟล์ที่มี `@freezed` แล้วต้องรัน `dart run build_runner build` (ไฟล์ `*.freezed.dart` อยู่ใน .gitignore — clone ใหม่ต้องรันก่อน build/test)

## กฎ
- ข้อความที่ผู้ใช้เห็นอยู่ใน `app/lib/core/l10n/` (ประกาศใน `app_strings.dart` แล้วใส่ให้ครบ `strings_th.dart` และ `strings_en.dart`) — View ใช้ `ref.watch(stringsProvider)`, ViewModel ใช้ `ref.read`; รองรับไทย (ค่าเริ่มต้น) และอังกฤษ
- กฎการตัดสินใจของ AI ในแอปอยู่ที่ `app/lib/features/assistant/recorder.dart` (พรอมต์ + ตรวจทุก action ก่อนแสดงผู้ใช้) — ถ้าแก้ ต้องแก้ test ใน `app/test/features/assistant/recorder_test.dart` ให้ตรง
- เข้าสู่ระบบด้วย Google/Apple/Facebook: `app/lib/data/supabase_social_auth_repository.dart` · scheme ใน `authCallbackScheme` ต้องตรงกับ `AndroidManifest.xml` · การตั้งค่าฝั่ง dashboard อยู่ที่ `docs/social-login.md`
- รูปของรายการลบเฉพาะที่ส่งใน `removedPhotos` ของ `DiaryRepository.update` — รูปที่ไม่อยู่ใน `entry.photos` ไม่ถูกลบ
- รูปของรายการที่ soft delete ถูกลบถาวรหลัง 30 วันโดย `supabase/functions/purge-photos` (cron) — ถ้าแก้กำหนดต้องแก้ข้อความ `photosPurgedLater` ด้วย
- ระบบ markdown เดิม (`legacy/`) ถูกลบแล้ว กู้ได้จาก git: `git show a4b6d1d:legacy/...` หรือ `git checkout a4b6d1d -- legacy`
- ห้าม commit `app/env.json` และ `life-export*.json` (มีข้อมูลส่วนตัว/คีย์ — อยู่ใน .gitignore แล้ว)
- ห้ามส่งข้อมูลส่วนตัวออกไปบริการภายนอกนอกจากที่ผู้ใช้เลือกในแอป:
  - Google AI Studio, Claude, OpenAI หรือ OpenRouter ด้วย API key ของผู้ใช้เอง
  - RevenueCat (การสมัคร Member): SDK ในแอปและ Edge Function `subscription` ส่งเฉพาะ id บัญชี (UUID) กับข้อมูลการซื้อ — ห้ามตั้งอีเมล ชื่อ หรือ subscriber attribute อื่น
  - AI ของแอป (`AiProviderKind.managed`): ผ่าน Edge Function ของเราไปยัง Anthropic หรือ Google ด้วย key ของเรา — เฉพาะเมื่อผู้ใช้เลือกและกดยินยอมแล้ว (ยินยอมแยกตามบัญชี) ถ้าเพิ่มข้อมูลที่ส่ง หรือเพิ่มผู้ให้บริการ ต้องแก้ข้อความ `managedConsentMessage` และขอความยินยอมใหม่
- แก้ `supabase/functions/<ชื่อ>/` แล้วต้องรัน `deno task test` ในโฟลเดอร์นั้น
- `supabase/functions/ai-generate/` ห้ามเก็บหรือ log พรอมต์ รูป และคำตอบ · สัญญา request/error ต้องตรงกับ `app/lib/ai/managed_provider.dart`
- สถานะสมาชิกเขียนได้จาก `supabase/functions/subscription/` เท่านั้น (ผ่าน `apply_subscription`) แอปไม่เชื่อ SDK อย่างเดียว ต้องให้ server ยืนยัน · ชื่อ entitlement `pro` ต้องตรงกันระหว่าง RevenueCat, secret ของฟังก์ชัน และ `RevenueCatBillingRepository`
- เปลี่ยนข้อมูลที่เก็บ ระยะเวลาเก็บ หรือผู้ให้บริการที่รับข้อมูล ต้องแก้ `docs/legal/` ให้ตรง
- ลบบัญชีทำที่ `supabase/functions/delete-account/` — ตารางใหม่ที่มีข้อมูลผู้ใช้ต้อง `references auth.users on delete cascade` และไฟล์ใน storage ต้องอยู่ใต้โฟลเดอร์ `<user id>/` ของ bucket ที่ฟังก์ชันนี้ลบ (เพิ่ม bucket ต้องแก้ฟังก์ชัน)
- โควตาบังคับที่ฐานข้อมูล (`consume_ai_quota`, policy ของ storage) แอปแค่แสดงผล — ตัวเลขอยู่ในตาราง `plans`
