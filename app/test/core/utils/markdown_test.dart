import 'package:flutter_test/flutter_test.dart';
import 'package:anything/core/utils/markdown.dart';

void main() {
  group('markdown checklist', () {
    const body = 'ทริป 6 วัน\n\n- [ ] ตั๋วเครื่องบิน\n- [ ] วีซ่า / เอกสารเดินทาง\n- [x] ที่พัก';

    test('counts and lists open items', () {
      final c = checklistOf(body)!;
      expect(c.done, 1);
      expect(c.total, 3);
      expect(c.open, ['ตั๋วเครื่องบิน', 'วีซ่า / เอกสารเดินทาง']);
    });

    test('toggle changes only that line', () {
      final out = toggleCheck(body, 1, true);
      expect(out, contains('- [x] วีซ่า / เอกสารเดินทาง'));
      expect(out, contains('- [ ] ตั๋วเครื่องบิน'));
    });

    test('findCheck matches loosely worded items', () {
      expect(findCheck(body, 'วีซ่า'), 1);
      expect(findCheck(body, 'วีซ่า/เอกสารเดินทาง'), 1);
      expect(findCheck(body, 'ประกันเดินทาง'), isNull);
    });
  });
}
