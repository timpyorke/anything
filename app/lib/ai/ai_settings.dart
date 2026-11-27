import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;

import '../app/providers.dart';
import 'ai_studio_provider.dart';
import 'llm_provider.dart';
import 'on_device_provider.dart';

part 'ai_settings.freezed.dart';

const defaultStudioModel = 'gemini-2.5-flash';

@freezed
abstract class AiSettingsState with _$AiSettingsState {
  const factory AiSettingsState({
    @Default(AiProviderKind.aiStudio) AiProviderKind provider,
    @Default(defaultStudioModel) String studioModel,
    @Default(false) bool hasStudioKey,
    @Default(false) bool loaded,
  }) = _AiSettingsState;
}

final aiSettingsProvider = NotifierProvider<AiSettingsViewModel, AiSettingsState>(AiSettingsViewModel.new);

final studioHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// รายชื่อโมเดลจาก AI Studio ตาม key ที่บันทึกไว้ (ว่าง = ยังไม่มี key) — ดึงใหม่เมื่อ key เปลี่ยน
/// ปิด retry อัตโนมัติ: key ผิดลองซ้ำก็ไม่หาย ให้ผู้ใช้กดโหลดใหม่เอง
final studioModelsProvider = FutureProvider.autoDispose<List<String>>(retry: (_, _) => null, (ref) async {
  final client = ref.watch(studioHttpClientProvider);
  final key = await ref.watch(secureStorageProvider).read(key: 'ai.studio.key');
  if (key == null || key.isEmpty) return const [];
  return AiStudioProvider.listModels(key, client: client);
});

/// การตั้งค่า AI — เก็บใน Keychain/Keystore (API key ไม่อยู่ในโค้ดและไม่ส่งขึ้น Supabase)
class AiSettingsViewModel extends Notifier<AiSettingsState> {
  @override
  AiSettingsState build() => const AiSettingsState();

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> load() async {
    final p = await _storage.read(key: 'ai.provider');
    final model = await _storage.read(key: 'ai.studio.model');
    final key = await _storage.read(key: 'ai.studio.key');
    state = AiSettingsState(
      provider: AiProviderKind.values.firstWhere((k) => k.id == p, orElse: () => AiProviderKind.aiStudio),
      studioModel: model ?? defaultStudioModel,
      hasStudioKey: key?.isNotEmpty ?? false,
      loaded: true,
    );
  }

  Future<void> setProvider(AiProviderKind k) async {
    state = state.copyWith(provider: k);
    await _storage.write(key: 'ai.provider', value: k.id);
  }

  Future<void> setStudioModel(String m) async {
    final model = m.trim().isEmpty ? defaultStudioModel : m.trim();
    state = state.copyWith(studioModel: model);
    await _storage.write(key: 'ai.studio.model', value: model);
  }

  Future<void> setStudioKey(String? key) async {
    final k = key?.trim() ?? '';
    if (k.isEmpty) {
      await _storage.delete(key: 'ai.studio.key');
    } else {
      await _storage.write(key: 'ai.studio.key', value: k);
    }
    state = state.copyWith(hasStudioKey: k.isNotEmpty);
    ref.invalidate(studioModelsProvider);
  }

  /// provider ที่พร้อมใช้ตามการตั้งค่าปัจจุบัน (null = ยังไม่ได้ตั้งค่า/ดาวน์โหลด)
  Future<LlmProvider?> resolveProvider() async {
    if (state.provider == AiProviderKind.aiStudio) {
      final key = await _storage.read(key: 'ai.studio.key');
      if (key == null || key.isEmpty) return null;
      return AiStudioProvider(apiKey: key, model: state.studioModel);
    }
    return await OnDeviceProvider.isInstalled() ? OnDeviceProvider() : null;
  }
}
