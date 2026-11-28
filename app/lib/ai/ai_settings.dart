import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;

import '../app/env.dart';
import '../app/language.dart';
import '../app/providers.dart';
import 'ai_studio_provider.dart';
import 'anthropic_provider.dart';
import 'llm_provider.dart';
import 'managed_provider.dart';
import 'on_device_provider.dart';
import 'openai_provider.dart';

part 'ai_settings.freezed.dart';

/// API key เก็บแยกตามบัญชี คนที่ล็อกอินต่อบนเครื่องเดียวกันจะใช้ key ของคนก่อนไม่ได้
String aiKeyName(AiProviderKind kind, String userId) => 'ai.${kind.slot}.key.$userId';
String _modelName(AiProviderKind kind) => 'ai.${kind.slot}.model';

/// การยินยอมให้ส่งข้อมูลผ่าน AI ของแอป แยกตามบัญชี
String managedConsentName(String userId) => 'ai.managed.consent.$userId';

/// ชื่อเดิมของ key AI Studio ที่ใช้ร่วมกันทั้งเครื่อง
const legacyStudioKeyName = 'ai.studio.key';

@freezed
abstract class AiSettingsState with _$AiSettingsState {
  const AiSettingsState._();

  const factory AiSettingsState({
    @Default(AiProviderKind.managed) AiProviderKind provider,
    /// โมเดลที่เลือกไว้ของแต่ละบริการ (ไม่มี = ใช้ค่าเริ่มต้น)
    @Default(<AiProviderKind, String>{}) Map<AiProviderKind, String> models,
    /// บริการที่บัญชีนี้บันทึก API key ไว้แล้ว
    @Default(<AiProviderKind>{}) Set<AiProviderKind> savedKeys,
    /// บัญชีนี้ยินยอมให้ส่งข้อมูลผ่าน AI ของแอปแล้ว
    @Default(false) bool managedConsent,
    @Default(false) bool loaded,
  }) = _AiSettingsState;

  String modelFor(AiProviderKind kind) => models[kind] ?? kind.defaultModel;

  /// บริการที่เลือกอยู่ต้องใช้ key แต่ยังไม่ได้ใส่
  bool get missingKey => provider.isCloud && !savedKeys.contains(provider);

  /// เลือก AI ของแอปอยู่แต่ยังไม่ได้ยินยอม
  bool get needsConsent => provider == AiProviderKind.managed && !managedConsent;
}

final aiSettingsProvider = NotifierProvider<AiSettingsViewModel, AiSettingsState>(AiSettingsViewModel.new);

final aiHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// รายชื่อโมเดลของบริการ ตาม key ที่บันทึกไว้ (ว่าง = ยังไม่มี key) — ดึงใหม่เมื่อ key เปลี่ยน
/// ปิด retry อัตโนมัติ: key ผิดลองซ้ำก็ไม่หาย ให้ผู้ใช้กดโหลดใหม่เอง
final aiModelsProvider =
    FutureProvider.autoDispose.family<List<String>, AiProviderKind>(retry: (_, _) => null, (ref, kind) async {
  final client = ref.watch(aiHttpClientProvider);
  final storage = ref.watch(secureStorageProvider);
  final userId = ref.watch(currentUserIdProvider);
  final key = userId == null ? null : await storage.read(key: aiKeyName(kind, userId));
  if (key == null || key.isEmpty) return const [];
  final strings = ref.read(stringsProvider);
  return switch (kind) {
    AiProviderKind.aiStudio => AiStudioProvider.listModels(key, strings: strings, client: client),
    AiProviderKind.anthropic => AnthropicProvider.listModels(key, strings: strings, client: client),
    AiProviderKind.openAi || AiProviderKind.openRouter =>
      OpenAiProvider.listModels(kind, key, strings: strings, client: client),
    AiProviderKind.managed || AiProviderKind.onDevice => const [],
  };
});

/// ทางเรียก AI ของแอป — token อ่านตอนใช้จริง จึงเป็นของเซสชันปัจจุบันเสมอ
final managedAiAccessProvider = Provider<ManagedAiAccess>((ref) => (
      endpoint: Uri.parse('$supabaseUrl/functions/v1/ai-generate'),
      apiKey: supabaseKey,
      accessToken: () async {
        final auth = ref.read(supabaseClientProvider).auth;
        final session = auth.currentSession;
        // แอปถูกพักไว้นาน token อาจหมดอายุก่อนการต่ออายุอัตโนมัติจะทำงาน
        if (session != null && session.isExpired) return (await auth.refreshSession()).session?.accessToken;
        return session?.accessToken;
      },
    ));

/// การตั้งค่า AI — เก็บใน Keychain/Keystore (API key ไม่อยู่ในโค้ดและไม่ส่งขึ้น Supabase)
class AiSettingsViewModel extends Notifier<AiSettingsState> {
  @override
  AiSettingsState build() {
    // เปลี่ยนบัญชี → สถานะ key ต้องเป็นของบัญชีใหม่
    ref.listen(currentUserIdProvider, (_, _) {
      state = state.copyWith(savedKeys: {}, managedConsent: false);
      load();
    });
    return const AiSettingsState();
  }

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  Future<String?> _readKey(AiProviderKind kind) async {
    final userId = ref.read(currentUserIdProvider);
    return userId == null ? null : _storage.read(key: aiKeyName(kind, userId));
  }

