import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../app/providers.dart';
import '../../core/widgets/notice_box.dart';
import 'delete_account_view_model.dart';

class DeleteAccountPage extends ConsumerWidget {
  const DeleteAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(deleteAccountViewModelProvider);
    final vm = ref.read(deleteAccountViewModelProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    ref.listen(deleteAccountViewModelProvider.select((s) => s.deleted), (_, deleted) {
      if (!deleted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.accountDeleted)));
      Navigator.of(context).popUntil((r) => r.isFirst);
    });
    return PopScope(
      canPop: !s.busy || s.deleted,
      child: Scaffold(
        appBar: AppBar(title: Text(t.deleteAccount)),
        body: ListView(
          padding: EdgeInsets.fromLTRB(Insets.page, 4, Insets.page, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            Text(t.deleteAccountWhat),
            const SizedBox(height: 12),
            Text(t.deleteAccountKept, style: Theme.of(context).textTheme.bodySmall),
            if (s.member) ...[
              const SizedBox(height: 16),
              NoticeBox(
                t.deleteAccountSubscription,
                action: TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final open = ref.read(openLinkProvider);
                    if (!await open(await vm.subscriptionsUrl()).catchError((_) => false)) {
                      messenger.showSnackBar(SnackBar(content: Text(t.cannotOpenLink)));
                    }
                  },
                  child: Text(t.manageSubscription),
                ),
              ),
            ],
            const SizedBox(height: 16),
            CheckboxListTile(
              value: s.agreed,
              onChanged: s.busy ? null : (v) => vm.setAgreed(v ?? false),
              title: Text(t.deleteAccountAgree),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (s.error case final error?) ...[const SizedBox(height: 8), NoticeBox(error)],
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
              onPressed: s.agreed && !s.busy ? vm.delete : null,
              child: s.busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t.deleteAccountConfirm),
            ),
          ],
        ),
      ),
    );
  }
}
