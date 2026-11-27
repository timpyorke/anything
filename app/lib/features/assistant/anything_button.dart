import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/llm_provider.dart';
import '../../app/language.dart';
import '../../core/l10n/app_strings.dart';
import '../../data/photo_picker.dart';
import '../../domain/photo.dart';
import '../photos/photo_widgets.dart';
import 'assistant_page.dart';
import 'photo_draft_view_model.dart';
import 'turn_view_model.dart';
import 'voice_view_model.dart';

/// กล่องพิมพ์หน้าแรกแบบแอป AI: พิมพ์แล้วกดส่ง หรือกดไมค์ (ตอนช่องว่าง) เพื่อพูด → กดส่งอีกครั้ง
/// แนบรูปจากกล้องหรือคลังรูปส่งไปพร้อมกันได้ → ผลขึ้นเป็น bottom sheet ให้ยืนยัน (ปุ่ม "ยกเลิก" ระหว่างอัด/ถอดเสียงเพื่อทิ้ง)
///
/// เสียงถูกถอดเป็นข้อความด้วย Gemma ในเครื่อง ไม่ส่งเสียงไปบริการภายนอก
class AnythingButton extends ConsumerStatefulWidget {
  const AnythingButton({super.key});

  @override
  ConsumerState<AnythingButton> createState() => _AnythingButtonState();
}

