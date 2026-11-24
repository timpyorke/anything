import 'dart:convert';
import 'dart:ui' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/data/repository.dart';
import 'package:anything/domain/category.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/metric.dart';
import 'package:anything/features/assistant/recorder.dart';
import 'package:anything/state/app_state.dart';

class FakeLlm implements LlmProvider {
  FakeLlm(this.reply);
  final String reply;
  String? lastSystem;
  @override
  AiProviderKind get kind => AiProviderKind.aiStudio;
  @override
  String get model => 'fake';
  @override
  Future<String> generateJson({required String system, required String user}) async {
    lastSystem = system;
    return reply;
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 24);
  late AppState state;
  late Entry trip, daily;

  setUp(() {
    // ไม่มีการเรียกเครือข่าย: ใช้เฉพาะข้อมูลในหน่วยความจำ
    state = AppState(Repository(SupabaseClient('http://localhost', 'test')));
    state.categories = [
      for (final k in ['milestone', 'finance', 'health', 'travel', 'daily'])
        EntryCategory(key: k, label: k, color: const Color(0xff000000)),
    ];
    state.metricDefs = const [MetricDef(key: 'weight', label: 'น้ำหนัก', unit: 'kg'), MetricDef(key: 'sleep', label: 'การนอน', unit: 'ชม.')];
    trip = Entry(
      id: 'trip-id',
      date: DateTime.utc(2027, 1, 22),
      endDate: DateTime.utc(2027, 1, 27),
      category: 'travel',
      title: 'ทริปปักกิ่ง',
      body: '- [ ] ตั๋วเครื่องบิน\n- [ ] วีซ่า / เอกสารเดินทาง',
    );
    daily = Entry(id: 'daily-id', kind: 'daily', date: now, category: 'health', title: 'วัดร่างกาย', metrics: [const MetricValue('weight', 75, 'kg')]);
    state.entries = [trip, daily];
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
