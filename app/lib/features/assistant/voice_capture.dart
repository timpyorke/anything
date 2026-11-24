import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../ai/ai_settings.dart';
import '../../ai/llm_provider.dart';
import '../../state/app_state.dart';
import 'assistant_page.dart';

/// ปุ่มหน้าแรก: กดค้างแล้วพูด → ปล่อยเพื่อส่งให้ AI → ผลขึ้นเป็น bottom sheet ให้ยืนยัน
/// เลื่อนนิ้วขึ้นก่อนปล่อยเพื่อยกเลิก
///
/// ใช้ระบบรู้จำเสียง "ในเครื่อง" เท่านั้น (onDevice) เพื่อไม่ส่งเสียงไปบริการภายนอก
class VoiceCaptureButton extends StatefulWidget {
  const VoiceCaptureButton({super.key, required this.state, required this.ai});
  final AppState state;
  final AiSettings ai;

  @override
  State<VoiceCaptureButton> createState() => _VoiceCaptureButtonState();
}

class _VoiceCaptureButtonState extends State<VoiceCaptureButton> {
  static const _cancelDistance = 90.0;

  final _speech = SpeechToText();
  late final _runner = AssistantRunner(widget.state, widget.ai);
  bool _ready = false, _pressing = false, _listening = false, _cancel = false;
  String _words = '';
  String? _speechError;
  double _startY = 0;

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
    if (await _runner.provider() == null) {
      _pressing = false;
      if (mounted) await _runner.ensureProvider(context);
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
    final provider = await _runner.ensureProvider(context);
    if (provider == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ResultSheet(runner: _runner, provider: provider, turn: Turn(text), state: widget.state, messenger: messenger),
    );
  }

  @override
  void dispose() {
    _speech.cancel();
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
      Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 68), // เว้นซ้ายเท่าปุ่มกล้อง+ช่องว่าง เพื่อให้ปุ่มคุยอยู่กลางจอจริง
        GestureDetector(
          onLongPressStart: _start,
          onLongPressMoveUpdate: _move,
          onLongPressEnd: (_) => _end(),
          onLongPressCancel: _end,
          child: FloatingActionButton.extended(
            heroTag: 'voice_capture',
            onPressed: () => _toast('กดค้างที่ปุ่ม แล้วพูดได้เลย'),
            icon: Icon(_listening ? Icons.mic : Icons.auto_awesome),
            label: Text(_listening ? 'กำลังฟัง…' : 'กดค้างเพื่อคุย'),
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

class _ResultSheet extends StatefulWidget {
  const _ResultSheet({required this.runner, required this.provider, required this.turn, required this.state, required this.messenger});
  final AssistantRunner runner;
  final LlmProvider provider;
  final Turn turn;
  final AppState state;
  final ScaffoldMessengerState messenger;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  @override
  void initState() {
    super.initState();
    widget.runner.run(widget.provider, widget.turn).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _apply() async {
    setState(() => widget.turn.busy = true);
    final n = await widget.runner.apply(widget.turn);
    if (!mounted) return;
    if (widget.turn.applied) {
      widget.messenger.showSnackBar(SnackBar(content: Text('บันทึกแล้ว $n รายการ')));
      Navigator.pop(context);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: TurnView(turn: widget.turn, state: widget.state, onApply: _apply, onChanged: () => setState(() {})),
        ),
      ),
    );
  }
}
