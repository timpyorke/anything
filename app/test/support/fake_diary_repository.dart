import 'dart:ui' show Color;

import 'package:anything/domain/category.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/metric.dart';
import 'package:anything/domain/repositories/diary_repository.dart';

/// repository ในหน่วยความจำ สำหรับทดสอบ ViewModel โดยไม่แตะเครือข่าย
class FakeDiaryRepository implements DiaryRepository {
  final cats = [const EntryCategory(key: 'health', label: 'สุขภาพ', color: Color(0xff00aa00)), const EntryCategory(key: 'daily', label: 'รายวัน', color: Color(0xff0000aa))];
  final metrics = [const MetricDef(key: 'weight', label: 'น้ำหนัก', unit: 'kg')];
  final rows = <Entry>[];
  final deleted = <String>{};
  var _next = 0;

  @override
  Future<void> ensureDefaults() async {}
  @override
  Future<List<EntryCategory>> categories() async => cats;
  @override
  Future<List<MetricDef>> metricDefs() async => metrics;
  @override
  Future<List<Entry>> entries() async => [for (final e in rows) if (!deleted.contains(e.id)) e];
  @override
  Future<Entry> insert(Entry e) async {
    final saved = e.copyWith(id: 'id-${_next++}');
    rows.add(saved);
    return saved;
  }

  @override
  Future<Entry> update(Entry e) async {
    rows[rows.indexWhere((x) => x.id == e.id)] = e;
    return e;
  }

  @override
  Future<void> softDelete(String id) async => deleted.add(id);
  @override
  Future<void> restore(String id) async => deleted.remove(id);
  @override
  Future<void> addCategory(EntryCategory c) async => cats.add(c);
  @override
  Future<void> addMetricDef(MetricDef m) async => metrics.add(m);
  @override
  Future<void> logAi({required String provider, required String model, required String input, Object? output, required String status, String? error}) async {}
  @override
  Future<int> importExport(Map<String, dynamic> data) async => 0;
}
