import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_settings.dart';
import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../app/providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/section.dart';
import 'ai_settings_page.dart';
import 'local_model_page.dart';
import 'settings_view_model.dart';
import 'usage_section.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _import(WidgetRef ref) async {
    final vm = ref.read(settingsViewModelProvider.notifier);
    final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (picked == null) return;
    await vm.importFile(await picked.readAsBytes());
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final signOut = ref.read(signOutProvider);
    final t = ref.read(stringsProvider);
    final ok = await confirmAction(
      context,
      title: t.signOutTitle,
      message: t.signOutMessage,
      cancelLabel: t.cancel,
      confirmLabel: t.signOut,
    );
    if (!ok) return;
    try {
      await signOut();
      nav.popUntil((r) => r.isFirst);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.signOutFailed(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // หน้าย่อยเปิดทับหน้านี้เสมอ จึงแสดงข้อความแจ้งที่นี่ที่เดียว (snackbar ขึ้นบนหน้าที่เห็นอยู่)
    ref.listen(settingsViewModelProvider.select((s) => s.notice), (_, notice) {
      if (notice != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
    });
    final t = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final email = ref.watch(currentUserEmailProvider) ?? '-';
    final ai = ref.watch(aiSettingsProvider);
    final st = ref.watch(settingsViewModelProvider);
    void push(Widget page) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    final theme = Theme.of(context);
    const chevron = Icon(Icons.chevron_right_rounded);
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        padding: EdgeInsets.only(top: 4, bottom: 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          SectionCard(children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: Insets.page, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Text(email.characters.first.toUpperCase()),
              ),
              title: Text(email, style: theme.textTheme.titleMedium),
              subtitle: Text(t.currentAccount),
            ),
          ]),
          SectionCard(title: 'AI', children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(t.aiForRecording),
              subtitle: Text(
                [
                  t.providerLabel(ai.provider),
                  if (ai.missingKey) t.noApiKeyYet,
                  if (ai.needsConsent) t.consentNeeded,
                ].join(' · '),
                // ยังใช้ AI ไม่ได้ ต้องสะดุดตา
                style: ai.missingKey ? TextStyle(color: scheme.error) : null,
              ),
              trailing: chevron,
              onTap: () => push(const AiSettingsPage()),
            ),
            ListTile(
              leading: const Icon(Icons.memory_rounded),
              title: Text(t.localModel),
              subtitle: Text(
                gemmaStatus(st, t),
                style: st.gemmaError == null ? null : TextStyle(color: scheme.error),
              ),
              trailing: chevron,
              onTap: () => push(const LocalModelPage()),
            ),
          ]),
          SectionCard(title: t.usage, children: const [UsageRows()]),
          SectionCard(title: t.general, children: [
            Padding(
              padding: const EdgeInsets.all(Insets.page),
              child: Labeled(
                t.languageSetting,
                child: SegmentedButton<AppLanguage>(
                  showSelectedIcon: false,
                  segments: [for (final l in AppLanguage.values) ButtonSegment(value: l, label: Text(l.nativeName))],
                  selected: {t.language},
                  onSelectionChanged: (v) => ref.read(languageProvider.notifier).select(v.first),
                ),
              ),
            ),
          ]),
          SectionCard(title: t.data, children: [
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: Text(t.importLegacy),
              subtitle: Text(t.importLegacyDetail),
              trailing: st.importing
                  ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3))
                  : chevron,
              onTap: st.importing ? null : () => _import(ref),
            ),
          ]),
          SectionCard(children: [
            ListTile(
              leading: Icon(Icons.logout_rounded, color: scheme.error),
              title: Text(t.signOut, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.error)),
              onTap: () => _signOut(context, ref),
            ),
          ]),
        ],
      ),
    );
  }
}
