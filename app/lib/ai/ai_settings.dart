import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'llm_provider.dart';

/// การตั้งค่า AI — เก็บใน Keychain/Keystore (API key ไม่อยู่ในโค้ดและไม่ส่งขึ้น Supabase)
class AiSettings extends ChangeNotifier {
  AiSettings([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  static const defaultStudioModel = 'gemini-2.5-flash';

  AiProviderKind provider = AiProviderKind.aiStudio;
  String studioModel = defaultStudioModel;
  bool hasStudioKey = false;
  bool loaded = false;

  Future<void> load() async {
    final p = await _storage.read(key: 'ai.provider');
    provider = AiProviderKind.values.firstWhere((k) => k.id == p, orElse: () => AiProviderKind.aiStudio);
    studioModel = await _storage.read(key: 'ai.studio.model') ?? defaultStudioModel;
    hasStudioKey = (await _storage.read(key: 'ai.studio.key'))?.isNotEmpty ?? false;
    loaded = true;
    notifyListeners();
  }

  Future<void> setProvider(AiProviderKind k) async {
    provider = k;
    await _storage.write(key: 'ai.provider', value: k.id);
    notifyListeners();
  }

  Future<void> setStudioModel(String m) async {
    studioModel = m.trim().isEmpty ? defaultStudioModel : m.trim();
    await _storage.write(key: 'ai.studio.model', value: studioModel);
    notifyListeners();
  }

  Future<void> setStudioKey(String? key) async {
    final k = key?.trim() ?? '';
    if (k.isEmpty) {
      await _storage.delete(key: 'ai.studio.key');
    } else {
      await _storage.write(key: 'ai.studio.key', value: k);
    }
    hasStudioKey = k.isNotEmpty;
    notifyListeners();
  }

  Future<String?> studioKey() => _storage.read(key: 'ai.studio.key');
}
