import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../ai/ai_settings.dart';
import '../../ai/pcm_audio.dart';
import '../../app/language.dart';
import '../../app/providers.dart';

part 'voice_view_model.freezed.dart';

/// Gemma 4 รับเสียงได้ไม่เกิน 30 วินาทีต่อคลิป
const maxVoiceSeconds = 30;

@freezed
abstract class VoiceState with _$VoiceState {
  const factory VoiceState({
    @Default(false) bool listening, // กำลังอัดเสียง
    @Default(false) bool transcribing, // กำลังถอดเสียงเป็นข้อความ
    @Default(0) int seconds, // อัดมาแล้วกี่วินาที
    String? notice, // ข้อความแจ้งผู้ใช้ครั้งเดียว (View ฟังผ่าน ref.listen)
  }) = _VoiceState;
}

enum VoiceStart { started, needsSetup, needsVoiceModel, unavailable, released }

/// ไม่ใช่ autoDispose: งานอัด/ถอดเสียงอาจเสร็จหลังหน้าถูกปิด จึงไม่ต้องเช็กว่า provider ยังอยู่
final voiceViewModelProvider = NotifierProvider<VoiceViewModel, VoiceState>(VoiceViewModel.new);

/// อัดเสียง → ถอดเป็นข้อความด้วย Gemma ในเครื่อง (เสียงไม่ออกจากเครื่อง)
class VoiceViewModel extends Notifier<VoiceState> {
  /// เพิ่มทุกครั้งที่เริ่มใหม่หรือทิ้ง — งานรอบเก่าที่เพิ่งเสร็จจะรู้ว่าตัวเองถูกยกเลิกแล้ว
  int _round = 0;
  bool _starting = false;
  Timer? _timer;

  @override
  VoiceState build() {
    ref.onDispose(() => _timer?.cancel());
    return const VoiceState();
  }

  Future<VoiceStart> start() async {
    if (_starting || state.listening || state.transcribing) return VoiceStart.released;
    _starting = true;
    final round = ++_round;
    state = const VoiceState();
    HapticFeedback.mediumImpact();
    try {
      // ยังไม่ตั้งค่า AI หรือยังไม่มีโมเดลฟังเสียง → ให้ view ถามก่อน อย่าให้ผู้ใช้พูดเสียเปล่า
      if (await ref.read(aiSettingsProvider.notifier).resolveProvider() == null) return VoiceStart.needsSetup;
      if (!await ref.read(transcriberProvider).isReady()) return VoiceStart.needsVoiceModel;
      final recorder = ref.read(voiceRecorderProvider);
      if (!await recorder.hasPermission()) {
        state = VoiceState(notice: ref.read(stringsProvider).micDenied);
        return VoiceStart.unavailable;
      }
      if (round != _round) return VoiceStart.released;
      await recorder.start();
      if (round != _round) {
        await recorder.cancel();
        return VoiceStart.released;
      }
      state = const VoiceState(listening: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        state = state.copyWith(seconds: state.seconds + 1);
        if (state.seconds >= maxVoiceSeconds) timer.cancel();
      });
      return VoiceStart.started;
    } catch (e) {
      state = VoiceState(notice: ref.read(stringsProvider).micFailed(e));
      return VoiceStart.unavailable;
    } finally {
      _starting = false;
    }
  }

  /// หยุดอัดและถอดเสียง: คืนข้อความที่จะส่งให้ AI หรือ null ถ้ายกเลิก/ไม่ได้ยิน/ผิดพลาด (จะตั้ง notice)
  Future<String?> finish() async {
    if (!state.listening) return null;
    final round = _round;
    _timer?.cancel();
    state = const VoiceState(transcribing: true);
    String? text, notice;
    final t = ref.read(stringsProvider);
    try {
      final pcm = await ref.read(voiceRecorderProvider).stop();
      if (round != _round) return null;
      if (!isSilent(pcm)) text = (await ref.read(transcriberProvider).transcribe(wavFromPcm(pcm))).trim();
      if (text == null || text.isEmpty) {
        text = null;
        notice = t.noSpeech;
      }
    } catch (e) {
      notice = t.transcribeFailed(e);
    }
    if (round != _round) return null;
    state = VoiceState(notice: notice);
    return text;
  }

  /// ผู้ใช้กด "ยกเลิก" ระหว่างอัดหรือถอดเสียง: ทิ้งทุกอย่าง ไม่ส่ง AI
  void discard() {
    _drop();
    state = const VoiceState();
  }

  /// view ถูกปิดระหว่างอัดหรือถอดเสียง
  void abort() {
    final active = state.listening || state.transcribing;
    _drop();
    // เลื่อนไปหลังขั้น unmount ของ widget tree (ห้ามแก้ provider ระหว่างนั้น)
    if (active) {
      Future.microtask(() {
        if (ref.mounted) state = const VoiceState();
      });
    }
  }

  void _drop() {
    _round++;
    _timer?.cancel();
    if (state.listening) ref.read(voiceRecorderProvider).cancel();
  }
}
