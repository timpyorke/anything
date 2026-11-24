import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';

import '../core/utils/markdown.dart' as md;
import '../data/repository.dart';
import '../domain/category.dart';
import '../domain/entry.dart';
import '../domain/entry_validation.dart';
import '../domain/metric.dart';

/// สถานะของแอปทั้งหมด: โหลดจาก Supabase ครั้งเดียว แล้วแก้ทั้งในเครื่องและฐานข้อมูลพร้อมกัน
class AppState extends ChangeNotifier {
  AppState(this.repo);
  final Repository repo;

  List<EntryCategory> categories = [];
  List<MetricDef> metricDefs = [];
  List<Entry> entries = [];
  bool loading = false;
  String? error;

  Map<String, EntryCategory> get categoryMap => {for (final c in categories) c.key: c};
  Map<String, MetricDef> get metricMap => {for (final m in metricDefs) m.key: m};
  Set<String> get categoryKeys => categories.map((c) => c.key).toSet();
  Set<String> get metricKeys => metricDefs.map((m) => m.key).toSet();

  EntryCategory category(String key) =>
      categoryMap[key] ?? EntryCategory(key: key, label: key, color: const Color(0xff6e6e73));

  String metricLabel(String key) => metricMap[key]?.label ?? key;
  String metricUnit(String key, [String unit = '']) => unit.isNotEmpty ? unit : (metricMap[key]?.unit ?? '');

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await repo.ensureDefaults();
      final results = await Future.wait([repo.categories(), repo.metricDefs(), repo.entries()]);
      categories = results[0] as List<EntryCategory>;
      metricDefs = results[1] as List<MetricDef>;
      entries = results[2] as List<Entry>;
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  List<String> validate(Entry e) => validateEntry(e, categories: categoryKeys, metricKeys: metricKeys);

  Future<Entry> save(Entry e) async {
    final errors = validate(e);
    if (errors.isNotEmpty) throw ArgumentError(errors.join('\n'));
    final saved = e.id == null ? await repo.insert(e) : await repo.update(e);
    entries = [for (final x in entries) if (x.id != saved.id) x, saved]..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    return saved;
  }

  Future<void> delete(Entry e) async {
    await repo.softDelete(e.id!);
    entries = entries.where((x) => x.id != e.id).toList();
    notifyListeners();
  }

  Future<void> undoDelete(Entry e) async {
    await repo.restore(e.id!);
    await load();
  }

  Future<void> toggleCheck(Entry e, int index, bool done) async {
    final copy = e.copy()..body = md.toggleCheck(e.body, index, done);
    await save(copy);
  }

  Future<void> addMetricDef(MetricDef m) async {
    await repo.addMetricDef(m);
    metricDefs = [...metricDefs, m]..sort((a, b) => a.key.compareTo(b.key));
    notifyListeners();
  }

  Entry? dailyOn(DateTime day) =>
      entries.where((e) => e.isDaily && e.date == day).firstOrNull;

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
