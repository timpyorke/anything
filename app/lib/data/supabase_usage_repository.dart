import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/repositories/usage_repository.dart';
import '../domain/usage.dart';
import 'mappers/row_mappers.dart';

class SupabaseUsageRepository implements UsageRepository {
  SupabaseUsageRepository(this.db);
  final SupabaseClient db;

  @override
  Future<UsageSummary> mine() async => usageFromJson(Map<String, dynamic>.from(await db.rpc('get_my_usage') as Map));

  @override
  Future<PlanLimits> memberPlan() async => planLimitsFromRow(await db.from('plans').select().eq('plan', 'pro').single());

  @override
  Future<bool> syncSubscription() async {
    final response = await db.functions.invoke('subscription/sync');
    return (response.data as Map)['member'] == true;
  }
}
