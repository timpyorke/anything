import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/utils/dates.dart';
import '../../domain/entry.dart';
import '../../domain/metric.dart';
import '../../domain/recurrence.dart';
import '../diary/diary_view_model.dart';

part 'entry_editor_view_model.freezed.dart';

/// ข้อมูลตั้งต้นของหน้าแก้ไข (ใช้เป็น key ของ family จึงต้องเทียบเท่ากันได้)
@freezed
abstract class EditorArgs with _$EditorArgs {
  const factory EditorArgs({Entry? entry, @Default(false) bool draft}) = _EditorArgs;
}

/// เหตุการณ์ครั้งเดียวที่ View ต้องตอบสนองด้วยการปิดหน้า (ฟังผ่าน ref.listen)
enum EditorExit { saved, deleted }

@freezed
abstract class EntryEditorState with _$EntryEditorState {
  const EntryEditorState._();

  const factory EntryEditorState({
    required Entry entry,
    String? every, // daily | weekly | monthly | yearly | null
    @Default(<String>[]) List<String> errors,
    @Default(false) bool saving,
    @Default(false) bool draft,
    EditorExit? exit,
  }) = _EntryEditorState;

  bool get isNew => entry.id == null;
}

final entryEditorViewModelProvider =
    NotifierProvider.autoDispose.family<EntryEditorViewModel, EntryEditorState, EditorArgs>(EntryEditorViewModel.new);

class EntryEditorViewModel extends Notifier<EntryEditorState> {
  EntryEditorViewModel(this.args);
  final EditorArgs args;

  @override
  EntryEditorState build() {
    final diary = ref.read(diaryViewModelProvider);
    final e = args.entry ?? Entry(date: today(), category: diary.categories.firstOrNull?.key ?? 'daily');
    return EntryEditorState(entry: e, every: e.recurrence?.every, draft: args.draft);
  }

  void setKind(String kind) => state = state.copyWith(entry: state.entry.copyWith(kind: kind));
  void setDate(DateTime d) => state = state.copyWith(entry: state.entry.copyWith(date: d));
  void setEndDate(DateTime? d) => state = state.copyWith(entry: state.entry.copyWith(endDate: d));
  void setCategory(String? c) {
    if (c != null) state = state.copyWith(entry: state.entry.copyWith(category: c));
  }

  void setEvery(String? every) =>
      state = state.copyWith(every: every, entry: every == null ? state.entry : state.entry.copyWith(endDate: null));

  /// รวมค่าจากฟอร์ม ตรวจ แล้วบันทึก — สำเร็จแล้วตั้ง state.exit = saved
  /// [metrics] = (key, ข้อความที่พิมพ์) ของช่องตัวเลข
  Future<void> save({
    required String title,
    required String body,
    required String times,
    required List<(String, String)> metrics,
  }) async {
    final diary = ref.read(diaryViewModelProvider);
    var out = state.entry.copyWith(
      title: title.trim(),
      body: body.trim(),
      recurrence: state.every == null ? null : Recurrence(state.every!, times: int.tryParse(times.trim())),
      metrics: [
        for (final (key, text) in metrics)
          if (text.trim().isNotEmpty)
            MetricValue(key, double.tryParse(text.trim().replaceAll(',', '')) ?? double.nan, diary.metricUnit(key)),
      ],
    );
    if (out.isDaily) out = out.copyWith(endDate: null);
    final errors = diary.validate(out);
    if (out.isDaily && state.isNew && diary.dailyOn(out.date) != null) {
      errors.add('มีบันทึกรายวันของ ${fmtDate(out.date)} อยู่แล้ว — เปิดรายการนั้นเพื่อแก้แทน');
    }
    state = state.copyWith(errors: errors);
    if (errors.isNotEmpty) return;
    state = state.copyWith(saving: true);
    // ผู้ใช้กดกลับได้ระหว่างบันทึก (provider ถูกทิ้ง) จึงเช็ก ref.mounted ก่อนแตะ state
    try {
      await ref.read(diaryViewModelProvider.notifier).save(out);
      if (ref.mounted) state = state.copyWith(exit: EditorExit.saved, saving: false);
    } catch (err) {
      if (ref.mounted) state = state.copyWith(errors: ['บันทึกไม่สำเร็จ: $err'], saving: false);
    }
  }

  Future<void> delete() async {
    await ref.read(diaryViewModelProvider.notifier).delete(state.entry);
    if (!ref.mounted) return;
    state = state.copyWith(exit: EditorExit.deleted);
  }
}
