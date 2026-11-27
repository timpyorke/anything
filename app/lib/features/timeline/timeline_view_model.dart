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
    /// เริ่มหลังวันนี้ เรียงจากใกล้ไปไกล
    required List<Entry> upcoming,
    /// ของวันนี้ รวมช่วงหลายวันที่เริ่มไปแล้วและยังไม่จบ
    required List<Entry> current,
    /// จบไปแล้ว เรียงจากใหม่ไปเก่า
    required List<Entry> past,
  }) = _TimelineViewState;

  int get count => upcoming.length + current.length + past.length;

  Map<int, List<Entry>> get pastByYear => _byYear(past);

  /// ทุกรายการเป็นเส้นเวลาเดียว ใหม่ไปเก่า (ใช้กับผลกรองและผลค้นหา)
  Map<int, List<Entry>> get allByYear =>
      _byYear([...upcoming, ...current, ...past]..sort((a, b) => b.shownDate(now).compareTo(a.shownDate(now))));

  /// รายการล่วงหน้าจัดกลุ่มตามเดือน (key = วันที่ 1 ของเดือน)
  Map<DateTime, List<Entry>> get upcomingByMonth {
    final byMonth = <DateTime, List<Entry>>{};
    for (final e in upcoming) {
      final d = e.shownDate(now);
      (byMonth[DateTime.utc(d.year, d.month)] ??= []).add(e);
    }
    return byMonth;
  }

  Map<int, List<Entry>> _byYear(List<Entry> items) {
    final byYear = <int, List<Entry>>{};
    for (final e in items) {
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
  int oldestFirst(Entry a, Entry b) => a.shownDate(now).compareTo(b.shownDate(now));
  int newestFirst(Entry a, Entry b) => oldestFirst(b, a);
  final upcoming = list.where((e) => e.shownDate(now).isAfter(now)).toList()..sort(oldestFirst);
  final current = list.where((e) => !e.shownDate(now).isAfter(now) && e.isUpcoming(now)).toList()..sort(newestFirst);
  final past = list.where((e) => !e.isUpcoming(now)).toList()..sort(newestFirst);
  return TimelineViewState(now: now, upcoming: upcoming, current: current, past: past);
}

final timelineViewProvider = Provider.autoDispose<TimelineViewState>(
  (ref) => buildTimelineView(ref.watch(diaryViewModelProvider), ref.watch(timelineFilterProvider), today()),
);
