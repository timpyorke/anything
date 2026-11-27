import 'dart:async';

import 'package:anything/ai/ai_settings.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/app/providers.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/features/assistant/turn_view_model.dart';
import 'package:anything/features/diary/diary_view_model.dart';
import 'package:anything/features/entry_editor/entry_editor_view_model.dart';
import 'package:anything/features/settings/settings_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_diary_repository.dart';

/// ปิดหน้า/sheet ระหว่างที่ view model ยังรองานอยู่ ต้องไม่ error และงานที่สั่งไว้ต้องทำต่อจนจบ
class _Repo extends FakeDiaryRepository {
  Completer<void>? gate;
  final logs = <String>[];

  @override
  Future<Entry> insert(Entry e) async {
    await gate?.future;
    return super.insert(e);
  }

  @override
  Future<void> logAi({required String provider, required String model, required String input, Object? output, required String status, String? error}) async =>
      logs.add(status);
}

class _Llm implements LlmProvider {
  final reply = Completer<String>();
  @override
  AiProviderKind get kind => AiProviderKind.onDevice;
  @override
  String get model => 'fake';
  @override
  Future<String> generateJson({required String system, required String user}) => reply.future;
}

class _Ai extends AiSettingsViewModel {
  _Ai(this.llm, this.gate);
  final LlmProvider llm;
  final Completer<void> gate;
  @override
  Future<LlmProvider?> resolveProvider() async => llm;
  @override
  Future<void> setStudioKey(String? key) => gate.future;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;
  late _Llm llm;
  late Completer<void> keyGate;
  late ProviderContainer c;

  setUp(() async {
    repo = _Repo();
    llm = _Llm();
    keyGate = Completer();
    c = ProviderContainer(overrides: [
      diaryRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('user'),
      aiSettingsProvider.overrideWith(() => _Ai(llm, keyGate)),
    ]);
    addTearDown(c.dispose);
    c.read(diaryViewModelProvider);
    await _settle();
  });

  const newEntry = '{"actions":[{"type":"create","kind":"event","date":"2026-12-01","category":"health","title":"หาหมอ"}]}';

  test('turn: sheet closed while the AI is still thinking', () async {
    final sub = c.listen(turnViewModelProvider('x'), (_, _) {});
    await _settle();
    sub.close();
    await _settle();
    llm.reply.complete('{"actions":[]}');
    await _settle();
    expect(repo.logs, ['rejected']);
  });

  test('turn: sheet closed while saving', () async {
    final sub = c.listen(turnViewModelProvider('x'), (_, _) {});
    llm.reply.complete(newEntry);
    await _settle();
    repo.gate = Completer();
    final applying = c.read(turnViewModelProvider('x').notifier).apply();
    sub.close();
    await _settle();
    repo.gate!.complete();
    final result = await applying;
    expect(result.count, 1);
    expect(result.error, isNull);
    expect(repo.rows.single.title, 'หาหมอ');
    expect(repo.logs, ['applied']);
  });

  test('editor: page closed while saving', () async {
    const args = EditorArgs();
    final sub = c.listen(entryEditorViewModelProvider(args), (_, _) {});
    repo.gate = Completer();
    final saving = c.read(entryEditorViewModelProvider(args).notifier).save(title: 'เดิน', body: '', times: '', metrics: []);
    sub.close();
    await _settle();
    repo.gate!.complete();
    await saving;
    expect(repo.rows.single.title, 'เดิน');
  });

  test('settings: page closed while saving the key', () async {
    final sub = c.listen(settingsViewModelProvider, (_, _) {});
    final saving = c.read(settingsViewModelProvider.notifier).saveKey('k');
    sub.close();
    await _settle();
    keyGate.complete();
    await saving;
  });
}
