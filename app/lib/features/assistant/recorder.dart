import 'dart:convert';

import '../../ai/llm_provider.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/markdown.dart';
import '../../domain/entry.dart';
import '../../domain/entry_validation.dart';
import '../../domain/metric.dart';
import '../../domain/recurrence.dart';
import '../diary/diary_state.dart';
import '../diary/diary_view_model.dart';

/// สิ่งที่ AI เสนอให้ทำ 1 อย่าง — ผู้ใช้เห็นก่อนและเลือกได้ว่าจะบันทึกหรือไม่
class ProposedAction {
  ProposedAction({required this.type, required this.summary, this.detail = '', this.errors = const [], this.run, this.entry, bool? selected})
      : selected = selected ?? errors.isEmpty;

  final String type; // create | update | check | new_metric
  final String summary;
  final String detail;
  final List<String> errors;
  final Future<void> Function(DiaryViewModel diary)? run;
  final Entry? entry; // สำหรับเปิดแก้ไขเองก่อนบันทึก
  final bool selected;
  bool get valid => errors.isEmpty && run != null;

  ProposedAction withSelected(bool value) =>
      ProposedAction(type: type, summary: summary, detail: detail, errors: errors, run: run, entry: entry, selected: value);
}

class AiResult {
  AiResult({required this.reply, required this.questions, required this.actions, required this.raw});
  final String reply;
  final List<String> questions;
  final List<ProposedAction> actions;
  final Object? raw;
}

class Recorder {
  Recorder(this.state, {DateTime Function()? clock}) : _clock = clock ?? today;
  final DiaryState state;
  final DateTime Function() _clock;

  /// รหัสสั้น (R1, R2, …) แทน uuid ในพรอมต์ — ประหยัด token และ AI อ้าง id มั่วไม่ได้
  final Map<String, String> refs = {};

  Future<AiResult> run(LlmProvider provider, String message) async {
    final now = _clock();
    final system = systemPrompt(now);
    final raw = await provider.generateJson(system: system, user: 'ข้อความจากผู้ใช้:\n$message');
    return parse(raw, now);
  }

  String systemPrompt(DateTime now) {
    refs.clear();
    String ref(Entry e) {
      final r = 'R${refs.length + 1}';
      refs[r] = e.id!;
      return r;
    }

    String line(Entry e) {
      final rs = e.recState(now);
      final when = rs != null ? '${ymd(rs.next ?? rs.last)} (เกิดซ้ำ ${e.recurrence!.every})' : '${ymd(e.date)}${e.endDate == null ? '' : '..${ymd(e.endDate!)}'}';
      final ms = e.metrics.map((m) => '${m.key}=${_num(m.value)}').join(', ');
      return '- ${ref(e)} $when [${e.category}]${e.isDaily ? ' (daily)' : ''} ${e.title}${ms.isEmpty ? '' : ' {$ms}'}';
    }

    final upcoming = state.entries.where((e) => !e.hidden && e.isUpcoming(now)).toList()
      ..sort((a, b) => a.shownDate(now).compareTo(b.shownDate(now)));
    final recentFrom = now.subtract(const Duration(days: 14));
    final recent = state.entries
        .where((e) => e.recurrence == null && !e.date.isBefore(recentFrom) && !e.date.isAfter(now))
        .take(15)
        .toList();
    final open = state.entries.where((e) => (e.checklist?.open.isNotEmpty ?? false)).take(5).toList();

    final b = StringBuffer()
      ..writeln('คุณคือผู้ช่วยบันทึกชีวิตส่วนตัว แปลงข้อความภาษาธรรมชาติเป็นการบันทึกที่ถูกต้อง แล้วตอบเป็น JSON เท่านั้น')
      ..writeln('วันนี้: ${ymd(now)} (วัน${thWeekdays[now.weekday - 1]}) · ใช้ปี ค.ศ. เสมอ (พ.ศ. − 543)')
      ..writeln()
      ..writeln('## หมวด (category) — ใช้ key เท่านั้น')
      ..writeln([for (final c in state.categories) '- ${c.key}: ${c.description.isEmpty ? c.label : c.description}'].join('\n'))
      ..writeln()
      ..writeln('## metric — ใช้ key เท่านั้น แปลงค่าเป็นหน่วยนี้ก่อน')
      ..writeln([for (final m in state.metricDefs) '- ${m.key} (${m.unit.isEmpty ? 'ไม่มีหน่วย' : m.unit})${m.description.isEmpty ? '' : ': ${m.description}'}'].join('\n'))
      ..writeln()
      ..writeln('## รายการที่มีอยู่ (อ้างถึงด้วยรหัส R…)')
      ..writeln('กำลังจะมาถึง:')
      ..writeln(upcoming.isEmpty ? '- (ไม่มี)' : upcoming.take(10).map(line).join('\n'))
      ..writeln('14 วันล่าสุด:')
      ..writeln(recent.isEmpty ? '- (ไม่มี)' : recent.map(line).join('\n'));
    if (open.isNotEmpty) {
      b.writeln('checklist ที่ยังค้าง:');
      for (final e in open) {
        final r = refs.entries.firstWhere((x) => x.value == e.id, orElse: () => MapEntry(ref(e), e.id!)).key;
        b.writeln('- $r ${e.title}: ${e.checklist!.open.join(' | ')}');
      }
    }
    b
      ..writeln()
      ..writeln(_rules)
      ..writeln(_schema);
    return b.toString();
  }

