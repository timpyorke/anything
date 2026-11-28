import 'dart:async';

import 'package:anything/app/anything_app.dart';
import 'package:anything/app/providers.dart';
import 'package:anything/core/l10n/strings_en.dart';
import 'package:anything/core/l10n/strings_th.dart';
import 'package:anything/domain/billing.dart';
import 'package:anything/features/settings/usage_section.dart';
import 'package:anything/features/subscription/paywall_page.dart';
import 'package:anything/features/subscription/paywall_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_billing_repository.dart';
import '../support/fake_usage_repository.dart';

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeUsageRepository usage;
  late FakeBillingRepository billing;

  setUp(() {
    usage = FakeUsageRepository();
    billing = FakeBillingRepository();
  });

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('user'),
      usageRepositoryProvider.overrideWithValue(usage),
      billingRepositoryProvider.overrideWithValue(billing),
      syncRetryDelayProvider.overrideWithValue(Duration.zero),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<(ProviderContainer, PaywallViewModel, PaywallState Function())> open() async {
    final c = container();
    c.listen(paywallViewModelProvider, (_, _) {});
    await _settle();
    return (c, c.read(paywallViewModelProvider.notifier), () => c.read(paywallViewModelProvider));
  }

  const t = ThStrings();

  test('shows the member benefits and the store’s offers', () async {
    final (_, _, state) = await open();
    expect(state().loading, isFalse);
    expect(state().member, isFalse);
    expect(state().offers.single.price, '฿99.00');
    expect(state().benefits?.aiPerDay, 40);
    expect(usage.syncs, 0);
  });

  test('a purchase counts only once the server confirms it, retrying while it catches up', () async {
    usage.syncAnswers.addAll([false, Exception('429'), true]);
    final (_, vm, state) = await open();
    await vm.buy(state().offers.single);
    expect(usage.syncs, 3);
    expect(state().member, isTrue);
    expect(state().message, t.purchaseActivated);
    expect(state().busy, isFalse);
  });

  test('a purchase the server cannot confirm says so and does not claim membership', () async {
    final (_, vm, state) = await open();
    await vm.buy(state().offers.single);
    expect(usage.syncs, 3);
    expect((state().member, state().message, state().failed), (false, t.purchaseNotYetActive, false));
  });

  test('cancelled, pending and failed purchases never sync', () async {
    final (_, vm, state) = await open();
    billing.outcome = PurchaseOutcome.cancelled;
    await vm.buy(state().offers.single);
    expect(state().message, isNull);

    billing.outcome = PurchaseOutcome.pending;
    await vm.buy(state().offers.single);
    expect(state().message, t.purchasePending);

    billing.outcome = BillingException('store down');
    await vm.buy(state().offers.single);
    expect((state().message, state().failed, state().busy), (t.billingFailed('store down'), true, false));
    expect(usage.syncs, 0);
  });

  test('a second tap while buying does nothing, and closing the page still records the purchase', () async {
    billing.gate = Completer();
    usage.syncAnswers.add(true);
    final c = container();
    final sub = c.listen(paywallViewModelProvider, (_, _) {});
    await _settle();
    final vm = c.read(paywallViewModelProvider.notifier);
    final offer = c.read(paywallViewModelProvider).offers.single;
    final first = vm.buy(offer);
    await vm.buy(offer);
    expect(billing.bought, hasLength(1));
    sub.close();
    await _settle();
    billing.gate!.complete();
    await first;
    expect(usage.syncs, 1);
    expect(usage.summary.member, isTrue);
  });

  test('restore confirms with the server, or says there is nothing to restore', () async {
    final (_, vm, state) = await open();
    await vm.restore();
    expect((state().message, usage.syncs), (t.nothingToRestore, 0));
    billing.restorable = true;
    usage.syncAnswers.add(true);
    await vm.restore();
    expect(state().member, isTrue);
  });

  test('opening the page repairs a membership the server missed', () async {
    billing.active = true;
    usage.syncAnswers.add(true);
    final (_, _, state) = await open();
    expect((state().member, usage.syncs), (true, 1));
    expect(state().offers, isEmpty);
  });

  test('store billing periods read naturally in both languages', () {
    expect(t.billingPeriod('P1M'), 'ทุกเดือน');
    expect(t.billingPeriod('P1Y'), 'ทุกปี');
    expect(const EnStrings().billingPeriod('P3M'), 'Every 3 months');
    expect(t.billingPeriod('P1M2D'), 'P1M2D');
  });

  Future<List<Uri>> pump(WidgetTester tester, Widget home, {({String terms, String privacy})? links}) async {
    final opened = <Uri>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user'),
        usageRepositoryProvider.overrideWithValue(usage),
        billingRepositoryProvider.overrideWithValue(billing),
        legalLinksProvider.overrideWithValue(links ?? (terms: 'https://x.example/terms', privacy: '')),
        openLinkProvider.overrideWithValue((url) async {
          opened.add(url);
          return true;
        }),
      ],
      child: MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('the paywall shows price, renewal terms, restore and the configured legal links', (tester) async {
    final opened = await pump(tester, const PaywallPage());
    expect(find.text('AI ของแอป 40 ครั้งต่อวัน สูงสุด 500 ครั้งต่อเดือน'), findsOneWidget);
    expect(find.text('พื้นที่เก็บรูป 5 GB'), findsOneWidget);
    expect(find.text('฿99.00 · ทุกเดือน'), findsOneWidget);
    expect(find.text(t.autoRenewNote), findsOneWidget);
    expect(find.text(t.restorePurchases), findsOneWidget);
    expect(find.text(t.privacyPolicy), findsNothing);
    await tester.tap(find.text(t.termsOfUse));
    await tester.pumpAndSettle();
    expect(opened.single.path, '/terms');
  });

  testWidgets('a member manages the subscription in the store', (tester) async {
    usage.summary = usage.summary.copyWith(member: true);
    final opened = await pump(tester, const PaywallPage());
    expect(find.text(t.memberAlready), findsOneWidget);
    expect(find.text(t.buy), findsNothing);
    await tester.tap(find.text(t.manageSubscription));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'store.example');
  });

  testWidgets('settings offer the membership only where it can be bought', (tester) async {
    await pump(tester, const Scaffold(body: SingleChildScrollView(child: UsageRows())));
    await tester.tap(find.text(t.subscribe));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallPage), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    billing.isAvailable = false;
    await pump(tester, const Scaffold(body: SingleChildScrollView(child: UsageRows())));
    expect(find.text(t.subscribe), findsNothing);
  });

  testWidgets('the app ties purchases to the signed-in account', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserIdProvider.overrideWithValue(null), billingRepositoryProvider.overrideWithValue(billing)],
      child: const AnythingApp(),
    ));
    await tester.pump();
    expect(billing.users, [null]);
  });
}
