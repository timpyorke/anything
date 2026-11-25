import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
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
    final s = ref.watch(diaryViewModelProvider);
    final st = ref.watch(overviewStatsProvider);
    final filter = ref.read(timelineFilterProvider.notifier);
    final now = today();
    final year = st.year, years = st.years, counts = st.counts;
    final cats = st.categoriesByCount, catCounts = st.categoryCounts;
    final maxCat = catCounts.values.fold(1, max);
    return Scaffold(
      appBar: AppBar(title: const Text('ภาพรวม')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
        children: [
          // สูงตามเนื้อหา (ไม่ล็อกอัตราส่วน) กันข้อความล้นเมื่อป้ายยาวหรือผู้ใช้ขยายตัวอักษร
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatTile(value: '${st.pastDays} วัน', label: 'วันที่มีบันทึก ($year)'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(value: '${st.bestStreak} วัน', label: 'บันทึกต่อเนื่องนานสุด'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatTile(value: '${st.totalEntries}', label: 'รายการทั้งหมด'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(value: '${st.plannedDays} วัน', label: 'มีแผนล่วงหน้า'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('ปฏิทินกิจกรรม', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      DropdownButton<int>(
                        value: year,
                        underline: const SizedBox(),
                        items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y (${be(y)})'))],
                        onChanged: ref.read(overviewYearProvider.notifier).select,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ActivityHeatmap(
                    year: year,
                    counts: counts,
                    now: now,
                    onTapDay: (d) {
                      filter.showOnly(day: d);
                      openTimeline();
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('แตะวันที่มีสีเพื่อดูใน Timeline · กรอบประ = แผนล่วงหน้า', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('แยกตามหมวด', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  for (final c in cats)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        filter.showOnly(cats: {c});
                        openTimeline();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            SizedBox(width: 110, child: Text(s.category(c).label, overflow: TextOverflow.ellipsis)),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: max(catCounts[c]! / maxCat, 0.03),
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(color: s.category(c).color, borderRadius: BorderRadius.circular(5)),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 32, child: Text('${catCounts[c]}', textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