  static const _rules = '''
## กฎการตัดสินใจ
- ผู้ใช้เล่าว่าทำหรือเจออะไร แม้สั้นมาก (เช่น "กินข้าวเย็น" "ไปวิ่งมา") → ต้องมีอย่างน้อย 1 action: create kind "daily" (ไม่บอกวัน = วันนี้) ใส่เรื่องที่เล่าใน body
- ตัวเลขประจำ (น้ำหนัก การนอน อารมณ์ ก้าวเดิน) และโน้ตสั้นประจำวัน → create kind "daily" (วันละ 1 รายการ ระบบรวมกับของเดิมให้)
- เรื่องที่ควรเห็นบน timeline (ทริป นัดหมาย ซื้อของใหญ่ สอบ เปลี่ยนงาน) → create kind "event"; หลายวันใส่ end_date
- จ่ายหรือเกิดเป็นรอบ (ค่างวด ค่าสมาชิก วันเกิดคนสำคัญ) → ใส่ every: daily/weekly/monthly/yearly หรือ 2w, 3m, 1y และ times ถ้ารู้จำนวนครั้ง
- milestone เฉพาะจุดเปลี่ยนชีวิตจริงๆ
- ผู้ใช้บอกว่าทำสิ่งใน checklist แล้ว → type "check" กับรายการเดิม ห้ามสร้างรายการใหม่
- แผนเปลี่ยน (เลื่อนวัน เปลี่ยนชื่อ) → type "update" กับรายการเดิม
- แผนที่ต้องเตรียมตัว → ใส่ checklist ใน body เป็นบรรทัด "- [ ] ..."
- ตัวเลขที่จะติดตามซ้ำแต่ไม่มี key → type "new_metric" ก่อน แล้วค่อยใช้ key นั้น; ตัวเลขครั้งเดียวให้เขียนใน body
- ห้ามแต่งข้อมูลที่ผู้ใช้ไม่ได้บอก; ถ้าขาดข้อมูลสำคัญ (วันที่ของเรื่องใหญ่ จำนวนเงิน) ให้ถามใน questions และไม่ต้องสร้าง action นั้น
- title สั้น กระชับ เป็นภาษาไทย; reply สรุปสั้นๆ ว่าจะบันทึกอะไร (1–2 ประโยค)''';

