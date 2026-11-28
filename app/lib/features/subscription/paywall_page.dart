import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../app/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/notice_box.dart';
import 'paywall_view_model.dart';

Future<void> openPaywall(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PaywallPage()));

/// สมัคร Member หรือจัดการการสมัครที่มีอยู่
class PaywallPage extends ConsumerWidget {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(paywallViewModelProvider);
    final vm = ref.read(paywallViewModelProvider.notifier);
    final links = ref.watch(legalLinksProvider);
    final theme = Theme.of(context);
    final benefits = s.benefits;

    Future<void> open(Uri? url) async {
      final opener = ref.read(openLinkProvider);
      if (url != null && !await opener(url).catchError((_) => false)) vm.linkFailed();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Member')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Insets.page, 4, Insets.page, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (s.loading || s.busy) const LinearProgressIndicator(),
          if (benefits != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final line in [
                  t.benefitAi(benefits.aiPerDay, benefits.aiPerMonth),
                  t.benefitStorage(fmtBytes(benefits.storageBytes)),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.check_rounded, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(line)),
                    ]),
                  ),
              ]),
            ),
          if (s.message case final message?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoticeBox(
                message,
                isError: s.failed,
                // โหลดไม่สำเร็จ (ยังไม่รู้สิทธิ์ของแผน) ให้ลองใหม่ได้
                action: s.failed && benefits == null && !s.loading
                    ? TextButton(onPressed: vm.load, child: Text(t.retry))
                    : null,
              ),
            ),
          if (!s.loading && benefits != null) ...[
            if (s.member) ...[
              Text(t.memberAlready, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: s.busy ? null : () async => open(await vm.managementUrl()),
                child: Text(t.manageSubscription),
              ),
            ] else ...[
              if (s.offers.isEmpty) Text(t.noOffers),
              for (final offer in s.offers)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.page),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(offer.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text([offer.price, if (offer.period case final p?) t.billingPeriod(p)].join(' · ')),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: s.busy ? null : () => vm.buy(offer), child: Text(t.buy)),
                    ]),
                  ),
                ),
              if (s.offers.isNotEmpty) Text(t.autoRenewNote, style: theme.textTheme.bodySmall),
            ],
            if (ref.watch(billingRepositoryProvider).isAvailable)
              TextButton(onPressed: s.busy ? null : vm.restore, child: Text(t.restorePurchases)),
            Wrap(alignment: WrapAlignment.center, children: [
              for (final (label, url) in [(t.termsOfUse, links.terms), (t.privacyPolicy, links.privacy)])
                if (url.isNotEmpty) TextButton(onPressed: () => open(Uri.tryParse(url)), child: Text(label)),
            ]),
          ],
        ],
      ),
    );
  }
}
