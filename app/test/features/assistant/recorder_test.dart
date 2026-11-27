import 'dart:convert';
import 'dart:ui' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/domain/category.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/metric.dart';
import 'package:anything/features/assistant/recorder.dart';
import 'package:anything/features/diary/diary_state.dart';

class FakeLlm implements LlmProvider {
  FakeLlm(this.reply);
  final String reply;
  String? lastSystem;
  @override
  AiProviderKind get kind => AiProviderKind.aiStudio;
  @override
  String get model => 'fake';
  @override
  Future<String> generateJson({required String system, required String user, Future<void>? cancel}) async {
    lastSystem = system;
    return reply;
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 24);
  late DiaryState state;
  late Entry trip, daily;

  setUp(() {
    trip = Entry(
      id: 'trip-id',
      date: DateTime.utc(2027, 1, 22),
      endDate: DateTime.utc(2027, 1, 27),
      category: 'travel',
      title: 'ทริปปักกิ่ง',
      body: '- [ ] ตั๋วเครื่องบิน\n- [ ] วีซ่า / เอกสารเดินทาง',
    );
    daily = Entry(id: 'daily-id', kind: 'daily', date: now, category: 'health', title: 'วัดร่างกาย', metrics: [const MetricValue('weight', 75, 'kg')]);
    state = DiaryState(
      categories: [
        for (final k in ['milestone', 'finance', 'health', 'travel', 'daily'])
          EntryCategory(key: k, label: k, color: const Color(0xff000000)),
      ],
      metricDefs: const [MetricDef(key: 'weight', label: 'น้ำหนัก', unit: 'kg'), MetricDef(key: 'sleep', label: 'การนอน', unit: 'ชม.')],
      entries: [trip, daily],
    );
  });

  Future<AiResult> run(Map<String, Object?> reply) async {
    final r = Recorder(state, clock: () => now);
    return r.run(FakeLlm(jsonEncode(reply)), 'test');
  }

  test('system prompt gives today, vocabulary and short refs instead of ids', () async {
    final llm = FakeLlm('{"reply":"","actions":[]}');
    await Recorder(state, clock: () => now).run(llm, 'x');
    expect(llm.lastSystem, contains('2026-11-24'));
    expect(llm.lastSystem, contains('- travel'));
    expect(llm.lastSystem, contains('weight (kg)'));
    expect(llm.lastSystem, contains('R1'));
    expect(llm.lastSystem, isNot(contains('trip-id')));
  });

  test('daily metrics merge into the existing daily entry of that day', () async {
    final r = await run({
      'reply': 'ok',
      'actions': [
        {'type': 'create', 'kind': 'daily', 'date': '2026-11-24', 'category': 'health', 'metrics': [{'key': 'weight', 'value': 74.5}, {'key': 'sleep', 'value': 7}]},
      ],
    });
    final a = r.actions.single;
    expect(a.type, 'update');
    expect(a.valid, isTrue);
    expect(a.detail, contains('75 → 74.5'));
    expect(a.entry!.id, 'daily-id');
    expect(a.entry!.metrics.map((m) => m.key), containsAll(['weight', 'sleep']));
  });

  test('title-only daily note is kept when merged into that day', () async {
    final r = await run({
      'actions': [
        {'type': 'create', 'kind': 'daily', 'date': '2026-11-24', 'category': 'daily', 'title': 'กินข้าวเย็น'},
      ],
    });
    final a = r.actions.single;
    expect(a.valid, isTrue);
    expect(a.entry!.title, 'วัดร่างกาย');
    expect(a.entry!.body, 'กินข้าวเย็น');
    expect(a.summary, endsWith(': โน้ต'));
    expect(a.detail, 'กินข้าวเย็น');
  });

  test('prompt tells the model to record even a short daily activity', () {
    final prompt = Recorder(state, clock: () => now).systemPrompt(now);
    expect(prompt, contains('ต้องมีอย่างน้อย 1 action'));
    expect(prompt, contains('"kind": "daily"'));
  });

  test('check action resolves the ref and the loosely worded item', () async {
    final rec = Recorder(state, clock: () => now);
    final llm = FakeLlm('');
    await rec.run(FakeLlm('{"actions":[]}'), 'x'); // สร้าง refs
    final ref = rec.refs.entries.firstWhere((e) => e.value == 'trip-id').key;
    final r = rec.parse(jsonEncode({'actions': [{'type': 'check', 'ref': ref, 'item': 'วีซ่า', 'done': true}]}), now);
    expect(llm.kind, AiProviderKind.aiStudio);
    expect(r.actions.single.valid, isTrue);
    expect(r.actions.single.summary, contains('วีซ่า / เอกสารเดินทาง'));
  });

  test('invalid actions are kept but not selectable', () async {
    final r = await run({
      'actions': [
        {'type': 'create', 'kind': 'event', 'date': '2569-12-01', 'category': 'travel', 'title': 'x'},
        {'type': 'create', 'kind': 'event', 'date': '2026-12-01', 'category': 'sport', 'title': 'y'},
        {'type': 'create', 'kind': 'event', 'date': '2026-12-01', 'category': 'health', 'title': 'z', 'metrics': [{'key': 'bmi', 'value': 22}]},
        {'type': 'check', 'ref': 'R99', 'item': 'x'},
      ],
    });
    expect(r.actions.map((a) => a.valid), everyElement(isFalse));
    expect(r.actions.map((a) => a.selected), everyElement(isFalse));
    expect(r.actions[0].errors.join(), contains('พ.ศ.'));
  });

