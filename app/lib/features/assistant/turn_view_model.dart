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

  Future<LlmProvider?> _provider() => ref.read(aiSettingsProvider.notifier).resolveProvider();

  Future<void> _run() async {
    final provider = await _provider();
    if (provider == null) {
      state = state.copyWith(busy: false, error: 'ยังไม่ได้ตั้งค่า AI');
      return;
    }
    try {
      final result = await Recorder(ref.read(diaryViewModelProvider)).run(provider, text);
      state = state.copyWith(result: result);
      if (result.actions.isEmpty) await _log(provider, result.raw, 'rejected');
    } on LlmException catch (e) {
      state = state.copyWith(error: e.message);
      await _log(provider, null, 'error', e.message);
    } catch (e) {
      state = state.copyWith(error: 'เกิดข้อผิดพลาด: $e');
      await _log(provider, null, 'error', '$e');
    }
    state = state.copyWith(busy: false);
  }

  void toggle(int index, bool selected) {
    final r = state.result;
    if (r == null) return;
    final actions = [...r.actions];
    actions[index] = actions[index].withSelected(selected);
    state = state.copyWith(result: AiResult(reply: r.reply, questions: r.questions, actions: actions, raw: r.raw));
  }

  /// บันทึกรายการที่เลือก คืนจำนวนที่บันทึก (ถ้าบางรายการพังจะใส่ error)
  Future<int> apply() async {
    final r = state.result!;
    state = state.copyWith(busy: true);
    final diary = ref.read(diaryViewModelProvider.notifier);
    final chosen = r.actions.where((a) => a.selected && a.valid).toList()
      ..sort((a, b) => (a.type == 'new_metric' ? 0 : 1).compareTo(b.type == 'new_metric' ? 0 : 1));
    final failures = <String>[];
    for (final a in chosen) {
      try {
        await a.run!(diary);
      } catch (e) {
        failures.add('${a.summary}: $e');
      }
    }
    final p = await _provider();
    if (p != null) {
      await _log(p, {'actions': [for (final a in chosen) a.summary], 'raw': r.raw}, failures.isEmpty ? 'applied' : 'error',
          failures.isEmpty ? null : failures.join('\n'));
    }
    state = state.copyWith(
      busy: false,
      applied: failures.isEmpty,
      error: failures.isEmpty ? null : 'บางรายการบันทึกไม่สำเร็จ:\n${failures.join('\n')}',
    );
    return chosen.length;
  }

  Future<void> _log(LlmProvider p, Object? output, String status, [String? error]) async {
    try {
      await ref
          .read(diaryViewModelProvider.notifier)
          .logAi(provider: p.kind.id, model: p.model, input: text, output: output, status: status, error: error);
    } catch (_) {
      // log ไม่สำเร็จไม่ควรขวางการบันทึก
    }
  }
}
