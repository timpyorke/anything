import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assistant_page.dart';
import 'turn_view_model.dart';
import 'voice_view_model.dart';

/// กล่องพิมพ์หน้าแรกแบบแอป AI: พิมพ์แล้วกดส่ง หรือกดไมค์ (ตอนช่องว่าง) เพื่อพูด → กดส่งอีกครั้ง
/// → ผลขึ้นเป็น bottom sheet ให้ยืนยัน (ปุ่ม "ยกเลิก" ระหว่างอัด/ถอดเสียงเพื่อทิ้ง)
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

  @override
  void initState() {
    super.initState();
    // อ่านตั้งแต่ตอนนี้ เพราะใช้ ref ใน dispose ไม่ได้
    _vm = ref.read(voiceViewModelProvider.notifier);
  }

  Future<void> _submitText() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final nav = Navigator.of(context), messenger = ScaffoldMessenger.of(context);
    _text.clear();
    _focus.unfocus();
    await _ask(text, nav, messenger);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _startVoice() async {
    _focus.unfocus();
    final nav = Navigator.of(context);
    switch (await _vm.start()) {
      case VoiceStart.needsSetup:
        await ensureLlmProvider(nav, ref);
      case VoiceStart.needsVoiceModel:
        await offerVoiceModelSetup(nav);
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
    final provider = await ensureLlmProvider(nav, ref);
    if (provider == null) return;
    await showModalBottomSheet<void>(
      // ignore: use_build_context_synchronously (context ของ Navigator อยู่ตลอดอายุแอป)
      context: nav.context,
      isScrollControlled: true,
      // ปัดลงปิด sheet ได้โดยข้าม PopScope จึงปิดการลากไว้ (กันปิดพลาดตอน AI คิดอยู่)
      enableDrag: false,
      builder: (_) => _ResultSheet(text: text, messenger: messenger),
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
    final v = ref.watch(voiceViewModelProvider);
    final scheme = Theme.of(context).colorScheme;
    // TextFieldTapRegion: แตะปุ่มในกล่องไม่นับเป็น "แตะข้างนอก" คีย์บอร์ดจึงไม่หุบ
    return TextFieldTapRegion(
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width - 32,
        child: Material(
          elevation: 3,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: v.listening
                  ? _listeningContent(context, v.seconds)
                  : v.transcribing
                      ? _transcribingContent(context)
                      : _inputContent(context),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _inputContent(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return [
      TextField(
        controller: _text,
        focusNode: _focus,
        minLines: 1,
        maxLines: 5,
        style: style,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        onTapOutside: (_) => _focus.unfocus(),
        decoration: InputDecoration(
          hintText: 'พิมพ์เล่าอะไรก็ได้…',
          hintStyle: style?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          // ปิดพื้นและเส้นขอบจากธีม ให้ช่องพิมพ์กลืนไปกับกล่อง
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        ),
      ),
      Row(children: [
        IconButton(
          icon: const Icon(Icons.photo_camera_outlined),
          tooltip: 'กล้อง',
          onPressed: () => _toast('ฟีเจอร์กล้องกำลังมาเร็วๆ นี้'),
        ),
        const Spacer(),
        ValueListenableBuilder(
          valueListenable: _text,
          builder: (context, value, _) => value.text.trim().isEmpty
              ? _primaryButton(context, icon: Icons.mic, tooltip: 'พูด', onPressed: _startVoice)
              : _primaryButton(context, icon: Icons.arrow_upward, tooltip: 'ส่ง', onPressed: _submitText),
        ),
      ]),
    ];
  }

  List<Widget> _listeningContent(BuildContext context, int seconds) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final left = maxVoiceSeconds - seconds;
    final color = left <= 5 ? scheme.error : scheme.onSurface; // 5 วินาทีสุดท้ายเตือนด้วยสีแดง
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('กำลังอัดเสียง… พูดได้เลย', style: theme.textTheme.bodyLarge),
              Text(
                'เหลือ $left วินาที · ครบแล้วส่งให้เอง',
                style: theme.textTheme.bodySmall?.copyWith(color: left <= 5 ? scheme.error : null),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          _countdownRing(context, seconds: seconds, color: color),
        ]),
      ),
      Row(children: [
        IconButton(icon: const Icon(Icons.close), tooltip: 'ยกเลิก', onPressed: _vm.discard),
        const Spacer(),
        _primaryButton(context, icon: Icons.arrow_upward, tooltip: 'หยุดและส่ง', onPressed: _end),
      ]),
    ];
  }

  /// วงนับถอยหลัง: ตัวเลขคือวินาทีที่เหลือ วงค่อยๆ หมดไปจนครบเวลา
  Widget _countdownRing(BuildContext context, {required int seconds, required Color color}) {
    final theme = Theme.of(context);
    final left = maxVoiceSeconds - seconds;
    return SizedBox.square(
      dimension: 48,
      child: Stack(fit: StackFit.expand, children: [
        // ตัวจับเวลาเดินทีละวินาที จึงไล่ค่าไปถึงวินาทีถัดไปให้วงเคลื่อนต่อเนื่อง
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: ((left - 1) / maxVoiceSeconds).clamp(0, 1)),
          duration: const Duration(seconds: 1),
          builder: (context, remaining, _) => CircularProgressIndicator(
            value: remaining,
            strokeWidth: 4,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        Center(child: Text('$left', style: theme.textTheme.titleMedium?.copyWith(color: color))),
      ]),
    );
  }

  List<Widget> _transcribingContent(BuildContext context) {
    final theme = Theme.of(context);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'กำลังถอดเสียงในเครื่อง…',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ]),
      ),
      Row(children: [
        IconButton(icon: const Icon(Icons.close), tooltip: 'ยกเลิก', onPressed: _vm.discard),
      ]),
    ];
  }

  Widget _primaryButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
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
  const _ResultSheet({required this.text, required this.messenger});
  final String text;
  final ScaffoldMessengerState messenger;

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context), route = ModalRoute.of(context);
    final result = await ref.read(turnViewModelProvider(text).notifier).apply();
    // ผู้ใช้อาจปิด sheet ไปแล้วระหว่างบันทึก: ห้าม pop ซ้ำ และต้องแจ้ง error ทาง snackbar แทน
    final open = route?.isCurrent ?? false;
    if (result.error == null) {
      messenger.showSnackBar(SnackBar(content: Text('บันทึกแล้ว ${result.count} รายการ')));
      if (open) navigator.pop();
    } else if (!open) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thinking = ref.watch(turnViewModelProvider(text).select((t) => t.thinking));
    // ระหว่าง AI คิด แตะข้างนอก/กดย้อนกลับไม่ปิด ต้องกด "ยกเลิก"
    return PopScope(
      canPop: !thinking,
      // ดัน sheet ขึ้นเหนือคีย์บอร์ดตอนพิมพ์ตอบ
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
            child: SingleChildScrollView(
              reverse: true, // เห็นข้อความล่าสุดและช่องตอบเสมอ
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: TurnView(text: text, onApply: () => _apply(context, ref)),
            ),
          ),
        ),
      ),
    );
  }
}
