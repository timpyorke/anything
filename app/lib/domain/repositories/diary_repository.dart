import '../category.dart';
import '../entry.dart';
import '../metric.dart';

/// สัญญาของที่เก็บข้อมูลบันทึก — domain/viewmodel รู้จักแค่ interface นี้ ไม่รู้ว่าเบื้องหลังเป็น Supabase
abstract class DiaryRepository {
  Future<void> ensureDefaults();
  Future<List<EntryCategory>> categories();
  Future<List<MetricDef>> metricDefs();
  Future<List<Entry>> entries();
  Future<Entry> insert(Entry e);
  Future<Entry> update(Entry e);
  Future<void> softDelete(String id);
  Future<void> restore(String id);
  Future<void> addCategory(EntryCategory c);
  Future<void> addMetricDef(MetricDef m);

  Future<void> logAi({
    required String provider,
    required String model,
    required String input,
    Object? output,
    required String status,
    String? error,
  });

  /// นำเข้าจากไฟล์ export ของระบบเดิม คืนจำนวนที่นำเข้า
  Future<int> importExport(Map<String, dynamic> data);
}
