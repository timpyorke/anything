# anything · diary's

บันทึกชีวิตด้วย AI — เล่าเป็นภาษาธรรมชาติ AI เสนอสิ่งที่จะบันทึก คุณตรวจแล้วจึงยืนยัน

แอปมือถือ iOS / Android เขียนด้วย Flutter ใช้ Supabase เป็นฐานข้อมูล ระบบล็อกอิน ที่เก็บรูป และ server

> **สถานะ:** อยู่ระหว่างเตรียมเปิดใช้จริง ยังมีงานค้างใน [รายการตรวจก่อนเปิดจริง](docs/launch-checklist.md)

## ความสามารถ

- **บันทึกด้วยข้อความ รูป หรือเสียง** — เช่น เล่าหลายเรื่องในข้อความเดียว หรือแนบใบเสร็จ เสียงถูกถอดเป็นข้อความในเครื่อง (ต้องดาวน์โหลดโมเดล Gemma)
- **AI เสนอ คุณยืนยัน** — ทุกรายการผ่านการตรวจก่อนแสดง แก้ไขหรือเลือกไม่บันทึกได้
- **Timeline** — เหตุการณ์ บันทึกรายวัน รายการที่เกิดซ้ำ และ checklist
- **ตัวเลขและภาพรวม** — น้ำหนัก การนอน การใช้จ่าย และปฏิทินกิจกรรม
- **ค้นหา** และเลิกทำหลังลบ
- **ภาษาไทยและอังกฤษ**
- **เข้าสู่ระบบ** ด้วยอีเมล Google Apple หรือ Facebook และลบบัญชีได้ในแอป

## AI ที่เลือกใช้ได้

| ตัวเลือก | ข้อมูลที่ส่งออกจากเครื่อง | ค่าใช้จ่ายและเพดาน |
|---|---|---|
| **AI ของแอป** | ผ่าน server ของเราไปยัง Google หรือ Anthropic (ต้องกดยินยอมก่อน) | ตามโควตาของแผน |
| **Gemma บนเครื่อง** | ไม่ส่ง (ดาวน์โหลดโมเดล 2.6 GB ครั้งแรก) | ฟรี ไม่จำกัด |
| **API key ของคุณ** — Google AI Studio, Claude, OpenAI, OpenRouter | ส่งตรงไปยังบริการที่เลือก | ตามราคาของบริการนั้น |

### แผน Free และ Member

| | Free | Member |
|---|---|---|
| AI ของแอป ต่อวัน / ต่อเดือน | 5 / 30 | 40 / 500 |
| พื้นที่เก็บรูป | 100 MB | 5 GB |

เป็นค่าเริ่มต้นในตาราง `plans` แก้ได้โดยไม่ต้องออกแอปใหม่ การสมัคร Member ใช้ In-App Purchase ผ่าน RevenueCat รายละเอียดอยู่ใน [แผนโควตา](docs/rate-limit.md)

## โครงสร้างโปรเจกต์

```
app/                  แอป Flutter
  lib/domain/         entity และ interface ของ repository
  lib/data/           การเชื่อมต่อ Supabase และ RevenueCat
  lib/features/       หน้าจอและ view model แยกตามฟีเจอร์
  lib/ai/             ผู้ให้บริการ AI
  test/
supabase/
  migrations/         schema, RLS, โควตา และงานตั้งเวลา
  functions/          Edge Functions
docs/                 แผน คู่มือตั้งค่า และร่างเอกสารกฎหมาย
```

สถาปัตยกรรมเป็น Clean Architecture + MVVM ใช้ Riverpod และ freezed กฎของโปรเจกต์อยู่ใน [CLAUDE.md](CLAUDE.md)

## เริ่มต้นใช้งาน

### สิ่งที่ต้องมี

