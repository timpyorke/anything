import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_settings.dart';
import '../../app/providers.dart';
import 'ai_settings_page.dart';
import 'local_model_page.dart';
import 'settings_header.dart';
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ออกจากระบบ?'),
        content: const Text('ต้องเข้าสู่ระบบใหม่เพื่อดูบันทึก'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ออกจากระบบ')),
        ],
      ),
    );
    if (ok != true) return;
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
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: CircleAvatar(child: Text(email.characters.first.toUpperCase())),
            title: Text(email),
          ),
          const Divider(height: 32),
          const SettingsHeader('AI'),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('AI ที่ใช้บันทึก'),
            subtitle: Text('${ai.provider.label}${ai.missingKey ? ' · ยังไม่ได้ใส่ API key' : ''}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(const AiSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('โมเดลในเครื่อง'),
            subtitle: Text(gemmaStatus(st), style: st.gemmaError == null ? null : TextStyle(color: scheme.error)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(const LocalModelPage()),
          ),
          const Divider(height: 32),
          const SettingsHeader('ข้อมูล'),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('นำเข้าจากระบบเดิม'),
            subtitle: const Text('ไฟล์ JSON ที่ export จากระบบเดิม · นำเข้าซ้ำได้ ไม่สร้างรายการซ้ำ'),
            trailing: st.importing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : null,
            onTap: st.importing ? null : () => _import(ref),
          ),
          const Divider(height: 32),
          ListTile(
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text('ออกจากระบบ', style: TextStyle(color: scheme.error)),
            onTap: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }
}
