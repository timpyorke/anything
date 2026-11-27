import 'dart:convert';
import 'dart:ui' show Color;

import '../../ai/llm_provider.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/markdown.dart';
import '../../domain/category.dart';
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

  final String type; // create | update | check | new_category | new_metric
  final String summary;
  final String detail;
  final List<String> errors;
  final Future<void> Function(DiaryViewModel diary)? run;
  final Entry? entry; // สำหรับเปิดแก้ไขเองก่อนบันทึก
  final bool selected;
  bool get valid => errors.isEmpty && run != null;

  /// สร้างหมวด/metric ใหม่ — ต้องทำก่อน action อื่นที่ใช้ key นั้น
  bool get isDefinition => type == 'new_category' || type == 'new_metric';

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

/// ข้อความของผู้ใช้ 1 ครั้งกับสิ่งที่ AI ตอบ ([result] ว่าง = รอบนั้นเรียก AI ไม่สำเร็จ)
typedef Exchange = ({String message, AiResult? result});

class Recorder {
  Recorder(this.state, {DateTime Function()? clock}) : _clock = clock ?? today;
  final DiaryState state;
  final DateTime Function() _clock;

  /// รหัสสั้น (R1, R2, …) แทน uuid ในพรอมต์ — ประหยัด token และ AI อ้าง id มั่วไม่ได้
  final Map<String, String> refs = {};

  Future<AiResult> run(LlmProvider provider, String message, {List<Exchange> history = const [], Future<void>? cancel}) async {
    final now = _clock();
    final system = systemPrompt(now);
    final raw = await provider.generateJson(system: system, user: userPrompt(message, history), cancel: cancel);
    return parse(raw, now);
  }

