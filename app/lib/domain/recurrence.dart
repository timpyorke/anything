
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/dates.dart';

part 'recurrence.freezed.dart';

/// รายการที่เกิดซ้ำ: daily/weekly/monthly/yearly หรือ 2w, 3m, 1y
@freezed
abstract class Recurrence with _$Recurrence {
  const Recurrence._();
  const factory Recurrence(String every, {int? times, DateTime? until}) = _Recurrence;

  static const words = {'daily': (1, 'd'), 'weekly': (1, 'w'), 'monthly': (1, 'm'), 'yearly': (1, 'y')};
  static const maxOccurrences = 1000;

  static (int, String)? parseEvery(String? s) {
    final v = (s ?? '').trim().toLowerCase();
    if (words.containsKey(v)) return words[v];
    final m = RegExp(r'^(\d{1,3})\s*([dwmy])$').firstMatch(v);
    if (m == null) return null;
    final n = int.parse(m[1]!);
    return n > 0 ? (n, m[2]!) : null;
  }

  /// ทุกครั้งที่เกิด นับจาก [start]; ถ้าไม่มี times/until จะหยุดที่ [horizon]
  List<DateTime> occurrences(DateTime start, {required DateTime horizon}) {
    final step = parseEvery(every);
    if (step == null) return const [];
    final (n, unit) = step;
    final out = <DateTime>[];
    for (var k = 0; k < maxOccurrences; k++) {
      if (times != null && k >= times!) break;
      final d = switch (unit) {
        'd' => start.add(Duration(days: n * k)),
        'w' => start.add(Duration(days: 7 * n * k)),
        'm' => addMonths(start, n * k),
        _ => addMonths(start, 12 * n * k),
      };
      final d0 = dayOf(d);
      if (until != null && d0.isAfter(until!)) break;
      if (times == null && until == null && d0.isAfter(horizon)) break;
      out.add(d0);
    }
    return out;
  }
}

/// สถานะของรายการที่เกิดซ้ำ ณ วันนี้
class RecState {
  RecState(this.dates, DateTime now) {
    final i = dates.indexWhere((d) => !d.isBefore(now));
    done = i < 0 ? dates.length : i;
    next = i < 0 ? null : dates[i];
  }
  final List<DateTime> dates;
  late final int done;
  late final DateTime? next;
  DateTime get last => dates.last;
}
