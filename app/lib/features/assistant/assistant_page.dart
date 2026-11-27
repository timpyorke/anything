import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_settings.dart';
import '../../ai/llm_provider.dart';
import '../../ai/on_device_provider.dart';
import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/notice_box.dart';
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
  final t = ref.read(stringsProvider);
  final p = await settings.resolveProvider();
  if (p != null) return p;
  await _offerSettings(
    nav,
    t,
    title: t.aiNotSetUp,
    message: kind.isCloud ? t.needApiKey(kind.label) : t.needLocalModel(OnDeviceProvider.sizeLabel),
    page: kind.isCloud ? const AiSettingsPage() : const LocalModelPage(),
  );
  return null;
}

/// การพูดต้องมี Gemma ในเครื่องเสมอ แม้จะเลือก AI ตัวอื่นไว้บันทึก
Future<void> offerVoiceModelSetup(NavigatorState nav, AppStrings t) => _offerSettings(
      nav,
      t,
      title: t.noVoiceModel,
      message: t.needVoiceModel(OnDeviceProvider.sizeLabel),
      page: const LocalModelPage(),
    );

Future<void> _offerSettings(NavigatorState nav, AppStrings t, {required String title, required String message, required Widget page}) async {
  final setUp = await confirmAction(
    // ignore: use_build_context_synchronously (context ของ Navigator อยู่ตลอดอายุแอป)
    nav.context,
    title: title,
    message: message,
    cancelLabel: t.later,
    confirmLabel: t.goToSettings,
    destructive: false,
  );
  if (setUp) {
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
    final t = ref.watch(stringsProvider);
    final turn = ref.watch(turnViewModelProvider(request));
    final vm = ref.read(turnViewModelProvider(request).notifier);
    final photos = [for (final b in turn.photos) Photo(bytes: b)];
    final scheme = Theme.of(context).colorScheme;
    final r = turn.result;
    final selectable = r?.actions.where((a) => a.valid).toList() ?? const <ProposedAction>[];
    final theme = Theme.of(context);
    final chosen = selectable.where((a) => a.selected).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // รูปแนบมากับข้อความแรก
      if (photos.isNotEmpty)
        Align(
          alignment: Alignment.centerRight,
          child: Padding(padding: const EdgeInsets.only(left: 48, bottom: 8), child: PhotoStrip(photos, size: 80)),
        ),
      for (final h in turn.history) ...[
        if (h.message.isNotEmpty) _UserBubble(h.message),
        if (h.result != null) _Reply(h.result!),
      ],
      if (turn.text.isNotEmpty) _UserBubble(turn.text),
      if (turn.thinking)
        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [
          const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text(t.aiThinking)),
          // ปิด sheet = provider ถูกทิ้ง ซึ่งยกเลิกคำขอ AI
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        ])),
      if (turn.error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NoticeBox(
            turn.error!,
            // ยังไม่ได้คำตอบเลย: ส่งข้อความเดิมซ้ำได้โดยไม่ต้องพิมพ์ใหม่
            action: r == null && !turn.busy ? TextButton(onPressed: vm.retry, child: Text(t.retry)) : null,
          ),
        ),
      if (r != null) ...[
        _Reply(r),
        // บอกตรงๆ เพราะโมเดลอาจตอบเหมือนบันทึกแล้วทั้งที่ไม่ได้เสนออะไร
        if (r.actions.isEmpty && r.questions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(t.nothingSaved, style: theme.textTheme.bodySmall),
          ),
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
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              t.unattachedPhotos(turn.unattachedPhotos),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
        if (selectable.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: turn.applied
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_rounded, color: scheme.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(t.saved),
                  ])
                : FilledButton.icon(
                    onPressed: turn.busy || chosen == 0 ? null : onApply,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(t.saveCount(chosen)),
                  ),
          ),
      ],
      if (!turn.busy && !turn.applied)
        _AnswerBox(
            hint: r?.questions.isNotEmpty ?? false ? t.answerHint : t.followUpHint, sendLabel: t.send, onSend: vm.answer),
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
        margin: const EdgeInsets.only(left: 48, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: const BorderRadius.all(Radius.circular(18)).copyWith(bottomRight: const Radius.circular(4)),
        ),
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
    if (result.reply.isEmpty && result.questions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 32, bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (result.reply.isNotEmpty) Text(result.reply),
        for (final q in result.questions)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Corners.control),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.help_outline_rounded, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(q)),
            ]),
          ),
      ]),
    );
  }
}

/// ช่องตอบ AI ต่อในเรื่องเดิม
class _AnswerBox extends StatefulWidget {
  const _AnswerBox({required this.hint, required this.sendLabel, required this.onSend});
  final String hint, sendLabel;
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
          suffixIcon: IconButton(icon: const Icon(Icons.arrow_upward_rounded), tooltip: widget.sendLabel, onPressed: _send),
        ),
      );
}

/// รายการที่ AI เสนอ 1 ข้อ: แตะทั้งการ์ดเพื่อเลือก/ไม่เลือก
class _ActionTile extends ConsumerWidget {
  const _ActionTile({required this.action, required this.photos, required this.locked, required this.vm, required this.index});
  final ProposedAction action;
  final List<Photo> photos;
  final bool locked;
  final TurnViewModel vm;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = action;
    final checked = a.valid && a.selected;
    final canToggle = a.valid && !locked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.card),
          side: BorderSide(
            color: !a.valid ? scheme.error : checked ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: canToggle ? () => vm.toggle(index, !a.selected) : null,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(value: checked, onChanged: canToggle ? (v) => vm.toggle(index, v ?? false) : null),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 4, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.summary, style: theme.textTheme.titleSmall?.copyWith(color: a.valid ? null : scheme.onSurfaceVariant)),
                  if (a.detail.isNotEmpty)
                    Text(a.detail, style: theme.textTheme.bodySmall, maxLines: 6, overflow: TextOverflow.ellipsis),
                  if (photos.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8), child: PhotoStrip(photos, size: 44)),
                  for (final err in a.errors)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('⚠ $err', style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
                    ),
                ]),
              ),
            ),
            if (a.entry != null && !locked)
              IconButton(
                tooltip: t.editBeforeSaving,
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () async {
                  final saved = await openEditor(context, entry: a.entry, draft: true);
                  if (saved) vm.markSaved(index);
                },
              ),
          ]),
        ),
      ),
    );
  }
}