  test('new_metric makes the metric usable in the same reply', () async {
    final r = await run({
      'actions': [
        {'type': 'new_metric', 'key': 'water', 'label': 'ดื่มน้ำ', 'unit': 'ลิตร'},
        {'type': 'create', 'kind': 'daily', 'date': '2026-11-23', 'category': 'health', 'metrics': [{'key': 'water', 'value': 2}]},
      ],
    });
    expect(r.actions.map((a) => a.valid), [true, true]);
    expect(r.actions[1].entry!.metrics.single.unit, 'ลิตร');
  });

  test('new_category is usable in the same reply, even when listed after its use', () async {
    final r = await run({
      'actions': [
        {'type': 'create', 'kind': 'event', 'date': '2026-12-01', 'category': 'pet', 'title': 'พาแมวหาหมอ'},
        {'type': 'update', 'ref': 'R1', 'category': 'pet'},
        {'type': 'new_category', 'key': 'pet', 'label': 'สัตว์เลี้ยง'},
      ],
    });
    expect(r.actions.map((a) => a.type), ['new_category', 'create', 'update']);
    expect(r.actions.map((a) => a.valid), everyElement(isTrue));
    expect(r.actions[1].summary, contains('สัตว์เลี้ยง'));
    expect(r.actions[2].summary, contains('สัตว์เลี้ยง'));
  });

  test('new_category rejects existing, repeated and malformed keys', () async {
    final r = await run({
      'actions': [
        {'type': 'new_category', 'key': 'travel', 'label': 'เที่ยว'},
        {'type': 'new_category', 'key': 'pet', 'label': 'สัตว์เลี้ยง'},
        {'type': 'new_category', 'key': 'pet', 'label': 'สัตว์'},
        {'type': 'new_category', 'key': 'งานบ้าน', 'label': 'งานบ้าน'},
      ],
    });
    expect(r.actions.map((a) => a.valid), [false, true, false, false]);
  });

  test('prompt asks for a reply every time and creating what is missing', () {
    final prompt = Recorder(const DiaryState(), clock: () => now).systemPrompt(now);
    expect(prompt, contains('reply ห้ามว่าง'));
    expect(prompt, contains('(ยังไม่มี)'));
    expect(prompt, contains('"new_category"'));
    expect(prompt, contains('"new_metric"'));
  });

  test('an empty reply from the model is filled in', () {
    final rec = Recorder(state, clock: () => now);
    expect(rec.parse('{"actions":[]}', now).reply, isNotEmpty);
    expect(rec.parse('{"reply":" ","questions":["วันไหน"]}', now).reply, isNotEmpty);
  });

  test('prompt tells the model to act first and not ask what it can decide', () {
    final prompt = Recorder(state, clock: () => now).systemPrompt(now);
    expect(prompt, contains('ลงมือเสนอ action จากข้อมูลที่มีก่อน'));
    expect(prompt, contains('ห้ามถามสิ่งที่ตัดสินใจเองได้'));
    expect(prompt, contains('"questions": []'));
  });

  test('a follow-up message carries the earlier conversation', () {
    final rec = Recorder(state, clock: () => now);
    expect(rec.userPrompt('x', const []), 'ข้อความจากผู้ใช้:\nx');
    final first = rec.parse('{"reply":"รับทราบ","questions":["วันไหน"],"actions":[]}', now);
    final next = rec.userPrompt('22 ม.ค.', [(message: 'จะไปปักกิ่ง', result: first)]);
    expect(next, allOf(contains('จะไปปักกิ่ง'), contains('รับทราบ'), contains('วันไหน'), contains('22 ม.ค.')));
  });

  test('recurring payment proposal', () async {
    final r = await run({
      'actions': [
        {'type': 'create', 'kind': 'event', 'date': '2026-12-01', 'category': 'finance', 'title': 'Netflix', 'every': 'monthly'},
      ],
    });
    expect(r.actions.single.valid, isTrue);
    expect(r.actions.single.summary, contains('ทุกเดือน'));
  });

  test('duplicate event on the same day is rejected', () async {
    final r = await run({
      'actions': [
        {'type': 'create', 'kind': 'event', 'date': '2027-01-22', 'category': 'travel', 'title': 'ทริปปักกิ่ง'},
      ],
    });
    expect(r.actions.single.errors.join(), contains('อยู่แล้ว'));
  });

  test('tolerates code fences and prose around the JSON', () {
    final r = Recorder(state, clock: () => now).parse('นี่คือผล:\n```json\n{"reply":"สวัสดี","actions":[]}\n```', now);
    expect(r.reply, 'สวัสดี');
    final bad = Recorder(state, clock: () => now).parse('ขอโทษ ฉันไม่เข้าใจ', now);
    expect(bad.actions, isEmpty);
    expect(bad.reply, contains('อ่านไม่ได้'));
  });
}
