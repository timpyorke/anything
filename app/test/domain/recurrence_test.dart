import 'package:flutter_test/flutter_test.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/metric.dart';
import 'package:anything/domain/recurrence.dart';

void main() {
  group('recurrence (ผลตรงกับระบบเดิม: งวดที่ 19/72 เมื่อ 2026-11-24)', () {
    final now = DateTime.utc(2026, 11, 24);

    test('car installment: 72 monthly payments from 2025-05-25', () {
      final e = Entry(
        date: DateTime.utc(2025, 5, 25),
        category: 'finance',
        title: 'ค่างวดรถ Camry',
        recurrence: const Recurrence('monthly', times: 72),
        metrics: [const MetricValue('installment', 22024, 'บาท')],
      );
      final rs = e.recState(now)!;
      expect(rs.dates.length, 72);
      expect(rs.done, 18);
      expect(rs.next, DateTime.utc(2026, 11, 25));
      expect(rs.last, DateTime.utc(2031, 4, 25));
      expect(e.shownDate(now), DateTime.utc(2026, 11, 25));
      expect(e.isUpcoming(now), isTrue);
    });

    test('unbounded recurrence stops at the horizon', () {
      const r = Recurrence('yearly');
      final ds = r.occurrences(DateTime.utc(1995, 8, 18), horizon: DateTime.utc(2027, 11, 24));
      expect(ds.first, DateTime.utc(1995, 8, 18));
      expect(ds.last, DateTime.utc(2027, 8, 18));
    });

    test('parseEvery', () {
      expect(Recurrence.parseEvery('monthly'), (1, 'm'));
      expect(Recurrence.parseEvery('2w'), (2, 'w'));
      expect(Recurrence.parseEvery('0d'), isNull);
      expect(Recurrence.parseEvery('sometimes'), isNull);
    });
  });
}
