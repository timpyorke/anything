# anything - diary's

บันทึกชีวิตด้วย AI — แอปมือถือ Flutter + Supabase

## โครงสร้าง
```
app/        แอป Flutter (iOS/Android) — flutter analyze && flutter test ต้องผ่านเสมอ
supabase/   migrations ของฐานข้อมูล (schema + RLS)
docs/       แผนและเอกสาร (mobile-migration.md)
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
- รูปของรายการลบเฉพาะที่ส่งใน `removedPhotos` ของ `DiaryRepository.update` — รูปที่ไม่อยู่ใน `entry.photos` ไม่ถูกลบ
- ระบบ markdown เดิม (`legacy/`) ถูกลบแล้ว กู้ได้จาก git: `git show a4b6d1d:legacy/...` หรือ `git checkout a4b6d1d -- legacy`
- ห้าม commit `app/env.json` และ `life-export*.json` (มีข้อมูลส่วนตัว/คีย์ — อยู่ใน .gitignore แล้ว)
- ห้ามส่งข้อมูลส่วนตัวออกไปบริการภายนอกนอกจากที่ผู้ใช้เลือกในแอป (Google AI Studio, Claude, OpenAI หรือ OpenRouter ด้วย API key ของผู้ใช้เอง)
