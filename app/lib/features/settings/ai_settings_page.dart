import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_settings.dart';
import '../../ai/llm_provider.dart';
import 'local_model_page.dart';
import 'settings_view_model.dart';

/// เลือก AI ที่ใช้บันทึก พร้อม API key และโมเดลของบริการที่เลือก
class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  final _key = TextEditingController();
  bool _showKey = false;

  SettingsViewModel get _vm => ref.read(settingsViewModelProvider.notifier);

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _saveKey() {
    final key = _key.text;
    _key.clear();
    FocusScope.of(context).unfocus();
    _vm.saveKey(ref.read(aiSettingsProvider).provider, key);
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiSettingsProvider);
    final aiVm = ref.read(aiSettingsProvider.notifier);
    final hasKey = ai.savedKeys.contains(ai.provider);
    // ถือ view model ไว้ตลอดอายุหน้า ผลการบันทึก key แสดงโดยหน้าตั้งค่าที่อยู่ข้างใต้
    ref.watch(settingsViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI ที่ใช้บันทึก')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          RadioGroup<AiProviderKind>(
            groupValue: ai.provider,
            onChanged: (v) {
              if (v == null) return;
              _key.clear(); // key ที่พิมพ์ค้างไว้เป็นของบริการเดิม ห้ามบันทึกให้บริการใหม่
              aiVm.setProvider(v);
            },
            child: Column(children: [
              for (final k in AiProviderKind.values)
                RadioListTile<AiProviderKind>(value: k, title: Text(k.label), subtitle: Text(k.description)),
            ]),
          ),
          if (ai.provider == AiProviderKind.onDevice)
            ListTile(
              leading: const Icon(Icons.memory),
              title: const Text('จัดการโมเดลในเครื่อง'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LocalModelPage())),
            ),
          if (ai.provider.isCloud) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _key,
                obscureText: !_showKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: hasKey ? 'API key (ตั้งไว้แล้ว — ใส่ใหม่เพื่อเปลี่ยน)' : 'API key ของ ${ai.provider.label}',
                  helperText: 'สร้างได้ที่ ${ai.provider.keyUrl} · เก็บใน Keychain/Keystore ของเครื่อง แยกตามบัญชี',
                  helperMaxLines: 3,
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
                if (hasKey) TextButton(onPressed: () => aiVm.setKey(ai.provider, null), child: const Text('ลบ key')),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 4, 0),
              child: _ModelField(ai.provider, key: ValueKey(ai.provider)),
            ),
          ],
        ],
      ),
    );
  }
}

/// เลือกโมเดลของบริการ จากรายชื่อที่ดึงมาอัตโนมัติ
class _ModelField extends ConsumerWidget {
  const _ModelField(this.kind, {super.key});
  final AiProviderKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(aiSettingsProvider.select((s) => s.modelFor(kind)));
    final hasKey = ref.watch(aiSettingsProvider.select((s) => s.savedKeys.contains(kind)));
    final models = ref.watch(aiModelsProvider(kind));
    final list = models.value ?? const <String>[];
    final error = models.isLoading ? null : models.error;
    // โมเดลที่เลือกไว้ต้องอยู่ในรายการเสมอ แม้ยังโหลดไม่เสร็จหรือบริการไม่มีแล้ว
    final items = [if (!list.contains(selected)) selected, ...list];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          menuMaxHeight: 400,
          decoration: InputDecoration(
            labelText: 'โมเดล',
            border: const OutlineInputBorder(),
            errorText: error == null ? null : 'โหลดรายชื่อโมเดลไม่ได้ — $error',
            errorMaxLines: 3,
            helperText: !hasKey
                ? 'บันทึก API key ก่อน เพื่อโหลดรายชื่อโมเดล'
                : models.isLoading
                    ? 'กำลังโหลดรายชื่อโมเดล…'
                    : list.contains(selected)
                        ? '${list.length} โมเดลจาก ${kind.label}'
                        : 'โมเดลที่เลือกไว้ไม่อยู่ในรายชื่อ — เลือกใหม่',
            helperMaxLines: 2,
          ),
          items: [for (final id in items) DropdownMenuItem(value: id, child: Text(id, overflow: TextOverflow.ellipsis))],
          onChanged: list.isEmpty ? null : (id) => id == null ? null : ref.read(aiSettingsProvider.notifier).setModel(kind, id),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: IconButton(
          tooltip: 'โหลดรายชื่อโมเดลใหม่',
          onPressed: !hasKey || models.isLoading ? null : () => ref.invalidate(aiModelsProvider(kind)),
          icon: models.isLoading
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
        ),
      ),
    ]);
  }
}
