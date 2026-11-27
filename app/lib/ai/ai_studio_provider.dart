import 'dart:convert';
import 'package:http/http.dart' as http;

import 'llm_provider.dart';

/// Google AI Studio (Gemini API) ด้วย API key ของผู้ใช้
/// รองรับทั้งโมเดล Gemini และ Gemma ที่ AI Studio ให้บริการ (เช่น gemma-3-27b-it)
class AiStudioProvider implements LlmProvider {
  AiStudioProvider({required this.apiKey, required this.model, http.Client? client}) : _client = client ?? http.Client();

  final String apiKey;
  @override
  final String model;
  final http.Client _client;

  @override
  AiProviderKind get kind => AiProviderKind.aiStudio;

  /// รหัสโมเดลที่ key นี้ใช้สร้างข้อความได้ (เรียง A→Z) — ตัดโมเดลสร้างเสียง/รูปออกเพราะใช้บันทึกไม่ได้
  static Future<List<String>> listModels(String apiKey, {http.Client? client}) async {
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
        throw LlmException('เชื่อมต่อ AI Studio ไม่ได้: $e');
      }
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        throw LlmException('AI Studio ตอบกลับผิดรูปแบบ (HTTP ${res.statusCode})');
      }
      if (res.statusCode != 200) {
        final msg = (json['error'] as Map?)?['message'] ?? 'HTTP ${res.statusCode}';
        throw LlmException('$msg'.contains('API key') ? 'API key ไม่ถูกต้อง' : 'AI Studio: $msg');
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
  Future<String> generateJson({required String system, required String user, Future<void>? cancel}) async {
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
      throw LlmException('เชื่อมต่อ AI Studio ไม่ได้: $e');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw LlmException('AI Studio ตอบกลับผิดรูปแบบ (HTTP ${res.statusCode})');
    }
    if (res.statusCode != 200) {
      final msg = (json['error'] as Map?)?['message'] ?? 'HTTP ${res.statusCode}';
      throw LlmException(switch (res.statusCode) {
        400 when '$msg'.contains('API key') => 'API key ไม่ถูกต้อง — ตรวจในหน้าตั้งค่า',
        403 => 'API key นี้ไม่มีสิทธิ์ใช้โมเดล $model',
        404 => 'ไม่พบโมเดล "$model" — ตรวจชื่อโมเดลในหน้าตั้งค่า',
        429 => 'ใช้โควตา AI Studio เกินแล้ว ลองใหม่ภายหลัง',
        _ => 'AI Studio: $msg',
      });
    }
    final candidates = json['candidates'] as List?;
    final parts = (candidates?.firstOrNull as Map?)?['content']?['parts'] as List?;
    final text = parts?.map((p) => (p as Map)['text'] ?? '').join() ?? '';
    if (text.trim().isEmpty) {
      final reason = (candidates?.firstOrNull as Map?)?['finishReason'] ?? json['promptFeedback']?['blockReason'];
      throw LlmException('AI ไม่ได้ตอบกลับ${reason == null ? '' : ' ($reason)'}');
    }
    return text;
  }
}
