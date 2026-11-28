import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/repositories/account_repository.dart';

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this.db);
  final SupabaseClient db;

  /// ค่า confirm ต้องตรงกับ supabase/functions/delete-account
  @override
  Future<void> delete() => db.functions.invoke('delete-account', body: {'confirm': 'delete'});
}
