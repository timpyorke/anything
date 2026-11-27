import 'package:anything/core/l10n/strings_th.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/entry_validation.dart';
import 'package:anything/domain/metric.dart';
import 'package:anything/domain/recurrence.dart';

void main() {
  group('validateEntry', () {
    final cats = {'health', 'finance', 'daily'};
    final metrics = {'weight'};

    test('rejects Buddhist-era years, unknown category and metric', () {
      final e = Entry(date: DateTime.utc(2569, 11, 24), category: 'sport', title: 'x', metrics: [const MetricValue('bmi', 22)]);
      final errors = validateEntry(e, categories: cats, metricKeys: metrics, strings: const ThStrings());
      expect(errors.join('\n'), allOf(contains('พ.ศ.'), contains('sport'), contains('bmi')));
    });

    test('accepts a valid daily entry with only metrics', () {
      final e = Entry(kind: 'daily', date: DateTime.utc(2026, 11, 24), category: 'daily', metrics: [const MetricValue('weight', 74.5)]);
      expect(validateEntry(e, categories: cats, metricKeys: metrics, strings: const ThStrings()), isEmpty);
    });

    test('recurrence and end date cannot be combined', () {
      final e = Entry(
        date: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 1, 3),
        category: 'finance',
        title: 'x',
        recurrence: const Recurrence('monthly'),
      );
      expect(validateEntry(e, categories: cats, metricKeys: metrics, strings: const ThStrings()), isNotEmpty);
    });
  });
}
