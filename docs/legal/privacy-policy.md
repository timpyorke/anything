<!-- ร่าง: เขียนตามพฤติกรรมของโค้ด ณ 28 พ.ย. 2026 ยังไม่ผ่านการตรวจทางกฎหมาย
     ก่อนเผยแพร่: แทนค่าใน [วงเล็บเหลี่ยม] ทั้งหมด ให้ผู้รู้กฎหมายตรวจ แล้วลบคอมเมนต์นี้ -->

# นโยบายความเป็นส่วนตัว — anything · diary's

มีผล [วันที่] · ผู้ควบคุมข้อมูล: [ชื่อผู้ให้บริการและที่อยู่] · ติดต่อ: [อีเมลติดต่อ]

[English version below](#privacy-policy--anything--diarys)

## ข้อมูลที่เราเก็บ

| ข้อมูล | ใช้ทำอะไร | เก็บนานเท่าไร |
|---|---|---|
| อีเมลและรหัสบัญชี (จากการสมัครด้วยอีเมล Google Apple หรือ Facebook) | เข้าสู่ระบบ | จนกว่าจะลบบัญชี |
| บันทึก หมวด ตัวเลขที่ติดตาม (เช่น น้ำหนัก การนอน การใช้จ่าย) และรูปที่แนบ | ให้บริการบันทึกชีวิต | จนกว่าจะลบบัญชี (ดูหัวข้อการลบ) |
| ประวัติการใช้ AI: ข้อความที่ส่ง คำตอบ และผลการบันทึก | ให้ตรวจย้อนหลังได้ว่า AI เสนออะไร | จนกว่าจะลบบัญชี |
| จำนวนครั้งที่ใช้ AI ของแอป ชื่อโมเดล จำนวน token และเวลา (ไม่มีเนื้อหา) | จำกัดโควตาและดูค่าใช้จ่าย | ไม่เกิน 90 วัน |
| วันหมดอายุของการเป็นสมาชิก | ให้สิทธิ์ Member | จนกว่าจะลบบัญชี |
| รายงานเมื่อแอปมีปัญหา: ชนิดของข้อผิดพลาด จุดที่โค้ดผิดพลาด ข้อมูลเครื่อง และรหัสการติดตั้ง (เฉพาะเมื่อคุณเปิด) | แก้ข้อผิดพลาด | 90 วัน |
| สถิติการใช้งาน: การเปิดใช้แอป ข้อมูลเครื่อง ตำแหน่งโดยประมาณ และรหัสการติดตั้ง (เฉพาะเมื่อคุณเปิด) | ดูว่าแอปถูกใช้งานอย่างไร | [ระยะเวลาที่ตั้งใน Google Analytics] |
| รหัสสำหรับส่งการแจ้งเตือน (เฉพาะเมื่อคุณเปิด) | ส่งการแจ้งเตือน | จนกว่าจะปิด หรือรหัสหมดอายุตามรอบของ Google |

บันทึกของคุณอาจมีข้อมูลสุขภาพหรือข้อมูลอ่อนไหวอื่นตามที่คุณเลือกเขียน [ระบุฐานทางกฎหมายและวิธีขอความยินยอมโดยชัดแจ้ง]

เราไม่ใช้โฆษณา รายงานข้อผิดพลาด สถิติการใช้งาน และการแจ้งเตือนใช้ Firebase ของ Google ทั้งสามอย่างปิดไว้จนกว่าคุณจะเปิดในหน้าตั้งค่า → ความเป็นส่วนตัว และปิดได้ทุกเมื่อ (การปิดรายงานข้อผิดพลาดมีผลครบเมื่อเปิดแอปครั้งถัดไป) เราไม่แนบเนื้อหาบันทึก อีเมล หรือรหัสบัญชีไปกับข้อมูลเหล่านี้ เราไม่ได้รับข้อมูลบัตรหรือบัญชีธนาคารของคุณ

## ข้อมูลที่อยู่ในเครื่องของคุณ

- API key ที่คุณใส่เองเก็บใน Keychain/Keystore ของเครื่อง ไม่ส่งให้เรา
- เสียงที่พูดถูกถอดเป็นข้อความในเครื่อง เสียงไม่ถูกส่งออก
- ถ้าใช้ AI ในเครื่อง (Gemma) ข้อความและรูปไม่ออกจากเครื่อง แอปดาวน์โหลดไฟล์โมเดลจากแหล่งภายนอกหนึ่งครั้ง
- รูป JPEG ถูกตัดข้อมูลกำกับ เช่น พิกัดและรุ่นกล้อง ก่อนอัปโหลดหรือส่งให้ AI (เก็บไว้เฉพาะทิศของรูป) ไฟล์รูปชนิดอื่นส่งตามต้นฉบับ

## การส่งข้อมูลให้ AI

เกิดเมื่อคุณส่งข้อความหรือรูปให้ AI เท่านั้น สิ่งที่ส่ง: ข้อความและรูปที่แนบ หมวด ตัวชี้วัด รายการที่กำลังจะมาถึง รายการใน 14 วันล่าสุด และ checklist ที่ค้าง

- **AI ของแอป** (ต้องกดยินยอมก่อน ถอนได้ในหน้าตั้งค่า): ส่งผ่านเซิร์ฟเวอร์ของเราไปยัง Google (Gemini) หรือ Anthropic (Claude) ตัวส่งต่อของเราไม่เก็บเนื้อหา การเก็บรักษาของบริษัท AI เป็นไปตามเงื่อนไขของบริษัทนั้น
- **API key ของคุณเอง**: ส่งจากเครื่องของคุณตรงไปยังบริการที่คุณเลือก (Google AI Studio, Anthropic, OpenAI หรือ OpenRouter) ภายใต้เงื่อนไขระหว่างคุณกับบริการนั้น

## ผู้ให้บริการที่เกี่ยวข้อง

| ผู้ให้บริการ | ข้อมูล | ที่ตั้งการประมวลผล |
|---|---|---|
| Supabase | ฐานข้อมูล ไฟล์รูป การเข้าสู่ระบบ และเซิร์ฟเวอร์ | เกาหลีใต้ (โซล) สำหรับฐานข้อมูล |
| Google / Anthropic | เนื้อหาที่ส่งให้ AI | ต่างประเทศ |
| Google (Firebase) | รายงานข้อผิดพลาด สถิติการใช้งาน และรหัสการแจ้งเตือน ตามที่คุณเปิด ชุดพัฒนาของ Google อาจสร้างรหัสการติดตั้งแม้ยังไม่ได้เปิด | ต่างประเทศ |
| RevenueCat | รหัสบัญชี (ส่งเมื่อเข้าสู่ระบบบนแอปที่เปิดขายสมาชิก แม้ยังไม่ได้สมัคร) ข้อมูลการซื้อ และข้อมูลเครื่องที่ชุดพัฒนาของเขาเก็บ | ต่างประเทศ |
| Apple / Google Play | การชำระเงิน | ตามนโยบายของสโตร์ |
| Google / Apple / Facebook | การเข้าสู่ระบบที่คุณเลือก | ตามนโยบายของผู้ให้บริการ |

ข้อมูลของคุณจึงถูกส่งออกนอกประเทศไทย [ระบุมาตรการคุ้มครองการโอนข้อมูลข้ามประเทศ]

## การรักษาความปลอดภัย

ข้อมูลส่งผ่านการเชื่อมต่อที่เข้ารหัส และฐานข้อมูลจำกัดให้แต่ละบัญชีเข้าถึงได้เฉพาะข้อมูลของตัวเอง ข้อมูลไม่ได้เข้ารหัสแบบต้นทางถึงปลายทาง ผู้ดูแลระบบจึงเข้าถึงได้ทางเทคนิค [ระบุเงื่อนไขที่อนุญาตให้ผู้ดูแลเข้าถึง]

## การลบข้อมูล

- **ลบรายการ:** รายการถูกซ่อนจากแอป รูปของรายการถูกลบถาวรหลัง 30 วัน ส่วนข้อความยังเก็บอยู่จนกว่าจะลบบัญชี
- **ลบบัญชี:** ตั้งค่า → ลบบัญชี ข้อมูลในระบบของเราถูกลบทันที และส่งคำขอลบข้อมูลลูกค้าไปยัง RevenueCat แอปปิดการส่งข้อมูลไปยัง Firebase ในเครื่องนั้นด้วย ส่วนรายงานและสถิติที่ส่งไปแล้วจะหายตามระยะเวลาเก็บ จำนวนครั้งที่ใช้ AI เก็บต่อแบบไม่ระบุตัวคนไม่เกิน 90 วัน สำเนาสำรองและข้อมูลที่ผู้ให้บริการรายอื่นเก็บจะหายตามรอบของผู้ให้บริการ
- การลบบัญชีไม่ยกเลิกการสมัครสมาชิกกับสโตร์ ต้องยกเลิกในสโตร์

## สิทธิของคุณ

ตาม พ.ร.บ.คุ้มครองข้อมูลส่วนบุคคล คุณขอเข้าถึง ขอสำเนา แก้ไข ลบ คัดค้าน ระงับการใช้ และถอนความยินยอมได้ ติดต่อ [อีเมลติดต่อ] เราตอบภายใน [จำนวน] วัน และคุณร้องเรียนต่อสำนักงานคณะกรรมการคุ้มครองข้อมูลส่วนบุคคลได้

## อายุผู้ใช้ และการเปลี่ยนนโยบาย

บริการนี้สำหรับผู้มีอายุ [จำนวน] ปีขึ้นไป หากเปลี่ยนนโยบายอย่างมีสาระสำคัญ เราจะแจ้งในแอปก่อนมีผล

---

# Privacy Policy — anything · diary's

Effective [date] · Controller: [provider name and address] · Contact: [contact email]

## What we store

| Data | Purpose | Retention |
|---|---|---|
| Email and account ID (email, Google, Apple or Facebook sign-in) | Sign-in | Until you delete your account |
| Entries, categories, tracked numbers (such as weight, sleep, spending) and attached photos | Providing the diary | Until you delete your account (see Deletion) |
| AI history: what you sent, the answer and the saved result | So you can review what the AI proposed | Until you delete your account |
| Number of Anything AI requests, model name, token counts and time (no content) | Quotas and cost control | Up to 90 days |
| Membership expiry date | Member features | Until you delete your account |
| Crash reports: error type, where the code failed, device details and an installation ID (only if you turn them on) | Fixing faults | 90 days |
| Usage statistics: app usage, device details, approximate location and an installation ID (only if you turn them on) | Understanding how the app is used | [Retention period set in Google Analytics] |
| Notification registration ID (only if you turn notifications on) | Sending notifications | Until you turn them off, or until it expires on Google's schedule |

Your entries may contain health or other sensitive information that you choose to write. [State the legal basis and how explicit consent is obtained]

We show no ads. Crash reports, usage statistics and notifications use Google Firebase. All three are off until you turn them on in Settings → Privacy, and you can turn them off at any time (turning off crash reports takes full effect the next time the app starts). We do not attach your entries, email or account ID to this data. We do not receive your card or bank details.

## What stays on your device

- API keys you enter are kept in the device Keychain/Keystore and are not sent to us.
- Speech is transcribed on the device. Audio is not sent anywhere.
- With on-device AI (Gemma), text and photos stay on the device. The model file is downloaded once from an external source.
- Location, camera model and other metadata are removed from JPEG photos before upload or AI processing (orientation is kept). Other image formats are sent as they are.

## Sending data to AI

This happens only when you send text or photos to the AI. What is sent: your text and photos, categories, metrics, upcoming entries, entries from the last 14 days and open checklists.

- **Anything AI** (requires your consent, which you can withdraw in settings): goes through our server to Google (Gemini) or Anthropic (Claude). Our relay does not store content. The AI company's retention follows its own terms.
- **Your own API key**: goes from your device directly to the service you chose (Google AI Studio, Anthropic, OpenAI or OpenRouter) under your agreement with that service.

## Service providers

| Provider | Data | Location |
|---|---|---|
| Supabase | Database, photo files, authentication and servers | Database in South Korea (Seoul) |
| Google / Anthropic | Content sent to the AI | Outside your country |
| Google (Firebase) | Crash reports, usage statistics and the notification ID, as you turn them on. Google's SDK may create an installation ID even while they are off | Outside your country |
| RevenueCat | Account ID (sent when you sign in to a build that sells membership, even before you subscribe), purchase data and device information collected by its SDK | Outside your country |
| Apple / Google Play | Payments | Per store policy |
| Google / Apple / Facebook | The sign-in method you choose | Per provider policy |

Your data is therefore transferred outside Thailand. [State the safeguards for international transfers]

## Security

Data travels over encrypted connections, and the database restricts each account to its own data. Data is not end-to-end encrypted, so administrators can technically access it. [State when administrator access is allowed]

## Deletion

- **Deleting an entry:** it is hidden from the app. Its photos are permanently deleted after 30 days; its text is kept until you delete your account.
- **Deleting your account:** Settings → Delete account. Data in our system is deleted immediately and a customer deletion request is sent to RevenueCat. The app also turns off sending to Firebase on that device; reports and statistics already sent expire after their retention period. The count of AI requests is kept, without identifying you, for up to 90 days. Backups and data held by other providers expire on their schedules.
- Deleting your account does not cancel a store subscription. Cancel it in the store.

## Your rights

Under Thailand's Personal Data Protection Act you may request access, a copy, correction, deletion, objection, restriction and withdraw consent. Contact [contact email]; we reply within [number] days. You may complain to the Office of the Personal Data Protection Committee.

## Age and changes

This service is for people aged [number] or older. We will tell you in the app before material changes take effect.