  static const _schema = '''
## รูปแบบคำตอบ (JSON object เท่านั้น ไม่มีข้อความอื่น)
{"reply": "...", "questions": ["..."], "actions": [
  {"type": "create", "kind": "event", "date": "YYYY-MM-DD", "end_date": null, "category": "travel", "title": "...", "body": "...", "metrics": [{"key": "weight", "value": 74.5}], "every": null, "times": null},
  {"type": "create", "kind": "daily", "date": "YYYY-MM-DD", "category": "daily", "title": "กินข้าวเย็น", "body": "กินข้าวเย็น"},
  {"type": "update", "ref": "R2", "date": "YYYY-MM-DD", "end_date": null, "title": "...", "body": "..."},
  {"type": "check", "ref": "R3", "item": "ข้อความใน checklist", "done": true},
  {"type": "new_metric", "key": "water", "label": "ดื่มน้ำ", "unit": "ลิตร"}
]}
update ใส่เฉพาะฟิลด์ที่เปลี่ยน
actions ว่างได้เฉพาะเมื่อเป็นคำทักทาย คำถาม หรือต้องถามข้อมูลเพิ่มก่อน — ถ้า actions ว่าง ห้ามบอกใน reply ว่าบันทึกแล้วหรือจะบันทึก''';

  /// แปลงคำตอบของ AI → AiResult (ตรวจทุก action ด้วยกฎเดียวกับฐานข้อมูล)
  AiResult parse(String raw, DateTime now) {
    final json = _extractJson(raw);
    if (json == null) {
      return AiResult(reply: 'AI ตอบกลับในรูปแบบที่อ่านไม่ได้ ลองพิมพ์ใหม่อีกครั้ง', questions: const [], actions: const [], raw: raw);
    }
    final newMetrics = <String, MetricDef>{};
    final actions = <ProposedAction>[];
    for (final a in (json['actions'] as List? ?? const []).whereType<Map>()) {
      final m = Map<String, dynamic>.from(a);
      actions.add(switch (m['type']) {
        'new_metric' => _newMetric(m, newMetrics),
        'create' => _create(m, now, newMetrics),
        'update' => _update(m),
        'check' => _check(m),
        _ => ProposedAction(type: '?', summary: 'คำสั่งที่ไม่รู้จัก: ${m['type']}', errors: const ['ไม่รองรับ']),
      });
    }
    return AiResult(
      reply: (json['reply'] as String?)?.trim() ?? '',
      questions: [for (final q in (json['questions'] as List? ?? const [])) if ('$q'.trim().isNotEmpty) '$q'.trim()],
      actions: actions,
      raw: json,
    );
  }

  ProposedAction _newMetric(Map<String, dynamic> m, Map<String, MetricDef> pending) {
    final key = '${m['key'] ?? ''}'.trim().toLowerCase();
    final def = MetricDef(key: key, label: '${m['label'] ?? key}'.trim(), unit: '${m['unit'] ?? ''}'.trim());
    final errors = <String>[
      if (!RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(key)) 'ชื่อ metric ต้องเป็นภาษาอังกฤษตัวเล็ก เช่น water',
      if (state.metricKeys.contains(key)) 'มี metric "$key" อยู่แล้ว',
    ];
    if (errors.isEmpty) pending[key] = def;
    return ProposedAction(
      type: 'new_metric',
      summary: 'เพิ่มตัวเลขใหม่ที่จะติดตาม: ${def.label}${def.unit.isEmpty ? '' : ' (${def.unit})'}',
      errors: errors,
      run: (s) => s.addMetricDef(def),
    );
  }

