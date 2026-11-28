# anything - diary's — แอปมือถือ (Flutter)

บันทึกชีวิตด้วย AI: เล่าเป็นภาษาธรรมชาติ → AI เสนอสิ่งที่จะบันทึก → คุณตรวจแล้วยืนยัน

แอป iOS / Android ข้อมูลอยู่บน Supabase ภาพรวมของโปรเจกต์ การตั้งฐานข้อมูล และการ deploy Edge Functions อยู่ใน [README หลัก](../README.md)

## รัน

ต้องมี Flutter ที่มี Dart 3.12.2 ขึ้นไป และโปรเจกต์ Supabase ที่รัน migration กับ deploy ฟังก์ชันแล้ว คำสั่งทั้งหมดรันใน `app/`

```bash
cp env.example.json env.json     # ใส่ SUPABASE_URL และ SUPABASE_PUBLISHABLE_KEY
flutter pub get
dart run build_runner build
flutter run --dart-define-from-file=env.json
```

- `env.json` ไม่เข้า git ถ้าไม่ใส่ค่า Supabase แอปจะแสดงหน้าแจ้งว่ายังไม่ได้ตั้งค่า
- ค่าที่ไม่บังคับ: `REVENUECAT_APPLE_KEY`, `REVENUECAT_GOOGLE_KEY` (ปุ่มสมัคร Member) และ `TERMS_URL`, `PRIVACY_URL` (ลิงก์ข้อกำหนด ต้องมีก่อนเปิดขาย)
- `*.freezed.dart` ไม่เข้า git ต้องรัน `build_runner` หลัง clone และหลังแก้ไฟล์ที่มี `@freezed`
- ปุ่มเข้าสู่ระบบด้วย Google / Apple / Facebook ต้องเปิดผู้ให้บริการใน Supabase ก่อน — [คู่มือ](../docs/social-login.md)
- ใน VS Code กด F5 แล้วเลือก configuration ได้เลย (path ของ Flutter SDK อยู่ใน `../.vscode/settings.json` ปรับให้ตรงกับเครื่อง)

### Build
```bash
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=env.json
flutter build ios --simulator --debug --dart-define-from-file=env.json
```

## หน้าจอ

หน้าแรกคือ Timeline มีกล่องพิมพ์ลอยด้านล่างสำหรับส่งข้อความ รูป หรือเสียงให้ AI ผลที่ AI เสนอแสดงในแผ่นล่าง (bottom sheet) ให้เลือกก่อนบันทึก ปุ่มบนแถบหัวเปิดหน้าค้นหา ภาพรวม และตั้งค่า

- รูป: ส่งได้ 4 รูปต่อข้อความ เก็บได้ 10 รูปต่อรายการ
- เสียง: คลิปละไม่เกิน 30 วินาที ถอดเป็นข้อความด้วย Gemma ในเครื่อง ต้องดาวน์โหลดโมเดลก่อน แม้จะเลือก AI ตัวอื่นไว้บันทึก
- ภาษา: ไทย (ค่าเริ่มต้น) และอังกฤษ เลือกได้ในหน้าตั้งค่า

## AI

| ตัวเลือก | โค้ด | ต้องตั้งค่า |
|---|---|---|
| AI ของแอป (ค่าเริ่มต้นของผู้ใช้ใหม่) | `ai/managed_provider.dart` → Edge Function `ai-generate` | กดยินยอมก่อนใช้ มีโควตาตามแผน |
| Gemma 4 E2B บนเครื่อง | `ai/on_device_provider.dart` | ดาวน์โหลดโมเดลประมาณ 2.6 GB ครั้งแรก |
| Google AI Studio | `ai/ai_studio_provider.dart` | API key ของผู้ใช้ |
| Claude | `ai/anthropic_provider.dart` | API key ของผู้ใช้ |
| OpenAI, OpenRouter | `ai/openai_provider.dart` | API key ของผู้ใช้ |

ทุกตัว implement `LlmProvider` (`ai/llm_provider.dart`) พรอมต์และการตรวจคำตอบอยู่ที่ `features/assistant/recorder.dart` ที่เดียว API key และความยินยอมเก็บใน Keychain/Keystore แยกตามบัญชี

### ข้อกำหนดของ Gemma บนเครื่อง (flutter_edge_ai + LiteRT-LM)
- Android: `minSdk 30`, arm64 เท่านั้น (ตั้งแล้ว)
- iOS 15 ขึ้นไป entitlements เพิ่มหน่วยความจำอยู่ใน `ios/Runner/Runner.entitlements` (ตั้งแล้ว) ต้องเซ็นด้วย Apple Developer team ใน Xcode
- iOS Simulator ใช้ GPU ไม่ได้ ให้ทดสอบบนเครื่องจริง

## โครงสร้าง

Clean Architecture + MVVM ใช้ Riverpod และ freezed

```
lib/
  main.dart     เริ่ม Firebase, Supabase และ Gemma โหลดภาษากับการตั้งค่า AI แล้วเปิดแอป
  app/          MaterialApp + ล็อกอิน, ธีม, ภาษา, ค่าจาก env, provider ระดับ infrastructure
  domain/       entity, กฎ validate และ repositories/ (interface)
  data/         implement repository (Supabase, RevenueCat, Firebase), เลือกรูป, mappers/ แถว DB ↔ entity
  ai/           ผู้ให้บริการ AI, การตั้งค่า AI, อัดเสียง
  core/         l10n/ (ข้อความไทย/อังกฤษ), utils/, widgets/
  features/     account, assistant, auth, diary, entry_editor, overview,
                photos, search, settings, subscription, timeline
test/           ai, app, core, data, domain, features และ support/ (repository ปลอม)
```

- แต่ละฟีเจอร์แยก View (`*_page.dart`) กับ ViewModel (`*_view_model.dart`) View แค่ watch state แล้วเรียกเมธอดของ ViewModel
- `features/diary/` ถือข้อมูลบันทึกทั้งหมดของผู้ใช้ หน้าอื่นอ่านและเขียนผ่าน `DiaryViewModel`
- ข้อความที่ผู้ใช้เห็นประกาศใน `core/l10n/app_strings.dart` แล้วใส่ให้ครบทั้ง `strings_th.dart` และ `strings_en.dart`

## ตรวจ

```bash
flutter analyze && flutter test                                  # ต้องผ่านเสมอ
flutter test test/features/assistant/recorder_test.dart          # ไฟล์เดียว
flutter test <ไฟล์> --plain-name 'ส่วนหนึ่งของชื่อ test'               # test เดียว
```

กฎของโปรเจกต์ (ความเป็นส่วนตัว โควตา การลบข้อมูล) อยู่ใน [CLAUDE.md](../CLAUDE.md)
