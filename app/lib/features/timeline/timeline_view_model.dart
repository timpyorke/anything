import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/utils/dates.dart';
import '../../domain/entry.dart';
import '../diary/diary_state.dart';
import '../diary/diary_view_model.dart';
import 'timeline_filter.dart';

part 'timeline_view_model.freezed.dart';

/// สิ่งที่หน้า Timeline แสดง — คำนวณจากข้อมูลทั้งหมด + ตัวกรอง (view ไม่ต้องคิดเอง)
@freezed
abstract class TimelineViewState with _$TimelineViewState {
  const TimelineViewState._();

  const factory TimelineViewState({
    required DateTime now,
    required List<Entry> upcoming,
    required List<Entry> past,
    Entry? next,
    Entry? birth,
  }) = _TimelineViewState;

  int get count => upcoming.length + past.length;

  /// รายการเก่า จัดกลุ่มตามปี (ปีล่าสุดก่อน)
  Map<int, List<Entry>> get pastByYear {
    final byYear = <int, List<Entry>>{};
    for (final e in past) {
      (byYear[e.shownDate(now).year] ??= []).add(e);
    }
    return byYear;
  }
}

TimelineViewState buildTimelineView(DiaryState s, TimelineFilter f, DateTime now) {
  final words = f.query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final list = s.entries.where((e) {
    if (f.day != null) {
      if (!e.coveredDays(now).contains(f.day)) return false;
    } else if (e.hidden) {
      return false;
    }
    if (f.cats != null && !f.cats!.contains(e.category)) return false;
    final text = '${e.searchText} ${s.category(e.category).label.toLowerCase()}';
    return words.every(text.contains);
  }).toList();
  final upcoming = list.where((e) => e.isUpcoming(now)).toList()..sort((a, b) => a.shownDate(now).compareTo(b.shownDate(now)));
  final past = list.where((e) => !e.isUpcoming(now)).toList()..sort((a, b) => b.shownDate(now).compareTo(a.shownDate(now)));
  final next = (s.entries.where((e) => !e.hidden && (e.shownDate(now).isAfter(now) || (e.endDate != null && e.isUpcoming(now)))).toList()
        ..sort((a, b) => a.shownDate(now).compareTo(b.shownDate(now))))
      .firstOrNull;
  return TimelineViewState(now: now, upcoming: upcoming, past: past, next: next, birth: s.birth);
}

final timelineViewProvider = Provider.autoDispose<TimelineViewState>(
  (ref) => buildTimelineView(ref.watch(diaryViewModelProvider), ref.watch(timelineFilterProvider), today()),
);
