import 'dart:typed_data';

import '../category.dart';
import '../entry.dart';
import '../metric.dart';
import '../photo.dart';

/// สัญญาของที่เก็บข้อมูลบันทึก — domain/viewmodel รู้จักแค่ interface นี้ ไม่รู้ว่าเบื้องหลังเป็น Supabase
abstract class DiaryRepository {
  Future<void> ensureDefaults();
  Future<List<EntryCategory>> categories();
  Future<List<MetricDef>> metricDefs();
  Future<List<Entry>> entries();
  /// รูปใน [Entry.photos] ที่ยังไม่เคยเก็บ (ไม่มี path) จะถูกอัปโหลด
  Future<Entry> insert(Entry e);

  /// เหมือน [insert] ส่วนรูปเดิมถูกลบเฉพาะที่ระบุใน [removedPhotos]
  /// (รูปที่ไม่อยู่ใน e.photos ไม่ถูกลบ กัน entity ที่เก่ากว่าฐานข้อมูลลบรูปที่เพิ่งแนบ)
  Future<Entry> update(Entry e, {List<Photo> removedPhotos = const []});

  /// ไฟล์รูปที่เก็บไว้
  Future<Uint8List> photoBytes(String path);
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

  /// นำเข้าจากไฟล์ export ของระบบเดิม คืนจำนวนที่นำเข้า (ไฟล์ผิดรูปแบบโยน [UnsupportedExportException])
  Future<int> importExport(Map<String, dynamic> data);
}

/// ไฟล์ที่นำเข้าไม่ใช่ export ของระบบเดิม
class UnsupportedExportException implements Exception {}
