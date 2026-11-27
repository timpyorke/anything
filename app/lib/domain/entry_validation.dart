
import 'entry.dart';
import 'photo.dart';
import 'recurrence.dart';

/// กฎเดียวกับ CHECK constraint ใน Supabase — ตรวจในแอปก่อน ให้ข้อความผิดพลาดเป็นภาษาไทย
List<String> validateEntry(Entry e, {required Set<String> categories, required Set<String> metricKeys}) {
  final errors = <String>[];
  if (e.date.year > 2400) errors.add('ปี ${e.date.year} ดูเหมือนเป็น พ.ศ. — ใช้ ค.ศ.');
  if (!categories.contains(e.category)) errors.add('ไม่มีหมวด "${e.category}"');
  if (e.endDate != null && !e.endDate!.isAfter(e.date)) errors.add('วันสิ้นสุดต้องอยู่หลังวันเริ่ม');
  if (e.isDaily && (e.endDate != null || e.recurrence != null)) errors.add('บันทึกรายวันใช้ช่วงวันที่/เกิดซ้ำไม่ได้');
  final r = e.recurrence;
  if (r != null) {
    if (Recurrence.parseEvery(r.every) == null) errors.add('รูปแบบการเกิดซ้ำไม่ถูกต้อง: ${r.every}');
    if (e.endDate != null) errors.add('รายการที่เกิดซ้ำใช้ช่วงวันที่ไม่ได้');
    if (r.times != null && (r.times! < 1 || r.times! > 1000)) errors.add('จำนวนครั้งต้องอยู่ระหว่าง 1–1000');
    if (r.until != null && r.until!.isBefore(e.date)) errors.add('วันสิ้นสุดการเกิดซ้ำต้องไม่ก่อนวันเริ่ม');
  }
  for (final m in e.metrics) {
    if (!metricKeys.contains(m.key)) errors.add('ไม่มี metric "${m.key}"');
    if (m.value.isNaN || m.value.isInfinite) errors.add('ค่า ${m.key} ไม่ใช่ตัวเลข');
  }
  if (!e.isDaily && e.hidden && e.metrics.isEmpty) errors.add('ต้องมีชื่อ เนื้อหา รูป หรือตัวเลขอย่างน้อยหนึ่งอย่าง');
  if (e.photos.length > maxPhotosPerEntry) errors.add('แนบรูปได้ไม่เกิน $maxPhotosPerEntry รูปต่อรายการ');
  return errors;
}
