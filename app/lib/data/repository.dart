import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/category.dart';
import '../domain/entry.dart';
import '../domain/metric.dart';

/// ทุกการอ่าน/เขียน Supabase อยู่ที่นี่ที่เดียว (RLS กรองข้อมูลตามผู้ใช้ที่ล็อกอินให้แล้ว)
class Repository {
  Repository(this.db);
  final SupabaseClient db;

  static const _entryColumns = '*, metric_values(key, value, unit)';

  /// ผู้ใช้ใหม่ยังไม่มีหมวด → สร้างค่าเริ่มต้นจากฟังก์ชันในฐานข้อมูล
  Future<void> ensureDefaults() async {
    final rows = await db.from('categories').select('key').limit(1);
    if (rows.isEmpty) await db.rpc('seed_defaults');
  }

  Future<List<EntryCategory>> categories() async =>
      [for (final r in await db.from('categories').select().order('sort')) EntryCategory.fromRow(r)];

  Future<List<MetricDef>> metricDefs() async =>
      [for (final r in await db.from('metric_defs').select().order('key')) MetricDef.fromRow(r)];

  Future<List<Entry>> entries() async => [
        for (final r in await db.from('entries').select(_entryColumns).isFilter('deleted_at', null).order('date', ascending: false))
          Entry.fromRow(r),
      ];

  Future<Entry> insert(Entry e) async {
    final row = await db.from('entries').insert(e.toRow()).select('id').single();
    final id = row['id'] as String;
    await _writeMetrics(id, e.metrics);
    return _fetch(id);
  }

  Future<Entry> update(Entry e) async {
    await db.from('entries').update(e.toRow()).eq('id', e.id!);
    await db.from('metric_values').delete().eq('entry_id', e.id!);
    await _writeMetrics(e.id!, e.metrics);
    return _fetch(e.id!);
  }

  Future<void> softDelete(String id) =>
      db.from('entries').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

  Future<void> restore(String id) => db.from('entries').update({'deleted_at': null}).eq('id', id);

  Future<void> addMetricDef(MetricDef m) => db.from('metric_defs').insert(m.toRow());

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

  Future<Entry> _fetch(String id) async => Entry.fromRow(await db.from('entries').select(_entryColumns).eq('id', id).single());
}
