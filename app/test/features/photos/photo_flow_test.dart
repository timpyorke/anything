import 'dart:typed_data';

import 'package:anything/ai/ai_settings.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/app/providers.dart';
import 'package:anything/core/utils/dates.dart';
import 'package:anything/data/photo_picker.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/photo.dart';
import 'package:anything/features/assistant/assistant_page.dart';
import 'package:anything/features/entry_editor/entry_editor_page.dart';
import 'package:anything/features/photos/photo_widgets.dart';
import 'package:anything/features/timeline/entry_card.dart';
import 'package:anything/features/timeline/timeline_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_diary_repository.dart';
import '../../support/photos.dart';

class _Llm implements LlmProvider {
  List<Uint8List>? images;
  @override
  AiProviderKind get kind => AiProviderKind.onDevice;
  @override
  String get model => 'fake';
  @override
  Future<String> generateJson({required String system, required String user, List<Uint8List> images = const [], Future<void>? cancel}) async {
    this.images = images;
    return '{"reply":"จะบันทึกให้","actions":[{"type":"create","kind":"daily","date":"${ymd(today())}","category":"daily","title":"ข้าวเที่ยง","photos":[1]}]}';
  }
}

class _Ai extends AiSettingsViewModel {
  _Ai(this.llm);
  final LlmProvider? llm;
  @override
  AiSettingsState build() => const AiSettingsState();
  @override
  Future<LlmProvider?> resolveProvider() async => llm;
}

void main() {
  late FakeDiaryRepository repo;
  late FakePhotoPicker picker;

  setUp(() {
    repo = FakeDiaryRepository();
    picker = FakePhotoPicker();
  });

  Future<void> pump(WidgetTester tester, {LlmProvider? llm}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('user'),
        photoPickerProvider.overrideWithValue(picker),
        aiSettingsProvider.overrideWith(() => _Ai(llm)),
      ],
      child: const MaterialApp(home: TimelinePage()),
    ));
    await tester.pumpAndSettle();
  }

  for (final (tooltip, source) in [('กล้อง', PhotoSource.camera), ('คลังรูป', PhotoSource.gallery)]) {
    testWidgets('$tooltip: a photo alone can be sent, confirmed and shows on the timeline', (tester) async {
      final llm = _Llm();
      await pump(tester, llm: llm);
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      expect(picker.calls.single.$1, source);
      expect(find.byType(PhotoImage), findsOneWidget);
      expect(find.byTooltip('พูด'), findsOneWidget);

      await tester.tap(find.byTooltip('ส่ง'));
      await tester.pumpAndSettle();
      expect(llm.images, [png()]);
      expect(find.descendant(of: find.byType(TurnView), matching: find.byType(PhotoImage)), findsNWidgets(2));

      await tester.tap(find.text('บันทึก 1 รายการ'));
      await tester.pumpAndSettle();
      expect(repo.rows.single.photos.single.path, isNotNull);
      expect(find.descendant(of: find.byType(EntryCard), matching: find.byType(PhotoImage)), findsOneWidget);
      expect(find.byTooltip('เอารูปออก'), findsNothing);

      await tester.tap(find.descendant(of: find.byType(EntryCard), matching: find.byType(PhotoImage)));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewerPage), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);
    });
  }

  testWidgets('a picked photo can be removed before sending', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('คลังรูป'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('เอารูปออก'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoImage), findsNothing);
    expect(find.byTooltip('ส่ง'), findsNothing);
  });

  testWidgets('the message box keeps focus when it grows on the first character', (tester) async {
    await pump(tester);
    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();
    final before = tester.state<EditableTextState>(find.byType(EditableText));
    final narrow = tester.getSize(find.byType(TextField)).width;

    tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'ก'));
    await tester.pumpAndSettle();
    expect(tester.state<EditableTextState>(find.byType(EditableText)), same(before));
    expect(before.widget.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.getSize(find.byType(TextField)).width, greaterThan(narrow));
  });

  testWidgets('without an AI set up the text and photo stay in the box', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('กล้อง'));
    await tester.enterText(find.byType(TextField), 'ข้าวเที่ยง');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ส่ง'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ไว้ก่อน'));
    await tester.pumpAndSettle();
    expect(find.text('ข้าวเที่ยง'), findsOneWidget);
    expect(find.byType(PhotoImage), findsOneWidget);
  });

  testWidgets('the editor attaches photos from the gallery and saves them', (tester) async {
    repo.rows.add(Entry(id: 'a', date: today(), category: 'daily', title: 'เดินเล่น'));
    await pump(tester);
    openEditor(tester.element(find.byType(TimelinePage)), entry: repo.rows.single);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('คลังรูป'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('คลังรูป'));
    await tester.pumpAndSettle();
    expect(picker.calls.single, (PhotoSource.gallery, maxPhotosPerEntry));
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();
    expect(repo.rows.single.photos, hasLength(1));
  });

  testWidgets('a photo that cannot be downloaded offers a retry', (tester) async {
    repo.rows.add(Entry(id: 'a', date: today(), category: 'daily', title: 'x', photos: const [Photo(path: 'user/missing.jpg')]));
    await pump(tester);
    expect(find.byTooltip('โหลดรูปไม่ได้ แตะเพื่อลองใหม่'), findsOneWidget);
    repo.files['user/missing.jpg'] = png();
    await tester.tap(find.byTooltip('โหลดรูปไม่ได้ แตะเพื่อลองใหม่'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });
}
