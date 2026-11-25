import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../app/providers.dart';

part 'timeline_filter.freezed.dart';

/// ตัวกรองของ Timeline — แชร์กับหน้าภาพรวม (คลิกวันใน heatmap / แถบหมวด)
@freezed
abstract class TimelineFilter with _$TimelineFilter {
  const TimelineFilter._();

  const factory TimelineFilter({
    Set<String>? cats, // null = ทุกหมวด
    @Default('') String query,
    DateTime? day,
  }) = _TimelineFilter;

  bool get active => cats != null || query.isNotEmpty || day != null;
}

final timelineFilterProvider = NotifierProvider<TimelineFilterViewModel, TimelineFilter>(TimelineFilterViewModel.new);

class TimelineFilterViewModel extends Notifier<TimelineFilter> {
  @override
  TimelineFilter build() {
    ref.watch(currentUserIdProvider); // เปลี่ยนบัญชี → ล้างตัวกรอง
    return const TimelineFilter();
  }

  void setQuery(String q) => state = state.copyWith(query: q);

  void clear() => state = const TimelineFilter();

  /// ล้างแล้วกรองเฉพาะวัน/หมวดที่เลือก (ใช้จากหน้าภาพรวม)
  void showOnly({DateTime? day, Set<String>? cats}) =>
      state = TimelineFilter(day: day, cats: (cats == null || cats.isEmpty) ? null : cats);
}
