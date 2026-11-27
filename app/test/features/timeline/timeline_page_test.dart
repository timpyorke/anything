import 'package:anything/app/providers.dart';
import 'package:anything/core/utils/dates.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/features/timeline/entry_card.dart';
import 'package:anything/features/timeline/timeline_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_diary_repository.dart';

void main() {
  testWidgets('the date is shown only on the first row of each day', (tester) async {
    Entry daily(String id, int day) => Entry(id: id, kind: 'daily', date: DateTime.utc(2020, 1, day), category: 'daily', title: id);
    final repo = FakeDiaryRepository()..rows.addAll([daily('a', 5), daily('b', 5), daily('c', 4)]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('user'),
      ],
      child: const MaterialApp(home: TimelinePage()),
    ));
    await tester.pumpAndSettle();

    final cards = tester.widgetList<EntryCard>(find.byType(EntryCard));
    expect(cards.map((c) => c.showDate), [true, false, true]);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    // แถวที่ไม่มีวันที่ยังจัดเนื้อหาตรงแนวกับแถวอื่น
    expect(tester.getTopLeft(find.text('b')).dx, tester.getTopLeft(find.text('a')).dx);
  });

  testWidgets('the same badge is not repeated within a day', (tester) async {
    Entry daily(String id) => Entry(id: id, kind: 'daily', date: today(), category: 'daily', title: id);
    final repo = FakeDiaryRepository()..rows.addAll([daily('a'), daily('b')]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('user'),
      ],
      child: const MaterialApp(home: TimelinePage()),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(EntryCard, 'วันนี้'), findsOneWidget);
  });
}
