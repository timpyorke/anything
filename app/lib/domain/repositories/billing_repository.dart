import '../billing.dart';

/// การซื้อผ่านสโตร์ — สิทธิ์จริงตัดสินที่ server (ดู UsageRepository.syncSubscription)
/// เมธอดที่ต้องคุยกับสโตร์โยน [BillingException] เมื่อไม่สำเร็จ
abstract class BillingRepository {
  /// false = รุ่นนี้ไม่ได้ตั้งค่าการขายไว้
  bool get isAvailable;

  /// ผูกการซื้อกับบัญชีที่ล็อกอิน (null = ออกจากระบบ)
  Future<void> identify(String? userId);

  Future<List<Offer>> offers();
  Future<PurchaseOutcome> buy(Offer offer);

  /// กู้การซื้อของบัญชีสโตร์นี้ คืน true ถ้าพบสมาชิกที่ใช้งานอยู่
  Future<bool> restore();

  /// สโตร์บอกว่าบัญชีนี้เป็นสมาชิกอยู่
  Future<bool> isActive();

  /// หน้าจัดการ/ยกเลิกการสมัครของสโตร์
  Future<Uri?> managementUrl();
}
