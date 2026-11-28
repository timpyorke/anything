# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# anything - diary's

บันทึกชีวิตด้วย AI — แอปมือถือ Flutter + Supabase

## โครงสร้าง
```
app/        แอป Flutter (iOS/Android) — flutter analyze && flutter test ต้องผ่านเสมอ
supabase/   migrations ของฐานข้อมูล (schema + RLS) และ Edge Functions (functions/)
docs/       แผนและเอกสาร (mobile-migration.md, rate-limit.md, launch-checklist.md, legal/)
.vscode/    launch.json (รัน/ดีบัก), tasks.json, settings.json
```

## คำสั่ง
แอป (รันใน `app/`):
```bash
flutter pub get
dart run build_runner build                       # สร้าง *.freezed.dart
flutter run --dart-define-from-file=env.json      # env.json คัดลอกจาก env.example.json
flutter analyze && flutter test
flutter test test/features/assistant/recorder_test.dart       # ไฟล์เดียว
flutter test <ไฟล์> --plain-name 'ส่วนหนึ่งของชื่อ test'          # test เดียว
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=env.json
flutter build ios --simulator --debug --dart-define-from-file=env.json
```
Edge Functions (รันใน `supabase/functions/<ชื่อ>/`):
```bash
deno task test
deno task test --filter 'ส่วนหนึ่งของชื่อ test'
```
Supabase (รันจากรากของโปรเจกต์ — เปลี่ยนของจริงบนโปรเจกต์ที่ link ไว้):
```bash
supabase db push
supabase functions deploy
```
การตั้งค่าครั้งแรก (secret ของฟังก์ชัน, vault `project_url` สำหรับ cron) อยู่ใน `README.md`

## สถาปัตยกรรม (app/lib) — Clean Architecture + MVVM, Riverpod + freezed
- `domain/` entity (freezed, immutable) + `repositories/` (interface) + กฎ validate — ไม่รู้จัก Flutter UI/Supabase
- `data/` implement repository (Supabase) + `mappers/` แปลงแถว DB ↔ entity
- `app/providers.dart` provider ระดับ infrastructure (Supabase client, repository, storage, auth)
- `features/<ชื่อ>/` = View (`*_page.dart`, ConsumerWidget) + ViewModel (`*_view_model.dart`, Notifier) + State (freezed) — View แค่ watch state แล้วเรียกเมธอดของ ViewModel
- ข้อมูลของผู้ใช้ (diary, ตัวกรอง) ผูกกับ `currentUserIdProvider` จึงถูกสร้างใหม่เมื่อเปลี่ยนบัญชี
- `DiaryViewModel` (`features/diary/`) เป็นที่เก็บข้อมูลกลาง: โหลดหมวด metric และรายการทั้งหมดครั้งเดียว หน้าอื่นอ่านจาก `DiaryState` และเขียนผ่าน ViewModel นี้ ซึ่งแก้ทั้ง state และฐานข้อมูล
- `main.dart` โหลดภาษาและการตั้งค่า AI ก่อนวาดหน้าแรก ไม่มีค่า Supabase จะแสดง `MissingConfigApp`
- ทดสอบ ViewModel โดย override `diaryRepositoryProvider` ด้วย `test/support/fake_diary_repository.dart` และ override `currentUserIdProvider` (fake ของ billing/usage อยู่ใน `test/support/` เหมือนกัน)
- แก้ไฟล์ที่มี `@freezed` แล้วต้องรัน `dart run build_runner build` (ไฟล์ `*.freezed.dart` อยู่ใน .gitignore — clone ใหม่ต้องรันก่อน build/test)

### เส้นทางของ AI
`TurnViewModel` (`features/assistant/`, 1 instance ต่อ 1 เรื่องที่ส่ง) → `AiSettingsViewModel.resolveProvider()` (`ai/ai_settings.dart`) → `Recorder.run` สร้างพรอมต์จาก `DiaryState`, เรียก `LlmProvider.generateJson`, ตรวจคำตอบเป็น `ProposedAction` → ผู้ใช้เลือกและยืนยัน → `apply()` บันทึกผ่าน `DiaryViewModel` และเขียน `ai_logs`

- ทุกผู้ให้บริการใน `ai/` implement `LlmProvider` (`ai/llm_provider.dart`) แค่รับพรอมต์แล้วคืนข้อความ JSON — กฎของแอปไม่อยู่ใน provider
- การถอดเสียงใช้ Gemma บนเครื่องเสมอ (`transcriberProvider`) ไม่ว่าจะเลือก AI ตัวไหน
- Gemma บนเครื่องทดสอบบน iOS Simulator ไม่ได้ (ใช้ GPU ไม่ได้)
- เพิ่ม `AiProviderKind` ต้องเพิ่ม migration แก้ check constraint `ai_logs_provider_check` ให้ตรงกับ `id`

### ฝั่ง server (supabase/)
- แต่ละฟังก์ชันแยก `index.ts` (อ่าน env แล้ว `Deno.serve`) กับ `handler.ts` (รับ dependency เข้ามา) — `handler_test.ts` ใช้ของปลอม ไม่ต่อเครือข่าย
- ทุกฟังก์ชันตั้ง `verify_jwt = false` ใน `config.toml` จึง**ต้องตรวจสิทธิ์ใน handler เอง** (token ของผู้ใช้, secret ของ webhook หรือ token ของ cron)

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
- ลบบัญชีทำที่ `supabase/functions/delete-account/` — ตารางใหม่ที่มีข้อมูลผู้ใช้ต้อง `references auth.users on delete cascade` (ข้อยกเว้นโดยตั้งใจ: `ai_usage` ใช้ `set null` เก็บยอดใช้แบบไม่ระบุตัวคน) และไฟล์ใน storage ต้องอยู่ใต้โฟลเดอร์ `<user id>/` ของ bucket ที่ฟังก์ชันนี้ลบ (เพิ่ม bucket ต้องแก้ฟังก์ชัน)
- โควตาบังคับที่ฐานข้อมูล (`consume_ai_quota`, policy ของ storage) แอปแค่แสดงผล — ตัวเลขอยู่ในตาราง `plans`
