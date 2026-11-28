/// ค่าเชื่อมต่อ Supabase มาจากตอน build:
///   flutter run --dart-define-from-file=env.json
/// env.json (ไม่อยู่ใน git): {"SUPABASE_URL": "...", "SUPABASE_PUBLISHABLE_KEY": "..."}
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