  ProposedAction _create(Map<String, dynamic> m, DateTime now, Map<String, MetricDef> pending) {
    final errors = <String>[];
    final date = _date(m['date'], errors, 'date') ?? now;
    final end = m['end_date'] == null ? null : _date(m['end_date'], errors, 'end_date');
    final every = (m['every'] as String?)?.trim();
    final times = (m['times'] as num?)?.toInt();
    final kind = m['kind'] == 'daily' ? 'daily' : 'event';
    final metrics = <MetricValue>[];
    for (final x in (m['metrics'] as List? ?? const []).whereType<Map>()) {
      final key = '${x['key']}'.trim();
      final value = (x['value'] is num) ? (x['value'] as num).toDouble() : double.tryParse('${x['value']}'.replaceAll(',', ''));
      if (value == null) {
        errors.add('ค่า $key ไม่ใช่ตัวเลข');
        continue;
      }
      metrics.add(MetricValue(key, value, pending[key]?.unit ?? state.metricUnit(key)));
    }
    final entry = Entry(
      kind: kind,
      date: date,
      endDate: end,
      category: '${m['category'] ?? (kind == 'daily' ? 'daily' : '')}'.trim(),
      title: '${m['title'] ?? ''}'.trim(),
      body: '${m['body'] ?? ''}'.trim(),
      recurrence: (every == null || every.isEmpty) ? null : Recurrence(every.toLowerCase(), times: times),
      source: 'ai',
      metrics: metrics,
    );
    errors.addAll(validateEntry(entry, categories: state.categoryKeys, metricKeys: {...state.metricKeys, ...pending.keys}));

    // daily ของวันเดียวกันมีอยู่แล้ว → รวมเข้าไปแทนการสร้างใหม่
    final existingDaily = kind == 'daily' ? state.dailyOn(date) : null;
    if (existingDaily != null) {
      var merged = existingDaily;
      final changes = <String>[];
      for (final mv in metrics) {
        final old = merged.metrics.where((x) => x.key == mv.key).firstOrNull;
        if (old != null && old.value != mv.value) changes.add('${state.metricLabel(mv.key)} ${_num(old.value)} → ${_num(mv.value)}');
        merged = merged.copyWith(metrics: [...merged.metrics.where((x) => x.key != mv.key), mv]);
      }
      // บันทึกวันนั้นมีชื่ออยู่แล้วและโน้ตใหม่มีแค่ชื่อ → เก็บชื่อนั้นเป็นเนื้อหา ไม่ให้หาย
      final titleOnly = entry.body.isEmpty && merged.title.isNotEmpty && entry.title != merged.title;
      final note = titleOnly ? entry.title : entry.body;
      if (note.isNotEmpty) {
        merged = merged.copyWith(body: [merged.body, note].where((s) => s.isNotEmpty).join('\n\n'));
      }
      if (merged.title.isEmpty) merged = merged.copyWith(title: entry.title);
      final result = merged;
      return ProposedAction(
        type: 'update',
        summary: 'เพิ่มในบันทึกวันที่ ${fmtDate(date)}: ${[if (metrics.isNotEmpty) _describeMetrics(metrics), if (note.isNotEmpty) 'โน้ต'].join(' + ')}',
        detail: [if (changes.isNotEmpty) 'แทนค่าเดิม: ${changes.join(', ')}', if (note.isNotEmpty) note].join('\n'),
        errors: errors,
        entry: result,
        run: (s) => s.save(result),
      );
    }

    if (kind == 'event' && entry.title.isNotEmpty) {
      final dup = state.entries.where((e) => e.date == date && e.title.trim() == entry.title).firstOrNull;
      if (dup != null) errors.add('มี "${entry.title}" วันที่ ${fmtDate(date)} อยู่แล้ว');
    }
    final when = entry.recurrence != null
        ? '${entry.recurrence!.label} เริ่ม ${fmtDate(date)}${times == null ? '' : ' · $times ครั้ง'}'
        : end == null
            ? fmtDate(date)
            : '${fmtDate(date)} – ${fmtDate(end)}';
    final cat = state.category(entry.category).label;
    return ProposedAction(
      type: 'create',
      summary: kind == 'daily'
          ? 'บันทึกวันที่ ${fmtDate(date)}: ${[if (metrics.isNotEmpty) _describeMetrics(metrics), if (entry.title.isNotEmpty) entry.title].join(' · ')}'
          : 'เพิ่ม "${entry.title}" · $cat · $when',
      detail: [if (kind != 'daily' && metrics.isNotEmpty) _describeMetrics(metrics), if (entry.body.isNotEmpty) entry.body].join('\n'),
      errors: errors,
      entry: entry,
      run: (s) => s.save(entry),
    );
  }

