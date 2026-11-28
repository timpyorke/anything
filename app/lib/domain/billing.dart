/// แพ็กเกจสมาชิกที่สโตร์ขาย — [price] เป็นข้อความพร้อมสกุลเงินจากสโตร์
/// [period] เป็นรอบแบบ ISO 8601 เช่น P1M (null = สโตร์ไม่บอก)
typedef Offer = ({String id, String title, String price, String? period});

enum PurchaseOutcome { bought, cancelled, pending }

class BillingException implements Exception {
  BillingException(this.message);
  final String message;
  @override
  String toString() => message;
}
