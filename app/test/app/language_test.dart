import 'package:anything/app/anything_app.dart';
import 'package:anything/app/language.dart';
import 'package:anything/app/providers.dart';
import 'package:anything/core/l10n/app_strings.dart';
import 'package:anything/features/settings/settings_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_diary_repository.dart';

void main() {
  ProviderContainer container([Map<String, String> stored = const {}]) {
    FlutterSecureStorage.setMockInitialValues({...stored});
    final c = ProviderContainer(overrides: [
      diaryRepositoryProvider.overrideWithValue(FakeDiaryRepository()),
      currentUserIdProvider.overrideWithValue('user'),
      currentUserEmailProvider.overrideWithValue('name@example.com'),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('defaults to Thai, including when the stored value is unknown', () async {
    for (final stored in <Map<String, String>>[{}, {languageKey: 'xx'}]) {
      final c = container(stored);
      await c.read(languageProvider.notifier).load();
      expect(c.read(languageProvider), AppLanguage.th);
    }
  });

  test('the chosen language is restored on the next launch', () async {
    final c = container();
    await c.read(languageProvider.notifier).select(AppLanguage.en);
    expect(await const FlutterSecureStorage().read(key: languageKey), 'en');

    final next = container({languageKey: 'en'});
    await next.read(languageProvider.notifier).load();
    expect(next.read(languageProvider), AppLanguage.en);
    expect(next.read(stringsProvider).settings, 'Settings');
  });

  testWidgets('switching in settings changes the whole app, including system widgets', (tester) async {
    final c = container();
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const AnythingApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ตั้งค่า'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('English'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    final context = tester.element(find.byType(SettingsPage));
    expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Cancel');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });
}
