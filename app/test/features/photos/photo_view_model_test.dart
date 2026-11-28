import 'package:anything/ai/ai_settings.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/app/providers.dart';
import 'package:anything/data/mappers/row_mappers.dart';
import 'package:anything/data/photo_picker.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/photo.dart';
import 'package:anything/features/assistant/photo_draft_view_model.dart';
import 'package:anything/features/assistant/turn_view_model.dart';
import 'package:anything/features/diary/diary_view_model.dart';
import 'package:anything/features/entry_editor/entry_editor_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_diary_repository.dart';
import '../../support/photos.dart';

class _Llm implements LlmProvider {
  String reply = '';
  List<Uint8List>? images;
  @override
  AiProviderKind get kind => AiProviderKind.onDevice;
  @override
  String get model => 'fake';
  @override
  Future<String> generateJson({required String system, required String user, List<Uint8List> images = const [], Future<void>? cancel}) async {
    this.images = images;
    return reply;
  }
}

class _Ai extends AiSettingsViewModel {
  _Ai(this.llm);
  final LlmProvider llm;
  @override
  Future<LlmProvider?> resolveProvider() async => llm;
}

class _Repo extends FakeDiaryRepository {
  final logs = <String>[];
  @override
  Future<void> logAi({required String provider, required String model, required String input, Object? output, required String status, String? error}) async =>
      logs.add(input);
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;
  late FakePhotoPicker picker;
  late _Llm llm;
  late ProviderContainer c;

  setUp(() async {
    repo = _Repo();
    picker = FakePhotoPicker();
    llm = _Llm();
    c = ProviderContainer(overrides: [
      diaryRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('user'),
      photoPickerProvider.overrideWithValue(picker),
      aiSettingsProvider.overrideWith(() => _Ai(llm)),
    ]);
    addTearDown(c.dispose);
    c.read(diaryViewModelProvider);
    await _settle();
  });

  PhotoDraftViewModel draft() => c.read(photoDraftViewModelProvider.notifier);
  PhotoDraftState drafted() => c.read(photoDraftViewModelProvider);

  test('draft collects photos up to the limit and asks only for the room left', () async {
    picker.next = [png(1), png(2), png(3)];
    await draft().add(PhotoSource.gallery);
    picker.next = [png(4), png(5)];
    await draft().add(PhotoSource.gallery);
    expect(picker.calls, [(PhotoSource.gallery, 4), (PhotoSource.gallery, 1)]);
    expect(drafted().photos, [png(1), png(2), png(3), png(4)]);
    expect(drafted().notice, isNotNull);

    await draft().add(PhotoSource.camera);
    expect(picker.calls, hasLength(2)); // เต็มแล้วไม่เปิดกล้อง

    draft().remove(0);
    expect(draft().take(), [png(2), png(3), png(4)]);
    expect(drafted().photos, isEmpty);
  });

  test('draft explains a denied camera and skips unsupported files', () async {
    picker.error = PlatformException(code: 'camera_access_denied');
    await draft().add(PhotoSource.camera);
    expect(drafted().notice, contains('ใช้กล้องไม่ได้'));
    expect(drafted().picking, isFalse);

    picker.error = null;
    picker.next = [Uint8List.fromList([1, 2, 3]), png()];
    await draft().add(PhotoSource.gallery);
    expect(drafted().photos, [png()]);
    expect(drafted().notice, contains('บางรูปใช้ไม่ได้'));
  });

  test('draft restores a photo taken before Android restarted the app', () async {
    picker.lost = [png(7)];
    await draft().restoreLost();
    await draft().restoreLost();
    expect(drafted().photos, [png(7)]);
  });

  test('applying a turn stores the photo with the entry and logs only the count', () async {
    llm.reply = '{"actions":[{"type":"create","kind":"daily","date":"2026-11-27","category":"daily","title":"ข้าวเที่ยง","photos":[1]}]}';
    final TurnRequest request = (text: '', photos: [png(1)]);
    final sub = c.listen(turnViewModelProvider(request), (_, _) {});
    addTearDown(sub.close);
    await _settle();
    expect(llm.images, [png(1)]);
    expect(sub.read().unattachedPhotos, 0);
    c.read(turnViewModelProvider(request).notifier).toggle(0, false);
    expect(sub.read().unattachedPhotos, 1);
    c.read(turnViewModelProvider(request).notifier).toggle(0, true);

    final result = await c.read(turnViewModelProvider(request).notifier).apply();
    expect(result.error, isNull);
    final saved = c.read(diaryViewModelProvider).entries.single;
    expect(repo.files[saved.photos.single.path], png(1));
    expect(repo.logs.single, startsWith('[แนบรูป 1 รูป]'));
  });

