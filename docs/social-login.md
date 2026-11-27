# เข้าสู่ระบบด้วย Google / Apple / Facebook

โค้ดในแอปพร้อมแล้ว แต่ปุ่มจะใช้ได้เมื่อเปิดผู้ให้บริการนั้นใน Supabase · เปิดเฉพาะตัวที่ตั้งค่าเสร็จแล้วก็ได้

| | iOS | Android |
|---|---|---|
| Google | หน้าเว็บ | หน้าเว็บ |
| Apple | หน้าต่างของระบบ (Face ID) | หน้าเว็บ |
| Facebook | หน้าเว็บ | หน้าเว็บ |

หน้าเว็บ = `ASWebAuthenticationSession` (iOS) / แท็บของเบราว์เซอร์ (Android) แล้วส่งผลกลับมาที่ `com.codenour.anything://login-callback` (PKCE)
ความลับ (client secret, app secret, ไฟล์ `.p8`) ใส่ใน Supabase Dashboard เท่านั้น — ห้ามใส่ในแอปหรือ commit

## 1. Supabase (ทำครั้งเดียว)
Authentication → URL Configuration → Redirect URLs → เพิ่ม `com.codenour.anything://login-callback`

ค่าที่ต้องเอาไปกรอกในฝั่งผู้ให้บริการทุกเจ้า (callback URL):
`https://<project-ref>.supabase.co/auth/v1/callback`

## 2. Google
1. Google Cloud Console → Google Auth Platform → ตั้งค่า Branding / Audience
2. Clients → Create client → ชนิด **Web application** (ใช้ชนิดนี้ทั้ง iOS และ Android เพราะล็อกอินผ่านหน้าเว็บ)
3. Authorized redirect URIs: ใส่ callback URL
4. Supabase → Authentication → Sign In / Providers → Google: ใส่ Client ID และ Client Secret แล้วเปิดใช้

ถ้า Audience ยังเป็นโหมดทดสอบ ต้องเพิ่มอีเมลตัวเองเป็น test user

## 3. Apple
ต้องมีบัญชี Apple Developer แบบเสียเงิน

**ใช้บน iOS อย่างเดียว** (ไม่ต้องมี secret)
1. App ID `com.codenour.anything` เปิด capability **Sign in with Apple** (entitlement ในโปรเจกต์ใส่ไว้แล้ว)
2. Supabase → Providers → Apple: Client IDs = `com.codenour.anything` แล้วเปิดใช้

**ถ้าจะใช้บน Android ด้วย**
1. Identifiers → สร้าง **Services ID** (เช่น `com.codenour.anything.web`) เปิด Sign in with Apple: Domain = `<project-ref>.supabase.co`, Return URL = callback URL
2. Keys → สร้าง key ที่เปิด Sign in with Apple → ดาวน์โหลด `.p8`
3. สร้าง client secret จาก Team ID, Key ID, `.p8` และ Services ID (มีเครื่องมือในหน้า [เอกสาร Supabase](https://supabase.com/docs/guides/auth/social-login/auth-apple))
4. Supabase → Providers → Apple: Client IDs = `com.codenour.anything.web,com.codenour.anything` (**Services ID ต้องอยู่ตัวแรก**) และใส่ Secret Key

⚠ secret ของ Apple ต้องสร้างใหม่ทุก 6 เดือน ไม่งั้นการล็อกอินบน Android จะใช้ไม่ได้ — ตั้งเตือนไว้

## 4. Facebook
1. developers.facebook.com → สร้างแอป → เพิ่ม use case การเข้าสู่ระบบ (Facebook Login)
2. สิทธิ์ `public_profile` และ `email` ต้องเพิ่มแล้วทั้งคู่
3. Facebook Login → Settings → Valid OAuth Redirect URIs: ใส่ callback URL
4. App settings → Basic: คัดลอก App ID และ App Secret ไปใส่ Supabase → Providers → Facebook แล้วเปิดใช้

โหมด development ล็อกอินได้เฉพาะบัญชีที่มีบทบาทในแอป (admin/developer/tester) ก่อนเปิดให้คนอื่นใช้ต้องใส่ Privacy Policy URL แล้วสลับเป็น Live (Meta อาจขอตรวจแอป)

## บัญชีเดียวกันหรือคนละบัญชี
- อีเมล (ที่ยืนยันแล้ว) ตรงกับบัญชีเดิม → Supabase ผูกเข้าบัญชีเดิม บันทึกเดิมยังอยู่
- อีเมลไม่ตรง — รวมถึง Apple แบบ **ซ่อนอีเมล (Hide My Email)** → ได้บัญชีใหม่ที่ยังไม่มีบันทึก
- ถ้าปิดรับสมัครใหม่ไว้ (แนะนำเมื่อใช้คนเดียว) บริการภายนอกจะเข้าได้เฉพาะบัญชีที่มีอยู่แล้ว

## ตรวจหลังตั้งค่า
- กดแต่ละปุ่ม → เข้าแอปได้ และหน้าตั้งค่าแสดงอีเมลบัญชีที่ถูกต้อง
- กดปุ่มแล้วปิดหน้าล็อกอิน → กลับมาหน้าเดิมโดยไม่มีข้อความผิดพลาด
- เห็นข้อความ `provider is not enabled` ในหน้าเว็บ = ยังไม่ได้เปิดผู้ให้บริการใน Supabase
