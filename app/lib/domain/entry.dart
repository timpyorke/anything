
import '../core/utils/dates.dart';
import '../core/utils/markdown.dart';
import 'metric.dart';
import 'recurrence.dart';

class Entry {
  Entry({
    this.id,
    this.kind = 'event',
    required this.date,
    this.endDate,
    required this.category,
    this.title = '',
    this.body = '',
    this.recurrence,
    this.source = 'manual',
    this.legacyRef,
    List<MetricValue>? metrics,
  }) : metrics = metrics ?? [];

  final String? id;
  String kind; // event | daily
  DateTime date;
  DateTime? endDate;
  String category;
  String title;
  String body;
  Recurrence? recurrence;
  String source; // manual | ai | import
  String? legacyRef;
  List<MetricValue> metrics;

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

  factory Entry.fromRow(Map<String, dynamic> r) => Entry(
        id: r['id'] as String,
        kind: r['kind'] as String,
        date: parseYmd(r['date'] as String)!,
        endDate: parseYmd(r['end_date'] as String?),
        category: r['category'] as String,
        title: (r['title'] as String?) ?? '',
        body: (r['body'] as String?) ?? '',
        recurrence: r['every'] == null
            ? null
            : Recurrence(r['every'] as String, times: r['times'] as int?, until: parseYmd(r['until'] as String?)),
        source: (r['source'] as String?) ?? 'manual',
        legacyRef: r['legacy_ref'] as String?,
        metrics: [
          for (final m in (r['metric_values'] as List? ?? const [])) MetricValue.fromRow(Map<String, dynamic>.from(m as Map)),
        ],
      );

  /// แถวของตาราง entries (ไม่รวม metric_values)
  Map<String, dynamic> toRow() => {
        'kind': kind,
        'date': ymd(date),
        'end_date': endDate == null ? null : ymd(endDate!),
        'category': category,
        'title': title.trim(),
        'body': body.trim(),
        'every': recurrence?.every,
        'times': recurrence?.times,
        'until': recurrence?.until == null ? null : ymd(recurrence!.until!),
        'source': source,
        'legacy_ref': legacyRef,
      };

  Entry copy() => Entry(
        id: id,
        kind: kind,
        date: date,
        endDate: endDate,
        category: category,
        title: title,
        body: body,
        recurrence: recurrence,
        source: source,
        legacyRef: legacyRef,
        metrics: [...metrics],
      );
}
