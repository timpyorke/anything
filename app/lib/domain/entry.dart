import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/dates.dart';
import '../core/utils/markdown.dart';
import 'metric.dart';
import 'recurrence.dart';

part 'entry.freezed.dart';

@freezed
abstract class Entry with _$Entry {
  const Entry._();

  const factory Entry({
    String? id,
    @Default('event') String kind, // event | daily
    required DateTime date,
    DateTime? endDate,
    required String category,
    @Default('') String title,
    @Default('') String body,
    Recurrence? recurrence,
    @Default('manual') String source, // manual | ai | import
    String? legacyRef,
    @Default(<MetricValue>[]) List<MetricValue> metrics,
  }) = _Entry;

  bool get isDaily => kind == 'daily';
  bool get hidden => title.trim().isEmpty && body.trim().isEmpty;
  Checklist? get checklist => checklistOf(body);

  /// วันที่ใช้แสดง/เรียง: รายการที่เกิดซ้ำใช้ครั้งถัดไป (หรือครั้งสุดท้ายถ้าครบแล้ว)
  DateTime shownDate(DateTime now) {
    final r = recState(now);
    return r == null ? date : (r.next ?? r.last);
  }

  DateTime lastDate(DateTime now) => recurrence != null ? shownDate(now) : (endDate ?? date);

  bool isUpcoming(DateTime now) => !lastDate(now).isBefore(now);

  RecState? recState(DateTime now) {
    if (recurrence == null) return null;
    final ds = recurrence!.occurrences(date, horizon: now.add(const Duration(days: 366)));
    return ds.isEmpty ? null : RecState(ds, now);
  }

  /// วันทั้งหมดที่รายการนี้ครอบคลุม (heatmap / กรองตามวัน)
  Iterable<DateTime> coveredDays(DateTime now) sync* {
    final r = recState(now);
    if (r != null) {
      yield* r.dates;
      return;
    }
    for (var d = date; !d.isAfter(endDate ?? date); d = d.add(const Duration(days: 1))) {
      yield dayOf(d);
    }
  }

  String get searchText => [title, body, category, ...metrics.map((m) => m.key)].join(' ').toLowerCase();
}
