/// ค่าเชื่อมต่อ Supabase มาจากตอน build:
///   flutter run --dart-define-from-file=env.json
/// env.json (ไม่อยู่ใน git): {"SUPABASE_URL": "...", "SUPABASE_PUBLISHABLE_KEY": "..."}
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// การสมัคร Member (ไม่บังคับ — ไม่ใส่ key ของแพลตฟอร์มไหน แพลตฟอร์มนั้นจะไม่แสดงปุ่มสมัคร)
/// เป็น public SDK key ของ RevenueCat ฝังในแอปได้ ส่วน secret key อยู่ที่ Edge Function เท่านั้น
const revenueCatAppleKey = String.fromEnvironment('REVENUECAT_APPLE_KEY');

const revenueCatGoogleKey = String.fromEnvironment('REVENUECAT_GOOGLE_KEY');

/// ลิงก์ที่สโตร์บังคับให้มีบนหน้าสมัคร
const termsUrl = String.fromEnvironment('TERMS_URL');

const privacyUrl = String.fromEnvironment('PRIVACY_URL');
