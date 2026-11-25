import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/utils/dates.dart';
import '../diary/diary_state.dart';
import '../diary/diary_view_model.dart';

part 'overview_view_model.freezed.dart';

@freezed
abstract class OverviewStats with _$OverviewStats {
  const factory OverviewStats({
    required int year,
    required List<int> years,
    required Map<DateTime, int> counts,
    required int pastDays,
    required int bestStreak,
    required int plannedDays,
    required int totalEntries,
    required List<String> categoriesByCount,
    required Map<String, int> categoryCounts,
  }) = _OverviewStats;
}

OverviewStats computeOverview(DiaryState s, DateTime now, int? selectedYear) {
  final years = {now.year, for (final e in s.entries) e.date.year}.toList()..sort((a, b) => b.compareTo(a));
  final year = years.contains(selectedYear) ? selectedYear! : now.year;

  final counts = <DateTime, int>{};
  for (final e in s.entries) {
    for (final d in e.coveredDays(now)) {
      if (d.year == year) counts[d] = (counts[d] ?? 0) + 1;
    }
  }
  final past = counts.keys.where((d) => !d.isAfter(now)).toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in past) {
    run = prev != null && daysBetween(prev, d) == 1 ? run + 1 : 1;
    best = max(best, run);
    prev = d;
  }
  final catCounts = <String, int>{};
  for (final e in s.entries.where((e) => !e.hidden)) {
    catCounts[e.category] = (catCounts[e.category] ?? 0) + 1;
  }
  return OverviewStats(
    year: year,
    years: years,
    counts: counts,
    pastDays: past.length,
    bestStreak: best,
    plannedDays: counts.keys.where((d) => d.isAfter(now)).length,
    totalEntries: s.entries.where((e) => !e.hidden).length,
    categoriesByCount: catCounts.keys.toList()..sort((a, b) => catCounts[b]!.compareTo(catCounts[a]!)),
    categoryCounts: catCounts,
  );
}

/// ปีที่เลือกในหน้าภาพรวม (null = ปีนี้)
final overviewYearProvider = NotifierProvider.autoDispose<OverviewYearViewModel, int?>(OverviewYearViewModel.new);

class OverviewYearViewModel extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? y) => state = y;
}

final overviewStatsProvider = Provider.autoDispose<OverviewStats>(
  (ref) => computeOverview(ref.watch(diaryViewModelProvider), today(), ref.watch(overviewYearProvider)),
);
