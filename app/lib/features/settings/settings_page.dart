import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ai/ai_settings.dart';
import '../../ai/llm_provider.dart';
import '../../ai/on_device_provider.dart';
import '../../state/app_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state, required this.ai});
  final AppState state;
  final AiSettings ai;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _model = TextEditingController(text: widget.ai.studioModel);
  final _key = TextEditingController();
  bool _showKey = false;
  bool? _gemmaInstalled;
  int? _progress;
  String? _gemmaError;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _checkGemma();
  }

  @override
  void dispose() {
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _checkGemma() async {
    try {
      final ok = await OnDeviceProvider.isInstalled();
      if (mounted) setState(() => _gemmaInstalled = ok);
    } catch (e) {
      if (mounted) setState(() => _gemmaError = '$e');
    }
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
    if (ok != true) return;
    setState(() {
      _progress = 0;
      _gemmaError = null;
    });
    try {
      await OnDeviceProvider.install(onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) setState(() => _gemmaInstalled = true);
    } catch (e) {
      if (mounted) setState(() => _gemmaError = 'ดาวน์โหลดไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _removeGemma() async {
    await OnDeviceProvider.uninstall();
    await _checkGemma();
  }

  Future<void> _saveKey() async {
    await widget.ai.setStudioKey(_key.text);
    _key.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึก API key แล้ว (เก็บในเครื่องเท่านั้น)')));
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (picked == null) return;
    setState(() => _importing = true);
    String message;
    try {
      final data = jsonDecode(utf8.decode(await picked.readAsBytes())) as Map<String, dynamic>;
      final n = await widget.state.repo.importExport(data);
      await widget.state.load();
      message = n == 0 ? 'ไม่มีรายการใหม่ (นำเข้าครบแล้ว)' : 'นำเข้าแล้ว $n รายการ';
    } catch (e) {
      message = 'นำเข้าไม่สำเร็จ: $e';
    }
    if (!mounted) return;
    setState(() => _importing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: ListenableBuilder(
        listenable: widget.ai,
        builder: (context, _) {
          final ai = widget.ai;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _Header('AI ที่ใช้บันทึก'),
              RadioGroup<AiProviderKind>(
                groupValue: ai.provider,
                onChanged: (v) => v == null ? null : ai.setProvider(v),
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
                    if (ai.hasStudioKey) TextButton(onPressed: () => ai.setStudioKey(null), child: const Text('ลบ key')),
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
                    onChanged: ai.setStudioModel,
                  ),
                ),
              ],
              if (ai.provider == AiProviderKind.onDevice)
                ListTile(
                  leading: const Icon(Icons.memory),
                  title: const Text('Gemma 4 E2B (${OnDeviceProvider.sizeLabel})'),
                  subtitle: Text(_gemmaError ??
                      (_progress != null
                          ? 'กำลังดาวน์โหลด $_progress%'
                          : _gemmaInstalled == null
                              ? 'กำลังตรวจสอบ…'
                              : _gemmaInstalled!
                                  ? 'พร้อมใช้ — ทำงานในเครื่อง ไม่ต้องใช้เน็ต'
                                  : 'ยังไม่ได้ดาวน์โหลด'),
                      style: _gemmaError == null ? null : TextStyle(color: scheme.error)),
                  trailing: _progress != null
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(value: _progress! / 100, strokeWidth: 3))
                      : _gemmaInstalled == true
                          ? TextButton(onPressed: _removeGemma, child: const Text('ลบ'))
                          : FilledButton(onPressed: _gemmaInstalled == null ? null : _downloadGemma, child: const Text('ดาวน์โหลด')),
                ),
              const Divider(height: 32),
              const _Header('ข้อมูล'),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('นำเข้าจากระบบเดิม'),
                subtitle: const Text('ไฟล์ JSON ที่ export จากระบบเดิม · นำเข้าซ้ำได้ ไม่สร้างรายการซ้ำ'),
                trailing: _importing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : null,
                onTap: _importing ? null : _import,
              ),
              const Divider(height: 32),
              const _Header('บัญชี'),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(user?.email ?? '-'),
                trailing: TextButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