  test('two actions on the same entry keep both the photo and the tick', () async {
    final trip = await c.read(diaryViewModelProvider.notifier).save(
        Entry(date: DateTime.utc(2030, 1, 1), category: 'health', title: 'ทริป', body: '- [ ] ตั๋ว'));
    llm.reply = '{"actions":[{"type":"update","ref":"R1","title":"ทริปใหม่","photos":[1]},{"type":"check","ref":"R1","item":"ตั๋ว"}]}';
    final TurnRequest request = (text: 'ซื้อตั๋วแล้ว', photos: [png(1)]);
    final sub = c.listen(turnViewModelProvider(request), (_, _) {});
    addTearDown(sub.close);
    await _settle();
    expect((await c.read(turnViewModelProvider(request).notifier).apply()).error, isNull);
    // รายการที่ค้างอยู่ในมือ action ที่สองเก่ากว่าฐานข้อมูล ต้องไม่ลบรูปที่ action แรกแนบ
    expect(repo.rows.singleWhere((e) => e.id == trip.id).photos, hasLength(1));
  });

  test('editor adds photos and removes only the ones the user took off', () async {
    final entry = await c.read(diaryViewModelProvider.notifier).save(
        Entry(date: DateTime.utc(2026, 1, 1), category: 'health', title: 'x', photos: [Photo(bytes: png(1)), Photo(bytes: png(2))]));
    final args = EditorArgs(entry: entry);
    final sub = c.listen(entryEditorViewModelProvider(args), (_, _) {});
    addTearDown(sub.close);
    final vm = c.read(entryEditorViewModelProvider(args).notifier);
    picker.next = [png(3)];
    await vm.addPhotos(PhotoSource.camera);
    expect(sub.read().entry.photos, hasLength(3));
    vm.removePhoto(sub.read().entry.photos.first);
    await vm.save(title: 'x', body: '', times: '', metrics: []);
    final stored = c.read(diaryViewModelProvider).entries.single.photos;
    expect([for (final p in stored) repo.files[p.path]], [png(2), png(3)]);
  });

  test('a full storage keeps the editor open and explains what to do', () async {
    repo.storageFullAt = 104857600;
    const args = EditorArgs();
    c.listen(entryEditorViewModelProvider(args), (_, _) {});
    final vm = c.read(entryEditorViewModelProvider(args).notifier);
    picker.next = [png()];
    await vm.addPhotos(PhotoSource.camera);
    await vm.save(title: 'ใบเสร็จ', body: '', times: '', metrics: const []);
    final state = c.read(entryEditorViewModelProvider(args));
    expect(state.errors.single, contains('พื้นที่เก็บรูปเต็ม (จำกัด 100 MB)'));
    expect(state.exit, isNull);
    expect(repo.rows, isEmpty);

    // เอารูปใหม่ออกแล้วบันทึกได้
    vm.removePhoto(state.entry.photos.single);
    await vm.save(title: 'ใบเสร็จ', body: 'x', times: '', metrics: const []);
    expect(repo.rows.single.title, 'ใบเสร็จ');
  });

  test('saving again after a full storage does not repeat the entries already saved', () async {
    repo.storageFullAt = 104857600;
    llm.reply = '{"actions":['
        '{"type":"create","kind":"daily","date":"2026-11-28","category":"daily","title":"วิ่ง","body":"วิ่ง"},'
        '{"type":"create","kind":"daily","date":"2026-11-28","category":"daily","title":"ใบเสร็จ","body":"x","photos":[1]}]}';
    final TurnRequest request = (text: 'สองเรื่อง', photos: [png()]);
    c.listen(turnViewModelProvider(request), (_, _) {});
    await _settle();
    final vm = c.read(turnViewModelProvider(request).notifier);

    final first = await vm.apply();
    expect(first.error, contains('พื้นที่เก็บรูปเต็ม'));
    expect([for (final e in repo.rows) e.title], ['วิ่ง']);
    final turn = c.read(turnViewModelProvider(request));
    expect([for (final a in turn.result!.actions) a.selected], [false, true]);
    expect(turn.applied, isFalse);

    repo.storageFullAt = null;
    expect((await vm.apply()).error, isNull);
    expect([for (final e in repo.rows) e.title], ['วิ่ง', 'ใบเสร็จ']);
  });

  test('an entry may be saved with nothing but a photo', () async {
    final saved = await c.read(diaryViewModelProvider.notifier)
        .save(Entry(date: DateTime.utc(2026, 1, 1), category: 'health', photos: [Photo(bytes: png())]));
    expect(saved.hidden, isFalse);
  });

  test('photo rows are read in the order they were attached', () {
    final photos = photosFromRows([
      {'path': 'u/b.jpg', 'seq': 2},
      {'path': 'u/a.jpg', 'seq': 1},
    ]);
    expect(photos.map((p) => p.path), ['u/a.jpg', 'u/b.jpg']);
    expect(photosFromRows(null), isEmpty);
  });
}