- Flutter ที่มี Dart 3.12.2 ขึ้นไป
- โปรเจกต์ Supabase และ [Supabase CLI](https://supabase.com/docs/guides/local-development)
- Xcode (iOS 15 ขึ้นไป) หรือ Android SDK (Android 11 ขึ้นไป, arm64)
- [Deno](https://deno.com) ถ้าจะแก้หรือทดสอบ Edge Functions

### 1. ตั้งฐานข้อมูล

```bash
supabase link --project-ref <ref>
supabase db push
```

จากนั้นรันใน SQL Editor หนึ่งครั้ง เพื่อให้งานตั้งเวลาลบรูปของรายการที่ลบแล้วเรียก server ได้:

```sql
select vault.create_secret('https://<ref>.supabase.co', 'project_url');
```

### 2. Deploy Edge Functions

| ฟังก์ชัน | หน้าที่ | secret |
|---|---|---|
| `ai-generate` | AI ของแอปและการหักโควตา | `GEMINI_API_KEY` หรือ `ANTHROPIC_API_KEY` · `AI_PROVIDER` (`anthropic` เป็นค่าเริ่มต้น หรือ `gemini`) · `AI_MODEL` และ `AI_GLOBAL_DAILY_CAP` (ไม่บังคับ) |
| `subscription` | webhook และ sync สถานะสมาชิก | `REVENUECAT_API_KEY` (secret key v1) · `REVENUECAT_WEBHOOK_AUTH` หรือ `REVENUECAT_WEBHOOK_SECRET` · `REVENUECAT_ENTITLEMENT` (ไม่บังคับ) |
| `delete-account` | ลบบัญชีและข้อมูลของผู้ใช้ | `REVENUECAT_API_KEY` (เมื่อเปิดขายสมาชิก) |
| `purge-photos` | ลบรูปของรายการที่ลบเกิน 30 วัน | – |

ตั้ง secret ที่ Dashboard → Edge Functions → Secrets แล้วรัน:

```bash
supabase functions deploy
```

ใช้ API key ของ AI แบบเสียเงิน เพราะ Gemini แบบฟรีนำข้อมูลไปปรับปรุงผลิตภัณฑ์

### 3. Firebase (ไม่บังคับ)

ใช้ Crashlytics, Analytics และ Cloud Messaging ของโปรเจกต์ `anything-1f48b` ถ้าไม่มีไฟล์ตั้งค่า แอปยัง build และใช้งานได้ แค่ไม่แสดงสวิตช์ในหมวดความเป็นส่วนตัว

```bash
npx firebase-tools login
npx firebase-tools apps:create android --package-name com.codenour.anything --project anything-1f48b   # ครั้งแรกครั้งเดียว
npx firebase-tools apps:create ios --bundle-id com.codenour.anything --project anything-1f48b          # ครั้งแรกครั้งเดียว
npx firebase-tools apps:sdkconfig android <app id> --out app/android/app/google-services.json
npx firebase-tools apps:sdkconfig ios <app id> --out app/ios/Runner/GoogleService-Info.plist
```

- iOS: ต้องเพิ่ม `GoogleService-Info.plist` เข้า target Runner ใน Xcode ด้วย (ลากไฟล์เข้าโฟลเดอร์ Runner)
- Firebase console: เปิด Crashlytics, Google Analytics และอัปโหลด APNs key (`.p8`) ที่ Project settings → Cloud Messaging
- ทดสอบการแจ้งเตือน: รัน debug เปิดสวิตช์การแจ้งเตือน แล้วนำ `FCM installation id` จาก log ไปใส่ในหน้า Send test message

### 4. รันแอป

```bash
cd app
cp env.example.json env.json
flutter pub get
dart run build_runner build
flutter run --dart-define-from-file=env.json
```

| ค่าใน `env.json` | จำเป็น | ใช้ทำอะไร |
|---|---|---|
| `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | ใช่ | เชื่อมต่อ Supabase |
| `REVENUECAT_APPLE_KEY`, `REVENUECAT_GOOGLE_KEY` | ไม่ | public SDK key — ไม่ใส่ แพลตฟอร์มนั้นจะไม่แสดงปุ่มสมัคร |
| `TERMS_URL`, `PRIVACY_URL` | ก่อนเปิดขาย | ลิงก์ในหน้าตั้งค่าและหน้าสมัคร |

ใน VS Code กด F5 แล้วเลือก configuration ได้เลย (ดู `.vscode/launch.json`)

- ปุ่มเข้าสู่ระบบด้วย Google / Apple / Facebook ต้องเปิดผู้ให้บริการใน Supabase ก่อน — [คู่มือ](docs/social-login.md)
- Gemma บนเครื่องต้องทดสอบบนเครื่องจริง iOS Simulator ใช้ GPU ไม่ได้ และบน iOS ต้องเซ็นด้วย Apple Developer team

## ทดสอบ

```bash
# แอป
cd app
flutter analyze && flutter test

# Edge Function (รันจากรากของโปรเจกต์ เปลี่ยนชื่อโฟลเดอร์ตามฟังก์ชัน)
cd supabase/functions/ai-generate
deno task test
```

## ความปลอดภัยและความเป็นส่วนตัว

- ทุกตารางเปิด Row Level Security ผู้ใช้เข้าถึงได้เฉพาะข้อมูลของตัวเอง โควตาและสถานะสมาชิกเขียนได้จาก server เท่านั้น
- แอปมีเฉพาะ publishable key ส่วน secret key อยู่ใน Supabase
- API key ที่ผู้ใช้ใส่เองเก็บใน Keychain/Keystore ของเครื่อง
- ห้าม commit `app/env.json`, `life-export*.json` และ secret ใดๆ

## เอกสาร

| เอกสาร | เนื้อหา |
|---|---|
| [launch-checklist.md](docs/launch-checklist.md) | งานที่เหลือก่อนเปิดจริง |
| [rate-limit.md](docs/rate-limit.md) | โควตา ต้นทุน การสมัครสมาชิก และการลบบัญชี |
| [social-login.md](docs/social-login.md) | ตั้งค่าการเข้าสู่ระบบ |
| [mobile-migration.md](docs/mobile-migration.md) | การย้ายจากระบบ markdown เดิม |
| [legal/](docs/legal/) | **ร่าง**นโยบายความเป็นส่วนตัว ข้อกำหนด และหน้าลบบัญชี (ยังไม่ผ่านการตรวจทางกฎหมาย) |

## ผู้พัฒนา

Timp Yorke