  ProposedAction _update(Map<String, dynamic> m) {
    final target = _target(m['ref']);
    if (target == null) return ProposedAction(type: 'update', summary: 'แก้ไขรายการ ${m['ref']}', errors: const ['ไม่พบรายการที่อ้างถึง']);
    final errors = <String>[];
    var e = target;
    final changes = <String>[];
    if (m.containsKey('date') && m['date'] != null) {
      final d = _date(m['date'], errors, 'date');
      if (d != null && d != e.date) {
        changes.add('วันที่ ${fmtDate(e.date)} → ${fmtDate(d)}');
        e = e.copyWith(date: d);
      }
    }
    if (m.containsKey('end_date')) {
      final d = m['end_date'] == null ? null : _date(m['end_date'], errors, 'end_date');
      if (d != e.endDate) {
        changes.add('ถึงวันที่ → ${d == null ? 'ไม่มี' : fmtDate(d)}');
        e = e.copyWith(endDate: d);
      }
    }
    for (final f in ['title', 'body', 'category']) {
      final v = m[f];
      if (v is String && v.trim().isNotEmpty) {
        final old = switch (f) { 'title' => e.title, 'body' => e.body, _ => e.category };
        if (v.trim() == old.trim()) continue;
        switch (f) {
          case 'title':
            changes.add('ชื่อ → ${v.trim()}');
            e = e.copyWith(title: v.trim());
          case 'body':
            changes.add('แก้เนื้อหา');
            e = e.copyWith(body: v.trim());
          case 'category':
            changes.add('หมวด → ${state.category(v.trim()).label}');
            e = e.copyWith(category: v.trim());
        }
      }
    }
    errors.addAll(state.validate(e));
    final updated = e;
    if (changes.isEmpty) errors.add('ไม่มีอะไรเปลี่ยน');
    return ProposedAction(
      type: 'update',
      summary: 'แก้ไข "${target.title}": ${changes.join(' · ')}',
      errors: errors,
      entry: updated,
      run: (s) => s.save(updated),
    );
  }

  ProposedAction _check(Map<String, dynamic> m) {
    final target = _target(m['ref']);
    final item = '${m['item'] ?? ''}'.trim();
    final done = m['done'] != false;
    if (target == null) return ProposedAction(type: 'check', summary: 'ติ๊ก "$item"', errors: const ['ไม่พบรายการที่อ้างถึง']);
    final index = findCheck(target.body, item);
    if (index == null) {
      return ProposedAction(type: 'check', summary: 'ติ๊ก "$item" ใน ${target.title}', errors: const ['ไม่พบข้อนี้ใน checklist']);
    }
    final text = parseMarkdown(target.body).whereType<MdCheck>().firstWhere((c) => c.index == index).text;
    return ProposedAction(
      type: 'check',
      summary: '${done ? '✓ เสร็จแล้ว' : 'ยกเลิกติ๊ก'}: $text (${target.title})',
      run: (s) => s.toggleCheck(target, index, done),
    );
  }

  Entry? _target(Object? ref) {
    final id = refs['$ref'.trim().toUpperCase()];
    return id == null ? null : state.byId(id);
  }

  DateTime? _date(Object? v, List<String> errors, String field) {
    final s = '$v'.trim();
    final y = int.tryParse(s.length >= 4 ? s.substring(0, 4) : '');
    if (y != null && y > 2400) {
      errors.add('$field $s ดูเหมือนเป็น พ.ศ.');
      return null;
    }
    final d = parseYmd(s);
    if (d == null) errors.add('$field "$s" ไม่ใช่วันที่ที่ถูกต้อง');
    return d;
  }

  String _describeMetrics(List<MetricValue> ms) =>
      ms.map((m) => '${state.metricLabel(m.key)} ${_num(m.value)}${m.unit.isEmpty ? '' : ' ${m.unit}'}').join(', ');

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static Map<String, dynamic>? _extractJson(String raw) {
    var s = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(s);
    if (fence != null) s = fence[1]!.trim();
    final start = s.indexOf('{'), end = s.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final v = jsonDecode(s.substring(start, end + 1));
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }
}
