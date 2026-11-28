import 'package:anything/domain/repositories/usage_repository.dart';
import 'package:anything/domain/usage.dart';

class FakeUsageRepository implements UsageRepository {
  /// ตั้งเป็น error เพื่อจำลองการโหลดไม่สำเร็จ
  Object? failure;
  var summary = const UsageSummary(
    member: false,
    aiToday: (used: 2, limit: 5),
    aiMonth: (used: 12, limit: 30),
    storage: (used: 1572864, limit: 104857600),
  );

  /// คำตอบของ syncSubscription ตามลำดับ (bool หรือ error) หมดแล้วตอบตาม [summary]
  final syncAnswers = <Object>[];
  var syncs = 0;

  @override
  Future<UsageSummary> mine() async {
    if (failure case final error?) throw error;
    return summary;
  }

  @override
  Future<PlanLimits> memberPlan() async => (aiPerDay: 40, aiPerMonth: 500, storageBytes: 5368709120);

  @override
  Future<bool> syncSubscription() async {
    syncs++;
    final answer = syncAnswers.isEmpty ? summary.member : syncAnswers.removeAt(0);
    if (answer is! bool) throw answer;
    if (answer) summary = summary.copyWith(member: true);
    return answer;
  }
}
