/// ข้อมูลที่ผู้ใช้เลือกเองว่าจะใช้ผ่าน Firebase — ปิดทั้งหมดจนกว่าผู้ใช้จะเปิด
enum DataSharing { crashReports, analytics, notifications }

abstract interface class DataSharingRepository {
  /// false = build นี้ไม่มีไฟล์ตั้งค่า Firebase
  bool get isAvailable;

  /// ใช้ค่าที่ผู้ใช้เคยเลือกตอนเปิดแอป คืนเฉพาะรายการที่ยังใช้ได้จริง
  /// (เช่น ปิดการแจ้งเตือนในการตั้งค่าของเครื่องแล้ว จะไม่คืน notifications)
  Future<Set<DataSharing>> restore(Set<DataSharing> enabled);

  /// ผู้ใช้เปิดหรือปิดเอง คืน false ถ้าเปิดไม่ได้เพราะระบบของเครื่องไม่อนุญาต
  Future<bool> setEnabled(DataSharing kind, bool enabled);
}

/// ใช้เมื่อไม่มี Firebase
class NoDataSharingRepository implements DataSharingRepository {
  const NoDataSharingRepository();

  @override
  bool get isAvailable => false;

  @override
  Future<Set<DataSharing>> restore(Set<DataSharing> enabled) async => const {};

  @override
  Future<bool> setEnabled(DataSharing kind, bool enabled) async => false;
}
