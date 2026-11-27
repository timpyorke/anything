import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/category.dart';
import '../domain/entry.dart';
import '../domain/metric.dart';
import '../domain/repositories/diary_repository.dart';
import 'mappers/row_mappers.dart';

/// ทุกการอ่าน/เขียน Supabase อยู่ที่นี่ที่เดียว (RLS กรองข้อมูลตามผู้ใช้ที่ล็อกอินให้แล้ว)
class SupabaseDiaryRepository implements DiaryRepository {
  SupabaseDiaryRepository(this.db);
  final SupabaseClient db;

  static const _entryColumns = '*, metric_values(key, value, unit)';

  /// ผู้ใช้ใหม่ยังไม่มีหมวด → สร้างค่าเริ่มต้นจากฟังก์ชันในฐานข้อมูล
  @override
  Future<void> ensureDefaults() async {
    final rows = await db.from('categories').select('key').limit(1);
    if (rows.isEmpty) await db.rpc('seed_defaults');
  }

  @override
  Future<List<EntryCategory>> categories() async =>
      [for (final r in await db.from('categories').select().order('sort')) categoryFromRow(r)];

  @override
  Future<List<MetricDef>> metricDefs() async =>
      [for (final r in await db.from('metric_defs').select().order('key')) metricDefFromRow(r)];

  @override
  Future<List<Entry>> entries() async => [
        for (final r in await db.from('entries').select(_entryColumns).isFilter('deleted_at', null).order('date', ascending: false))
          entryFromRow(r),
      ];

  @override
  Future<Entry> insert(Entry e) async {
    final row = await db.from('entries').insert(entryToRow(e)).select('id').single();
    final id = row['id'] as String;
    await _writeMetrics(id, e.metrics);
    return _fetch(id);
  }

  @override
  Future<Entry> update(Entry e) async {
    await db.from('entries').update(entryToRow(e)).eq('id', e.id!);
    await db.from('metric_values').delete().eq('entry_id', e.id!);
    await _writeMetrics(e.id!, e.metrics);
    return _fetch(e.id!);
  }

  @override
  Future<void> softDelete(String id) =>
      db.from('entries').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

  @override
  Future<void> restore(String id) => db.from('entries').update({'deleted_at': null}).eq('id', id);

  @override
  Future<void> addCategory(EntryCategory c) => db.from('categories').insert(categoryToRow(c));

  @override
  Future<void> addMetricDef(MetricDef m) => db.from('metric_defs').insert(metricDefToRow(m));

  @override
  Future<void> logAi({
    required String provider,
    required String model,
    required String input,
    Object? output,
    required String status,
    String? error,
  }) =>
      db.from('ai_logs').insert({
        'provider': provider,
        'model': model,
        'input': input,
        'output': output,
        'status': status,
        'error': error,
      });

  /// นำเข้าข้อมูลจากไฟล์ export ของระบบ markdown เดิม (format life-dashboard-export) (ข้ามรายการที่ legacy_ref เคยนำเข้าแล้ว จึงรันซ้ำได้)
  @override
  Future<int> importExport(Map<String, dynamic> data) async {
    if (data['format'] != 'life-dashboard-export' || data['version'] != 1) {
      throw const FormatException('ไม่ใช่ไฟล์ export ที่รองรับ (life-dashboard-export version 1)');
    }
    await db.from('categories').upsert([
      for (final c in data['categories'] as List)
        {'key': c['key'], 'label': c['label'], 'color': c['color'], 'description': c['description'], 'sort': c['sort']},
    ], onConflict: 'user_id,key');
    await db.from('metric_defs').upsert([
      for (final m in data['metrics'] as List)
        {'key': m['key'], 'label': m['label'], 'unit': m['unit'], 'description': m['description']},
    ], onConflict: 'user_id,key');

    final existing = {
      for (final r in await db.from('entries').select('legacy_ref').not('legacy_ref', 'is', null)) r['legacy_ref'] as String,
    };
    var count = 0;
    for (final e in data['entries'] as List) {
      if (existing.contains(e['legacy_ref'])) continue;
      final row = await db
          .from('entries')
          .insert({
            'kind': e['kind'],
            'date': e['date'],
            'end_date': e['end_date'],
            'category': e['category'],
            'title': e['title'],
            'body': e['body'],
            'every': e['every'],
            'times': e['times'],
            'until': e['until'],
            'source': 'import',
            'legacy_ref': e['legacy_ref'],
          })
          .select('id')
          .single();
      await _writeMetrics(row['id'] as String, [
        for (final m in e['metrics'] as List) MetricValue(m['key'] as String, (m['value'] as num).toDouble(), (m['unit'] as String?) ?? ''),
      ]);
      count++;
    }
    return count;
  }

  Future<void> _writeMetrics(String entryId, List<MetricValue> metrics) async {
    if (metrics.isEmpty) return;
    await db.from('metric_values').insert([
      for (final m in metrics) {'entry_id': entryId, 'key': m.key, 'value': m.value, 'unit': m.unit},
    ]);
  }

  Future<Entry> _fetch(String id) async => entryFromRow(await db.from('entries').select(_entryColumns).eq('id', id).single());
}
