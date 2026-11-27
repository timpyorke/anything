import 'package:anything/app/providers.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/features/search/search_page.dart';
import 'package:anything/features/timeline/entry_card.dart';
import 'package:anything/features/timeline/timeline_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_diary_repository.dart';

void main() {
  testWidgets('search opens its own page and leaves the timeline unfiltered', (tester) async {
    Entry entry(String id, String title) => Entry(id: id, date: DateTime.utc(2020, 1, 5), category: 'daily', title: title);
    final repo = FakeDiaryRepository()..rows.addAll([entry('a', 'ไปวิ่ง'), entry('b', 'กินข้าว')]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('user'),
      ],
      child: const MaterialApp(home: TimelinePage()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('ค้นหา'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.byType(EntryCard), findsNothing);

    await tester.enterText(find.byType(TextField), 'วิ่ง');
    await tester.pumpAndSettle();
    expect(find.text('พบ 1 รายการ'), findsOneWidget);
    expect(tester.widget<EntryCard>(find.byType(EntryCard)).entry.id, 'a');

    await tester.enterText(find.byType(TextField), 'ไม่มีคำนี้');
    await tester.pumpAndSettle();
    expect(find.text('ไม่พบรายการที่ตรงกับคำค้น'), findsOneWidget);

    await tester.tap(find.byTooltip('ล้างคำค้น'));
    await tester.pumpAndSettle();
    expect(find.text('พิมพ์คำที่ต้องการค้นหา'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(EntryCard), findsNWidgets(2));
  });
}