class _AnythingButtonState extends ConsumerState<AnythingButton> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final VoiceViewModel _vm;
  late final PhotoDraftViewModel _photos;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // อ่านตั้งแต่ตอนนี้ เพราะใช้ ref ใน dispose ไม่ได้
    _vm = ref.read(voiceViewModelProvider.notifier);
    _photos = ref.read(photoDraftViewModelProvider.notifier);
    // เลื่อนไปหลัง build แรก (ห้ามแก้ provider ระหว่างสร้าง widget)
    Future.microtask(_photos.restoreLost);
  }

  Future<void> _submitText() async {
    final text = _text.text.trim();
    if (text.isEmpty && ref.read(photoDraftViewModelProvider).photos.isEmpty) return;
    final nav = Navigator.of(context), messenger = ScaffoldMessenger.of(context);
    _focus.unfocus();
    await _ask(text, nav, messenger);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addPhotos(PhotoSource source) async {
    _focus.unfocus();
    await _photos.add(source);
  }

  Future<void> _startVoice() async {
    _focus.unfocus();
    final nav = Navigator.of(context);
    switch (await _vm.start()) {
      case VoiceStart.needsSetup:
        await ensureLlmProvider(nav, ref);
      case VoiceStart.needsVoiceModel:
        await offerVoiceModelSetup(nav, ref.read(stringsProvider));
      case VoiceStart.started || VoiceStart.unavailable || VoiceStart.released:
        break;
    }
  }

  Future<void> _end() async {
    final nav = Navigator.of(context), messenger = ScaffoldMessenger.of(context);
    final text = await _vm.finish();
    if (text != null) await _ask(text, nav, messenger);
  }

  Future<void> _ask(String text, NavigatorState nav, ScaffoldMessengerState messenger) async {
    if (_sending) return; // แตะส่งซ้ำระหว่างตรวจการตั้งค่า
    _sending = true;
    final LlmProvider? provider;
    try {
      provider = await ensureLlmProvider(nav, ref);
    } finally {
      _sending = false;
    }
    // ยังไม่ตั้งค่า AI → ข้อความและรูปยังอยู่ในกล่องให้ส่งใหม่ได้
    if (provider == null) return;
    _text.clear();
    final TurnRequest request = (text: text, photos: _photos.take());
    await showModalBottomSheet<void>(
      // ignore: use_build_context_synchronously (context ของ Navigator อยู่ตลอดอายุแอป)
      context: nav.context,
      isScrollControlled: true,
      // ปัดลงปิด sheet ได้โดยข้าม PopScope จึงปิดการลากไว้ (กันปิดพลาดตอน AI คิดอยู่)
      enableDrag: false,
      builder: (_) => _ResultSheet(request: request, messenger: messenger),
    );
  }

  @override
  void dispose() {
    _vm.abort();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(voiceViewModelProvider.select((v) => v.notice), (_, notice) {
      if (notice != null) _toast(notice);
    });
    // อัดครบความยาวสูงสุดแล้ว → หยุดและส่งให้เลย
    ref.listen(voiceViewModelProvider.select((v) => v.seconds >= maxVoiceSeconds), (_, full) {
      if (full) _end();
    });
    ref.listen(photoDraftViewModelProvider.select((p) => p.notice), (_, notice) {
      if (notice != null) _toast(notice);
    });
    final t = ref.watch(stringsProvider);
    final v = ref.watch(voiceViewModelProvider);
    final draft = ref.watch(photoDraftViewModelProvider);
    final scheme = Theme.of(context).colorScheme;
    // TextFieldTapRegion: แตะปุ่มในกล่องไม่นับเป็น "แตะข้างนอก" คีย์บอร์ดจึงไม่หุบ
    return TextFieldTapRegion(
      child: SizedBox(
        width: math.min(MediaQuery.sizeOf(context).width - 24, 640),
        child: Material(
          elevation: 3,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: v.listening
                ? _listeningContent(context, t, v.seconds)
                : v.transcribing
                    ? _transcribingContent(context, t)
                    : _inputContent(context, t, draft),
          ),
        ),
      ),
    );
  }

  /// ช่องว่าง = แถวเดียว (แนบรูป · ช่องพิมพ์ · พูด) กินที่น้อยสุด
  /// มีข้อความแล้ว = ช่องพิมพ์กว้างเต็มกล่อง ปุ่มย้ายลงแถวล่าง · รูปที่แนบขึ้นเป็นแถวด้านบน
  Widget _inputContent(BuildContext context, AppStrings t, PhotoDraftState draft) {
    final theme = Theme.of(context);
    final canPick = !draft.picking && draft.photos.length < maxPhotosPerMessage;
    final attach = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        icon: const Icon(Icons.photo_camera_outlined),
        tooltip: t.camera,
        color: theme.colorScheme.onSurfaceVariant,
        onPressed: canPick ? () => _addPhotos(PhotoSource.camera) : null,
      ),
      IconButton(
        icon: const Icon(Icons.photo_library_outlined),
        tooltip: t.gallery,
        color: theme.colorScheme.onSurfaceVariant,
        onPressed: canPick ? () => _addPhotos(PhotoSource.gallery) : null,
      ),
    ]);
    final field = TextField(
      controller: _text,
      focusNode: _focus,
      minLines: 1,
      maxLines: 5,
      style: theme.textTheme.bodyLarge,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      onTapOutside: (_) => _focus.unfocus(),
      decoration: InputDecoration(
        hintText: t.composerHint,
        hintMaxLines: 1,
        // ปิดพื้นและเส้นขอบจากธีม ให้ช่องพิมพ์กลืนไปกับกล่อง
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (draft.photos.isNotEmpty || draft.picking)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: Row(children: [
              Flexible(child: PhotoStrip([for (final b in draft.photos) Photo(bytes: b)], onRemove: _photos.remove)),
              if (draft.picking)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ]),
          ),
        ValueListenableBuilder(
          valueListenable: _text,
          builder: (context, value, _) {
            final empty = value.text.trim().isEmpty;
            final expanded = value.text.isNotEmpty;
            final send = _primaryButton(
                icon: Icons.arrow_upward_rounded, tooltip: t.send, onPressed: draft.picking ? null : _submitText);
            final Widget actions = !empty
                ? send
                : draft.photos.isEmpty
                    ? _primaryButton(icon: Icons.mic_rounded, tooltip: t.speak, onPressed: _startVoice)
                    // มีแต่รูป: ส่งได้เลย หรือจะพูดเล่าประกอบก็ได้
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.mic_rounded), tooltip: t.speak, onPressed: _startVoice),
                        send,
                      ]);
            // ช่องพิมพ์ต้องอยู่ตำแหน่งเดิมใน tree ทั้งสองแบบ ไม่งั้นจะเสียโฟกัสตอนพิมพ์ตัวแรก
            // ปุ่มสองข้างจึงห่อด้วย SizedBox เสมอ (ชนิด widget ในแถวไม่เปลี่ยน)
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                SizedBox(child: expanded ? null : attach),
                Expanded(child: field),
                SizedBox(child: expanded ? null : actions),
              ]),
              if (expanded) Row(children: [attach, const Spacer(), actions]),
            ]);
          },
        ),
      ],
    );
  }

  Widget _listeningContent(BuildContext context, AppStrings t, int seconds) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final left = maxVoiceSeconds - seconds;
    final color = left <= 5 ? scheme.error : scheme.onSurface; // 5 วินาทีสุดท้ายเตือนด้วยสีแดง
    return Row(children: [
      IconButton(icon: const Icon(Icons.close_rounded), tooltip: t.cancel, onPressed: _vm.discard),
      const SizedBox(width: 4),
      Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.recording, style: theme.textTheme.titleSmall),
          Text(
            t.recordingLeft(left),
            style: theme.textTheme.bodySmall?.copyWith(color: left <= 5 ? scheme.error : null),
          ),
        ]),
      ),
      const SizedBox(width: 8),
      _countdownRing(context, seconds: seconds, color: color),
      const SizedBox(width: 8),
      _primaryButton(icon: Icons.arrow_upward_rounded, tooltip: t.stopAndSend, onPressed: _end),
    ]);
  }

  /// วงนับถอยหลัง: ตัวเลขคือวินาทีที่เหลือ วงค่อยๆ หมดไปจนครบเวลา
  Widget _countdownRing(BuildContext context, {required int seconds, required Color color}) {
    final theme = Theme.of(context);
    final left = maxVoiceSeconds - seconds;
    return SizedBox.square(
      dimension: 40,
      child: Stack(fit: StackFit.expand, children: [
        // ตัวจับเวลาเดินทีละวินาที จึงไล่ค่าไปถึงวินาทีถัดไปให้วงเคลื่อนต่อเนื่อง
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: ((left - 1) / maxVoiceSeconds).clamp(0, 1)),
          duration: const Duration(seconds: 1),
          builder: (context, remaining, _) => CircularProgressIndicator(
            value: remaining,
            strokeWidth: 3,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        // ย่อแทนการล้นวงเมื่อผู้ใช้ขยายตัวอักษร
        Padding(
          padding: const EdgeInsets.all(7),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text('$left', style: theme.textTheme.titleSmall?.copyWith(color: color))),
        ),
      ]),
    );
  }

  Widget _transcribingContent(BuildContext context, AppStrings t) {
    final theme = Theme.of(context);
    return Row(children: [
      IconButton(icon: const Icon(Icons.close_rounded), tooltip: t.cancel, onPressed: _vm.discard),
      const SizedBox(width: 4),
      Expanded(child: Text(t.transcribing, style: theme.textTheme.titleSmall)),
      const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    ]);
  }

  Widget _primaryButton({required IconData icon, required String tooltip, required VoidCallback? onPressed}) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(backgroundColor: scheme.onSurface, foregroundColor: scheme.surface),
    );
  }
}

