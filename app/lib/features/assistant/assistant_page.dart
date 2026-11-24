import 'package:flutter/material.dart';

import '../../ai/ai_settings.dart';
import '../../ai/ai_studio_provider.dart';
import '../../ai/llm_provider.dart';
import '../../ai/on_device_provider.dart';
import '../../state/app_state.dart';
import '../entry_editor/entry_editor_page.dart';
import '../settings/settings_page.dart';
import 'recorder.dart';

class Turn {
  Turn(this.text);
  final String text;
  AiResult? result;
  String? error;
  bool busy = true;
  bool applied = false;
}

/// ตรรกะคุยกับ AI → เสนอรายการ → บันทึก ใช้ร่วมกันระหว่างหน้าแชทและปุ่มกดค้างพูด
class AssistantRunner {
  AssistantRunner(this.state, this.ai);
  final AppState state;
  final AiSettings ai;

  Future<LlmProvider?> provider() async {
    if (ai.provider == AiProviderKind.aiStudio) {
      final key = await ai.studioKey();
      if (key == null || key.isEmpty) return null;
      return AiStudioProvider(apiKey: key, model: ai.studioModel);
    }
    return await OnDeviceProvider.isInstalled() ? OnDeviceProvider() : null;
  }

  /// คืน provider ที่พร้อมใช้ ถ้ายังไม่ตั้งค่าจะถามว่าจะไปหน้าตั้งค่าไหม
  Future<LlmProvider?> ensureProvider(BuildContext context) async {
    final p = await provider();
    if (p != null || !context.mounted) return p;
    final setUp = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ยังไม่ได้ตั้งค่า AI'),
        content: Text(ai.provider == AiProviderKind.aiStudio
            ? 'ใส่ API key ของ Google AI Studio ในหน้าตั้งค่าก่อน'
            : 'ดาวน์โหลดโมเดล Gemma (${OnDeviceProvider.sizeLabel}) ในหน้าตั้งค่าก่อน'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ไว้ก่อน')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ไปตั้งค่า')),
        ],
      ),
    );
    if (setUp == true && context.mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(state: state, ai: ai)));
    }
    return null;
  }

  Future<void> run(LlmProvider provider, Turn turn) async {
    try {
      turn.result = await Recorder(state).run(provider, turn.text);
      if (turn.result!.actions.isEmpty) {
        await _log(provider, turn.text, turn.result!.raw, 'rejected');
      }
    } on LlmException catch (e) {
      turn.error = e.message;
      await _log(provider, turn.text, null, 'error', e.message);
    } catch (e) {
      turn.error = 'เกิดข้อผิดพลาด: $e';
      await _log(provider, turn.text, null, 'error', '$e');
    }
    turn.busy = false;
  }

  /// บันทึกรายการที่เลือก คืนจำนวนที่บันทึก (ถ้าบางรายการพังจะใส่ turn.error)
  Future<int> apply(Turn turn) async {
    final r = turn.result!;
    final chosen = r.actions.where((a) => a.selected && a.valid).toList()
      ..sort((a, b) => (a.type == 'new_metric' ? 0 : 1).compareTo(b.type == 'new_metric' ? 0 : 1));
    final failures = <String>[];
    for (final a in chosen) {
      try {
        await a.run!(state);
      } catch (e) {
        failures.add('${a.summary}: $e');
      }
    }
    final p = await provider();
    if (p != null) {
      await _log(p, turn.text, {'actions': [for (final a in chosen) a.summary], 'raw': r.raw},
          failures.isEmpty ? 'applied' : 'error', failures.isEmpty ? null : failures.join('\n'));
    }
    turn.busy = false;
    turn.applied = failures.isEmpty;
    if (failures.isNotEmpty) turn.error = 'บางรายการบันทึกไม่สำเร็จ:\n${failures.join('\n')}';
    return chosen.length;
  }

  Future<void> _log(LlmProvider p, String input, Object? output, String status, [String? error]) async {
    try {
      await state.repo.logAi(provider: p.kind.id, model: p.model, input: input, output: output, status: status, error: error);
    } catch (_) {
      // log ไม่สำเร็จไม่ควรขวางการบันทึก
    }
  }
}


class TurnView extends StatelessWidget {
  const TurnView({super.key, required this.turn, required this.state, required this.onApply, required this.onChanged});
  final Turn turn;
  final AppState state;
  final VoidCallback onApply, onChanged;

  @override
  Widget build(BuildContext context) {
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
          child: Text(turn.text, style: TextStyle(color: scheme.onPrimaryContainer)),
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
              for (final a in r.actions) _ActionTile(action: a, state: state, locked: turn.applied || turn.busy, onChanged: onChanged),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.state, required this.locked, required this.onChanged});
  final ProposedAction action;
  final AppState state;
  final bool locked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = action;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(
          value: a.valid && a.selected,
          onChanged: !a.valid || locked
              ? null
              : (v) {
                  a.selected = v ?? false;
                  onChanged();
                },
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
              final saved = await openEditor(context, state, entry: a.entry, draft: true);
              if (saved) {
                a.selected = false;
                onChanged();
              }
            },
          ),
      ]),
    );
  }
}
