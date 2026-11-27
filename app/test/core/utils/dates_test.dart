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
  });
}
