/// markdown ชุดย่อยเดียวกับ dashboard เดิม: ย่อหน้า, list, checklist, หัวข้อย่อย, **ตัวหนา**
library;

final _list = RegExp(r'^\s*(?:[-*+]|\d+[.)])\s+(?:\[([ xX])\]\s+)?(.*)$');
final _sub = RegExp(r'^#{1,6}\s+(.*)$');
final _comment = RegExp(r'<!--.*?-->', dotAll: true);

sealed class MdBlock {}

class MdParagraph extends MdBlock {
  MdParagraph(this.lines);
  final List<String> lines;
}

class MdHeading extends MdBlock {
  MdHeading(this.text);
  final String text;
}

class MdBullet extends MdBlock {
  MdBullet(this.text);
  final String text;
}

class MdCheck extends MdBlock {
  MdCheck(this.text, this.done, this.index);
  final String text;
  final bool done;

  /// ลำดับของ checklist ในเนื้อหา (ใช้กับ [toggleCheck])
  final int index;
}

List<MdBlock> parseMarkdown(String body) {
  final out = <MdBlock>[];
  var para = <String>[];
  var checkIndex = 0;
  void flush() {
    if (para.isNotEmpty) out.add(MdParagraph(para));
    para = <String>[];
  }

  for (final line in body.replaceAll(_comment, '').split('\n')) {
    final m = _list.firstMatch(line);
    if (line.trim().isEmpty) {
      flush();
    } else if (m != null) {
      flush();
      if (m[1] == null) {
        out.add(MdBullet(m[2]!.trim()));
      } else {
        out.add(MdCheck(m[2]!.trim(), m[1] != ' ', checkIndex++));
      }
    } else if (_sub.hasMatch(line)) {
      flush();
      out.add(MdHeading(_sub.firstMatch(line)![1]!.trim()));
    } else {
      para.add(line.trim());
    }
  }
  flush();
  return out;
}

class Checklist {
  const Checklist(this.done, this.total, this.open);
  final int done, total;
  final List<String> open;
}

Checklist? checklistOf(String body) {
  final items = parseMarkdown(body).whereType<MdCheck>().toList();
  if (items.isEmpty) return null;
  return Checklist(items.where((c) => c.done).length, items.length, [for (final c in items) if (!c.done) c.text]);
}

/// ติ๊ก/ยกเลิก checklist ข้อที่ [index] คืนเนื้อหาใหม่ (บรรทัดอื่นไม่เปลี่ยน)
String toggleCheck(String body, int index, bool done) {
  var i = 0;
  final lines = body.split('\n');
  for (var n = 0; n < lines.length; n++) {
    final m = _list.firstMatch(lines[n]);
    if (m == null || m[1] == null) continue;
    if (i++ == index) {
      lines[n] = lines[n].replaceFirst(RegExp(r'\[([ xX])\]'), done ? '[x]' : '[ ]');
      break;
    }
  }
  return lines.join('\n');
}

/// หา checklist ที่ข้อความใกล้เคียง [text] ที่สุด (ให้ AI อ้างถึงด้วยข้อความได้)
int? findCheck(String body, String text) {
  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r"[\s/]+"), "");
  final want = norm(text);
  if (want.isEmpty) return null;
  final items = parseMarkdown(body).whereType<MdCheck>().toList();
  for (final c in items) {
    if (norm(c.text) == want) return c.index;
  }
  for (final c in items) {
    final have = norm(c.text);
    if (have.contains(want) || want.contains(have)) return c.index;
  }
  return null;
}
