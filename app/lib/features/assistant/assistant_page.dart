import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_settings.dart';
import '../../ai/llm_provider.dart';
import '../../ai/on_device_provider.dart';
import '../../domain/photo.dart';
import '../entry_editor/entry_editor_page.dart';
import '../photos/photo_widgets.dart';
import '../settings/ai_settings_page.dart';
import '../settings/local_model_page.dart';
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
  await _offerSettings(
    nav,
    title: 'ยังไม่ได้ตั้งค่า AI',
    message: kind.isCloud
        ? 'ใส่ API key ของ ${kind.label} ในหน้าตั้งค่าก่อน'
        : 'ดาวน์โหลดโมเดล Gemma (${OnDeviceProvider.sizeLabel}) ในหน้าตั้งค่าก่อน',
    page: kind.isCloud ? const AiSettingsPage() : const LocalModelPage(),
  );
  return null;
}

/// การพูดต้องมี Gemma ในเครื่องเสมอ แม้จะเลือก AI ตัวอื่นไว้บันทึก
Future<void> offerVoiceModelSetup(NavigatorState nav) => _offerSettings(
      nav,
      title: 'ยังไม่มีโมเดลฟังเสียง',
      message: 'ดาวน์โหลดโมเดล Gemma (${OnDeviceProvider.sizeLabel}) ในหน้าตั้งค่าก่อน '
          'เสียงจะถูกถอดเป็นข้อความในเครื่อง',
      page: const LocalModelPage(),
    );

Future<void> _offerSettings(NavigatorState nav, {required String title, required String message, required Widget page}) async {
  final setUp = await showDialog<bool>(
    // ignore: use_build_context_synchronously (context ของ Navigator อยู่ตลอดอายุแอป)
    context: nav.context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ไว้ก่อน')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ไปตั้งค่า')),
      ],
    ),
  );
  if (setUp == true) {
    // ไปหน้าย่อยที่ต้องตั้งค่าเลย กดกลับแล้วเจอหน้าตั้งค่า
    nav.push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
    await nav.push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class TurnView extends ConsumerWidget {
  const TurnView({super.key, required this.request, required this.onApply});
  final TurnRequest request;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turn = ref.watch(turnViewModelProvider(request));
    final vm = ref.read(turnViewModelProvider(request).notifier);
    final photos = [for (final b in turn.photos) Photo(bytes: b)];
    final scheme = Theme.of(context).colorScheme;
    final r = turn.result;
    final selectable = r?.actions.where((a) => a.valid).toList() ?? const <ProposedAction>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // รูปแนบมากับข้อความแรก
      if (photos.isNotEmpty)
        Align(
          alignment: Alignment.centerRight,
          child: Padding(padding: const EdgeInsets.only(left: 48, bottom: 8), child: PhotoStrip(photos, size: 80)),
        ),
      for (final h in turn.history) ...[
        if (h.message.isNotEmpty) _UserBubble(h.message),
        if (h.result != null)
          Card(
            margin: const EdgeInsets.only(right: 24, bottom: 8),
            child: Padding(padding: const EdgeInsets.all(12), child: _Reply(h.result!)),
          ),
      ],
      if (turn.text.isNotEmpty) _UserBubble(turn.text),
      if (turn.thinking)
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          const Expanded(child: Text('AI กำลังคิด…')),
          // ปิด sheet = provider ถูกทิ้ง ซึ่งยกเลิกคำขอ AI
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
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
              _Reply(r),
              // บอกตรงๆ เพราะโมเดลอาจตอบเหมือนบันทึกแล้วทั้งที่ไม่ได้เสนออะไร
              if (r.actions.isEmpty && r.questions.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('ยังไม่มีอะไรถูกบันทึก', style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
              if (r.actions.isNotEmpty) const Divider(height: 20),
              for (final (i, a) in r.actions.indexed)
                _ActionTile(
                  action: a,
                  photos: [for (final p in a.photos) photos[p]],
                  locked: turn.applied || turn.busy,
                  vm: vm,
                  index: i,
                ),
              if (!turn.applied && r.actions.isNotEmpty && turn.unattachedPhotos > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'รูป ${turn.unattachedPhotos} รูปไม่ได้แนบกับรายการที่เลือก จะไม่ถูกเก็บ',
                    style: TextStyle(fontSize: 13, color: scheme.error),
                  ),
                ),
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
      if (!turn.busy && !turn.applied)
        _AnswerBox(hint: r?.questions.isNotEmpty ?? false ? 'ตอบคำถาม…' : 'บอกเพิ่มหรือแก้…', onSend: vm.answer),
    ]);
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 48, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
        child: Text(text, style: TextStyle(color: scheme.onPrimaryContainer)),
      ),
    );
  }
}

/// คำตอบและคำถามของ AI
class _Reply extends StatelessWidget {
  const _Reply(this.result);
  final AiResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (result.reply.isNotEmpty) Text(result.reply),
      for (final q in result.questions)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.help_outline, size: 18, color: scheme.tertiary),
            const SizedBox(width: 6),
            Expanded(child: Text(q, style: TextStyle(color: scheme.tertiary))),
          ]),
        ),
    ]);
  }
}

/// ช่องตอบ AI ต่อในเรื่องเดิม
class _AnswerBox extends StatefulWidget {
  const _AnswerBox({required this.hint, required this.onSend});
  final String hint;
  final ValueChanged<String> onSend;

  @override
  State<_AnswerBox> createState() => _AnswerBoxState();
}

class _AnswerBoxState extends State<_AnswerBox> {
  final _text = TextEditingController();

  void _send() {
    if (_text.text.trim().isNotEmpty) widget.onSend(_text.text);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _text,
        minLines: 1,
        maxLines: 4,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _send(),
        decoration: InputDecoration(
          hintText: widget.hint,
          suffixIcon: IconButton(icon: const Icon(Icons.arrow_upward), tooltip: 'ส่ง', onPressed: _send),
        ),
      );
}

class _ActionTile extends ConsumerWidget {
  const _ActionTile({required this.action, required this.photos, required this.locked, required this.vm, required this.index});
  final ProposedAction action;
  final List<Photo> photos;
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
              if (photos.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: PhotoStrip(photos, size: 44)),
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
              if (saved) vm.markSaved(index);
            },
          ),
      ]),
    );
  }
}
