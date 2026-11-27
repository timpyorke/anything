import 'package:anything/app/providers.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/recurrence.dart';
import 'package:anything/features/timeline/timeline_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_diary_repository.dart';

void main() {
  testWidgets('the recurrence progress bar is readable by screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    final repo = FakeDiaryRepository()
      ..rows.add(Entry(
        id: 'a',
        date: DateTime.utc(2020, 1, 5),
        category: 'daily',
        title: 'a',
        recurrence: const Recurrence('monthly', times: 2),
      ));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('user'),
      ],
      child: const MaterialApp(home: TimelinePage()),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(RegExp('ความคืบหน้า 2 จาก 2')), findsOneWidget);
    semantics.dispose();
  });
}
