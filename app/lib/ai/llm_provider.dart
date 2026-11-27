

/// ผู้ให้บริการ AI ที่ผู้ใช้เลือกได้
enum AiProviderKind {
  onDevice('on_device', 'Gemma บนเครื่อง', 'ทำงานในมือถือ ไม่ต้องใช้เน็ต ข้อมูลไม่ออกจากเครื่อง'),
  aiStudio('ai_studio', 'Google AI Studio', 'ใช้ API key ของคุณ ข้อความถูกส่งไปที่ Google',
      defaultModel: 'gemini-2.5-flash', keyUrl: 'aistudio.google.com/apikey', slot: 'studio'),
  anthropic('anthropic', 'Claude (Anthropic)', 'ใช้ API key ของคุณ ข้อความถูกส่งไปที่ Anthropic',
      defaultModel: 'claude-opus-5-5', keyUrl: 'platform.claude.com/settings/keys', slot: 'anthropic'),
  openAi('openai', 'OpenAI', 'ใช้ API key ของคุณ ข้อความถูกส่งไปที่ OpenAI',
      defaultModel: 'gpt-6-luna', keyUrl: 'platform.openai.com/api-keys', slot: 'openai'),
  openRouter('openrouter', 'OpenRouter', 'key เดียวใช้ได้หลายค่าย ข้อความผ่าน OpenRouter ไปยังผู้ให้บริการของโมเดล',
      defaultModel: 'openrouter/auto', keyUrl: 'openrouter.ai/keys', slot: 'openrouter');

  const AiProviderKind(this.id, this.label, this.description, {this.defaultModel = '', this.keyUrl = '', this.slot = ''});

  /// ค่าที่เก็บใน ai_logs.provider (ต้องตรงกับ check constraint ในฐานข้อมูล)
  final String id;
  final String label, description;
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

  /// ส่ง [system] + [user] แล้วคืนข้อความที่ควรเป็น JSON object
  /// เมื่อ [cancel] จบ ให้หยุดคำขอ — จะโยน [LlmCancelled] หรือคืนผลที่ผู้เรียกต้องทิ้ง
  Future<String> generateJson({required String system, required String user, Future<void>? cancel});
}

class LlmCancelled implements Exception {
  @override
  String toString() => 'ยกเลิกแล้ว';
}

class LlmException implements Exception {
  LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}
