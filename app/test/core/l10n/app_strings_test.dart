import 'package:anything/ai/llm_provider.dart';
import 'package:anything/core/l10n/app_strings.dart';
import 'package:anything/domain/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final th = AppStrings.of(AppLanguage.th), en = AppStrings.of(AppLanguage.en);

  test('Thai dates use the Buddhist year, English the Gregorian year', () {
    final from = DateTime.utc(2026, 12, 30), to = DateTime.utc(2027, 1, 2);
    expect(th.fmtDate(DateTime.utc(2026, 11, 24)), '24 พ.ย. 2569');
    expect(th.fmtRange(from, to), '30 ธ.ค. 2569 – 2 ม.ค. 2570');
    expect(en.fmtRange(from, to), '30 Dec 2026 – 2 Jan 2027');
    expect(th.yearLabel(2026), 'พ.ศ. 2569');
    expect(en.yearLabel(2026), '2026');
  });

  test('relative labels', () {
    final now = DateTime.utc(2026, 11, 24);
    String? label(AppStrings s, DateTime d) => s.relativeLabel(d, d, now);
    expect(label(th, DateTime.utc(2026, 11, 25)), 'พรุ่งนี้');
    expect(label(th, now), 'วันนี้');
    expect(label(th, DateTime.utc(2026, 11, 1)), isNull);
    expect(label(en, DateTime.utc(2026, 11, 25)), 'Tomorrow');
    expect(label(en, DateTime.utc(2026, 11, 29)), 'In 5 days');
  });

  test('recurrence labels', () {
    expect(th.recurrenceLabel(const Recurrence('monthly')), 'ทุกเดือน');
    expect(th.recurrenceLabel(const Recurrence('2w')), 'ทุก 2 สัปดาห์');
    expect(en.recurrenceLabel(const Recurrence('2w')), 'Every 2 weeks');
    expect(en.recurrenceLabel(const Recurrence('1y')), 'Every 1 year');
  });

  test('English counts agree in number', () {
    expect(en.itemCount(1), '1 entry');
    expect(en.itemCount(2), '2 entries');
    expect(en.dayCount(0), '0 days');
  });

  test('service names are the same except for the on-device model', () {
    expect(th.providerLabel(AiProviderKind.onDevice), 'Gemma บนเครื่อง');
    expect(en.providerLabel(AiProviderKind.onDevice), 'Gemma on device');
    expect(en.providerLabel(AiProviderKind.openAi), 'OpenAI');
    expect(en.providerDescription(AiProviderKind.aiStudio), contains('sent to Google'));
  });
}