  /// ย้าย key ชื่อเดิมให้บัญชีที่ล็อกอินค้างอยู่ ถ้าไม่มีใครล็อกอินก็ทิ้ง
  /// (เรียกครั้งแรกตอนเปิดแอป บัญชีที่ล็อกอินทีหลังจึงรับ key นี้ไปไม่ได้)
  Future<void> _moveLegacyKey() async {
    final legacy = await _storage.read(key: legacyStudioKeyName);
    if (legacy == null) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      final name = aiKeyName(AiProviderKind.aiStudio, userId);
      if (await _storage.read(key: name) == null) await _storage.write(key: name, value: legacy);
    }
    await _storage.delete(key: legacyStudioKeyName);
  }

  Future<void> load() async {
    await _moveLegacyKey();
    final userId = ref.read(currentUserIdProvider);
    final p = await _storage.read(key: 'ai.provider');
    final models = <AiProviderKind, String>{};
    final savedKeys = <AiProviderKind>{};
    for (final kind in AiProviderKind.cloud) {
      final model = await _storage.read(key: _modelName(kind));
      if (model != null) models[kind] = model;
      if ((await _readKey(kind))?.isNotEmpty ?? false) savedKeys.add(kind);
    }
    final consent = userId != null && await _storage.read(key: managedConsentName(userId)) == 'true';
    // เปลี่ยนบัญชีระหว่างอ่าน → ทิ้งผลนี้ รอบของบัญชีใหม่จะตั้งค่าเอง
    if (userId != ref.read(currentUserIdProvider)) return;
    state = AiSettingsState(
      // ยังไม่เคยเลือก: คนที่ใส่ key ไว้แล้วใช้ AI Studio ต่อ คนใหม่เริ่มที่ AI ของแอป
      provider: AiProviderKind.values.firstWhere((k) => k.id == p,
          orElse: () => savedKeys.isEmpty ? AiProviderKind.managed : AiProviderKind.aiStudio),
      models: models,
      savedKeys: savedKeys,
      managedConsent: consent,
      loaded: true,
    );
  }

  Future<void> setProvider(AiProviderKind k) async {
    state = state.copyWith(provider: k);
    await _storage.write(key: 'ai.provider', value: k.id);
  }

  Future<void> setModel(AiProviderKind kind, String m) async {
    final model = m.trim().isEmpty ? kind.defaultModel : m.trim();
    state = state.copyWith(models: {...state.models, kind: model});
    await _storage.write(key: _modelName(kind), value: model);
  }

  Future<void> setKey(AiProviderKind kind, String? key) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || !kind.isCloud) return;
    final k = key?.trim() ?? '';
    if (k.isEmpty) {
      await _storage.delete(key: aiKeyName(kind, userId));
    } else {
      await _storage.write(key: aiKeyName(kind, userId), value: k);
    }
    state = state.copyWith(savedKeys: k.isEmpty ? ({...state.savedKeys}..remove(kind)) : {...state.savedKeys, kind});
    ref.invalidate(aiModelsProvider(kind));
  }

  Future<void> setManagedConsent(bool value) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    state = state.copyWith(managedConsent: value);
    if (value) {
      await _storage.write(key: managedConsentName(userId), value: 'true');
    } else {
      await _storage.delete(key: managedConsentName(userId));
    }
  }

  /// ลบค่าที่เก็บในเครื่องของบัญชีที่ถูกลบ (API key และความยินยอม)
  Future<void> forgetAccount(String userId) async {
    for (final kind in AiProviderKind.cloud) {
      await _storage.delete(key: aiKeyName(kind, userId));
    }
    await _storage.delete(key: managedConsentName(userId));
  }

  /// provider ที่พร้อมใช้ตามการตั้งค่าปัจจุบัน (null = ยังไม่ได้ตั้งค่า/ดาวน์โหลด/ยินยอม)
  Future<LlmProvider?> resolveProvider() async {
    final kind = state.provider;
    final strings = ref.read(stringsProvider);
    if (kind == AiProviderKind.managed) {
      if (!state.managedConsent || ref.read(currentUserIdProvider) == null) return null;
      return ManagedProvider(
          access: ref.read(managedAiAccessProvider), strings: strings, client: ref.read(aiHttpClientProvider));
    }
    if (kind == AiProviderKind.onDevice) {
      return await OnDeviceProvider.isInstalled() ? OnDeviceProvider(strings: strings) : null;
    }
    final key = await _readKey(kind);
    if (key == null || key.isEmpty) return null;
    final model = state.modelFor(kind);
    return switch (kind) {
      AiProviderKind.aiStudio => AiStudioProvider(apiKey: key, model: model, strings: strings),
      AiProviderKind.anthropic => AnthropicProvider(apiKey: key, model: model, strings: strings),
      AiProviderKind.openAi ||
      AiProviderKind.openRouter =>
        OpenAiProvider(kind: kind, apiKey: key, model: model, strings: strings),
      AiProviderKind.managed || AiProviderKind.onDevice => null,
    };
  }
}
