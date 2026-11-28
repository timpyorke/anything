import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/repositories/usage_repository.dart';
import '../domain/usage.dart';
import 'mappers/row_mappers.dart';

class SupabaseUsageRepository implements UsageRepository {
  SupabaseUsageRepository(this.db);
  final SupabaseClient db;

  @override
  Future<UsageSummary> mine() async => usageFromJson(Map<String, dynamic>.from(await db.rpc('get_my_usage') as Map));
}
