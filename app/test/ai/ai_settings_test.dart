import 'package:anything/ai/ai_settings.dart';
import 'package:anything/ai/anthropic_provider.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/ai/openai_provider.dart';
import 'package:anything/app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends Notifier<String?> {
  _User(this.initial);
  final String? initial;
  @override
  String? build() => initial;
  void set(String? id) => state = id;
}

const _storage = FlutterSecureStorage();

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// เปิดแอปด้วยค่าที่เก็บไว้ [stored] และผู้ใช้ [user]
  Future<(ProviderContainer, void Function(String?))> start(Map<String, String> stored, String? user) async {
    FlutterSecureStorage.setMockInitialValues({...stored});
    final userProvider = NotifierProvider<_User, String?>(() => _User(user));
    final c = ProviderContainer(overrides: [currentUserIdProvider.overrideWith((ref) => ref.watch(userProvider))]);
    addTearDown(c.dispose);
    c.listen(aiSettingsProvider, (_, _) {});
    await c.read(aiSettingsProvider.notifier).load();
    return (c, (String? id) => c.read(userProvider.notifier).set(id));
  }

  test('the API key of one account is not usable by another', () async {
    final (c, switchTo) = await start({}, 'a');
    final vm = c.read(aiSettingsProvider.notifier);
    await vm.setKey(AiProviderKind.aiStudio, 'key-a');
    expect(await vm.resolveProvider(), isNotNull);

    switchTo(null);
    await _settle();
    expect(c.read(aiSettingsProvider).savedKeys, isEmpty);

    switchTo('b');
    await _settle();
    expect(c.read(aiSettingsProvider).savedKeys, isEmpty);
    expect(await vm.resolveProvider(), isNull);

    // กลับมาบัญชีเดิมไม่ต้องใส่ key ใหม่
    switchTo('a');
    await _settle();
    expect(c.read(aiSettingsProvider).savedKeys, {AiProviderKind.aiStudio});
    expect(await vm.resolveProvider(), isNotNull);
  });

  test('removing the key only affects the current account', () async {
    final (c, _) = await start({aiKeyName(AiProviderKind.aiStudio, 'a'): 'key-a', aiKeyName(AiProviderKind.aiStudio, 'b'): 'key-b'}, 'a');
    await c.read(aiSettingsProvider.notifier).setKey(AiProviderKind.aiStudio, null);
    expect(await _storage.read(key: aiKeyName(AiProviderKind.aiStudio, 'a')), isNull);
    expect(await _storage.read(key: aiKeyName(AiProviderKind.aiStudio, 'b')), 'key-b');
  });

  test('the old shared key moves to the account that is signed in at startup', () async {
    final (c, _) = await start({legacyStudioKeyName: 'old'}, 'a');
    expect(c.read(aiSettingsProvider).savedKeys, {AiProviderKind.aiStudio});
    expect(await _storage.read(key: aiKeyName(AiProviderKind.aiStudio, 'a')), 'old');
    expect(await _storage.read(key: legacyStudioKeyName), isNull);
  });

  test('the old shared key does not overwrite a newer account key', () async {
    await start({legacyStudioKeyName: 'old', aiKeyName(AiProviderKind.aiStudio, 'a'): 'new'}, 'a');
    expect(await _storage.read(key: aiKeyName(AiProviderKind.aiStudio, 'a')), 'new');
    expect(await _storage.read(key: legacyStudioKeyName), isNull);
  });

  test('the old shared key is dropped when nobody is signed in, so a later account cannot claim it', () async {
    final (c, switchTo) = await start({legacyStudioKeyName: 'old'}, null);
    switchTo('b');
    await _settle();
    expect(c.read(aiSettingsProvider).savedKeys, isEmpty);
    expect(await _storage.readAll(), isEmpty);
  });

  test('each service keeps its own key and model, and resolves to its own provider', () async {
    final (c, _) = await start({}, 'a');
    final vm = c.read(aiSettingsProvider.notifier);
    await vm.setKey(AiProviderKind.anthropic, 'ant');

    await vm.setProvider(AiProviderKind.openAi);
    expect(await vm.resolveProvider(), isNull, reason: 'ยังไม่มี key ของ OpenAI');

    await vm.setProvider(AiProviderKind.anthropic);
    final claude = await vm.resolveProvider();
    expect(claude, isA<AnthropicProvider>());
    expect(claude!.model, 'claude-opus-5-5');

    await vm.setProvider(AiProviderKind.openRouter);
    await vm.setKey(AiProviderKind.openRouter, 'or');
    await vm.setModel(AiProviderKind.openRouter, 'vendor/model');
    final router = await vm.resolveProvider();
    expect(router, isA<OpenAiProvider>());
    expect((router!.kind, router.model), (AiProviderKind.openRouter, 'vendor/model'));

    // เปิดแอปใหม่แล้วค่ายังอยู่
    await vm.load();
    final s = c.read(aiSettingsProvider);
    expect(s.provider, AiProviderKind.openRouter);
    expect(s.savedKeys, {AiProviderKind.anthropic, AiProviderKind.openRouter});
    expect(s.modelFor(AiProviderKind.openRouter), 'vendor/model');
    expect(s.modelFor(AiProviderKind.anthropic), 'claude-opus-5-5');
  });
}
