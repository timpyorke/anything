# Deploy ด้วย GitHub Actions

workflow อยู่ใน `.github/workflows/` ทุกตัว**กดรันเอง** (Actions → เลือก workflow → Run workflow) และรันได้จาก `main` เท่านั้น
ปุ่ม Run workflow จะขึ้นหลังไฟล์ workflow อยู่บน `main` แล้ว

| workflow | ทำอะไร | ตรวจก่อน |
|---|---|---|
| **Deploy Supabase** | apply migration แล้ว deploy Edge Functions ทั้งหมด | `deno task test` ทุกฟังก์ชัน |
| **Deploy Android** | ส่ง APK ให้ Firebase App Distribution และ/หรือ AAB ขึ้น Google Play (internal testing) | `flutter analyze && flutter test` |
| **Deploy iOS** | ส่ง IPA ขึ้น TestFlight | `flutter analyze && flutter test` |

## 1. สร้าง environment

GitHub → Settings → Environments → New environment ชื่อ `production`

- ใส่ secret และ variable ทั้งหมดข้างล่างใน environment นี้
- Deployment branches: เลือกเฉพาะ `main`
- ถ้าแพ็กเกจของ repo รองรับ เปิด Required reviewers เพื่อให้ต้องกดอนุมัติก่อน deploy

ใส่เฉพาะของ workflow ที่จะใช้ก็พอ ขาดค่าไหน workflow จะหยุดตั้งแต่ต้นและบอกชื่อค่านั้น

