import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../ai/ai_settings.dart';
import '../../ai/llm_provider.dart';
import '../diary/diary_view_model.dart';
import 'recorder.dart';

part 'turn_view_model.freezed.dart';

/// การคุยกับ AI 1 เรื่อง: ข้อความผู้ใช้ → ผลที่ AI เสนอ → ผู้ใช้ตอบเพิ่มได้ → เลือก/ยืนยัน
/// [text] คือข้อความล่าสุด รอบก่อนหน้าอยู่ใน [history]
@freezed
abstract class TurnState with _$TurnState {
  const TurnState._();

  const factory TurnState({
    required String text,
    @Default(<Exchange>[]) List<Exchange> history,
    AiResult? result,
    String? error,
    @Default(true) bool busy,
    @Default(false) bool applied,
  }) = _TurnState;

  /// กำลังรอคำตอบจาก AI (ไม่ใช่กำลังบันทึก)
  bool get thinking => busy && result == null;
}

/// 1 provider ต่อ 1 ข้อความแรก (autoDispose: ปิด sheet แล้วทิ้ง)
final turnViewModelProvider =
    NotifierProvider.autoDispose.family<TurnViewModel, TurnState, String>(TurnViewModel.new);

class TurnViewModel extends Notifier<TurnState> {
  TurnViewModel(this.text);
  final String text;

  /// จบเมื่อผู้ใช้ยกเลิกรอบที่กำลังคิดอยู่
  Completer<void>? _cancel;

  @override
  TurnState build() {
    ref.onDispose(() => _cancel?.complete());
    Future.microtask(_run);
    return TurnState(text: text);
  }

  // ผู้ใช้ปิด sheet ได้ (provider ถูกทิ้ง) จึงต้องอ่าน notifier ที่ใช้ไว้ก่อน await และเช็ก ref.mounted
  // ก่อนแตะ state — ปิดตอนคิดอยู่ = ยกเลิกคำขอ ส่วนงานบันทึกที่สั่งไว้ยังทำต่อจนจบ
  Future<void> _run() async {
    // อ่าน state ก่อน await (หลังจากนั้น provider อาจถูกทิ้งแล้ว)
    final message = state.text, history = state.history, input = _input;
    final diary = ref.read(diaryViewModelProvider.notifier);
    final cancel = _cancel = Completer<void>();
    final provider = await ref.read(aiSettingsProvider.notifier).resolveProvider();
    if (!ref.mounted) return;
    if (provider == null) {
      state = state.copyWith(busy: false, error: 'ยังไม่ได้ตั้งค่า AI');
      return;
    }
    try {
      final result = await Recorder(ref.read(diaryViewModelProvider))
          .run(provider, message, history: history, cancel: cancel.future);
      if (cancel.isCompleted) return;
      state = state.copyWith(result: result, busy: false);
      if (result.actions.isEmpty) await _log(diary, provider, input, result.raw, 'rejected');
    } catch (e) {
      if (cancel.isCompleted) return;
      // LlmException.toString() คือข้อความภาษาไทยที่พร้อมแสดงอยู่แล้ว
      if (ref.mounted) state = state.copyWith(busy: false, error: e is LlmException ? e.message : 'เกิดข้อผิดพลาด: $e');
      await _log(diary, provider, input, null, 'error', '$e');
    }
  }

  /// ผู้ใช้ตอบคำถามหรือบอกเพิ่ม — ผลรอบใหม่แทนรายการที่เสนอไว้เดิม
  Future<void> answer(String message) async {
    final m = message.trim();
    if (m.isEmpty || state.busy || state.applied) return;
    state = TurnState(text: m, history: [...state.history, (message: state.text, result: state.result)]);
    await _run();
  }

  /// ข้อความของผู้ใช้ทุกรอบ สำหรับเก็บใน log
  String get _input => [for (final h in state.history) h.message, state.text].join('\n');

  void toggle(int index, bool selected) {
    final r = state.result;
    if (r == null) return;
    final actions = [...r.actions];
    actions[index] = actions[index].withSelected(selected);
    state = state.copyWith(result: AiResult(reply: r.reply, questions: r.questions, actions: actions, raw: r.raw));
  }

  /// บันทึกรายการที่เลือก คืนจำนวนที่สั่งบันทึก และ error ถ้าบางรายการพัง
  Future<({int count, String? error})> apply() async {
    final r = state.result!;
    final diary = ref.read(diaryViewModelProvider.notifier);
    final settings = ref.read(aiSettingsProvider.notifier);
    final input = _input;
    state = state.copyWith(busy: true);
    final chosen = r.actions.where((a) => a.selected && a.valid).toList()
      ..sort((a, b) => (a.isDefinition ? 0 : 1).compareTo(b.isDefinition ? 0 : 1));
    final failures = <String>[];
    for (final a in chosen) {
      try {
        await a.run!(diary);
      } catch (e) {
        failures.add('${a.summary}: $e');
      }
    }
    final p = await settings.resolveProvider();
    if (p != null) {
      await _log(diary, p, input, {'actions': [for (final a in chosen) a.summary], 'raw': r.raw}, failures.isEmpty ? 'applied' : 'error',
          failures.isEmpty ? null : failures.join('\n'));
    }
    final error = failures.isEmpty ? null : 'บางรายการบันทึกไม่สำเร็จ:\n${failures.join('\n')}';
    if (ref.mounted) state = state.copyWith(busy: false, applied: error == null, error: error);
    return (count: chosen.length, error: error);
  }

  Future<void> _log(DiaryViewModel diary, LlmProvider p, String input, Object? output, String status, [String? error]) async {
    try {
      await diary.logAi(provider: p.kind.id, model: p.model, input: input, output: output, status: status, error: error);
    } catch (_) {
      // log ไม่สำเร็จไม่ควรขวางการบันทึก
    }
  }
}
