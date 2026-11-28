import 'dart:async';
import 'dart:convert';

import 'package:anything/ai/ai_settings.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/app/providers.dart';
import 'package:anything/core/l10n/strings_th.dart';
import 'package:anything/data/supabase_account_repository.dart';
import 'package:anything/domain/repositories/account_repository.dart';
import 'package:anything/features/account/delete_account_page.dart';
import 'package:anything/features/account/delete_account_view_model.dart';
import 'package:anything/features/settings/settings_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_billing_repository.dart';
import '../support/fake_diary_repository.dart';
import '../support/fake_usage_repository.dart';

class _Accounts implements AccountRepository {
  var calls = 0;
  Object? failure;
  Completer<void>? gate;
  @override
  Future<void> delete() async {
    calls++;
    await gate?.future;
    if (failure case final error?) throw error;
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const t = ThStrings();
  const storage = FlutterSecureStorage();
  late _Accounts accounts;
  late FakeUsageRepository usage;
  late FakeBillingRepository billing;
  late int signOuts;
  late List<Uri> opened;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      aiKeyName(AiProviderKind.anthropic, 'me'): 'k',
      managedConsentName('me'): 'true',
      aiKeyName(AiProviderKind.anthropic, 'other'): 'k2',
      managedConsentName('other'): 'true',
    });
    accounts = _Accounts();
    usage = FakeUsageRepository();
    billing = FakeBillingRepository();
    signOuts = 0;
    opened = [];
  });

  // ignore: strict_top_level_inference (ชนิด Override ไม่ได้ export จาก flutter_riverpod)
  overrides({({String terms, String privacy}) links = (terms: '', privacy: '')}) => [
        currentUserIdProvider.overrideWithValue('me'),
        currentUserEmailProvider.overrideWithValue('name@example.com'),
        diaryRepositoryProvider.overrideWithValue(FakeDiaryRepository()),
        accountRepositoryProvider.overrideWithValue(accounts),
        usageRepositoryProvider.overrideWithValue(usage),
        billingRepositoryProvider.overrideWithValue(billing),
        signOutProvider.overrideWithValue(() async => signOuts++),
        legalLinksProvider.overrideWithValue(links),
        openLinkProvider.overrideWithValue((url) async {
          opened.add(url);
          return true;
        }),
      ];

  Future<(ProviderContainer, DeleteAccountViewModel)> start() async {
    final c = ProviderContainer(overrides: overrides());
    addTearDown(c.dispose);
    c.listen(deleteAccountViewModelProvider, (_, _) {});
    await _settle();
    return (c, c.read(deleteAccountViewModelProvider.notifier));
  }

  test('nothing is deleted until the user agrees', () async {
    final (_, vm) = await start();
    await vm.delete();
    expect((accounts.calls, signOuts), (0, 0));
  });

  test('deleting removes this account’s local keys and consent only, then signs out', () async {
    final (c, vm) = await start();
    vm.setAgreed(true);
    await vm.delete();
    expect((accounts.calls, signOuts, c.read(deleteAccountViewModelProvider).deleted), (1, 1, true));
    expect((await storage.readAll()).keys,
        unorderedEquals([aiKeyName(AiProviderKind.anthropic, 'other'), managedConsentName('other')]));
  });

  test('a failed deletion keeps the user signed in with their settings, and can be retried', () async {
    accounts.failure = Exception('offline');
    final (c, vm) = await start();
    vm.setAgreed(true);
    await vm.delete();
    final state = c.read(deleteAccountViewModelProvider);
    expect((state.busy, state.deleted, signOuts), (false, false, 0));
    expect(state.error, contains('offline'));
    expect(await storage.readAll(), hasLength(4));

    accounts.failure = null;
    await vm.delete();
    expect(signOuts, 1);
  });

  test('a second tap while deleting does nothing', () async {
    accounts.gate = Completer();
    final (_, vm) = await start();
    vm.setAgreed(true);
    final first = vm.delete();
    await vm.delete();
    accounts.gate!.complete();
    await first;
    expect(accounts.calls, 1);
  });

  Future<void> pump(WidgetTester tester, Widget home,
      {({String terms, String privacy}) links = (terms: '', privacy: '')}) async {
    await tester.pumpWidget(ProviderScope(overrides: overrides(links: links), child: MaterialApp(home: home)));
    await tester.pumpAndSettle();
  }

  testWidgets('from settings: confirm, delete, and land on the first page', (tester) async {
    await pump(tester, const SettingsPage());
    await tester.scrollUntilVisible(find.text(t.deleteAccount), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.deleteAccount));
    await tester.pumpAndSettle();
    expect(find.text(t.deleteAccountSubscription), findsNothing);
    final button = find.widgetWithText(FilledButton, t.deleteAccountConfirm);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountPage), findsNothing);
    expect(find.text(t.accountDeleted), findsOneWidget);
    expect(signOuts, 1);
  });

  testWidgets('a member is warned that the subscription keeps charging', (tester) async {
    billing.active = true;
    await pump(tester, const DeleteAccountPage());
    expect(find.text(t.deleteAccountSubscription), findsOneWidget);
    await tester.tap(find.text(t.manageSubscription));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'store.example');
  });

  testWidgets('without a billing setup the warning links to the store’s subscription page', (tester) async {
    billing.isAvailable = false;
    usage.summary = usage.summary.copyWith(member: true);
    await pump(tester, const DeleteAccountPage());
    await tester.tap(find.text(t.manageSubscription));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'play.google.com');
  });

  testWidgets('settings link to the legal pages that are configured', (tester) async {
    await pump(tester, const SettingsPage(), links: (terms: '', privacy: 'https://x.example/privacy'));
    await tester.scrollUntilVisible(find.text(t.privacyPolicy), 200);
    await tester.pumpAndSettle();
    expect(find.text(t.termsOfUse), findsNothing);
    await tester.tap(find.text(t.privacyPolicy));
    await tester.pumpAndSettle();
    expect(opened.single.path, '/privacy');
  });

  test('the repository sends the confirmation and fails loudly', () async {
    late http.Request sent;
    var status = 200;
    final db = SupabaseClient('https://x.test', 'key',
        httpClient: MockClient((r) async {
          sent = r;
          return http.Response('{}', status, headers: {'content-type': 'application/json'}, request: r);
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false, authFlowType: AuthFlowType.implicit));
    addTearDown(db.dispose);
    await SupabaseAccountRepository(db).delete();
    expect((sent.method, sent.url.path), ('POST', '/functions/v1/delete-account'));
    expect(jsonDecode(sent.body), {'confirm': 'delete'});
    status = 500;
    await expectLater(SupabaseAccountRepository(db).delete(), throwsA(isA<FunctionException>()));
  });
}
