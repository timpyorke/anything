import 'package:anything/app/providers.dart';
import 'package:anything/core/utils/dates.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/features/timeline/entry_card.dart';
import 'package:anything/features/timeline/timeline_filter.dart';
import 'package:anything/features/timeline/timeline_page.dart';
import 'package:anything/features/timeline/upcoming_card.dart';
import 'package:anything/features/timeline/upcoming_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_diary_repository.dart';

void main() {
  testWidgets('the date is shown only on the first row of each day', (tester) async {
    Entry daily(String id, int day) => Entry(id: id, kind: 'daily', date: DateTime.utc(2020, 1, day), category: 'daily', title: id);
    final repo = FakeDiaryRepository()..rows.addAll([daily('a', 5), daily('b', 5), daily('c', 4)]);
    await _pump(tester, repo);

    final cards = tester.widgetList<EntryCard>(find.byType(EntryCard));
    expect(cards.map((c) => c.showDate), [true, false, true]);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    // แถวที่ไม่มีวันที่ยังจัดเนื้อหาตรงแนวกับแถวอื่น
    expect(tester.getTopLeft(find.text('b')).dx, tester.getTopLeft(find.text('a')).dx);
  });

  testWidgets('the today header replaces the today badge on rows', (tester) async {
    final repo = FakeDiaryRepository()..rows.add(Entry(id: 'a', kind: 'daily', date: today(), category: 'daily', title: 'a'));
    await _pump(tester, repo);

    expect(find.text('วันนี้'), findsOneWidget);
    expect(find.widgetWithText(EntryCard, 'วันนี้'), findsNothing);
  });

  testWidgets('today comes first and only the nearest upcoming entries are previewed above it', (tester) async {
    Entry inDays(int n) => Entry(id: 'd$n', date: today().add(Duration(days: n)), category: 'health', title: 'อีก$n');
    final repo = FakeDiaryRepository()..rows.addAll([inDays(40), inDays(3), inDays(-1), inDays(2), inDays(1)]);
    await _pump(tester, repo);

    for (final title in ['อีก1', 'อีก2', 'อีก3']) {
      expect(find.widgetWithText(UpcomingCard, title), findsOneWidget);
    }
    expect(find.text('อีก40'), findsNothing);
    expect(find.text('ทั้งหมด 4'), findsOneWidget);
    // อนาคตไม่ปนอยู่ในเส้นเวลา และหัวข้อวันนี้แสดงแม้ยังไม่ได้บันทึก
    expect(tester.widgetList<EntryCard>(find.byType(EntryCard)).map((c) => c.entry.id), ['d-1']);
    expect(find.textContaining('ยังไม่ได้บันทึก'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(UpcomingCard)).dy, lessThan(tester.getTopLeft(find.text('วันนี้')).dy));

    await tester.tap(find.text('ทั้งหมด 4'));
    await tester.pumpAndSettle();
    expect(find.byType(UpcomingPage), findsOneWidget);
    expect(tester.widgetList<EntryCard>(find.byType(EntryCard)).map((c) => c.entry.id), ['d1', 'd2', 'd3', 'd40']);
  });

  testWidgets('filtering by a future day shows that entry in the list', (tester) async {
    final day = today().add(const Duration(days: 10));
    final repo = FakeDiaryRepository()..rows.add(Entry(id: 'a', date: day, category: 'health', title: 'นัดหมอ'));
    await _pump(tester, repo);

    ProviderScope.containerOf(tester.element(find.byType(TimelinePage))).read(timelineFilterProvider.notifier).showOnly(day: day);
    await tester.pumpAndSettle();

    expect(find.byType(UpcomingCard), findsNothing);
    expect(find.text('วันนี้'), findsNothing);
    expect(find.widgetWithText(EntryCard, 'นัดหมอ'), findsOneWidget);
  });

  testWidgets('age is shown on the overview page instead of the timeline', (tester) async {
    final born = DateTime.utc(today().year - 30, 1, 1);
    final repo = FakeDiaryRepository()..rows.add(Entry(id: 'a', date: born, category: 'daily', title: 'เกิด'));
    await _pump(tester, repo);
    expect(find.text('อายุ 30 ปี'), findsNothing);

    await tester.tap(find.byTooltip('ภาพรวม'));
    await tester.pumpAndSettle();
    expect(find.text('อายุ 30 ปี'), findsOneWidget);
  });
}

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
