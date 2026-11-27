import 'dart:ui' show Color;

import 'package:anything/app/providers.dart';
import 'package:anything/domain/category.dart';
import 'package:anything/domain/entry.dart';
import 'package:anything/domain/metric.dart';
import 'package:anything/features/diary/diary_view_model.dart';
import 'package:anything/features/timeline/timeline_filter.dart';
import 'package:anything/features/timeline/timeline_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_diary_repository.dart';

void main() {
  late FakeDiaryRepository repo;
  late ProviderContainer container;
  final now = DateTime.utc(2026, 11, 24);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    repo = FakeDiaryRepository();
    container = ProviderContainer(overrides: [
      diaryRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('user-1'),
    ]);
    addTearDown(container.dispose);
    container.listen(diaryViewModelProvider, (_, _) {}); // เปิด provider ให้ build() + โหลดข้อมูล
    await settle();
    await settle();
  });

  test('loads categories, metrics and entries on creation', () {
    final s = container.read(diaryViewModelProvider);
    expect(s.loading, isFalse);
    expect(s.categoryKeys, {'health', 'daily'});
    expect(s.metricKeys, {'weight'});
  });

  test('save inserts, validates and keeps entries newest-first', () async {
    final vm = container.read(diaryViewModelProvider.notifier);
    await vm.save(Entry(date: DateTime.utc(2026, 1, 1), category: 'health', title: 'เก่า'));
    await vm.save(Entry(date: DateTime.utc(2026, 5, 1), category: 'health', title: 'ใหม่'));
    expect(container.read(diaryViewModelProvider).entries.map((e) => e.title), ['ใหม่', 'เก่า']);
    expect(() => vm.save(Entry(date: now, category: 'nope', title: 'x')), throwsArgumentError);
  });

  test('delete then undo restores the entry', () async {
    final vm = container.read(diaryViewModelProvider.notifier);
    final e = await vm.save(Entry(date: now, category: 'health', title: 'ลบทดสอบ'));
    await vm.delete(e);
    expect(container.read(diaryViewModelProvider).entries, isEmpty);
    await vm.undoDelete(e);
    expect(container.read(diaryViewModelProvider).entries.single.title, 'ลบทดสอบ');
  });

  test('toggleCheck rewrites the markdown checklist', () async {
    final vm = container.read(diaryViewModelProvider.notifier);
    final e = await vm.save(Entry(date: now, category: 'health', title: 'ของต้องทำ', body: '- [ ] a\n- [ ] b'));
    await vm.toggleCheck(e, 1, true);
    expect(container.read(diaryViewModelProvider).entries.single.body, '- [ ] a\n- [x] b');
  });

  test('addCategory makes the new category usable by entries', () async {
    final vm = container.read(diaryViewModelProvider.notifier);
    await vm.addCategory(const EntryCategory(key: 'pet', label: 'สัตว์เลี้ยง', color: Color(0xff12a594), sort: 2));
    await vm.save(Entry(date: now, category: 'pet', title: 'พาแมวหาหมอ'));
    expect(container.read(diaryViewModelProvider).categoryKeys, contains('pet'));
    expect(container.read(diaryViewModelProvider).entries.single.category, 'pet');
  });

  test('addMetricDef adds to state', () async {
    await container.read(diaryViewModelProvider.notifier).addMetricDef(const MetricDef(key: 'water', label: 'น้ำ', unit: 'ml'));
    expect(container.read(diaryViewModelProvider).metricKeys, {'weight', 'water'});
  });

  test('timeline view splits upcoming/past and applies the filter', () async {
    final vm = container.read(diaryViewModelProvider.notifier);
    await vm.save(Entry(date: DateTime.utc(2030, 1, 1), category: 'health', title: 'อนาคต'));
    await vm.save(Entry(date: DateTime.utc(2020, 1, 1), category: 'daily', title: 'อดีต'));
    final s = container.read(diaryViewModelProvider);
    var view = buildTimelineView(s, const TimelineFilter(), now);
    expect(view.upcoming.single.title, 'อนาคต');
    expect(view.past.single.title, 'อดีต');
    expect(view.next?.title, 'อนาคต');
    view = buildTimelineView(s, const TimelineFilter(cats: {'daily'}), now);
    expect(view.count, 1);
    view = buildTimelineView(s, const TimelineFilter(query: 'อดีต'), now);
    expect(view.past.single.title, 'อดีต');
  });

  test('filter view model: showOnly replaces previous filter, clear resets', () {
    final f = container.read(timelineFilterProvider.notifier);
    f.setQuery('x');
    f.showOnly(cats: {'health'});
    expect(container.read(timelineFilterProvider), const TimelineFilter(cats: {'health'}));
    f.clear();
    expect(container.read(timelineFilterProvider).active, isFalse);
  });
}
