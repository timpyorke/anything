import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:anything/ai/llm_provider.dart';
import 'package:anything/ai/managed_provider.dart';
import 'package:anything/core/l10n/strings_en.dart';
import 'package:anything/data/mappers/row_mappers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/photos.dart';

ManagedProvider _provider(http.Client client, {String? token = 'jwt'}) => ManagedProvider(
      access: (endpoint: Uri.parse('https://x.test/functions/v1/ai-generate'), apiKey: 'pub', accessToken: () async => token),
      strings: const EnStrings(),
      client: client,
    );

Future<String> _ask(ManagedProvider p, {List<Uint8List> images = const [], Future<void>? cancel}) =>
    p.generateJson(system: 'ระบบ', user: 'ทัก', images: images, cancel: cancel);

/// คำตอบของ server ที่สถานะ [status]
ManagedProvider _answering(int status, Object body) =>
    _provider(MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode(body)), status)));

void main() {
  test('sends the prompt and photos with the session token, and returns the text', () async {
    late http.Request sent;
    final photo = png();
    final provider = _provider(MockClient((r) async {
      sent = r;
      return http.Response.bytes(utf8.encode(jsonEncode({'text': '{"reply":"สวัสดี"}'})), 200);
    }));
    expect(await _ask(provider, images: [photo]), '{"reply":"สวัสดี"}');
    expect(sent.url.path, '/functions/v1/ai-generate');
    expect(sent.headers['authorization'], 'Bearer jwt');
    expect(sent.headers['apikey'], 'pub');
    expect(jsonDecode(sent.body), {
      'system': 'ระบบ',
      'user': 'ทัก',
      'images': [
        {'mime': 'image/png', 'data': base64Encode(photo)},
      ],
    });
  });

  test('without a session nothing is sent', () async {
    var requests = 0;
    final provider = _provider(MockClient((_) async => http.Response('{}', 200 + requests++ * 0)), token: null);
    await expectLater(_ask(provider), throwsA(isA<LlmException>()));
    expect(requests, 0);
  });

  test('quota errors say when the app’s AI is available again, in local time', () async {
    const resetAt = '2026-11-29T00:00:00+07:00';
    final when = const EnStrings().fmtDateTime(DateTime.parse(resetAt).toLocal());
    for (final (status, code, expected) in [
      (429, 'quota_minute', 'Wait a moment'),
      (429, 'quota_day', when),
      (429, 'quota_month', when),
      (503, 'service_busy', 'full for today'),
    ]) {
      final provider = _answering(status, {
        'error': {'code': code, 'message': code, 'plan': 'free', 'reset_at': resetAt},
      });
      await expectLater(
          _ask(provider), throwsA(isA<AiQuotaException>().having((e) => e.message, code, contains(expected))));
    }
  });

  test('only a free account’s own quota can be raised by subscribing', () async {
    for (final (code, plan, upgradable) in [
      ('quota_minute', 'free', true),
      ('quota_day', 'free', true),
      ('quota_month', 'free', true),
      ('quota_day', 'pro', false),
      ('service_busy', 'free', false),
    ]) {
      final provider = _answering(429, {'error': {'code': code, 'plan': plan}});
      await expectLater(_ask(provider),
          throwsA(isA<AiQuotaException>().having((e) => e.upgradable, '$code $plan', upgradable)));
    }
  });

  test('other errors are not quota errors', () async {
    for (final (status, body, expected) in <(int, Object, String)>[
      (401, {'error': {'code': 'unauthorized'}}, 'session expired'),
      (413, {'error': {'code': 'too_large'}}, 'too large'),
      (422, {'error': {'code': 'refused'}}, 'refused'),
      (422, {'error': {'code': 'answer_too_long'}}, 'too long'),
      (422, {'error': {'code': 'empty_answer'}}, 'did not answer'),
      (502, {'error': {'code': 'provider_error'}}, 'HTTP 502'),
      (404, {'message': 'Function not found'}, 'HTTP 404'),
      (200, {'text': '  '}, 'HTTP 200'),
    ]) {
      await expectLater(
          _ask(_answering(status, body)),
          throwsA(allOf(
              isNot(isA<AiQuotaException>()),
              isA<LlmException>().having((e) => e.message.toLowerCase(), '$status', contains(expected.toLowerCase())))));
    }
  });

  test('cancelling aborts the request', () async {
    final cancel = Completer<void>();
    final provider = _provider(MockClient.streaming((request, _) async {
      await (request as http.AbortableRequest).abortTrigger;
      throw http.RequestAbortedException();
    }));
    final result = _ask(provider, cancel: cancel.future);
    cancel.complete();
    await expectLater(result, throwsA(isA<LlmCancelled>()));
  });

  test('the usage returned by the database maps to the app’s summary', () {
    final usage = usageFromJson({
      'plan': 'pro',
      'ai': {
        'day': {'used': 1, 'limit': 40},
        'month': {'used': 9, 'limit': 500},
      },
      'storage': {'used': 624266, 'limit': 5368709120},
    });
    expect(usage.member, isTrue);
    expect(usage.aiToday, (used: 1, limit: 40));
    expect(usage.aiMonth, (used: 9, limit: 500));
    expect(usage.storage, (used: 624266, limit: 5368709120));
  });
}
