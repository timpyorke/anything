import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../ai/ai_settings.dart';
import '../../ai/llm_provider.dart';
import '../diary/diary_view_model.dart';
import 'recorder.dart';

part 'turn_view_model.freezed.dart';

/// การคุยกับ AI 1 รอบ: ข้อความผู้ใช้ → ผลที่ AI เสนอ → ผู้ใช้เลือก/ยืนยัน
@freezed
abstract class TurnState with _$TurnState {
  const factory TurnState({
    required String text,
    AiResult? result,
    String? error,
    @Default(true) bool busy,
    @Default(false) bool applied,
  }) = _TurnState;
}

/// 1 provider ต่อ 1 ข้อความ (autoDispose: ปิด sheet แล้วทิ้ง)
final turnViewModelProvider =
    NotifierProvider.autoDispose.family<TurnViewModel, TurnState, String>(TurnViewModel.new);

class TurnViewModel extends Notifier<TurnState> {
  TurnViewModel(this.text);
  final String text;

  @override
  TurnState build() {
    Future.microtask(_run);
    return TurnState(text: text);
  }

  // ผู้ใช้ปิด sheet ได้ทุกเมื่อ (provider ถูกทิ้ง) จึงต้องอ่าน notifier ที่ใช้ไว้ก่อน await
  // และเช็ก ref.mounted ก่อนแตะ state — งานที่สั่งไว้ (บันทึก, log) ยังทำต่อจนจบ
  Future<void> _run() async {
    final diary = ref.read(diaryViewModelProvider.notifier);
    final provider = await ref.read(aiSettingsProvider.notifier).resolveProvider();
    if (!ref.mounted) return;
    if (provider == null) {
      state = state.copyWith(busy: false, error: 'ยังไม่ได้ตั้งค่า AI');
      return;
    }
    try {
      final result = await Recorder(ref.read(diaryViewModelProvider)).run(provider, text);
      if (ref.mounted) state = state.copyWith(result: result, busy: false);
      if (result.actions.isEmpty) await _log(diary, provider, result.raw, 'rejected');
    } catch (e) {
      // LlmException.toString() คือข้อความภาษาไทยที่พร้อมแสดงอยู่แล้ว
      if (ref.mounted) state = state.copyWith(busy: false, error: e is LlmException ? e.message : 'เกิดข้อผิดพลาด: $e');
      await _log(diary, provider, null, 'error', '$e');
    }
  }

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
      await _log(diary, p, {'actions': [for (final a in chosen) a.summary], 'raw': r.raw}, failures.isEmpty ? 'applied' : 'error',
          failures.isEmpty ? null : failures.join('\n'));
    }
    final error = failures.isEmpty ? null : 'บางรายการบันทึกไม่สำเร็จ:\n${failures.join('\n')}';
    if (ref.mounted) state = state.copyWith(busy: false, applied: error == null, error: error);
    return (count: chosen.length, error: error);
  }

  Future<void> _log(DiaryViewModel diary, LlmProvider p, Object? output, String status, [String? error]) async {
    try {
      await diary.logAi(provider: p.kind.id, model: p.model, input: text, output: output, status: status, error: error);
    } catch (_) {
      // log ไม่สำเร็จไม่ควรขวางการบันทึก
    }
  }
}
