import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/l10n/app_strings.dart';
import '../core/l10n/strings_th.dart';
import '../domain/photo.dart';
import 'llm_http.dart';
import 'llm_provider.dart';

/// Claude API ของ Anthropic (Messages API) ด้วย API key ของผู้ใช้
/// ไม่ส่ง temperature และไม่ตั้งค่า thinking: ใช้ค่าเริ่มต้นของแต่ละโมเดล
class AnthropicProvider implements LlmProvider {
  AnthropicProvider({required this.apiKey, required this.model, this.strings = const ThStrings(), http.Client? client})
      : _client = client ?? http.Client();

  /// ภาษาของข้อความผิดพลาด
  final AppStrings strings;

  final String apiKey;
  @override
  final String model;
  final http.Client _client;

  static const _service = 'Claude';
  static const _version = '2026-10-21';

  /// โมเดลที่ให้ API ส่งต่อไปโมเดลสำรองเองเมื่อคำขอถูกปฏิเสธ — โมเดลอื่นไม่ส่งพารามิเตอร์นี้
  static const _fallbackModels = {'claude-fable-5-2', 'claude-fable-5-1', 'claude-opus-5-5', 'claude-opus-5', 'claude-sonnet-5-5'};

  static Map<String, String> _headers(String apiKey) => {'x-api-key': apiKey, 'anthropic-version': _version};

  @override
  AiProviderKind get kind => AiProviderKind.anthropic;

  /// รหัสโมเดลที่ key นี้ใช้ได้ (เรียง A→Z)
  static Future<List<String>> listModels(String apiKey, {AppStrings strings = const ThStrings(), http.Client? client}) async {
    final c = client ?? http.Client();
    final ids = <String>{};
    String? after;
    do {
      final uri = Uri.https('api.anthropic.com', '/v1/models', {'limit': '1000', 'after_id': ?after});
      final (status, json) = await llmRequest(c, _service, uri, headers: _headers(apiKey), strings: strings);
      if (status != 200) throw llmError(_service, status, json, strings: strings);
      for (final m in (json['data'] as List? ?? const []).whereType<Map>()) {
        final id = m['id'];
        if (id is String && id.isNotEmpty) ids.add(id);
      }
      after = json['has_more'] == true ? json['last_id'] as String? : null;
    } while (after != null);
    return ids.toList()..sort();
  }

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    List<Uint8List> images = const [],
    Future<void>? cancel,
  }) async {
    final fallback = _fallbackModels.contains(model);
    final (status, json) = await llmRequest(
      _client,
      _service,
      Uri.https('api.anthropic.com', '/v1/messages'),
      headers: {..._headers(apiKey), if (fallback) 'anthropic-beta': 'server-side-fallback-2026-07-01'},
      body: {
        'model': model,
        'max_tokens': 16000,
        'system': system,
        'messages': [
          {
            'role': 'user',
            'content': images.isEmpty
                ? user
                : [
                    for (final image in images)
                      {
                        'type': 'image',
                        'source': {'type': 'base64', 'media_type': imageMime(image), 'data': base64Encode(image)},
                      },
                    {'type': 'text', 'text': user},
                  ],
          },
        ],
        if (fallback) 'fallbacks': 'default',
      },
      strings: strings,
      cancel: cancel,
      timeout: const Duration(seconds: 120),
    );
    if (status != 200) throw llmError(_service, status, json, strings: strings, model: model);
    // ตรวจเหตุที่หยุดก่อนอ่านเนื้อหา: ปฏิเสธหรือถูกตัดกลางทางอาจมีข้อความไม่ครบ
    final stop = json['stop_reason'];
    if (stop == 'refusal') throw LlmException(strings.requestRefused(_service));
    if (stop == 'max_tokens') throw LlmException(strings.answerTooLong);
    // content มีบล็อกชนิดอื่นปนได้ (เช่น thinking) เอาเฉพาะข้อความ
    final text = (json['content'] as List? ?? const [])
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] ?? '')
        .join();
    if (text.trim().isEmpty) throw LlmException(strings.emptyAnswer(stop));
    return text;
  }
}
