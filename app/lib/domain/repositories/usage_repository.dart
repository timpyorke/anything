import '../usage.dart';

abstract class UsageRepository {
  /// การใช้งานของผู้ใช้ที่ล็อกอินอยู่
  Future<UsageSummary> mine();

  /// สิ่งที่สมาชิกได้
  Future<PlanLimits> memberPlan();

  /// ให้ server ถามสถานะสมาชิกล่าสุดจากผู้ให้บริการการสมัคร คืน true ถ้าเป็นสมาชิก
  Future<bool> syncSubscription();
}
