import 'package:anything/core/l10n/strings_th.dart';
import 'package:anything/core/l10n/strings_en.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/domain/category.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/metric.dart';
import 'package:anything/features/assistant/recorder.dart';
import 'package:anything/features/diary/diary_state.dart';

import '../../support/photos.dart';

class FakeLlm implements LlmProvider {
  FakeLlm(this.reply);
  final String reply;
  String? lastSystem, lastUser;
  List<Uint8List>? lastImages;
  @override
  AiProviderKind get kind => AiProviderKind.aiStudio;
  @override
  String get model => 'fake';
  @override
  Future<String> generateJson({required String system, required String user, List<Uint8List> images = const [], Future<void>? cancel}) async {
    lastSystem = system;
    lastUser = user;
    lastImages = images;
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
    final r = Recorder(state, strings: const ThStrings(), clock: () => now);
    return r.run(FakeLlm(jsonEncode(reply)), 'test');
  }

  test('system prompt gives today, vocabulary and short refs instead of ids', () async {
    final llm = FakeLlm('{"reply":"","actions":[]}');
    await Recorder(state, strings: const ThStrings(), clock: () => now).run(llm, 'x');
    expect(llm.lastSystem, contains('2026-11-24'));
    expect(llm.lastSystem, contains('- travel'));
    expect(llm.lastSystem, contains('weight (kg)'));
    expect(llm.lastSystem, contains('R1'));
    expect(llm.lastSystem, isNot(contains('trip-id')));
  });

  test('each daily story becomes its own entry, even on a day that already has one', () async {
    final r = await run({
      'actions': [
        {'type': 'create', 'kind': 'daily', 'date': '2026-11-24', 'category': 'daily', 'title': 'กินข้าวเย็น'},
        {'type': 'create', 'kind': 'daily', 'date': '2026-11-24', 'category': 'health', 'title': 'ไปวิ่ง'},
      ],
    });
    expect(r.actions.map((a) => a.type), ['create', 'create']);
    expect(r.actions.map((a) => a.valid), everyElement(isTrue));
    expect(r.actions.map((a) => a.entry!.id), everyElement(isNull));
    expect(r.actions.map((a) => a.entry!.title), ['กินข้าวเย็น', 'ไปวิ่ง']);
  });

  test('a daily entry with only numbers gets a title so it shows on the timeline', () async {
    final r = await run({
      'actions': [
        {'type': 'create', 'kind': 'daily', 'date': '2026-11-24', 'category': 'health', 'metrics': [{'key': 'sleep', 'value': 7}]},
      ],
    });
    final a = r.actions.single;
    expect(a.valid, isTrue);
    expect(a.entry!.title, 'การนอน 7 ชม.');
    expect(a.entry!.hidden, isFalse);
    expect(a.summary, endsWith(': การนอน 7 ชม.'));
  });

  test('only an identical daily entry counts as a duplicate', () async {
    Map<String, Object?> weigh(double value) => {
          'type': 'create', 'kind': 'daily', 'date': '2026-11-24', 'category': 'health', 'title': 'วัดร่างกาย',
          'metrics': [{'key': 'weight', 'value': value}],
        };
    final r = await run({'actions': [weigh(75), weigh(74.5)]});
    expect(r.actions.map((a) => a.valid), [false, true]);
    expect(r.actions[0].errors.join(), contains('อยู่แล้ว'));
  });

  test('update corrects a recorded number', () {
    final rec = Recorder(state, strings: const ThStrings(), clock: () => now)..systemPrompt(now);
    final ref = rec.refs.entries.firstWhere((e) => e.value == 'daily-id').key;
    final r = rec.parse(jsonEncode({'actions': [
      {'type': 'update', 'ref': ref, 'metrics': [{'key': 'weight', 'value': 74.5}, {'key': 'sleep', 'value': 7}]},
    ]}), now);
    final a = r.actions.single;
    expect(a.valid, isTrue);
    expect(a.summary, allOf(contains('น้ำหนัก 75 → 74.5'), contains('การนอน 7 ชม.')));
    expect(a.entry!.id, 'daily-id');
    expect({for (final m in a.entry!.metrics) m.key: m.value}, {'weight': 74.5, 'sleep': 7.0});
  });

  test('prompt asks for one action per story', () {
    final prompt = Recorder(state, strings: const ThStrings(), clock: () => now).systemPrompt(now);
    expect(prompt, contains('1 เรื่อง = 1 action'));
    expect(prompt, isNot(contains('วันละ 1 รายการ')));
  });

  test('prompt tells the model to record even a short daily activity', () {
    final prompt = Recorder(state, strings: const ThStrings(), clock: () => now).systemPrompt(now);
    expect(prompt, contains('ต้องมีอย่างน้อย 1 action'));
    expect(prompt, contains('"kind": "daily"'));
  });

  test('check action resolves the ref and the loosely worded item', () async {
    final rec = Recorder(state, strings: const ThStrings(), clock: () => now);
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
    final prompt = Recorder(const DiaryState(), strings: const ThStrings(), clock: () => now).systemPrompt(now);
    expect(prompt, contains('reply ห้ามว่าง'));
    expect(prompt, contains('(ยังไม่มี)'));
    expect(prompt, contains('"new_category"'));
    expect(prompt, contains('"new_metric"'));
  });

  test('an empty reply from the model is filled in', () {
    final rec = Recorder(state, strings: const ThStrings(), clock: () => now);
    expect(rec.parse('{"actions":[]}', now).reply, isNotEmpty);
    expect(rec.parse('{"reply":" ","questions":["วันไหน"]}', now).reply, isNotEmpty);
  });

