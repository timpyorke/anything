import 'dart:convert';

import 'package:anything/data/supabase_diary_repository.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/photo.dart';
import 'package:anything/domain/repositories/diary_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/photos.dart';

const _limit = 1000;

/// Supabase ปลอม: อัปโหลดได้ [room] ไฟล์ หลังจากนั้น Storage ปฏิเสธ และยอดใช้พื้นที่เป็น [used]
class _Server {
  _Server({this.room = 0, this.used = _limit, this.usageStatus = 200});
  int room;
  final int used, usageStatus;
  final log = <String>[];
  final removed = <String>[];

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    http.Response json(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'}, request: r);
    if (path.endsWith('/auth/v1/token')) {
      return json({
        'access_token': 'a', 'token_type': 'bearer', 'expires_in': 3600, 'refresh_token': 'r',
        'user': {'id': 'user', 'aud': 'authenticated', 'app_metadata': {}, 'user_metadata': {}, 'created_at': '2026-01-01T00:00:00Z'},
      });
    }
    if (r.method == 'POST' && path.startsWith('/storage/v1/object/entry-photos/')) {
      if (room-- > 0) {
        log.add('upload');
        return json({'Key': path});
      }
      log.add('rejected');
      return json({'statusCode': '403', 'error': 'Unauthorized', 'message': 'new row violates row-level security policy'}, 400);
    }
    if (path.endsWith('/rpc/get_my_usage')) {
      log.add('usage');
      return json({
        'plan': 'free',
        'ai': {'day': {'used': 0, 'limit': 5}, 'month': {'used': 0, 'limit': 30}},
        'storage': {'used': used, 'limit': _limit},
      }, usageStatus);
    }
    if (r.method == 'DELETE' && path == '/storage/v1/object/entry-photos') {
      log.add('remove');
      removed.addAll(((jsonDecode(r.body) as Map)['prefixes'] as List).cast<String>());
      return json([]);
    }
    log.add('${r.method} $path');
    return json({'message': 'unexpected'}, 500);
  }
}

Future<SupabaseDiaryRepository> _repo(_Server server) async {
  final db = SupabaseClient('https://x.test', 'key',
      httpClient: MockClient(server.handle),
      authOptions: const AuthClientOptions(autoRefreshToken: false, authFlowType: AuthFlowType.implicit));
  addTearDown(db.dispose);
  await db.auth.signInWithPassword(email: 'a@x.test', password: 'p');
  return SupabaseDiaryRepository(db);
}

Entry _entry(int photos) => Entry(
    date: DateTime.utc(2026, 11, 28), category: 'daily', photos: [for (var i = 0; i < photos; i++) Photo(bytes: png(i))]);

void main() {
  test('a rejected upload with no space left becomes StorageFullException and writes no row', () async {
    final server = _Server();
    final repo = await _repo(server);
    await expectLater(repo.insert(_entry(1)), throwsA(isA<StorageFullException>().having((e) => e.limit, 'limit', _limit)));
    expect(server.log, ['rejected', 'usage']);
  });

  test('space is checked before the files uploaded in the same save are removed', () async {
    final server = _Server(room: 2);
    final repo = await _repo(server);
    await expectLater(repo.insert(_entry(3)), throwsA(isA<StorageFullException>()));
    expect(server.log, ['upload', 'upload', 'rejected', 'usage', 'remove']);
    expect(server.removed, hasLength(2));
  });

  test('editing an entry while full changes nothing', () async {
    final server = _Server();
    final repo = await _repo(server);
    await expectLater(repo.update(_entry(1).copyWith(id: 'e1')), throwsA(isA<StorageFullException>()));
    expect(server.log, ['rejected', 'usage']);
  });

  test('a rejected upload with space left, or unknown usage, keeps the storage error', () async {
    for (final server in [_Server(used: _limit - 1), _Server(usageStatus: 500)]) {
      final repo = await _repo(server);
      await expectLater(repo.insert(_entry(1)), throwsA(isA<StorageException>()));
    }
  });
}
