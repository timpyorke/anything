import 'package:anything/app/providers.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/recurrence.dart';
import 'package:anything/features/entry_editor/entry_editor_page.dart';
import 'package:anything/features/timeline/entry_card.dart';
import 'package:anything/features/timeline/timeline_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_diary_repository.dart';

class _FailingRepo extends FakeDiaryRepository {
  @override
  Future<void> softDelete(String id) async => throw Exception('offline');
}

Entry _entry(String id, int day) => Entry(id: id, date: DateTime.utc(2020, 1, day), category: 'daily', title: id);

Future<void> _pump(WidgetTester tester, FakeDiaryRepository repo) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      diaryRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('user'),
    ],
    child: const MaterialApp(home: TimelinePage()),
  ));
  await tester.pumpAndSettle();
}

Future<void> _swipe(WidgetTester tester, String title) async {
  await tester.drag(find.text(title), const Offset(-300, 0));
  await tester.pumpAndSettle();
}

List<String?> _shown(WidgetTester tester) => [for (final c in tester.widgetList<EntryCard>(find.byType(EntryCard))) c.entry.id];

void main() {
  testWidgets('swiping reveals the actions without doing anything yet', (tester) async {
    final repo = FakeDiaryRepository()..rows.add(_entry('a', 5));
    await _pump(tester, repo);
    expect(find.text('ลบ'), findsNothing);

    await _swipe(tester, 'a');
    expect(find.text('แก้ไข'), findsOneWidget);
    expect(find.text('ลบ'), findsOneWidget);
    expect(repo.deleted, isEmpty);
  });

  testWidgets('delete removes only that row, and undo brings it back', (tester) async {
    final repo = FakeDiaryRepository()..rows.addAll([_entry('a', 5), _entry('b', 4)]);
    await _pump(tester, repo);

    await _swipe(tester, 'a');
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    expect(repo.deleted, {'a'});
    expect(_shown(tester), ['b']);
    expect(find.text('ลบแล้ว'), findsOneWidget);
    // แถวที่เลื่อนขึ้นมาแทนต้องปิดอยู่
    expect(find.text('ลบ'), findsNothing);

    await tester.tap(find.text('เลิกทำ'));
    await tester.pumpAndSettle();
    expect(_shown(tester), ['a', 'b']);
  });

  testWidgets('the undo bar goes away by itself', (tester) async {
    final repo = FakeDiaryRepository()..rows.add(_entry('a', 5));
    await _pump(tester, repo);
    await _swipe(tester, 'a');
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('เลิกทำ'), findsNothing);
  });

  testWidgets('deleting a recurring entry says the whole series is gone', (tester) async {
    final repo = FakeDiaryRepository()
      ..rows.add(_entry('a', 5).copyWith(recurrence: const Recurrence('yearly')));
    await _pump(tester, repo);
    // รายการเกิดซ้ำที่ยังไม่จบอยู่ในหน้ารายการล่วงหน้า
    await tester.tap(find.text('ทั้งหมด 1'));
    await tester.pumpAndSettle();
    await _swipe(tester, 'a');
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    expect(find.text('ลบรายการที่เกิดซ้ำทั้งชุดแล้ว'), findsOneWidget);
  });

  testWidgets('a failed delete keeps the row and reports the error', (tester) async {
    final repo = _FailingRepo()..rows.add(_entry('a', 5));
    await _pump(tester, repo);
    await _swipe(tester, 'a');
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    expect(_shown(tester), ['a']);
    expect(find.textContaining('ลบไม่สำเร็จ'), findsOneWidget);
  });

  testWidgets('only one row stays open, and tapping an open row just closes it', (tester) async {
    final repo = FakeDiaryRepository()..rows.addAll([_entry('a', 5), _entry('b', 4)]);
    await _pump(tester, repo);

    await _swipe(tester, 'a');
    await _swipe(tester, 'b');
    expect(find.text('ลบ'), findsOneWidget);

    // เนื้อหาเลื่อนออกซ้ายแล้ว จึงแตะกลางแถวส่วนที่ยังเห็นอยู่
    await tester.tapAt(tester.getCenter(find.byType(EntryCard).last));
    await tester.pumpAndSettle();
    expect(find.text('ลบ'), findsNothing);
    expect(find.byType(EntryEditorPage), findsNothing);
  });

  testWidgets('swiping back closes the row, and tapping it then opens the editor', (tester) async {
    final repo = FakeDiaryRepository()..rows.add(_entry('a', 5));
    await _pump(tester, repo);
    await _swipe(tester, 'a');
    await tester.dragFrom(tester.getCenter(find.byType(EntryCard)), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('ลบ'), findsNothing);

    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditorPage), findsOneWidget);
  });

  testWidgets('edit opens the editor', (tester) async {
    final repo = FakeDiaryRepository()..rows.add(_entry('a', 5));
    await _pump(tester, repo);
    await _swipe(tester, 'a');
    await tester.tap(find.text('แก้ไข'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditorPage), findsOneWidget);
  });
}
