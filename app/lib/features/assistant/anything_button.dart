import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assistant_page.dart';
import 'turn_view_model.dart';
import 'voice_view_model.dart';

/// กล่องพิมพ์หน้าแรกแบบแอป AI: พิมพ์แล้วกดส่ง หรือกดไมค์ (ตอนช่องว่าง) เพื่อพูด → กดส่งอีกครั้ง
/// → ผลขึ้นเป็น bottom sheet ให้ยืนยัน (ปุ่ม "ยกเลิก" ระหว่างฟังเพื่อทิ้ง)
///
/// ใช้ระบบรู้จำเสียง "ในเครื่อง" เท่านั้น (onDevice) เพื่อไม่ส่งเสียงไปบริการภายนอก
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
    if (await _vm.start(0) == VoiceStart.needsSetup) await ensureLlmProvider(nav, ref);
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
      showDragHandle: true,
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
              children: v.listening ? _listeningContent(context, v.words) : _inputContent(context),
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

  List<Widget> _listeningContent(BuildContext context, String words) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return [
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 144),
        // reverse: พูดยาวแล้วยังเห็นคำล่าสุดเสมอ
        child: SingleChildScrollView(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Text(
            words.isEmpty ? 'กำลังฟัง… พูดได้เลย' : words,
            style: theme.textTheme.bodyLarge?.copyWith(color: words.isEmpty ? scheme.onSurfaceVariant : null),
          ),
        ),
      ),
      Row(children: [
        IconButton(icon: const Icon(Icons.close), tooltip: 'ยกเลิก', onPressed: _vm.discard),
        const SizedBox(width: 4),
        Icon(Icons.graphic_eq, size: 20, color: scheme.error),
        const SizedBox(width: 6),
        Expanded(child: Text('กำลังฟัง', style: theme.textTheme.bodySmall)),
        _primaryButton(context, icon: Icons.arrow_upward, tooltip: 'หยุดและส่ง', onPressed: _end),
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
    final navigator = Navigator.of(context);
    final vm = ref.read(turnViewModelProvider(text).notifier);
    final n = await vm.apply();
    if (ref.read(turnViewModelProvider(text)).applied) {
      messenger.showSnackBar(SnackBar(content: Text('บันทึกแล้ว $n รายการ')));
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: TurnView(text: text, onApply: () => _apply(context, ref)),
        ),
      ),
    );
  }
}
