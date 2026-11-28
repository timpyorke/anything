import 'dart:convert';

import 'package:anything/data/supabase_usage_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseUsageRepository _repo(Future<http.Response> Function(http.Request) handler) {
  final db = SupabaseClient('https://x.test', 'key',
      httpClient: MockClient(handler),
      authOptions: const AuthClientOptions(autoRefreshToken: false, authFlowType: AuthFlowType.implicit));
  addTearDown(db.dispose);
  return SupabaseUsageRepository(db);
}

http.Response _json(http.Request r, Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'}, request: r);

void main() {
  test('sync calls the subscription function and reads membership', () async {
    late http.Request sent;
    final repo = _repo((r) async {
      sent = r;
      return _json(r, {'member': true});
    });
    expect(await repo.syncSubscription(), isTrue);
    expect((sent.method, sent.url.path), ('POST', '/functions/v1/subscription/sync'));
  });

  test('a throttled or failed sync throws instead of reporting “not a member”', () async {
    for (final status in [429, 502]) {
      final repo = _repo((r) async => _json(r, {'error': {'code': 'x'}}, status));
      await expectLater(repo.syncSubscription(), throwsA(isA<FunctionException>()));
    }
  });

  test('member benefits come from the plans table', () async {
    late http.Request sent;
    final repo = _repo((r) async {
      sent = r;
      return _json(r, {'plan': 'pro', 'ai_per_minute': 10, 'ai_per_day': 40, 'ai_per_month': 500, 'storage_bytes': 5368709120});
    });
    expect(await repo.memberPlan(), (aiPerDay: 40, aiPerMonth: 500, storageBytes: 5368709120));
    expect(sent.url.path, '/rest/v1/plans');
    expect(sent.url.queryParameters['plan'], 'eq.pro');
  });
}
