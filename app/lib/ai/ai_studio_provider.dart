import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/l10n/app_strings.dart';
import '../core/l10n/strings_th.dart';
import '../domain/photo.dart';
import 'llm_provider.dart';

/// Google AI Studio (Gemini API) ด้วย API key ของผู้ใช้
/// รองรับทั้งโมเดล Gemini และ Gemma ที่ AI Studio ให้บริการ (เช่น gemma-3-27b-it)
class AiStudioProvider implements LlmProvider {
  AiStudioProvider({required this.apiKey, required this.model, this.strings = const ThStrings(), http.Client? client})
      : _client = client ?? http.Client();

  /// ภาษาของข้อความผิดพลาด
  final AppStrings strings;

  final String apiKey;
  @override
  final String model;
  final http.Client _client;

  @override
  AiProviderKind get kind => AiProviderKind.aiStudio;

  /// รหัสโมเดลที่ key นี้ใช้สร้างข้อความได้ (เรียง A→Z) — ตัดโมเดลสร้างเสียง/รูปออกเพราะใช้บันทึกไม่ได้
  static Future<List<String>> listModels(String apiKey, {AppStrings strings = const ThStrings(), http.Client? client}) async {
    final c = client ?? http.Client();
    final mediaOnly = RegExp(r'-(tts|image)(-|$)');
    final ids = <String>{};
    String? page;
    do {
      final uri = Uri.https('generativelanguage.googleapis.com', '/v1beta/models', {'pageSize': '1000', 'pageToken': ?page});
      final http.Response res;
      try {
        res = await c.get(uri, headers: {'x-goog-api-key': apiKey}).timeout(const Duration(seconds: 15));
      } catch (e) {
        throw LlmException(strings.serviceUnreachable('AI Studio', e));
      }
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        throw LlmException(strings.malformedResponse('AI Studio', res.statusCode));
      }
      if (res.statusCode != 200) {
        final msg = (json['error'] as Map?)?['message'] ?? 'HTTP ${res.statusCode}';
        throw LlmException('$msg'.contains('API key') ? strings.invalidApiKey : 'AI Studio: $msg');
      }
      for (final m in (json['models'] as List? ?? const []).whereType<Map>()) {
        final id = '${m['name'] ?? ''}'.replaceFirst('models/', '');
        final methods = m['supportedGenerationMethods'] as List? ?? const [];
        if (id.isNotEmpty && methods.contains('generateContent') && !mediaOnly.hasMatch(id)) ids.add(id);
      }
      page = json['nextPageToken'] as String?;
    } while (page != null && page.isNotEmpty);
    return ids.toList()..sort();
  }

  /// โมเดล Gemma บน API ไม่รองรับ system instruction และ JSON mode
  bool get _isGemma => model.toLowerCase().startsWith('gemma');

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    List<Uint8List> images = const [],
    Future<void>? cancel,
  }) async {
    final uri = Uri.https('generativelanguage.googleapis.com', '/v1beta/models/$model:generateContent');
    final body = <String, Object?>{
      if (!_isGemma)
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
      'contents': [
        {
          'role': 'user',
          'parts': [
            for (final image in images)
              {
                'inlineData': {'mimeType': imageMime(image), 'data': base64Encode(image)},
              },
            {'text': _isGemma ? '$system\n\n---\n\n$user' : user},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        if (!_isGemma) 'responseMimeType': 'application/json',
      },
    };
    final http.Response res;
    try {
      final request = http.AbortableRequest('POST', uri, abortTrigger: cancel)
        ..headers.addAll({'content-type': 'application/json', 'x-goog-api-key': apiKey})
        ..body = jsonEncode(body);
      res = await _client.send(request).then(http.Response.fromStream).timeout(const Duration(seconds: 60));
    } on http.RequestAbortedException {
      throw LlmCancelled();
    } catch (e) {
      throw LlmException(strings.serviceUnreachable('AI Studio', e));
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw LlmException(strings.malformedResponse('AI Studio', res.statusCode));
    }
    if (res.statusCode != 200) {
      final msg = (json['error'] as Map?)?['message'] ?? 'HTTP ${res.statusCode}';
      throw LlmException(switch (res.statusCode) {
        400 when '$msg'.contains('API key') => strings.invalidApiKeyCheckSettings,
        403 => strings.modelForbidden(model),
        404 => strings.modelNotFound(model),
        429 => strings.quotaExceeded('AI Studio'),
        _ => 'AI Studio: $msg',
      });
    }
    final candidates = json['candidates'] as List?;
    final parts = (candidates?.firstOrNull as Map?)?['content']?['parts'] as List?;
    final text = parts?.map((p) => (p as Map)['text'] ?? '').join() ?? '';
    if (text.trim().isEmpty) {
      final reason = (candidates?.firstOrNull as Map?)?['finishReason'] ?? json['promptFeedback']?['blockReason'];
      throw LlmException(strings.emptyAnswer(reason));
    }
    return text;
  }
}
