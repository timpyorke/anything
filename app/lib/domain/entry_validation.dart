
import '../core/l10n/app_strings.dart';
import 'entry.dart';
import 'photo.dart';
import 'recurrence.dart';

/// กฎเดียวกับ CHECK constraint ใน Supabase — ตรวจในแอปก่อน ให้ข้อความผิดพลาดเป็นภาษาของผู้ใช้
List<String> validateEntry(Entry e,
    {required Set<String> categories, required Set<String> metricKeys, required AppStrings strings}) {
  final errors = <String>[];
  if (e.date.year > 2400) errors.add(strings.yearLooksBuddhist(e.date.year));
  if (!categories.contains(e.category)) errors.add(strings.unknownCategory(e.category));
  if (e.endDate != null && !e.endDate!.isAfter(e.date)) errors.add(strings.endNotAfterStart);
  if (e.isDaily && (e.endDate != null || e.recurrence != null)) errors.add(strings.dailyNoRange);
  final r = e.recurrence;
  if (r != null) {
    if (Recurrence.parseEvery(r.every) == null) errors.add(strings.invalidRecurrence(r.every));
    if (e.endDate != null) errors.add(strings.recurringNoRange);
    if (r.times != null && (r.times! < 1 || r.times! > 1000)) errors.add(strings.timesOutOfRange);
    if (r.until != null && r.until!.isBefore(e.date)) errors.add(strings.untilBeforeStart);
  }
  for (final m in e.metrics) {
    if (!metricKeys.contains(m.key)) errors.add(strings.unknownMetric(m.key));
    if (m.value.isNaN || m.value.isInfinite) errors.add(strings.notANumber(m.key));
  }
  if (!e.isDaily && e.hidden && e.metrics.isEmpty) errors.add(strings.entryEmpty);
  if (e.photos.length > maxPhotosPerEntry) errors.add(strings.tooManyPhotos(maxPhotosPerEntry));
  return errors;
}
