import 'dart:typed_data';

/// ผู้ให้บริการ AI ที่ผู้ใช้เลือกได้
enum AiProviderKind {
  onDevice('on_device', 'Gemma'),
  aiStudio('ai_studio', 'Google AI Studio', company: 'Google',
      defaultModel: 'gemini-3.5-flash-lite', keyUrl: 'aistudio.google.com/apikey', slot: 'studio'),
  anthropic('anthropic', 'Claude (Anthropic)', company: 'Anthropic',
      defaultModel: 'claude-opus-5-5', keyUrl: 'platform.claude.com/settings/keys', slot: 'anthropic'),
  openAi('openai', 'OpenAI', company: 'OpenAI',
      defaultModel: 'gpt-6-luna', keyUrl: 'platform.openai.com/api-keys', slot: 'openai'),
  openRouter('openrouter', 'OpenRouter',
      defaultModel: 'openrouter/auto', keyUrl: 'openrouter.ai/keys', slot: 'openrouter');

  const AiProviderKind(this.id, this.label, {this.company = '', this.defaultModel = '', this.keyUrl = '', this.slot = ''});

  /// ค่าที่เก็บใน ai_logs.provider (ต้องตรงกับ check constraint ในฐานข้อมูล)
  final String id;
  /// ชื่อบริการ (ชื่อและคำอธิบายตามภาษาของแอปอยู่ที่ AppStrings.providerLabel/providerDescription)
  final String label;

  /// บริษัทที่ได้รับข้อความและรูปที่ส่ง
  final String company;
  final String defaultModel, keyUrl;

  /// ส่วนของชื่อค่าที่เก็บในเครื่อง (ว่าง = ไม่ใช้ API key)
  final String slot;

  /// บริการออนไลน์ที่ต้องใช้ API key
  bool get isCloud => slot.isNotEmpty;
  static Iterable<AiProviderKind> get cloud => values.where((k) => k.isCloud);
}

abstract class LlmProvider {
  AiProviderKind get kind;
  String get model;

  /// ส่ง [system] + [user] พร้อมรูป [images] (ถ้ามี เรียงตามที่แนบ) แล้วคืนข้อความที่ควรเป็น JSON object
  /// เมื่อ [cancel] จบ ให้หยุดคำขอ — จะโยน [LlmCancelled] หรือคืนผลที่ผู้เรียกต้องทิ้ง
  Future<String> generateJson({
    required String system,
    required String user,
    List<Uint8List> images = const [],
    Future<void>? cancel,
  });
}

class LlmCancelled implements Exception {
  @override
  String toString() => 'LlmCancelled';
}

class LlmException implements Exception {
  LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}