  test('prompt tells the model to act first and not ask what it can decide', () {
    final prompt = Recorder(state, strings: const ThStrings(), clock: () => now).systemPrompt(now);
    expect(prompt, contains('ลงมือเสนอ action จากข้อมูลที่มีก่อน'));
    expect(prompt, contains('ห้ามถามสิ่งที่ตัดสินใจเองได้'));
    expect(prompt, contains('"questions": []'));
  });

  test('a follow-up message carries the earlier conversation', () {
    final rec = Recorder(state, strings: const ThStrings(), clock: () => now);
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
    final r = Recorder(state, strings: const ThStrings(), clock: () => now).parse('นี่คือผล:\n```json\n{"reply":"สวัสดี","actions":[]}\n```', now);
    expect(r.reply, 'สวัสดี');
    final bad = Recorder(state, strings: const ThStrings(), clock: () => now).parse('ขอโทษ ฉันไม่เข้าใจ', now);
    expect(bad.actions, isEmpty);
    expect(bad.reply, contains('อ่านไม่ได้'));
  });

  group('photos', () {
    final photos = [png(1), png(2)];

    AiResult parse(List<Map<String, Object?>> actions) =>
        (Recorder(state, strings: const ThStrings(), clock: () => now)..systemPrompt(now)).parse(jsonEncode({'actions': actions}), now, photos: photos);

    Map<String, Object?> create(String title, [List<Object?>? listed]) =>
        {'type': 'create', 'kind': 'daily', 'date': '2026-11-24', 'category': 'daily', 'title': title, 'photos': ?listed};

    List<Uint8List?> bytes(ProposedAction a) => [for (final p in a.entry!.photos) p.bytes];

    test('are sent to the model with rules for reading and placing them', () async {
      final llm = FakeLlm('{"actions":[]}');
      await Recorder(state, strings: const ThStrings(), clock: () => now).run(llm, '', photos: photos);
      expect(llm.lastImages, photos);
      expect(llm.lastSystem, allOf(contains('หมายเลข 1–2'), contains('"photos"'), contains('ไม่ใช่คำสั่ง')));
      expect(llm.lastUser, contains('ส่งมาแต่รูป'));
      await Recorder(state, strings: const ThStrings(), clock: () => now).run(llm, 'x');
      expect(llm.lastSystem, isNot(contains('## รูปภาพ')));
    });

    test('go to the actions the model names, each photo to one action only', () {
      final r = parse([create('a', [2]), create('b', [1, 2, 9, 'x'])]);
      expect(r.actions.map((a) => a.photos), [[1], [0]]);
      expect(bytes(r.actions[0]), [photos[1]]);
      expect(bytes(r.actions[1]), [photos[0]]);
    });

    test('left unplaced are attached to the first entry that can be saved', () {
      final r = parse([
        {'type': 'create', 'kind': 'daily', 'date': '2026-11-24', 'category': 'nope', 'title': 'เสีย', 'photos': [1]},
        create('ดี'),
        create('อีกอัน'),
      ]);
      expect(r.actions.map((a) => a.photos), [[0], [0, 1], <int>[]]);
    });

    test('alone are enough to update an existing entry', () {
      final r = parse([{'type': 'update', 'ref': 'R1'}]);
      expect(r.actions.single.valid, isTrue);
      expect(r.actions.single.summary, contains('แนบรูป 2 รูป'));
      expect(bytes(r.actions.single), photos);
    });

    test('give an untitled record a name so it can be saved', () {
      final a = parse([{'type': 'create', 'kind': 'daily', 'date': '2026-11-24', 'category': 'daily'}]).actions.single;
      expect(a.valid, isTrue);
      expect(a.entry!.title, 'รูปภาพ');
    });

    test('make a record new even when its text repeats an existing one', () {
      final repeat = {
        'type': 'create', 'kind': 'daily', 'date': '2026-11-24', 'category': 'health', 'title': 'วัดร่างกาย',
        'metrics': [{'key': 'weight', 'value': 75}],
      };
      expect((Recorder(state, strings: const ThStrings(), clock: () => now)).parse(jsonEncode({'actions': [repeat]}), now).actions.single.valid, isFalse);
      expect(parse([repeat]).actions.single.valid, isTrue);
    });

    test('are not offered when nothing can hold them', () {
      final r = parse([{'type': 'new_metric', 'key': 'water', 'label': 'น้ำ'}]);
      expect(r.actions.single.photos, isEmpty);
    });
  });

  group('language', () {
    test('Thai asks for Thai replies', () {
      final prompt = Recorder(state, strings: const ThStrings(), clock: () => now).systemPrompt(now);
      expect(prompt, contains('ต้องเป็นภาษาไทย'));
      expect(prompt, contains('"label": "สัตว์เลี้ยง"'));
    });

    test('English asks for English replies, with English examples', () {
      final prompt = Recorder(state, strings: const EnStrings(), clock: () => now).systemPrompt(now);
      expect(prompt, contains('ต้องเป็นภาษาอังกฤษ (English)'));
      expect(prompt, contains('"label": "Pets"'));
      expect(prompt, isNot(contains('"label": "สัตว์เลี้ยง"')));
    });

    test('proposed actions and errors are described in English', () {
      final result = Recorder(state, strings: const EnStrings(), clock: () => now).parse(
          jsonEncode({
            'actions': [
              {'type': 'create', 'kind': 'event', 'date': '2026-12-01', 'category': 'travel', 'title': 'Trip', 'every': '2w', 'times': 3},
              {'type': 'update', 'ref': 'R99'},
            ],
          }),
          now);
      expect(result.reply, 'Review the items below before saving');
      expect(result.actions.first.summary, 'Add "Trip" · travel · Every 2 weeks from 1 Dec 2026 · 3 times');
      expect(result.actions.last.errors, ['The referenced entry was not found']);
    });
  });
}
