import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_settings.dart';
import '../../ai/llm_provider.dart';
import '../../ai/on_device_provider.dart';
import '../entry_editor/entry_editor_page.dart';
import '../settings/settings_page.dart';
import 'recorder.dart';
import 'turn_view_model.dart';

/// คืน provider ที่พร้อมใช้ ถ้ายังไม่ตั้งค่าจะถามว่าจะไปหน้าตั้งค่าไหม
///
/// รับ [nav] (เก็บจาก `Navigator.of(context)` ก่อน await) แทน BuildContext — context ของ Navigator
/// อยู่ตลอดอายุแอป จึงใช้แสดง dialog/push หน้าหลัง await ได้โดยไม่ต้องเช็ก mounted
Future<LlmProvider?> ensureLlmProvider(NavigatorState nav, WidgetRef ref) async {
  final settings = ref.read(aiSettingsProvider.notifier);
  final kind = ref.read(aiSettingsProvider).provider;
  final p = await settings.resolveProvider();
  if (p != null) return p;
  final setUp = await showDialog<bool>(
    // ignore: use_build_context_synchronously (context ของ Navigator อยู่ตลอดอายุแอป)
    context: nav.context,
    builder: (c) => AlertDialog(
      title: const Text('ยังไม่ได้ตั้งค่า AI'),
      content: Text(kind == AiProviderKind.aiStudio
          ? 'ใส่ API key ของ Google AI Studio ในหน้าตั้งค่าก่อน'
          : 'ดาวน์โหลดโมเดล Gemma (${OnDeviceProvider.sizeLabel}) ในหน้าตั้งค่าก่อน'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ไว้ก่อน')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ไปตั้งค่า')),
      ],
    ),
  );
  if (setUp == true) {
    await nav.push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }
  return null;
}

class TurnView extends ConsumerWidget {
  const TurnView({super.key, required this.text, required this.onApply});
  final String text;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turn = ref.watch(turnViewModelProvider(text));
    final vm = ref.read(turnViewModelProvider(text).notifier);
    final scheme = Theme.of(context).colorScheme;
    final r = turn.result;
    final selectable = r?.actions.where((a) => a.valid).toList() ?? const <ProposedAction>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
          child: Text(text, style: TextStyle(color: scheme.onPrimaryContainer)),
        ),
      ),
      if (turn.busy && r == null)
        const Padding(padding: EdgeInsets.all(12), child: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('AI กำลังคิด…'),
        ])),
      if (turn.error != null)
        Card(
          color: scheme.errorContainer,
          child: Padding(padding: const EdgeInsets.all(12), child: Text(turn.error!, style: TextStyle(color: scheme.onErrorContainer))),
        ),
      if (r != null)
        Card(
          margin: const EdgeInsets.only(right: 24, bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.reply.isNotEmpty) Text(r.reply),
              for (final q in r.questions)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.help_outline, size: 18, color: scheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(q, style: TextStyle(color: scheme.tertiary))),
                  ]),
                ),
              if (r.actions.isNotEmpty) const Divider(height: 20),
              for (final (i, a) in r.actions.indexed) _ActionTile(action: a, locked: turn.applied || turn.busy, vm: vm, index: i),
              if (selectable.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: turn.applied
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle, color: scheme.primary, size: 18),
                          const SizedBox(width: 6),
                          const Text('บันทึกแล้ว'),
                        ])
                      : FilledButton.icon(
                          onPressed: turn.busy || !selectable.any((a) => a.selected) ? null : onApply,
                          icon: const Icon(Icons.check),
                          label: Text('บันทึก ${selectable.where((a) => a.selected).length} รายการ'),
                        ),
                ),
              ],
            ]),
          ),
        ),
    ]);
  }
}

class _ActionTile extends ConsumerWidget {
  const _ActionTile({required this.action, required this.locked, required this.vm, required this.index});
  final ProposedAction action;
  final bool locked;
  final TurnViewModel vm;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final a = action;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(
          value: a.valid && a.selected,
          onChanged: !a.valid || locked
              ? null
              : (v) => vm.toggle(index, v ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.summary, style: TextStyle(fontWeight: FontWeight.w500, color: a.valid ? null : scheme.onSurfaceVariant)),
              if (a.detail.isNotEmpty)
                Text(a.detail, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant), maxLines: 6, overflow: TextOverflow.ellipsis),
              for (final err in a.errors) Text('⚠ $err', style: TextStyle(fontSize: 13, color: scheme.error)),
            ]),
          ),
        ),
        if (a.entry != null && !locked)
          IconButton(
            tooltip: 'แก้ก่อนบันทึก',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () async {
              final saved = await openEditor(context, entry: a.entry, draft: true);
              if (saved) vm.toggle(index, false);
            },
          ),
      ]),
    );
  }
}