  /// ข้อความที่ส่งให้ AI — ถ้าเป็นการตอบต่อ แนบบทสนทนาก่อนหน้าไปด้วยเพราะ AI จำเองไม่ได้
  String userPrompt(String message, List<Exchange> history) {
    if (history.isEmpty) return 'ข้อความจากผู้ใช้:\n$message';
    final b = StringBuffer('บทสนทนาก่อนหน้า:\n');
    for (final h in history) {
      b.writeln('ผู้ใช้: ${h.message}');
      final r = h.result;
      if (r == null) continue;
      b.writeln('ผู้ช่วย: ${r.reply}');
      if (r.questions.isNotEmpty) b.writeln('ผู้ช่วยถาม: ${r.questions.join(' / ')}');
      final offered = r.actions.where((a) => a.valid).map((a) => a.summary);
      if (offered.isNotEmpty) b.writeln('ผู้ช่วยเสนอ (ยังไม่ได้บันทึก): ${offered.join(' / ')}');
    }
    b
      ..writeln()
      ..writeln('ข้อความล่าสุดจากผู้ใช้:')
      ..writeln(message)
      ..writeln()
      ..write('ตอบข้อความล่าสุดโดยใช้บทสนทนาข้างบนประกอบ ห้ามถามซ้ำ; actions ต้องครบทุกอย่างที่ยังไม่ได้บันทึก เพราะชุดใหม่จะแทนชุดที่เสนอไว้');
    return b.toString();
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

    // บันทึกรายวันของวันนี้อยู่ใน "14 วันล่าสุด" แล้ว ไม่ให้แย่งที่ของแผนข้างหน้า
    final upcoming = state.entries.where((e) => !e.hidden && !e.isDaily && e.isUpcoming(now)).toList()
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
      ..writeln('## หมวด (category) — อ้างด้วย key')
      ..writeln(state.categories.isEmpty
          ? '- (ยังไม่มี)'
          : [for (final c in state.categories) '- ${c.key}: ${c.description.isEmpty ? c.label : c.description}'].join('\n'))
      ..writeln()
      ..writeln('## metric — อ้างด้วย key แปลงค่าเป็นหน่วยนี้ก่อน')
      ..writeln(state.metricDefs.isEmpty
          ? '- (ยังไม่มี)'
          : [for (final m in state.metricDefs) '- ${m.key} (${m.unit.isEmpty ? 'ไม่มีหน่วย' : m.unit})${m.description.isEmpty ? '' : ': ${m.description}'}'].join('\n'))
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
- ตอบทุกข้อความ: reply ห้ามว่าง — ทักทายก็ทักตอบ; ถูกถามก็ตอบจากรายการที่เห็นด้านบน ถ้าไม่พบให้บอกตรงๆ ว่าไม่พบ
- ผู้ใช้เล่าว่าทำหรือเจออะไร แม้สั้นมาก (เช่น "กินข้าวเย็น" "ไปวิ่งมา") → ต้องมีอย่างน้อย 1 action: create kind "daily" (ไม่บอกวัน = วันนี้) ใส่เรื่องที่เล่าใน body
- ตัวเลขประจำ (น้ำหนัก การนอน อารมณ์ ก้าวเดิน) และโน้ตสั้นประจำวัน → create kind "daily" มี title เสมอ (วันหนึ่งมีได้หลายรายการ)
- เล่าหลายเรื่องในข้อความเดียว → แยก 1 เรื่อง = 1 action ห้ามรวม ตัวเลขใส่ใน action ของเรื่องนั้น
- เรื่องที่ควรเห็นบน timeline (ทริป นัดหมาย ซื้อของใหญ่ สอบ เปลี่ยนงาน) → create kind "event"; หลายวันใส่ end_date
- จ่ายหรือเกิดเป็นรอบ (ค่างวด ค่าสมาชิก วันเกิดคนสำคัญ) → ใส่ every: daily/weekly/monthly/yearly หรือ 2w, 3m, 1y และ times ถ้ารู้จำนวนครั้ง
- milestone เฉพาะจุดเปลี่ยนชีวิตจริงๆ
- ผู้ใช้บอกว่าทำสิ่งใน checklist แล้ว → type "check" กับรายการเดิม ห้ามสร้างรายการใหม่
- แผนเปลี่ยน (เลื่อนวัน เปลี่ยนชื่อ) หรือแก้ตัวเลขที่บันทึกแล้ว → type "update" กับรายการเดิม
- แผนที่ต้องเตรียมตัว → ใส่ checklist ใน body เป็นบรรทัด "- [ ] ..."
- วันที่ที่ไม่บอกปี: เรื่องที่วางแผนไว้ใช้ครั้งถัดไปนับจากวันนี้ เรื่องที่เกิดแล้วใช้ครั้งล่าสุด ("ปีหน้า" = ปีของวันนี้ + 1)
- เรื่องที่มีอยู่แล้วในรายการ → อ้างรายการนั้น (update/check) ไม่สร้างซ้ำ; ไม่มีอะไรใหม่ก็ตอบว่ามีบันทึกแล้ว
- เลือกหมวดเดิมที่ตรงความหมายก่อน; ไม่มีหมวดที่ตรง (หรือยังไม่มีหมวด) หรือผู้ใช้ขอหมวดใหม่ → type "new_category" แล้วใช้ key นั้นใน action ถัดไป ห้ามทิ้งเรื่องเพราะไม่มีหมวด
- ตัวเลขที่ควรติดตามซ้ำแต่ไม่มี key → type "new_metric" แล้วใช้ key นั้นใน action ถัดไป; ตัวเลขครั้งเดียวให้เขียนใน body
- ใช้ key ได้เฉพาะที่มีในรายการด้านบน หรือที่สร้างใน actions ชุดเดียวกัน
- ลงมือเสนอ action จากข้อมูลที่มีก่อน ผู้ใช้ตรวจและแก้ได้ก่อนบันทึก
- ห้ามถามสิ่งที่ตัดสินใจเองได้ (หมวด kind title จะบันทึกหรือไม่) และห้ามถามรายละเอียดเสริมที่ไม่จำเป็น (งบประมาณ ความสนใจ)
- ห้ามแต่งข้อมูลที่ผู้ใช้ไม่ได้บอก; ถามได้เฉพาะเมื่อขาดข้อมูลจนสร้าง action ไม่ได้ (เช่น วันที่ของนัดหมาย จำนวนเงินของค่างวด) ถามข้อเดียวใน questions และ reply บอกว่ารอข้อมูลอะไร
- title สั้น กระชับ เป็นภาษาไทย; reply สั้น (1–2 ประโยค): สรุปว่าจะบันทึกอะไร หรือตอบสิ่งที่ถูกถาม''';

  static const _schema = '''
## รูปแบบคำตอบ (JSON object เท่านั้น ไม่มีข้อความอื่น)
{"reply": "...", "questions": [], "actions": [
  {"type": "new_category", "key": "pet", "label": "สัตว์เลี้ยง", "description": "เรื่องของสัตว์เลี้ยง: อาหาร หาหมอ วัคซีน"},
  {"type": "create", "kind": "event", "date": "YYYY-MM-DD", "end_date": null, "category": "travel", "title": "...", "body": "...", "metrics": [{"key": "weight", "value": 74.5}], "every": null, "times": null},
  {"type": "create", "kind": "daily", "date": "YYYY-MM-DD", "category": "daily", "title": "กินข้าวเย็น", "body": "กินข้าวเย็น"},
  {"type": "update", "ref": "R2", "date": "YYYY-MM-DD", "end_date": null, "title": "...", "body": "..."},
  {"type": "check", "ref": "R3", "item": "ข้อความใน checklist", "done": true},
  {"type": "new_metric", "key": "water", "label": "ดื่มน้ำ", "unit": "ลิตร"}
]}
update ใส่เฉพาะฟิลด์ที่เปลี่ยน (แก้ตัวเลขใส่ metrics แบบเดียวกับ create)
questions ปกติเป็น [] ว่าง
actions ว่างได้เฉพาะเมื่อเป็นคำทักทาย คำถาม หรือต้องถามข้อมูลเพิ่มก่อน — ถ้า actions ว่าง ห้ามบอกใน reply ว่าบันทึกแล้วหรือจะบันทึก''';

  /// แปลงคำตอบของ AI → AiResult (ตรวจทุก action ด้วยกฎเดียวกับฐานข้อมูล)
  AiResult parse(String raw, DateTime now) {
    final json = _extractJson(raw);
    if (json == null) {
      return AiResult(reply: 'AI ตอบกลับในรูปแบบที่อ่านไม่ได้ ลองพิมพ์ใหม่อีกครั้ง', questions: const [], actions: const [], raw: raw);
    }
    final newCategories = <String, EntryCategory>{};
    final newMetrics = <String, MetricDef>{};
    final proposed = [for (final a in (json['actions'] as List? ?? const []).whereType<Map>()) Map<String, dynamic>.from(a)];
    bool isDefinition(Map<String, dynamic> m) => m['type'] == 'new_category' || m['type'] == 'new_metric';
    final actions = <ProposedAction>[];
    // ตรวจการสร้างหมวด/metric ก่อน เผื่อ AI เรียงไว้หลัง action ที่ใช้ key นั้น
    for (final m in [...proposed.where(isDefinition), ...proposed.where((m) => !isDefinition(m))]) {
      actions.add(switch (m['type']) {
        'new_category' => _newCategory(m, newCategories),
        'new_metric' => _newMetric(m, newMetrics),
        'create' => _create(m, now, newCategories, newMetrics),
        'update' => _update(m, newCategories, newMetrics),
        'check' => _check(m),
        _ => ProposedAction(type: '?', summary: 'คำสั่งที่ไม่รู้จัก: ${m['type']}', errors: const ['ไม่รองรับ']),
      });
    }
    final questions = [for (final q in (json['questions'] as List? ?? const [])) if ('$q'.trim().isNotEmpty) '$q'.trim()];
    var reply = '${json['reply'] ?? ''}'.trim();
    // โมเดลเล็กอาจไม่ใส่ reply — ผู้ใช้ต้องได้คำตอบเสมอ
    if (reply.isEmpty) {
      reply = actions.any((a) => a.valid)
          ? 'ตรวจรายการด้านล่างก่อนบันทึก'
          : questions.isNotEmpty
              ? 'ขอข้อมูลเพิ่มอีกนิด'
              : 'ยังไม่มีคำตอบ ลองพิมพ์ใหม่อีกครั้ง';
    }
    return AiResult(
      reply: reply,
      questions: questions,
      actions: actions,
      raw: json,
    );
  }

  /// สีของหมวดใหม่ (โทนเดียวกับหมวดเริ่มต้น) วนใช้ตามลำดับ
  static const _palette = [0xffe5484d, 0xffb7791f, 0xff30a46c, 0xfff76b15, 0xff3e63dd, 0xff8e4ec6, 0xffd6409f, 0xff12a594];

  ProposedAction _newCategory(Map<String, dynamic> m, Map<String, EntryCategory> pending) {
    final key = '${m['key'] ?? ''}'.trim().toLowerCase();
    final label = '${m['label'] ?? key}'.trim();
    final count = state.categories.length + pending.length;
    final category = EntryCategory(
      key: key,
      label: label,
      color: Color(_palette[count % _palette.length]),
      description: '${m['description'] ?? ''}'.trim(),
      sort: [...state.categories, ...pending.values].fold(0, (next, c) => c.sort >= next ? c.sort + 1 : next),
    );
    final errors = <String>[
      if (!_keyPattern.hasMatch(key)) 'ชื่อ key ของหมวดต้องเป็นภาษาอังกฤษตัวเล็ก เช่น pet',
      if (label.isEmpty || label.length > 40) 'ชื่อหมวดต้องยาว 1–40 ตัวอักษร',
      if (state.categoryKeys.contains(key) || pending.containsKey(key)) 'มีหมวด "$key" อยู่แล้ว',
    ];
    if (errors.isEmpty) pending[key] = category;
    return ProposedAction(
      type: 'new_category',
      summary: 'สร้างหมวดใหม่: $label',
      detail: category.description,
      errors: errors,
      run: (s) => s.addCategory(category),
    );
  }

  ProposedAction _newMetric(Map<String, dynamic> m, Map<String, MetricDef> pending) {
    final key = '${m['key'] ?? ''}'.trim().toLowerCase();
    final def = MetricDef(key: key, label: '${m['label'] ?? key}'.trim(), unit: '${m['unit'] ?? ''}'.trim());
    final errors = <String>[
      if (!_keyPattern.hasMatch(key)) 'ชื่อ metric ต้องเป็นภาษาอังกฤษตัวเล็ก เช่น water',
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

  ProposedAction _create(Map<String, dynamic> m, DateTime now, Map<String, EntryCategory> newCategories, Map<String, MetricDef> pending) {
    final errors = <String>[];
    final date = _date(m['date'], errors, 'date') ?? now;
    final end = m['end_date'] == null ? null : _date(m['end_date'], errors, 'end_date');
    final every = (m['every'] as String?)?.trim();
    final times = (m['times'] as num?)?.toInt();
    final kind = m['kind'] == 'daily' ? 'daily' : 'event';
    final metrics = _metrics(m, errors, pending);
    final body = '${m['body'] ?? ''}'.trim();
    var title = '${m['title'] ?? ''}'.trim();
    // รายการที่ไม่มีทั้งชื่อและเนื้อหาจะไม่ขึ้น timeline → ใช้ตัวเลขเป็นชื่อ
    if (kind == 'daily' && title.isEmpty && body.isEmpty) title = _describeMetrics(metrics, pending);
    final entry = Entry(
      kind: kind,
      date: date,
      endDate: end,
      category: '${m['category'] ?? (kind == 'daily' ? 'daily' : '')}'.trim(),
      title: title,
      body: body,
      recurrence: (every == null || every.isEmpty) ? null : Recurrence(every.toLowerCase(), times: times),
      source: 'ai',
      metrics: metrics,
    );
    errors.addAll(validateEntry(entry,
        categories: {...state.categoryKeys, ...newCategories.keys}, metricKeys: {...state.metricKeys, ...pending.keys}));

    // กันบันทึกซ้ำ: เหตุการณ์ดูแค่ชื่อกับวัน ส่วนบันทึกรายวันมีชื่อซ้ำได้ จึงต้องเหมือนกันทุกอย่าง
    final duplicate = state.entries.any((e) =>
        e.date == date &&
        e.title.trim() == entry.title &&
        (kind == 'daily'
            ? e.isDaily && e.body.trim() == entry.body && _metricSet(e.metrics) == _metricSet(metrics)
            : entry.title.isNotEmpty));
    if (duplicate) errors.add('มี "${entry.title}" วันที่ ${fmtDate(date)} อยู่แล้ว');
    final when = entry.recurrence != null
        ? '${entry.recurrence!.label} เริ่ม ${fmtDate(date)}${times == null ? '' : ' · $times ครั้ง'}'
        : end == null
            ? fmtDate(date)
            : '${fmtDate(date)} – ${fmtDate(end)}';
    final cat = (newCategories[entry.category] ?? state.category(entry.category)).label;
    return ProposedAction(
      type: 'create',
      summary: kind == 'daily'
          // เป็น set เพราะชื่ออาจมาจากตัวเลขเอง
          ? 'บันทึกวันที่ ${fmtDate(date)}: ${<String>{if (entry.title.isNotEmpty) entry.title, if (metrics.isNotEmpty) _describeMetrics(metrics, pending)}.join(' · ')}'
          : 'เพิ่ม "${entry.title}" · $cat · $when',
      detail: [if (kind != 'daily' && metrics.isNotEmpty) _describeMetrics(metrics, pending), if (entry.body.isNotEmpty) entry.body].join('\n'),
      errors: errors,
      entry: entry,
      run: (s) => s.save(entry),
    );
  }

  ProposedAction _update(Map<String, dynamic> m, Map<String, EntryCategory> newCategories, Map<String, MetricDef> pending) {
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
            changes.add('หมวด → ${(newCategories[v.trim()] ?? state.category(v.trim())).label}');
            e = e.copyWith(category: v.trim());
        }
      }
    }
    for (final mv in _metrics(m, errors, pending)) {
      final old = e.metrics.where((x) => x.key == mv.key).firstOrNull;
      if (old?.value == mv.value) continue;
      final label = pending[mv.key]?.label ?? state.metricLabel(mv.key);
      changes.add(old == null ? _describeMetrics([mv], pending) : '$label ${_num(old.value)} → ${_num(mv.value)}');
      e = e.copyWith(metrics: [...e.metrics.where((x) => x.key != mv.key), mv]);
    }
    errors.addAll(validateEntry(e,
        categories: {...state.categoryKeys, ...newCategories.keys}, metricKeys: {...state.metricKeys, ...pending.keys}));
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

  List<MetricValue> _metrics(Map<String, dynamic> m, List<String> errors, Map<String, MetricDef> pending) {
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
    return metrics;
  }

  String _describeMetrics(List<MetricValue> ms, Map<String, MetricDef> pending) => ms
      .map((m) => '${pending[m.key]?.label ?? state.metricLabel(m.key)} ${_num(m.value)}${m.unit.isEmpty ? '' : ' ${m.unit}'}')
      .join(', ');

  /// ใช้เทียบว่าตัวเลขสองชุดเหมือนกันโดยไม่สนลำดับ
  static String _metricSet(List<MetricValue> ms) => ([for (final m in ms) '${m.key}=${m.value}']..sort()).join(',');

  /// รูปแบบ key เดียวกับ CHECK constraint ของตาราง categories และ metric_defs
  static final _keyPattern = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

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
