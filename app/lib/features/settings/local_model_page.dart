import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/on_device_provider.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/confirm_dialog.dart';
import 'settings_view_model.dart';

/// สถานะของโมเดลในเครื่องเป็นข้อความ
String gemmaStatus(SettingsState st) {
  if (st.gemmaError != null) return st.gemmaError!;
  if (st.progress != null) return 'กำลังดาวน์โหลด ${st.progress}%';
  return switch (st.gemmaInstalled) {
    null => 'กำลังตรวจสอบ…',
    true => 'พร้อมใช้ — ทำงานในเครื่อง ไม่ต้องใช้เน็ต',
    false => 'ยังไม่ได้ดาวน์โหลด',
  };
}

/// ดาวน์โหลด/ลบโมเดลในเครื่อง
class LocalModelPage extends ConsumerStatefulWidget {
  const LocalModelPage({super.key});

  @override
  ConsumerState<LocalModelPage> createState() => _LocalModelPageState();
}

class _LocalModelPageState extends ConsumerState<LocalModelPage> {
  SettingsViewModel get _vm => ref.read(settingsViewModelProvider.notifier);

  Future<void> _downloadGemma() async {
    final vm = _vm;
    final ok = await confirmAction(
      context,
      title: 'ดาวน์โหลด Gemma 4 E2B?',
      message: 'ไฟล์ขนาด ${OnDeviceProvider.sizeLabel} ควรใช้ Wi-Fi และมีพื้นที่ว่างพอ\n'
          'หลังดาวน์โหลดแล้ว AI จะทำงานในเครื่องได้โดยไม่ต้องใช้เน็ต',
      confirmLabel: 'ดาวน์โหลด',
      destructive: false,
    );
    if (ok) await vm.downloadGemma();
  }

  Future<void> _removeGemma() async {
    final vm = _vm;
    final ok = await confirmAction(
      context,
      title: 'ลบโมเดลในเครื่อง?',
      message: 'จะใช้เสียงพูดและ AI ในเครื่องไม่ได้จนกว่าจะดาวน์โหลดใหม่ (${OnDeviceProvider.sizeLabel})',
      confirmLabel: 'ลบ',
    );
    if (ok) await vm.removeGemma();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final st = ref.watch(settingsViewModelProvider);
    final installed = st.gemmaInstalled == true;
    return Scaffold(
      appBar: AppBar(title: const Text('โมเดลในเครื่อง')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Insets.page, 4, Insets.page, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(
                  installed ? Icons.offline_pin_rounded : Icons.memory_rounded,
                  size: 40,
                  color: installed ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text('Gemma 4 E2B', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                Text('ขนาด ${OnDeviceProvider.sizeLabel}', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    gemmaStatus(st),
                    textAlign: TextAlign.center,
                    style: st.gemmaError == null ? null : TextStyle(color: scheme.error),
                  ),
                ),
                if (st.progress != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: st.progress! / 100, minHeight: 8),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  if (installed)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                      onPressed: _removeGemma,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('ลบ'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: st.gemmaInstalled == null && st.gemmaError == null ? null : _downloadGemma,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('ดาวน์โหลด'),
                    ),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
            child: Text(
              'ใช้ฟังเสียงที่พูด (ถอดเป็นข้อความในเครื่อง) และใช้บันทึกได้เมื่อเลือก AI ในเครื่อง',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
