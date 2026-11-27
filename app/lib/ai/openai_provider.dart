import 'package:http/http.dart' as http;

import 'llm_http.dart';
import 'llm_provider.dart';

/// บริการที่ใช้ API แบบ Chat Completions: OpenAI และ OpenRouter ด้วย API key ของผู้ใช้
class OpenAiProvider implements LlmProvider {
  OpenAiProvider({required this.kind, required this.apiKey, required this.model, http.Client? client})
      : assert(kind == AiProviderKind.openAi || kind == AiProviderKind.openRouter),
        _client = client ?? http.Client();

  @override
  final AiProviderKind kind;
  final String apiKey;
  @override
  final String model;
  final http.Client _client;

  static Uri _base(AiProviderKind kind) =>
      Uri.parse(kind == AiProviderKind.openRouter ? 'https://openrouter.ai/api/v1/' : 'https://api.openai.com/v1/');

  static Map<String, String> _headers(String apiKey) => {'authorization': 'Bearer $apiKey'};

  /// รายชื่อของ OpenAI มีโมเดลเสียง/รูป/embedding และโมเดลที่ใช้กับ Chat Completions ไม่ได้ปนมา
  static final _openAiChat = RegExp(r'^(gpt-|o\d|chatgpt-)');
  static final _openAiOther = RegExp(r'embed|tts|whisper|transcribe|audio|realtime|image|moderation|codex|instruct|search|deep-research|-pro(-|$)');

  static bool _usable(AiProviderKind kind, Map model, String id) {
    if (kind == AiProviderKind.openAi) return _openAiChat.hasMatch(id) && !_openAiOther.hasMatch(id);
    final outputs = (model['architecture'] as Map?)?['output_modalities'] as List?;
    return outputs == null || outputs.contains('text');
  }

  /// รหัสโมเดลสร้างข้อความ (เรียง A→Z)
  static Future<List<String>> listModels(AiProviderKind kind, String apiKey, {http.Client? client}) async {
    final c = client ?? http.Client();
    final base = _base(kind);
    final ids = <String>{};
    Uri? uri = base.resolve('models');
    final seen = <Uri>{};
    // ตามหน้าถัดไปเฉพาะบนโฮสต์เดิม เพื่อไม่ส่ง key ไปที่อื่น
    while (uri != null && uri.scheme == 'https' && uri.host == base.host && seen.add(uri)) {
      final (status, json) = await llmRequest(c, kind.label, uri, headers: _headers(apiKey));
      if (status != 200) throw llmError(kind.label, status, json);
      for (final m in (json['data'] as List? ?? const []).whereType<Map>()) {
        final id = m['id'];
        if (id is String && id.isNotEmpty && _usable(kind, m, id)) ids.add(id);
      }
      final next = (json['links'] as Map?)?['next'];
      uri = next is String && next.isNotEmpty ? uri.resolve(next) : null;
    }
    return ids.toList()..sort();
  }

  @override
  Future<String> generateJson({required String system, required String user, Future<void>? cancel}) async {
    final (status, json) = await llmRequest(
      _client,
      kind.label,
      _base(kind).resolve('chat/completions'),
      headers: _headers(apiKey),
      body: {
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        // OpenRouter มีโมเดลที่ไม่รองรับ JSON mode จึงอาศัยคำสั่งในพรอมต์แทน
        if (kind == AiProviderKind.openAi) 'response_format': {'type': 'json_object'},
      },
      cancel: cancel,
      timeout: const Duration(seconds: 120),
    );
    if (status != 200) throw llmError(kind.label, status, json, model: model);
    final choice = (json['choices'] as List?)?.firstOrNull as Map?;
    // OpenRouter ตอบ HTTP 200 พร้อม error ได้เมื่อผู้ให้บริการปลายทางพัง
    final error = choice?['error'] ?? json['error'];
    if (error is Map) throw LlmException('${kind.label}: ${error['message'] ?? 'ผู้ให้บริการโมเดลขัดข้อง'}');
    final message = choice?['message'] as Map?;
    final stop = choice?['finish_reason'];
    if (message?['refusal'] != null || stop == 'content_filter') throw LlmException('${kind.label} ปฏิเสธคำขอนี้');
    if (stop == 'length') throw LlmException('คำตอบของ AI ยาวเกินกำหนด ลองแบ่งเล่าทีละเรื่อง');
    final text = message?['content'];
    if (text is! String || text.trim().isEmpty) throw LlmException('AI ไม่ได้ตอบกลับ${stop == null ? '' : ' ($stop)'}');
    return text;
  }
}
