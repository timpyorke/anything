# anything - diary's — แอปมือถือ (Flutter)

บันทึกชีวิตด้วย AI: เล่าเป็นภาษาธรรมชาติ → AI เสนอสิ่งที่จะบันทึก → คุณยืนยัน
ข้อมูลอยู่บน Supabase · AI เลือกได้ระหว่าง Gemma 4 E2B บนเครื่อง หรือบริการออนไลน์ด้วย API key ของคุณเอง: Google AI Studio, Claude, OpenAI, OpenRouter

## รัน
```
cp env.example.json env.json     # ใส่ค่า Supabase (env.json ไม่เข้า git)
flutter run --dart-define-from-file=env.json
```
ต้องรัน migration ใน `../supabase/migrations/` กับโปรเจกต์ Supabase ก่อน — ดู `../docs/mobile-migration.md`

## โครงสร้าง
แยกตามฟีเจอร์ (feature-first) — แต่ละฟีเจอร์อยู่ในโฟลเดอร์เดียว โค้ดที่ใช้ร่วมกันอยู่ใน `core/` และ `domain/`
```
lib/
  main.dart                  จุดเริ่มต้น: ตั้งค่า Supabase / AI แล้วเปิดแอป
  app/                       anything_app (MaterialApp + ล็อกอิน), app_shell (แท็บล่าง), app_theme, missing_config_page
  core/
    utils/                   dates (พ.ศ., ป้าย "อีก 5 วัน"), markdown (+ checklist), format
    widgets/                 pill, markdown_view, stat_tile, empty_state
  domain/                    entry, recurrence (เกิดซ้ำ), category, metric, entry_validation — ไม่พึ่ง UI/เครือข่าย
  data/repository.dart       ทุกการเรียก Supabase + นำเข้าไฟล์ JSON (life-dashboard-export)
  state/app_state.dart       AppState (ChangeNotifier)
  ai/                        llm_provider (interface), ai_settings, ai_studio_provider, on_device_provider (Gemma)
  features/
    timeline/                timeline_page, timeline_filter, entry_card
    assistant/               assistant_page (แท็บ "บันทึก"), recorder (พรอมต์ + ตรวจ action ของ AI)
    entry_editor/            entry_editor_page (เพิ่ม/แก้เอง)
    overview/                overview_page, activity_heatmap
    metrics/                 metrics_page, trend_chart, metric_colors
    settings/                settings_page
    auth/                    auth_page
test/                        โครงสร้างเหมือน lib/ (core/utils, domain, features/assistant)
```

## ข้อกำหนดของ Gemma บนเครื่อง (flutter_edge_ai + LiteRT-LM)
- Android: `minSdk 30`, arm64 เท่านั้น (ตั้งแล้ว)
- iOS 15+, entitlements เพิ่มหน่วยความจำใน `ios/Runner/Runner.entitlements` (ตั้งแล้ว) — ต้องเซ็นด้วย Apple Developer team ใน Xcode
- iOS Simulator ใช้ GPU ไม่ได้ ทดสอบ Gemma บนเครื่องจริง

## ตรวจ
```
flutter analyze && flutter test
```
