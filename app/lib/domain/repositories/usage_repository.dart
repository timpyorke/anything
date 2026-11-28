import '../usage.dart';

abstract class UsageRepository {
  /// การใช้งานของผู้ใช้ที่ล็อกอินอยู่
  Future<UsageSummary> mine();
}
