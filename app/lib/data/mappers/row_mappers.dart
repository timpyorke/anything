import 'dart:ui' show Color;

import '../../core/utils/dates.dart';
import '../../domain/category.dart';
import '../../domain/entry.dart';
import '../../domain/metric.dart';
import '../../domain/photo.dart';
import '../../domain/recurrence.dart';
import '../../domain/usage.dart';

/// แปลงแถวจาก Supabase ↔ entity ของ domain (ที่เดียวที่รู้ชื่อคอลัมน์)
Color parseHex(String hex) => Color(int.parse('ff${hex.replaceFirst('#', '')}', radix: 16));

EntryCategory categoryFromRow(Map<String, dynamic> r) => EntryCategory(
      key: r['key'] as String,
      label: r['label'] as String,
      color: parseHex(r['color'] as String),
      description: (r['description'] as String?) ?? '',
      sort: (r['sort'] as int?) ?? 0,
    );

Map<String, dynamic> categoryToRow(EntryCategory c) => {
      'key': c.key,
      'label': c.label,
      'color': '#${(c.color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}',
      'description': c.description,
      'sort': c.sort,
    };

MetricDef metricDefFromRow(Map<String, dynamic> r) => MetricDef(
      key: r['key'] as String,
      label: r['label'] as String,
      unit: (r['unit'] as String?) ?? '',
      description: (r['description'] as String?) ?? '',
    );

Map<String, dynamic> metricDefToRow(MetricDef m) => {'key': m.key, 'label': m.label, 'unit': m.unit, 'description': m.description};

MetricValue metricValueFromRow(Map<String, dynamic> r) =>
    MetricValue(r['key'] as String, (r['value'] as num).toDouble(), (r['unit'] as String?) ?? '');

/// แถวของ entry_photos → รูปเรียงตามลำดับที่แนบ
List<Photo> photosFromRows(List<dynamic>? rows) {
  final sorted = [...?rows?.cast<Map>()]..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
  return [for (final r in sorted) Photo(path: r['path'] as String)];
}

Entry entryFromRow(Map<String, dynamic> r) => Entry(
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
        for (final m in (r['metric_values'] as List? ?? const [])) metricValueFromRow(Map<String, dynamic>.from(m as Map)),
      ],
      photos: photosFromRows(r['entry_photos'] as List?),
    );

/// แถวของตาราง entries (ไม่รวม metric_values และ entry_photos)
Map<String, dynamic> entryToRow(Entry e) => {
      'kind': e.kind,
      'date': ymd(e.date),
      'end_date': e.endDate == null ? null : ymd(e.endDate!),
      'category': e.category,
      'title': e.title.trim(),
      'body': e.body.trim(),
      'every': e.recurrence?.every,
      'times': e.recurrence?.times,
      'until': e.recurrence?.until == null ? null : ymd(e.recurrence!.until!),
      'source': e.source,
      'legacy_ref': e.legacyRef,
    };

/// ผลของฟังก์ชัน get_my_usage
UsageSummary usageFromJson(Map<String, dynamic> r) {
  Quota quota(Object? v) {
    final m = v as Map;
    return (used: (m['used'] as num).toInt(), limit: (m['limit'] as num).toInt());
  }

  final ai = r['ai'] as Map;
  return UsageSummary(
    member: r['plan'] == 'pro',
    aiToday: quota(ai['day']),
    aiMonth: quota(ai['month']),
    storage: quota(r['storage']),
  );
}

/// แถวของตาราง plans
PlanLimits planLimitsFromRow(Map<String, dynamic> r) => (
      aiPerDay: (r['ai_per_day'] as num).toInt(),
      aiPerMonth: (r['ai_per_month'] as num).toInt(),
      storageBytes: (r['storage_bytes'] as num).toInt(),
    );
