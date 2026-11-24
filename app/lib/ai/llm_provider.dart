

/// ผู้ให้บริการ AI ที่ผู้ใช้เลือกได้
enum AiProviderKind {
  onDevice('on_device', 'Gemma บนเครื่อง', 'ทำงานในมือถือ ไม่ต้องใช้เน็ต ข้อมูลไม่ออกจากเครื่อง'),
  aiStudio('ai_studio', 'Google AI Studio', 'ใช้ API key ของคุณ เร็วและแม่นกว่า ต้องใช้เน็ต');

  const AiProviderKind(this.id, this.label, this.description);
  final String id, label, description;
}

abstract class LlmProvider {
  AiProviderKind get kind;
  String get model;

  /// ส่ง [system] + [user] แล้วคืนข้อความที่ควรเป็น JSON object
  Future<String> generateJson({required String system, required String user});
}

class LlmException implements Exception {
  LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}
