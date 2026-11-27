import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../ai/ai_settings.dart';

part 'voice_view_model.freezed.dart';

@freezed
abstract class VoiceState with _$VoiceState {
  const factory VoiceState({
    @Default(false) bool listening,
    @Default(false) bool cancel, // เลื่อนนิ้วขึ้นพอแล้ว → ปล่อยเพื่อยกเลิก
    @Default('') String words,
    String? notice, // ข้อความแจ้งผู้ใช้ครั้งเดียว (View ฟังผ่าน ref.listen)
  }) = _VoiceState;
}

enum VoiceStart { started, needsSetup, unavailable, released }

/// ไม่ใช่ autoDispose: callback ของ plugin เสียงเรียกกลับมาเมื่อไหร่ก็ได้ จึงไม่ต้องเช็กว่า provider ยังอยู่
final voiceViewModelProvider = NotifierProvider<VoiceViewModel, VoiceState>(VoiceViewModel.new);

/// ใช้ระบบรู้จำเสียง "ในเครื่อง" เท่านั้น (onDevice) เพื่อไม่ส่งเสียงไปบริการภายนอก
class VoiceViewModel extends Notifier<VoiceState> {
  static const _cancelDistance = 90.0;

  final _speech = SpeechToText();
  bool _ready = false, _pressing = false;
  String? _speechError;
  double _startY = 0;

  @override
  VoiceState build() => const VoiceState();

  Future<VoiceStart> start(double globalY) async {
    _pressing = true;
    _startY = globalY;
    state = state.copyWith(notice: null);
    HapticFeedback.mediumImpact();
    // ยังไม่ตั้งค่า AI → ให้ view ถามก่อน อย่าให้ผู้ใช้พูดเสียเปล่า
    if (await ref.read(aiSettingsProvider.notifier).resolveProvider() == null) {
      _pressing = false;
      return VoiceStart.needsSetup;
    }
    if (!_ready) {
      try {
        _ready = await _speech.initialize(onError: (e) => _speechError = e.errorMsg);
      } on MissingPluginException {
        // ปลั๊กอิน native ยังไม่ถูก build รวมเข้าแอป (ต้องรัน build ใหม่ทั้งหมด)
        _ready = false;
      }
    }
    if (!_ready) {
      _pressing = false;
      state = state.copyWith(notice: 'ใช้ไมโครโฟน/รู้จำเสียงไม่ได้ ตรวจสิทธิ์ในการตั้งค่าเครื่อง');
      return VoiceStart.unavailable;
    }
    if (!_pressing) return VoiceStart.released; // ปล่อยนิ้วไปก่อนเริ่มฟังพร้อม
    _speechError = null;
    state = state.copyWith(listening: true, cancel: false, words: '');
    await _speech.listen(
      onResult: (r) => state = state.copyWith(words: r.recognizedWords),
      listenOptions: SpeechListenOptions(
        localeId: 'th_TH',
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 30),
        onDevice: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
    return VoiceStart.started;
  }

  void move(double globalY) {
    if (!state.listening) return;
    final cancel = _startY - globalY > _cancelDistance;
    if (cancel != state.cancel) {
      HapticFeedback.selectionClick();
      state = state.copyWith(cancel: cancel);
    }
  }

  /// ปล่อยนิ้ว: คืนข้อความที่จะส่งให้ AI หรือ null ถ้ายกเลิก/ไม่ได้ยิน (กรณีไม่ได้ยินจะตั้ง notice)
  Future<String?> finish() async {
    _pressing = false;
    if (!state.listening) return null;
    state = state.copyWith(notice: null);
    await _speech.stop();
    await Future<void>.delayed(const Duration(milliseconds: 350)); // รอผลสุดท้ายของคำสุดท้าย
    final text = state.words.trim(), cancelled = state.cancel;
    state = state.copyWith(listening: false);
    if (cancelled) return null;
    if (text.isEmpty) {
      state = state.copyWith(
        notice: _speechError == null
            ? 'ไม่ได้ยินเสียง แตะไมค์แล้วพูดใหม่ได้เลย'
            : 'รู้จำเสียงในเครื่องไม่ได้ ($_speechError) — ตรวจว่าติดตั้งภาษาไทยสำหรับพิมพ์/สั่งงานด้วยเสียงแล้ว',
      );
      return null;
    }
    return text;
  }

  /// ผู้ใช้กด "ยกเลิก" ระหว่างฟัง: ทิ้งทุกอย่าง ไม่ส่ง AI
  void discard() {
    _pressing = false;
    _speech.cancel();
    state = const VoiceState();
  }

  /// view ถูกปิดระหว่างฟัง
  void abort() {
    _pressing = false;
    _speech.cancel();
    // เลื่อนไปหลังขั้น unmount ของ widget tree (ห้ามแก้ provider ระหว่างนั้น)
    if (state.listening) Future.microtask(() => state = const VoiceState());
  }
}
