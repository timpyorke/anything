import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../ai/ai_settings.dart';
import 'assistant_page.dart';
import 'turn_view_model.dart';

/// ปุ่มหน้าแรก: กดค้างแล้วพูด → ปล่อยเพื่อส่งให้ AI → ผลขึ้นเป็น bottom sheet ให้ยืนยัน
/// เลื่อนนิ้วขึ้นก่อนปล่อยเพื่อยกเลิก
///
/// ใช้ระบบรู้จำเสียง "ในเครื่อง" เท่านั้น (onDevice) เพื่อไม่ส่งเสียงไปบริการภายนอก
class AnythingButton extends ConsumerStatefulWidget {
  const AnythingButton({super.key});

  @override
  ConsumerState<AnythingButton> createState() => _AnythingButtonState();
}

class _AnythingButtonState extends ConsumerState<AnythingButton> {
  static const _cancelDistance = 90.0;

  final _speech = SpeechToText();
  bool _ready = false, _pressing = false, _listening = false, _cancel = false;
  String _words = '';
  String? _speechError;
  double _startY = 0;
  bool _typing = false;
  final _text = TextEditingController();
  final _focus = FocusNode();

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
    _text.clear();
    _closeTyping();
    await _ask(text);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _start(LongPressStartDetails d) async {
    _pressing = true;
    _startY = d.globalPosition.dy;
    HapticFeedback.mediumImpact();
    // ยังไม่ตั้งค่า AI → ถามก่อน อย่าให้ผู้ใช้พูดเสียเปล่า
    if (await ref.read(aiSettingsProvider.notifier).resolveProvider() == null) {
      _pressing = false;
      if (mounted) await ensureLlmProvider(context, ref);
      return;
    }
    if (!_ready) {
      try {
        _ready = await _speech.initialize(onError: (e) => _speechError = e.errorMsg);
      } on MissingPluginException {
        // ปลั๊กอิน native ยังไม่ถูก build รวมเข้าแอป (ต้องรัน build ใหม่ทั้งหมด)
        _ready = false;
      }
    }
    if (!mounted) return;
    if (!_ready) {
      _pressing = false;
      _toast('ใช้ไมโครโฟน/รู้จำเสียงไม่ได้ ตรวจสิทธิ์ในการตั้งค่าเครื่อง');
      return;
    }
    if (!_pressing) return; // ปล่อยนิ้วไปก่อนเริ่มฟังพร้อม
    _speechError = null;
    setState(() {
      _listening = true;
      _cancel = false;
      _words = '';
    });
    await _speech.listen(
      onResult: (r) {
        if (mounted) setState(() => _words = r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        localeId: 'th_TH',
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 30),
        onDevice: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _move(LongPressMoveUpdateDetails d) {
    if (!_listening) return;
    final cancel = _startY - d.globalPosition.dy > _cancelDistance;
    if (cancel != _cancel) {
      HapticFeedback.selectionClick();
      setState(() => _cancel = cancel);
    }
  }

  Future<void> _end() async {
    _pressing = false;
    if (!_listening) return;
    await _speech.stop();
    await Future<void>.delayed(const Duration(milliseconds: 350)); // รอผลสุดท้ายของคำสุดท้าย
    if (!mounted) return;
    final text = _words.trim(), cancelled = _cancel;
    setState(() => _listening = false);
    if (cancelled) return;
    if (text.isEmpty) {
      _toast(_speechError == null
          ? 'ไม่ได้ยินเสียง กดค้างแล้วพูดใหม่ได้เลย'
          : 'รู้จำเสียงในเครื่องไม่ได้ ($_speechError) — ตรวจว่าติดตั้งภาษาไทยสำหรับพิมพ์/สั่งงานด้วยเสียงแล้ว');
      return;
    }
    await _ask(text);
  }

  Future<void> _ask(String text) async {
    final provider = await ensureLlmProvider(context, ref);
    if (provider == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ResultSheet(text: text, messenger: messenger),
    );
  }

  @override
  void dispose() {
    _speech.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (_listening)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 40),
            child: Card(
              margin: EdgeInsets.zero,
              color: _cancel ? scheme.errorContainer : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _words.isEmpty ? 'กำลังฟัง… พูดได้เลย' : _words,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _words.isEmpty ? scheme.onSurfaceVariant : null,
                        ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _cancel ? 'ปล่อยเพื่อยกเลิก' : 'ปล่อยเพื่อส่ง · เลื่อนขึ้นเพื่อยกเลิก',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _cancel ? scheme.error : null),
                  ),
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
          const SizedBox(width: 68), // เว้นซ้ายเท่าปุ่มกล้อง+ช่องว่าง เพื่อให้ปุ่มคุยอยู่กลางจอจริง
          GestureDetector(
            onLongPressStart: _start,
            onLongPressMoveUpdate: _move,
            onLongPressEnd: (_) => _end(),
            onLongPressCancel: _end,
            child: FloatingActionButton.extended(
              heroTag: 'voice_capture',
              onPressed: _openTyping,
              icon: Icon(_listening ? Icons.mic : Icons.edit_outlined),
              label: Text(_listening ? 'กำลังฟัง…' : 'พิมพ์ หรือกดค้างเพื่อคุย'),
            ),
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
    final vm = ref.read(turnViewModelProvider(text).notifier);
    final n = await vm.apply();
    if (ref.read(turnViewModelProvider(text)).applied) {
      messenger.showSnackBar(SnackBar(content: Text('บันทึกแล้ว $n รายการ')));
      if (context.mounted) Navigator.pop(context);
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
