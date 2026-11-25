import 'dart:ui' show Color;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/category.dart';
import '../../domain/entry.dart';
import '../../domain/entry_validation.dart';
import '../../domain/metric.dart';

part 'diary_state.freezed.dart';

/// สถานะข้อมูลบันทึกทั้งหมดของผู้ใช้ (immutable) — แก้ผ่าน DiaryViewModel เท่านั้น
@freezed
abstract class DiaryState with _$DiaryState {
  const DiaryState._();

  const factory DiaryState({
    @Default(<EntryCategory>[]) List<EntryCategory> categories,
    @Default(<MetricDef>[]) List<MetricDef> metricDefs,
    @Default(<Entry>[]) List<Entry> entries,
    @Default(false) bool loading,
    String? error,
  }) = _DiaryState;

  Map<String, EntryCategory> get categoryMap => {for (final c in categories) c.key: c};
  Map<String, MetricDef> get metricMap => {for (final m in metricDefs) m.key: m};
  Set<String> get categoryKeys => categories.map((c) => c.key).toSet();
  Set<String> get metricKeys => metricDefs.map((m) => m.key).toSet();

  EntryCategory category(String key) =>
      categoryMap[key] ?? EntryCategory(key: key, label: key, color: const Color(0xff6e6e73));

  String metricLabel(String key) => metricMap[key]?.label ?? key;
  String metricUnit(String key, [String unit = '']) => unit.isNotEmpty ? unit : (metricMap[key]?.unit ?? '');

  List<String> validate(Entry e) => validateEntry(e, categories: categoryKeys, metricKeys: metricKeys);

  Entry? dailyOn(DateTime day) => entries.where((e) => e.isDaily && e.date == day).firstOrNull;

  Entry? byId(String id) => entries.where((e) => e.id == id).firstOrNull;

  Entry? get birth => entries
      .where((e) => const {'เกิด', 'วันเกิด', 'born', 'birthday'}.contains(e.title.trim().toLowerCase()))
      .firstOrNull;

  /// ค่าตัวเลขเรียงตามวัน (ไม่นับรายการที่เกิดซ้ำและวันในอนาคต)
  Map<String, List<(DateTime, double, String)>> series(DateTime now) {
    final out = <String, List<(DateTime, double, String)>>{};
    final sorted = entries.where((e) => e.recurrence == null && !e.date.isAfter(now)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final e in sorted) {
      for (final m in e.metrics) {
        (out[m.key] ??= []).add((e.date, m.value, metricUnit(m.key, m.unit)));
      }
    }
    return out;
  }
}
