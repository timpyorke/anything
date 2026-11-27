import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/on_device_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = ref.watch(settingsViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('โมเดลในเครื่อง')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('Gemma 4 E2B (${OnDeviceProvider.sizeLabel})'),
            subtitle: Text(gemmaStatus(st), style: st.gemmaError == null ? null : TextStyle(color: scheme.error)),
            trailing: st.progress != null
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(value: st.progress! / 100, strokeWidth: 3))
                : st.gemmaInstalled == true
                    ? TextButton(onPressed: _vm.removeGemma, child: const Text('ลบ'))
                    : FilledButton(onPressed: st.gemmaInstalled == null ? null : _downloadGemma, child: const Text('ดาวน์โหลด')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'ใช้ฟังเสียงที่พูด (ถอดเป็นข้อความในเครื่อง) และใช้บันทึกได้เมื่อเลือก AI ในเครื่อง',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
