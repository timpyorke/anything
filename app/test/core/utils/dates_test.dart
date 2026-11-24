import 'package:flutter_test/flutter_test.dart';
import 'package:anything/core/utils/dates.dart';

void main() {
  group('dates', () {
    test('parseYmd rejects impossible dates', () {
      expect(parseYmd('2026-02-30'), isNull);
      expect(parseYmd('2026-3-14'), isNull);
      expect(parseYmd('2026-11-24'), DateTime.utc(2026, 11, 24));
    });

    test('addMonths clamps to end of short months', () {
      expect(addMonths(DateTime.utc(2026, 1, 31), 1), DateTime.utc(2026, 2, 28));
      expect(addMonths(DateTime.utc(2026, 1, 31), 13), DateTime.utc(2027, 2, 28));
      expect(addMonths(DateTime.utc(2026, 3, 15), -3), DateTime.utc(2025, 12, 15));
    });

    test('Thai formatting uses Buddhist year', () {
      expect(fmtDate(DateTime.utc(2026, 11, 24)), '24 พ.ย. 2569');
      expect(fmtRange(DateTime.utc(2026, 12, 30), DateTime.utc(2027, 1, 2)), '30 ธ.ค. 2569 – 2 ม.ค. 2570');
    });

    test('relative labels', () {
      final now = DateTime.utc(2026, 11, 24);
      expect(relativeLabel(DateTime.utc(2026, 11, 25), DateTime.utc(2026, 11, 25), now), 'พรุ่งนี้');
      expect(relativeLabel(now, now, now), 'วันนี้');
      expect(relativeLabel(DateTime.utc(2026, 11, 1), DateTime.utc(2026, 11, 1), now), isNull);
    });
  });
}