class _ResultSheet extends ConsumerWidget {
  const _ResultSheet({required this.request, required this.messenger});
  final TurnRequest request;
  final ScaffoldMessengerState messenger;

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context), route = ModalRoute.of(context);
    final t = ref.read(stringsProvider);
    final result = await ref.read(turnViewModelProvider(request).notifier).apply();
    // ผู้ใช้อาจปิด sheet ไปแล้วระหว่างบันทึก: ห้าม pop ซ้ำ และต้องแจ้ง error ทาง snackbar แทน
    final open = route?.isCurrent ?? false;
    if (result.error == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.savedCount(result.count))));
      if (open) navigator.pop();
    } else if (!open) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final thinking = ref.watch(turnViewModelProvider(request).select((turn) => turn.thinking));
    final theme = Theme.of(context);
    // ระหว่าง AI คิด แตะข้างนอก/กดย้อนกลับไม่ปิด ต้องกด "ยกเลิก"
    return PopScope(
      canPop: !thinking,
      // ดัน sheet ขึ้นเหนือคีย์บอร์ดตอนพิมพ์ตอบ
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                  child: Row(children: [
                    Icon(Icons.auto_awesome_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t.assistantTitle, style: theme.textTheme.titleMedium)),
                    // ระหว่างคิดมีปุ่ม "ยกเลิก" อยู่แล้ว ปุ่มปิดจึงโผล่หลังได้คำตอบ
                    Visibility.maintain(
                      visible: !thinking,
                      child: IconButton(
                        tooltip: t.close,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ]),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    reverse: true, // เห็นข้อความล่าสุดและช่องตอบเสมอ
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TurnView(request: request, onApply: () => _apply(context, ref)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