ตัวอย่างใช้ [GitHub CLI](https://cli.github.com) (หรือวางค่าในหน้าเว็บก็ได้):

```bash
gh secret set APP_ENV_JSON --env production < app/env.json
base64 -i release.keystore | gh secret set ANDROID_KEYSTORE_BASE64 --env production
gh variable set SUPABASE_PROJECT_REF --env production --body <ref>
```

## 2. Supabase

| ชื่อ | ชนิด | ได้จาก |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | secret | Supabase → Account → Access Tokens |
| `SUPABASE_DB_PASSWORD` | secret | รหัสผ่านฐานข้อมูลของโปรเจกต์ (Project Settings → Database) |
| `SUPABASE_PROJECT_REF` | variable | ส่วนหน้าของ URL โปรเจกต์ `https://<ref>.supabase.co` |

- ช่อง **dry_run ติ๊กไว้เป็นค่าเริ่มต้น** จะทดสอบและแสดง migration ที่ค้างเท่านั้น เอาออกเมื่อจะ deploy จริง
- secret ของฟังก์ชัน (เช่น `GEMINI_API_KEY`) และ vault `project_url` ยังตั้งเองตาม [README](../README.md) workflow ไม่แตะ
- migration ย้อนกลับอัตโนมัติไม่ได้ ดูผล dry run ก่อนทุกครั้ง

## 3. ค่าที่แอปใช้ร่วมกัน

| ชื่อ | ชนิด | ค่า |
|---|---|---|
| `APP_ENV_JSON` | secret | เนื้อหาของ `app/env.json` (ใส่เฉพาะ publishable key และ public SDK key) |
| `BUILD_NUMBER_OFFSET` | variable (ไม่บังคับ) | เลข build = ค่านี้ (เริ่มต้น 100) + เลขรอบของ workflow |

เลข build ต้องมากกว่าที่เคยส่งขึ้นสโตร์ ระบุเองตอนกดรันได้ ถ้ากด Re-run หลังอัปโหลดสำเร็จแล้ว สโตร์จะปฏิเสธเลขซ้ำ ให้กดรันรอบใหม่
เลขเวอร์ชัน (เช่น 1.0.0) มาจาก `version` ใน `app/pubspec.yaml`

## 4. Android

### keystore (ทำครั้งเดียว)

```bash
keytool -genkeypair -v -keystore release.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

เก็บไฟล์และรหัสผ่านไว้ที่ปลอดภัยนอก repo ถ้าหายจะส่งอัปเดตด้วย key เดิมไม่ได้ (บน Google Play ต้องขอรีเซ็ต upload key)

| ชื่อ (secret) | ค่า |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i release.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | รหัสผ่าน keystore |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | รหัสผ่านของ key |
| `GOOGLE_SERVICES_JSON` | เนื้อหาของ `app/android/app/google-services.json` |

เซ็น release ในเครื่อง: ตั้ง `ANDROID_KEYSTORE_PATH` (path เต็ม) และ 3 ตัวแปรข้างบนเป็น environment variable ไม่ตั้งจะใช้ debug key

ลายนิ้วมือ (SHA) ของ key ใหม่ต้องเพิ่มในบริการที่ตรวจ package ของแอป (เช่น Firebase → Project settings → แอป Android)

### Firebase App Distribution

1. Firebase console → App Distribution → เริ่มใช้งาน และสร้างกลุ่มผู้ทดสอบ
2. Google Cloud console (โปรเจกต์ `anything-1f48b`) → สร้าง service account ให้ role **Firebase App Distribution Admin** แล้วสร้าง key แบบ JSON

| ชื่อ | ชนิด | ค่า |
|---|---|---|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | secret | เนื้อหาไฟล์ key |
| `FIREBASE_TESTER_GROUPS` | variable (ไม่บังคับ) | alias ของกลุ่ม คั่นด้วยจุลภาค — ไม่ใส่จะอัปโหลดโดยยังไม่ส่งให้ใคร |

### Google Play

1. สร้างแอป `com.codenour.anything` ใน Play Console และอัปโหลด AAB ครั้งแรกด้วยมือ (เซ็นด้วย keystore เดียวกัน)
2. เปิด Google Play Android Developer API สร้าง service account แล้วเชิญใน Play Console → Users and permissions ให้สิทธิ์ release ไปยัง testing track ของแอปนี้

| ชื่อ (secret) | ค่า |
|---|---|
| `PLAY_SERVICE_ACCOUNT_JSON` | เนื้อหาไฟล์ key |

แอปที่ยังไม่เคยเผยแพร่ ให้เลือก `play_status` เป็น `draft`

## 5. iOS (TestFlight)

เตรียมใน Apple Developer (team เดียวกับ `DEVELOPMENT_TEAM` ในโปรเจกต์):

1. App ID `com.codenour.anything` เปิด Push Notifications, Sign in with Apple, Extended Virtual Addressing และ Increased Memory Limit (รวมแบบ Debugging ให้ตรงกับ `Runner.entitlements`)
2. certificate **Apple Distribution** แล้ว export จาก Keychain Access เป็น `.p12`
3. provisioning profile แบบ **App Store Connect** ของ App ID นี้ ที่ผูกกับ certificate ข้อ 2 (แก้ capability แล้วต้องสร้าง profile ใหม่)
4. สร้างแอปใน App Store Connect
5. App Store Connect → Users and Access → Integrations → สร้าง API key (role App Manager)

| ชื่อ (secret) | ค่า |
|---|---|
| `GOOGLE_SERVICE_INFO_PLIST` | เนื้อหาของ `app/ios/Runner/GoogleService-Info.plist` |
| `IOS_CERTIFICATE_BASE64` | `base64 -i distribution.p12` |
| `IOS_CERTIFICATE_PASSWORD` | รหัสผ่านของ `.p12` |
| `IOS_PROFILE_BASE64` | `base64 -i profile.mobileprovision` |
| `APPSTORE_API_KEY_ID` | Key ID |
| `APPSTORE_API_ISSUER_ID` | Issuer ID |
| `APPSTORE_API_PRIVATE_KEY` | เนื้อหาไฟล์ `AuthKey_<id>.p8` |

- certificate และ profile หมดอายุทุกปี ต้องสร้างใหม่และเปลี่ยน secret
- ตอนรันบน CI สคริปต์ `.github/scripts/ios-signing.sh` ตั้งการเซ็นแบบ manual และเปลี่ยน APNs เป็น production ไฟล์ใน repo ไม่ถูกแก้
- หลังอัปโหลด App Store Connect อาจถามเรื่อง export compliance (การเข้ารหัส) ก่อนส่งให้ผู้ทดสอบ

## การดูแล

- action จากภายนอกตรึงไว้ที่ commit SHA จะอัปเกรดให้เปลี่ยนทั้ง SHA และเลขเวอร์ชันในคอมเมนต์
- เลข Flutter (`3.50.1`) อยู่ใน 3 workflow ของแอป เปลี่ยนพร้อมกัน
- iOS ใช้ Xcode ค่าเริ่มต้นของ runner `macos-26`
