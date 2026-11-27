import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_settings.dart';
import '../../app/app_theme.dart';
import '../../app/providers.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/section.dart';
import 'ai_settings_page.dart';
import 'local_model_page.dart';
import 'settings_view_model.dart';

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
    final ok = await confirmAction(
      context,
      title: 'ออกจากระบบ?',
      message: 'ต้องเข้าสู่ระบบใหม่เพื่อดูบันทึก',
      confirmLabel: 'ออกจากระบบ',
    );
    if (!ok) return;
    try {
      await signOut();
      nav.popUntil((r) => r.isFirst);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ออกจากระบบไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // หน้าย่อยเปิดทับหน้านี้เสมอ จึงแสดงข้อความแจ้งที่นี่ที่เดียว (snackbar ขึ้นบนหน้าที่เห็นอยู่)
    ref.listen(settingsViewModelProvider.select((s) => s.notice), (_, notice) {
      if (notice != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
    });
    final scheme = Theme.of(context).colorScheme;
    final email = ref.watch(currentUserEmailProvider) ?? '-';
    final ai = ref.watch(aiSettingsProvider);
    final st = ref.watch(settingsViewModelProvider);
    void push(Widget page) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    final theme = Theme.of(context);
    const chevron = Icon(Icons.chevron_right_rounded);
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
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
              subtitle: const Text('บัญชีที่ใช้อยู่'),
            ),
          ]),
          SectionCard(title: 'AI', children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('AI ที่ใช้บันทึก'),
              subtitle: Text(
                '${ai.provider.label}${ai.missingKey ? ' · ยังไม่ได้ใส่ API key' : ''}',
                // ยังใช้ AI ไม่ได้ ต้องสะดุดตา
                style: ai.missingKey ? TextStyle(color: scheme.error) : null,
              ),
              trailing: chevron,
              onTap: () => push(const AiSettingsPage()),
            ),
            ListTile(
              leading: const Icon(Icons.memory_rounded),
              title: const Text('โมเดลในเครื่อง'),
              subtitle: Text(
                gemmaStatus(st),
                style: st.gemmaError == null ? null : TextStyle(color: scheme.error),
              ),
              trailing: chevron,
              onTap: () => push(const LocalModelPage()),
            ),
          ]),
          SectionCard(title: 'ข้อมูล', children: [
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('นำเข้าจากระบบเดิม'),
              subtitle: const Text('ไฟล์ JSON ที่ export จากระบบเดิม · นำเข้าซ้ำได้ ไม่สร้างรายการซ้ำ'),
              trailing: st.importing
                  ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3))
                  : chevron,
              onTap: st.importing ? null : () => _import(ref),
            ),
          ]),
          SectionCard(children: [
            ListTile(
              leading: Icon(Icons.logout_rounded, color: scheme.error),
              title: Text('ออกจากระบบ', style: theme.textTheme.bodyLarge?.copyWith(color: scheme.error)),
              onTap: () => _signOut(context, ref),
            ),
          ]),
        ],
      ),
    );
  }
}
