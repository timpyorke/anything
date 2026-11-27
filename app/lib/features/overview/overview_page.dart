import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/category_dot.dart';
import '../../core/widgets/stat_tile.dart';
import '../diary/diary_view_model.dart';
import '../timeline/timeline_filter.dart';
import 'activity_heatmap.dart';
import 'overview_view_model.dart';

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key, required this.openTimeline});
  final VoidCallback openTimeline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(diaryViewModelProvider);
    final st = ref.watch(overviewStatsProvider);
    final filter = ref.read(timelineFilterProvider.notifier);
    final theme = Theme.of(context);
    final now = today();
    final year = st.year, years = st.years, counts = st.counts;
    final cats = st.categoriesByCount, catCounts = st.categoryCounts;
    final maxCat = catCounts.values.fold(1, max);

    // สูงตามเนื้อหา (ไม่ล็อกอัตราส่วน) กันข้อความล้นเมื่อป้ายยาวหรือผู้ใช้ขยายตัวอักษร
    Widget pair(StatTile a, StatTile b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(t.overview)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Insets.page, 4, Insets.page, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (st.age != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                t.age(st.age!),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          pair(
            StatTile(icon: Icons.event_available_rounded, value: t.dayCount(st.pastDays), label: t.daysLogged(t.yearLabel(year))),
            StatTile(icon: Icons.local_fire_department_outlined, value: t.dayCount(st.bestStreak), label: t.bestStreak),
          ),
          const SizedBox(height: 8),
          pair(
            StatTile(icon: Icons.notes_rounded, value: '${st.totalEntries}', label: t.totalEntries),
            StatTile(icon: Icons.upcoming_outlined, value: t.dayCount(st.plannedDays), label: t.plannedAhead),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(t.activityCalendar, style: theme.textTheme.titleMedium),
                        DropdownButton<int>(
                          value: year,
                          underline: const SizedBox(),
                          style: theme.textTheme.labelLarge,
                          borderRadius: BorderRadius.circular(Corners.control),
                          items: [for (final y in years) DropdownMenuItem(value: y, child: Text(t.yearLabel(y)))],
                          onChanged: ref.read(overviewYearProvider.notifier).select,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ActivityHeatmap(
                    // ปีใหม่ = ตำแหน่งเลื่อนใหม่
                    key: ValueKey(year),
                    year: year,
                    counts: counts,
                    now: now,
                    onTapDay: (d) {
                      filter.showOnly(day: d);
                      openTimeline();
                    },
                  ),
                  const SizedBox(height: 10),
                  const HeatmapLegend(),
                  const SizedBox(height: 4),
                  Text(t.tapDayHint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                    child: Text(t.byCategory, style: theme.textTheme.titleMedium),
                  ),
                  for (final c in cats)
                    InkWell(
                      onTap: () {
                        filter.showOnly(cats: {c});
                        openTimeline();
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Column(children: [
                          Row(children: [
                            CategoryDot(s.category(c).color),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s.category(c).label, overflow: TextOverflow.ellipsis)),
                            Text('${catCounts[c]}', style: theme.textTheme.titleSmall),
                            Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: ExcludeSemantics(
                              child: LinearProgressIndicator(
                                value: max(catCounts[c]! / maxCat, 0.02),
                                minHeight: 6,
                                color: s.category(c).color,
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
