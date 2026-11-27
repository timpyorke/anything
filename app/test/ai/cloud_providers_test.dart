import 'dart:async';
import 'dart:convert';

import 'package:anything/ai/anthropic_provider.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/ai/openai_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status);

Map<String, dynamic> _body(http.Request r) => jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;

Matcher _fails(String text) => throwsA(isA<LlmException>().having((e) => e.message, 'message', contains(text)));

void main() {
  group('Claude', () {
    Future<String> ask(http.Client client, [String model = 'claude-opus-5-5']) =>
        AnthropicProvider(apiKey: 'k', model: model, client: client).generateJson(system: 'ระบบ', user: 'ทัก');

    Map<String, Object> reply(String stop) => {
          'stop_reason': stop,
          'content': [
            {'type': 'thinking', 'thinking': ''},
            {'type': 'text', 'text': '{"reply":"สวัสดี"}'},
          ],
        };

    test('sends the Messages request and returns only the text blocks', () async {
      late http.Request sent;
      final text = await ask(MockClient((r) async {
        sent = r;
        return _json(reply('end_turn'));
      }));
      expect(text, '{"reply":"สวัสดี"}');
      expect(sent.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(sent.headers['x-api-key'], 'k');
      expect(sent.headers['anthropic-version'], '2026-10-21');
      expect(sent.headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
      final body = _body(sent);
      expect(body['system'], 'ระบบ');
      expect(body['messages'], [{'role': 'user', 'content': 'ทัก'}]);
      expect(body['fallbacks'], 'default');
      expect(body.keys, isNot(contains('temperature')));
    });

    test('does not ask for fallbacks on a model without them', () async {
      late http.Request sent;
      await ask(MockClient((r) async {
        sent = r;
        return _json(reply('end_turn'));
      }), 'claude-haiku-4-5');
      expect(sent.headers.keys, isNot(contains('anthropic-beta')));
      expect(_body(sent).keys, isNot(contains('fallbacks')));
    });

    test('a refusal or a cut-off answer is reported instead of returned', () async {
      await expectLater(ask(MockClient((_) async => _json(reply('refusal')))), _fails('ปฏิเสธ'));
      await expectLater(ask(MockClient((_) async => _json(reply('max_tokens')))), _fails('ยาวเกิน'));
    });

    test('HTTP errors are explained', () async {
      Future<String> failWith(int status) => ask(MockClient((_) async => _json({'type': 'error', 'error': {'message': 'm'}}, status)));
      await expectLater(failWith(401), _fails('API key ไม่ถูกต้อง'));
      await expectLater(failWith(404), _fails('claude-opus-5-5'));
      await expectLater(failWith(529), _fails('ผู้ใช้มาก'));
    });

    test('lists models across pages', () async {
      final seen = <Uri>[];
      final models = await AnthropicProvider.listModels('k', client: MockClient((r) async {
        seen.add(r.url);
        final first = r.url.queryParameters['after_id'] == null;
        return _json({'data': [{'id': first ? 'claude-b' : 'claude-a'}], 'has_more': first, 'last_id': first ? 'claude-b' : 'claude-a'});
      }));
      expect(models, ['claude-a', 'claude-b']);
      expect(seen.last.queryParameters['after_id'], 'claude-b');
    });
  });

  group('OpenAI and OpenRouter', () {
    Future<String> ask(AiProviderKind kind, http.Client client, {Future<void>? cancel}) =>
        OpenAiProvider(kind: kind, apiKey: 'k', model: 'm', client: client).generateJson(system: 'ตอบ JSON', user: 'ทัก', cancel: cancel);

    Map<String, Object?> reply(String stop, [String? content = '{}']) => {
          'choices': [
            {'finish_reason': stop, 'message': {'content': content}},
          ],
        };

    test('OpenAI gets a chat completion in JSON mode', () async {
      late http.Request sent;
      final text = await ask(AiProviderKind.openAi, MockClient((r) async {
        sent = r;
        return _json(reply('stop'));
      }));
      expect(text, '{}');
      expect(sent.url.toString(), 'https://api.openai.com/v1/chat/completions');
      expect(sent.headers['authorization'], 'Bearer k');
      expect(_body(sent)['response_format'], {'type': 'json_object'});
      expect(_body(sent)['messages'], [{'role': 'system', 'content': 'ตอบ JSON'}, {'role': 'user', 'content': 'ทัก'}]);
    });

    test('OpenRouter uses its own host and skips JSON mode', () async {
      late http.Request sent;
      await ask(AiProviderKind.openRouter, MockClient((r) async {
        sent = r;
        return _json(reply('stop'));
      }));
      expect(sent.url.toString(), 'https://openrouter.ai/api/v1/chat/completions');
      expect(_body(sent).keys, isNot(contains('response_format')));
    });

    test('failures are explained', () async {
      Future<String> run(Object body, [int status = 200]) => ask(AiProviderKind.openRouter, MockClient((_) async => _json(body, status)));
      await expectLater(run({'error': {'message': 'm'}}, 401), _fails('API key ไม่ถูกต้อง'));
      await expectLater(run({'error': {'message': 'm'}}, 402), _fails('เครดิต'));
      await expectLater(run({'error': {'message': 'ปลายทางล่ม'}}), _fails('ปลายทางล่ม'));
      await expectLater(run(reply('length')), _fails('ยาวเกิน'));
      await expectLater(run(reply('content_filter')), _fails('ปฏิเสธ'));
      await expectLater(run(reply('stop', null)), _fails('ไม่ได้ตอบกลับ'));
    });

    test('cancelling aborts the request', () async {
      final client = MockClient.streaming((request, _) async {
        await (request as http.Abortable).abortTrigger;
        throw http.RequestAbortedException(request.url);
      });
      final cancel = Completer<void>();
      final expectation = expectLater(ask(AiProviderKind.openAi, client, cancel: cancel.future), throwsA(isA<LlmCancelled>()));
      cancel.complete();
      await expectation;
    });

    test('only text chat models are listed', () async {
      final openAi = await OpenAiProvider.listModels(AiProviderKind.openAi, 'k', client: MockClient((_) async => _json({
            'data': [
              for (final id in ['gpt-b', 'o3', 'gpt-a', 'text-embedding-3', 'gpt-4o-mini-tts', 'whisper-1', 'gpt-image-1', 'gpt-5-pro'])
                {'id': id},
            ],
          })));
      expect(openAi, ['gpt-a', 'gpt-b', 'o3']);

      final router = await OpenAiProvider.listModels(AiProviderKind.openRouter, 'k', client: MockClient((_) async => _json({
            'data': [
              {'id': 'x/chat', 'architecture': {'output_modalities': ['text']}},
              {'id': 'x/draw', 'architecture': {'output_modalities': ['image']}},
            ],
          })));
      expect(router, ['x/chat']);
    });

    test('the key is never sent to another host while paging', () async {
      final hosts = <String>[];
      await OpenAiProvider.listModels(AiProviderKind.openRouter, 'k', client: MockClient((r) async {
        hosts.add(r.url.host);
        return _json({'data': [], 'links': {'next': 'https://example.com/models'}});
      }));
      expect(hosts, ['openrouter.ai']);
    });
  });
}
