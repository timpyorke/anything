/// บริการภายนอกที่ใช้เข้าสู่ระบบได้ — [label] เป็นชื่อแบรนด์ ไม่ต้องแปล
enum SocialProvider {
  google('Google'),
  apple('Apple'),
  facebook('Facebook');

  const SocialProvider(this.label);
  final String label;
}

abstract interface class SocialAuthRepository {
  /// เข้าสู่ระบบ (บัญชีใหม่จะถูกสร้างให้เอง) — ผู้ใช้กดยกเลิกเองให้จบเงียบๆ ไม่โยน error
  Future<void> signIn(SocialProvider provider);
}
