import 'dart:async';
import 'dart:convert';

import 'package:anything/ai/ai_studio_provider.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/photos.dart';

void main() {
  test('sends the prompt with the key and returns the reply text', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'candidates': [
            {'content': {'parts': [{'text': '{"reply":"สวัสดี"}'}]}},
          ],
        })),
        200,
      );
    });
    final text = await AiStudioProvider(apiKey: 'k', model: 'gemini-test', client: client).generateJson(system: 'ระบบ', user: 'ทัก');
    expect(text, '{"reply":"สวัสดี"}');
    expect(sent.method, 'POST');
    expect(sent.headers['x-goog-api-key'], 'k');
    expect(sent.headers['content-type'], startsWith('application/json'));
    expect(utf8.decode(sent.bodyBytes), contains('ทัก'));
  });

  test('sends photos inline before the text', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode({'candidates': [{'content': {'parts': [{'text': '{}'}]}}]}), 200);
    });
    await AiStudioProvider(apiKey: 'k', model: 'gemini-test', client: client).generateJson(system: 's', user: 'u', images: [png()]);
    final body = jsonDecode(utf8.decode(sent.bodyBytes)) as Map<String, dynamic>;
    expect((body['contents'] as List).single['parts'], [
      {'inlineData': {'mimeType': 'image/png', 'data': base64Encode(png())}},
      {'text': 'u'},
    ]);
  });

  test('cancelling aborts the request', () async {
    final client = MockClient.streaming((request, _) async {
      await (request as http.Abortable).abortTrigger;
      throw http.RequestAbortedException(request.url);
    });
    final cancel = Completer<void>();
    final result = AiStudioProvider(apiKey: 'k', model: 'gemini-test', client: client)
        .generateJson(system: 's', user: 'u', cancel: cancel.future);
    final expectation = expectLater(result, throwsA(isA<LlmCancelled>()));
    cancel.complete();
    await expectation;
  });

  test('lists text models across pages without putting the key in the URL', () async {
    final seen = <Uri>[];
    final client = MockClient((request) async {
      seen.add(request.url);
      expect(request.headers['x-goog-api-key'], 'k');
      Map<String, Object> model(String id, [String method = 'generateContent']) =>
          {'name': 'models/$id', 'supportedGenerationMethods': [method]};
      final first = request.url.queryParameters['pageToken'] == null;
      return http.Response(
        jsonEncode(first
            ? {
                'models': [model('gemini-b'), model('text-embedding', 'embedContent'), model('gemini-b-preview-tts')],
                'nextPageToken': 'p2',
              }
            : {
                'models': [model('gemini-a'), model('gemini-b-image'), model('gemma-x')],
              }),
        200,
      );
    });
    expect(await AiStudioProvider.listModels('k', client: client), ['gemini-a', 'gemini-b', 'gemma-x']);
    expect(seen.length, 2);
    expect(seen.last.queryParameters['pageToken'], 'p2');
    expect(seen.join(), isNot(contains('key=')));
  });

  test('listing with a bad key explains the problem', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({'error': {'message': 'API key not valid.'}}), 400));
    await expectLater(
      AiStudioProvider.listModels('bad', client: client),
      throwsA(isA<LlmException>().having((e) => e.message, 'message', 'API key ไม่ถูกต้อง')),
    );
  });
}
