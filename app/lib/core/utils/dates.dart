/// วันที่ในแอปเป็น "วันล้วน" (ไม่มีเวลา) เก็บเป็น DateTime.utc เที่ยงคืน เพื่อไม่ให้ DST/โซนเวลาทำให้เลื่อนวัน
library;

DateTime dayOf(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime today() => dayOf(DateTime.now());

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final _ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// แปลง YYYY-MM-DD → วัน; คืน null ถ้ารูปแบบผิดหรือไม่มีวันนั้นจริง (เช่น 2026-02-30)
DateTime? parseYmd(String? s) {
  final m = _ymd.firstMatch(s?.trim() ?? '');
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final dt = DateTime.utc(y, mo, d);
  return (dt.year == y && dt.month == mo && dt.day == d) ? dt : null;
}

int daysBetween(DateTime a, DateTime b) => dayOf(b).difference(dayOf(a)).inDays;

int daysInMonth(int y, int m) => DateTime.utc(y, m + 1, 0).day;

/// บวกเดือน โดยวันที่ 31 ในเดือนสั้นจะเป็นวันสุดท้ายของเดือน
DateTime addMonths(DateTime d, int n) {
  final total = d.month - 1 + n;
  final y = d.year + (total ~/ 12) - (total < 0 && total % 12 != 0 ? 1 : 0);
  final m = total % 12 + 1;
  return DateTime.utc(y, m, d.day.clamp(1, daysInMonth(y, m)));
}

int ageOn(DateTime born, DateTime now) =>
    now.year - born.year - ((now.month < born.month || (now.month == born.month && now.day < born.day)) ? 1 : 0);
