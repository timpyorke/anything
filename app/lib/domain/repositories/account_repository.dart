abstract class AccountRepository {
  /// ลบบัญชีที่ล็อกอินอยู่และข้อมูลทั้งหมดบน server อย่างถาวร (ไม่สำเร็จจะโยน error และบัญชียังอยู่)
  Future<void> delete();
}
