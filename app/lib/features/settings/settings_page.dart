import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_settings.dart';
import '../../ai/llm_provider.dart';
import '../../ai/on_device_provider.dart';
import '../../app/providers.dart';
import 'settings_view_model.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _model = TextEditingController(text: ref.read(aiSettingsProvider).studioModel);
  final _key = TextEditingController();
  bool _showKey = false;

  SettingsViewModel get _vm => ref.read(settingsViewModelProvider.notifier);

  @override
  void dispose() {
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _downloadGemma() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ดาวน์โหลด Gemma 4 E2B?'),
        content: const Text('ไฟล์ขนาด ${OnDeviceProvider.sizeLabel} ควรใช้ Wi-Fi และมีพื้นที่ว่างพอ\n'
            'หลังดาวน์โหลดแล้ว AI จะทำงานในเครื่องได้โดยไม่ต้องใช้เน็ต'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ดาวน์โหลด')),
        ],
      ),
    );
    if (ok == true) await _vm.downloadGemma();
  }

  void _saveKey() {
    final key = _key.text;
    _key.clear();
    FocusScope.of(context).unfocus();
    _vm.saveKey(key);
  }

  Future<void> _import() async {
    final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (picked == null) return;
    await _vm.importFile(await picked.readAsBytes());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsViewModelProvider.select((s) => s.notice), (_, notice) {
      if (notice != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
    });
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final ai = ref.watch(aiSettingsProvider);
    final aiVm = ref.read(aiSettingsProvider.notifier);
    final st = ref.watch(settingsViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: Builder(
        builder: (context) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _Header('AI ที่ใช้บันทึก'),
              RadioGroup<AiProviderKind>(
                groupValue: ai.provider,
                onChanged: (v) => v == null ? null : aiVm.setProvider(v),
                child: Column(children: [
                  for (final k in AiProviderKind.values)
                    RadioListTile<AiProviderKind>(value: k, title: Text(k.label), subtitle: Text(k.description)),
                ]),
              ),
              if (ai.provider == AiProviderKind.aiStudio) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: _key,
                    obscureText: !_showKey,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: ai.hasStudioKey ? 'API key (ตั้งไว้แล้ว — ใส่ใหม่เพื่อเปลี่ยน)' : 'API key ของ Google AI Studio',
                      helperText: 'สร้างได้ที่ aistudio.google.com/apikey · เก็บใน Keychain/Keystore ของเครื่อง',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _showKey ? 'ซ่อน' : 'แสดง',
                        icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showKey = !_showKey),
                      ),
                    ),
                    onSubmitted: (_) => _saveKey(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(children: [
                    FilledButton(onPressed: _saveKey, child: const Text('บันทึก key')),
                    const SizedBox(width: 8),
                    if (ai.hasStudioKey) TextButton(onPressed: () => aiVm.setStudioKey(null), child: const Text('ลบ key')),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TextField(
                    controller: _model,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'โมเดล',
                      helperText: 'เช่น gemini-2.5-flash หรือ gemma-3-27b-it',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: aiVm.setStudioModel,
                  ),
                ),
              ],
              if (ai.provider == AiProviderKind.onDevice)
                ListTile(
                  leading: const Icon(Icons.memory),
                  title: const Text('Gemma 4 E2B (${OnDeviceProvider.sizeLabel})'),
                  subtitle: Text(st.gemmaError ??
                      (st.progress != null
                          ? 'กำลังดาวน์โหลด $st.progress%'
                          : st.gemmaInstalled == null
                              ? 'กำลังตรวจสอบ…'
                              : st.gemmaInstalled!
                                  ? 'พร้อมใช้ — ทำงานในเครื่อง ไม่ต้องใช้เน็ต'
                                  : 'ยังไม่ได้ดาวน์โหลด'),
                      style: st.gemmaError == null ? null : TextStyle(color: scheme.error)),
                  trailing: st.progress != null
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(value: st.progress! / 100, strokeWidth: 3))
                      : st.gemmaInstalled == true
                          ? TextButton(onPressed: _vm.removeGemma, child: const Text('ลบ'))
                          : FilledButton(onPressed: st.gemmaInstalled == null ? null : _downloadGemma, child: const Text('ดาวน์โหลด')),
                ),
              const Divider(height: 32),
              const _Header('ข้อมูล'),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('นำเข้าจากระบบเดิม'),
                subtitle: const Text('ไฟล์ JSON ที่ export จากระบบเดิม · นำเข้าซ้ำได้ ไม่สร้างรายการซ้ำ'),
                trailing: st.importing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : null,
                onTap: st.importing ? null : _import,
              ),
              const Divider(height: 32),
              const _Header('บัญชี'),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(user?.email ?? '-'),
                trailing: TextButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await ref.read(supabaseClientProvider).auth.signOut();
                    nav.popUntil((r) => r.isFirst);
                  },
                  child: const Text('ออกจากระบบ'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
