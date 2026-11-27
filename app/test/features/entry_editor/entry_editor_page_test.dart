import 'package:anything/app/providers.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/recurrence.dart';
import 'package:anything/features/entry_editor/entry_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_diary_repository.dart';

class _OfflineRepo extends FakeDiaryRepository {
  @override
  Future<void> softDelete(String id) async => throw Exception('offline');
}

Future<void> _open(WidgetTester tester, FakeDiaryRepository repo) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      diaryRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('user'),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => openEditor(context, entry: repo.rows.single), child: const Text('go')),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

Entry _entry({Recurrence? recurrence}) =>
    Entry(id: 'a', date: DateTime.utc(2020, 1, 5), category: 'daily', title: 'ค่างวด', recurrence: recurrence);

void main() {
  testWidgets('a custom recurrence opens, and saving keeps its interval and end date', (tester) async {
    final until = DateTime.utc(2020, 6, 1);
    final repo = FakeDiaryRepository()..rows.add(_entry(recurrence: Recurrence('2w', until: until)));
    await _open(tester, repo);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(repo.rows.single.recurrence, Recurrence('2w', until: until));
    expect(find.byType(EntryEditorPage), findsNothing);
  });

  testWidgets('closing without changes leaves straight away', (tester) async {
    final repo = FakeDiaryRepository()..rows.add(_entry());
    await _open(tester, repo);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditorPage), findsNothing);
  });

  testWidgets('closing with unsaved typing asks before throwing it away', (tester) async {
    final repo = FakeDiaryRepository()..rows.add(_entry());
    await _open(tester, repo);
    await tester.enterText(find.byType(TextField).first, 'แก้แล้ว');
    await tester.pump();

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('แก้ต่อ'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditorPage), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทิ้ง'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditorPage), findsNothing);
    expect(repo.rows.single.title, 'ค่างวด');
  });

  testWidgets('a failed delete stays on the page and reports the error', (tester) async {
    final repo = _OfflineRepo()..rows.add(_entry());
    await _open(tester, repo);
    await tester.tap(find.byTooltip('ลบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ลบ'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditorPage), findsOneWidget);
    expect(find.textContaining('ลบไม่สำเร็จ'), findsOneWidget);
  });
}
