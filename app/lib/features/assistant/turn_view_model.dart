import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../ai/ai_settings.dart';
import '../../ai/llm_provider.dart';
import '../../app/language.dart';
import '../diary/diary_view_model.dart';
import '../diary/storage_full.dart';
import 'recorder.dart';

part 'turn_view_model.freezed.dart';

/// สิ่งที่ผู้ใช้ส่งมาเริ่มเรื่อง: ข้อความ และรูปที่แนบ (อย่างน้อยหนึ่งอย่าง)
typedef TurnRequest = ({String text, List<Uint8List> photos});

/// การคุยกับ AI 1 เรื่อง: ข้อความผู้ใช้ → ผลที่ AI เสนอ → ผู้ใช้ตอบเพิ่มได้ → เลือก/ยืนยัน
/// [text] คือข้อความล่าสุด รอบก่อนหน้าอยู่ใน [history] ส่วน [photos] ใช้ร่วมกันทุกรอบ
@freezed
abstract class TurnState with _$TurnState {
  const TurnState._();

  const factory TurnState({
    required String text,
    @Default(<Uint8List>[]) List<Uint8List> photos,
    /// รูปที่บันทึกไปแล้วผ่านหน้าแก้ไข
    @Default(<int>{}) Set<int> savedPhotos,
    @Default(<Exchange>[]) List<Exchange> history,
    AiResult? result,
    String? error,
    /// [error] มาจากโควตาของ AI ของแอป
    @Default(false) bool quotaReached,
    @Default(true) bool busy,
    @Default(false) bool applied,
  }) = _TurnState;

  /// กำลังรอคำตอบจาก AI (ไม่ใช่กำลังบันทึก)
  bool get thinking => busy && result == null;

  /// จำนวนรูปที่จะไม่ถูกเก็บถ้ากดบันทึกตอนนี้
  int get unattachedPhotos {
    final kept = {
      ...savedPhotos,
      for (final a in result?.actions ?? const <ProposedAction>[]) if (a.valid && a.selected) ...a.photos,
    };
    return photos.length - kept.length;
  }
}

/// 1 provider ต่อ 1 เรื่องที่ส่ง (autoDispose: ปิด sheet แล้วทิ้ง)
final turnViewModelProvider =
    NotifierProvider.autoDispose.family<TurnViewModel, TurnState, TurnRequest>(TurnViewModel.new);

class TurnViewModel extends Notifier<TurnState> {
  TurnViewModel(this.request);
  final TurnRequest request;

  /// จบเมื่อผู้ใช้ยกเลิกรอบที่กำลังคิดอยู่
  Completer<void>? _cancel;

  @override
  TurnState build() {
    ref.onDispose(() => _cancel?.complete());
    Future.microtask(_run);
    return TurnState(text: request.text, photos: request.photos);
  }

  // ผู้ใช้ปิด sheet ได้ (provider ถูกทิ้ง) จึงต้องอ่าน notifier ที่ใช้ไว้ก่อน await และเช็ก ref.mounted
  // ก่อนแตะ state — ปิดตอนคิดอยู่ = ยกเลิกคำขอ ส่วนงานบันทึกที่สั่งไว้ยังทำต่อจนจบ
  Future<void> _run() async {
    // อ่าน state ก่อน await (หลังจากนั้น provider อาจถูกทิ้งแล้ว)
    final message = state.text, history = state.history, photos = state.photos, input = _input;
    final diary = ref.read(diaryViewModelProvider.notifier);
    final t = ref.read(stringsProvider);
    final cancel = _cancel = Completer<void>();
    final provider = await ref.read(aiSettingsProvider.notifier).resolveProvider();
    if (!ref.mounted) return;
    if (provider == null) {
      state = state.copyWith(busy: false, error: t.aiNotSetUp);
      return;
    }
    try {
      final result = await Recorder(ref.read(diaryViewModelProvider), strings: t)
          .run(provider, message, history: history, photos: photos, cancel: cancel.future);
      if (cancel.isCompleted) return;
      state = state.copyWith(result: result, busy: false);
      if (result.actions.isEmpty) await _log(diary, provider, input, result.raw, 'rejected');
    } catch (e) {
      if (cancel.isCompleted) return;
      // ข้อความของ LlmException พร้อมแสดงอยู่แล้ว
      if (ref.mounted) {
        state = state.copyWith(
            busy: false, error: e is LlmException ? e.message : t.unexpectedError(e), quotaReached: e is AiQuotaException);
      }
      await _log(diary, provider, input, null, 'error', '$e');
    }
  }

  /// รอบล่าสุดพังก่อนได้คำตอบ (เน็ตหลุด, บริการล่ม) — ส่งข้อความและรูปเดิมอีกครั้ง
  Future<void> retry() async {
    if (state.busy || state.result != null || state.error == null) return;
    state = state.copyWith(busy: true, error: null, quotaReached: false);
    await _run();
  }

  /// ผู้ใช้ตอบคำถามหรือบอกเพิ่ม — ผลรอบใหม่แทนรายการที่เสนอไว้เดิม
  Future<void> answer(String message) async {
    final m = message.trim();
    if (m.isEmpty || state.busy || state.applied) return;
    state = TurnState(
      text: m,
      photos: state.photos,
      savedPhotos: state.savedPhotos,
      history: [...state.history, (message: state.text, result: state.result)],
    );
    await _run();
  }

  /// ข้อความของผู้ใช้ทุกรอบ สำหรับเก็บใน log (เก็บแค่จำนวนรูป ไม่เก็บตัวรูป)
  String get _input => [
        if (state.photos.isNotEmpty) ref.read(stringsProvider).attachedPhotosLog(state.photos.length),
        for (final h in state.history) h.message,
        state.text,
      ].join('\n');

  /// ผู้ใช้แก้และบันทึกรายการนี้จากหน้าแก้ไขแล้ว — เอาออกจากชุดที่จะบันทึกอีก
  void markSaved(int index) {
    final r = state.result;
    if (r == null) return;
    state = state.copyWith(savedPhotos: {...state.savedPhotos, ...r.actions[index].photos});
    toggle(index, false);
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
    final t = ref.read(stringsProvider);
    final input = _input;
    state = state.copyWith(busy: true);
    final chosen = r.actions.where((a) => a.selected && a.valid).toList()
      ..sort((a, b) => (a.isDefinition ? 0 : 1).compareTo(b.isDefinition ? 0 : 1));
    final failures = <String>[];
    final done = <ProposedAction>[];
    for (final a in chosen) {
      try {
        await a.run!(diary);
        done.add(a);
      } catch (e) {
        failures.add('${a.summary}: ${storageFullMessage(e, t) ?? e}');
      }
    }
    final p = await settings.resolveProvider();
    if (p != null) {
      await _log(diary, p, input, {'actions': [for (final a in chosen) a.summary], 'raw': r.raw}, failures.isEmpty ? 'applied' : 'error',
          failures.isEmpty ? null : failures.join('\n'));
    }
    final error = failures.isEmpty ? null : t.someSavesFailed(failures.join('\n'));
    if (ref.mounted) {
      state = state.copyWith(busy: false, applied: error == null, error: error);
      // บางรายการพัง: เอารายการที่บันทึกแล้วออกจากชุด กดบันทึกอีกครั้งจะได้ไม่เกิดรายการซ้ำ
      if (error != null) {
        for (final a in done) {
          markSaved(r.actions.indexOf(a));
        }
      }
    }
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
