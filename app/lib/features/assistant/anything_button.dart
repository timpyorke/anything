import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assistant_page.dart';
import 'turn_view_model.dart';
import 'voice_view_model.dart';

/// ปุ่มหน้าแรก: แตะแถบเพื่อพิมพ์ / แตะปุ่มไมค์เพื่อเริ่มพูด → แตะอีกครั้งเพื่อส่งให้ AI
/// → ผลขึ้นเป็น bottom sheet ให้ยืนยัน (ปุ่ม "ยกเลิก" ระหว่างฟังเพื่อทิ้ง)
///
/// ใช้ระบบรู้จำเสียง "ในเครื่อง" เท่านั้น (onDevice) เพื่อไม่ส่งเสียงไปบริการภายนอก
class AnythingButton extends ConsumerStatefulWidget {
  const AnythingButton({super.key});

  @override
  ConsumerState<AnythingButton> createState() => _AnythingButtonState();
}

class _AnythingButtonState extends ConsumerState<AnythingButton> {
  bool _typing = false;
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final _vm = ref.read(voiceViewModelProvider.notifier);

  void _openTyping() {
    setState(() => _typing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _closeTyping() {
    _focus.unfocus();
    setState(() => _typing = false);
  }

  Future<void> _submitText() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final nav = Navigator.of(context), messenger = ScaffoldMessenger.of(context);
    _text.clear();
    _closeTyping();
    await _ask(text, nav, messenger);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleVoice() async {
    if (ref.read(voiceViewModelProvider).listening) return _end();
    final nav = Navigator.of(context);
    if (await _vm.start(0) == VoiceStart.needsSetup) await ensureLlmProvider(nav, ref);
  }

  Future<void> _cancelVoice() async {
    _vm.discard();
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
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (v.listening)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 40),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    v.words.isEmpty ? 'กำลังฟัง… พูดได้เลย' : v.words,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: v.words.isEmpty ? scheme.onSurfaceVariant : null,
                        ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text('แตะไมค์อีกครั้งเพื่อส่ง', style: Theme.of(context).textTheme.bodySmall)),
                    TextButton(onPressed: _cancelVoice, child: const Text('ยกเลิก')),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      if (_typing)
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32),
          child: Material(
            elevation: 3,
            color: scheme.surfaceContainerHigh,
            shape: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 4, 4),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitText(),
                    decoration: const InputDecoration(
                      hintText: 'พิมพ์เล่าอะไรก็ได้…',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), tooltip: 'ปิด', onPressed: _closeTyping),
                IconButton.filled(icon: const Icon(Icons.arrow_upward), tooltip: 'ส่ง', onPressed: _submitText),
              ]),
            ),
          ),
        )
      else
        Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 68), // เว้นซ้ายเท่าปุ่มกล้อง+ช่องว่าง เพื่อให้ปุ่มกลางอยู่กลางจอจริง
          FloatingActionButton.extended(
            heroTag: 'voice_capture',
            onPressed: v.listening ? null : _openTyping,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('พิมพ์เล่าอะไรก็ได้'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'mic_capture',
            shape: const CircleBorder(),
            tooltip: v.listening ? 'หยุดและส่ง' : 'พูด',
            backgroundColor: v.listening ? scheme.error : null,
            foregroundColor: v.listening ? scheme.onError : null,
            onPressed: _toggleVoice,
            child: Icon(v.listening ? Icons.stop : Icons.mic),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'camera_capture',
            shape: const CircleBorder(),
            tooltip: 'กล้อง',
            onPressed: () => _toast('ฟีเจอร์กล้องกำลังมาเร็วๆ นี้'),
            child: const Icon(Icons.photo_camera_outlined),
          ),
        ]),
    ]);
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
