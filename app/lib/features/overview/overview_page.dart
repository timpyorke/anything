import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../core/widgets/stat_tile.dart';
import '../../state/app_state.dart';
import '../timeline/timeline_filter.dart';
import 'activity_heatmap.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.state, required this.filter, required this.openTimeline});
  final AppState state;
  final TimelineFilter filter;
  final VoidCallback openTimeline;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state, now = today();
        final years = {now.year, for (final e in s.entries) e.date.year}.toList()..sort((a, b) => b.compareTo(a));
        final year = years.contains(_year) ? _year! : now.year;

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
        final planned = counts.keys.where((d) => d.isAfter(now)).length;

        final catCounts = <String, int>{};
        for (final e in s.entries.where((e) => !e.hidden)) {
          catCounts[e.category] = (catCounts[e.category] ?? 0) + 1;
        }
        final cats = catCounts.keys.toList()..sort((a, b) => catCounts[b]!.compareTo(catCounts[a]!));
        final maxCat = catCounts.values.fold(1, max);

        return Scaffold(
          appBar: AppBar(title: const Text('ภาพรวม')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
            children: [
              // สูงตามเนื้อหา (ไม่ล็อกอัตราส่วน) กันข้อความล้นเมื่อป้ายยาวหรือผู้ใช้ขยายตัวอักษร
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: StatTile(value: '${past.length} วัน', label: 'วันที่มีบันทึก ($year)')),
                  const SizedBox(width: 8),
                  Expanded(child: StatTile(value: '$best วัน', label: 'บันทึกต่อเนื่องนานสุด')),
                ]),
              ),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: StatTile(value: '${s.entries.where((e) => !e.hidden).length}', label: 'รายการทั้งหมด')),
                  const SizedBox(width: 8),
                  Expanded(child: StatTile(value: '$planned วัน', label: 'มีแผนล่วงหน้า')),
                ]),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('ปฏิทินกิจกรรม', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      DropdownButton<int>(
                        value: year,
                        underline: const SizedBox(),
                        items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y (${be(y)})'))],
                        onChanged: (y) => setState(() => _year = y),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ActivityHeatmap(
                      year: year,
                      counts: counts,
                      now: now,
                      onTapDay: (d) {
                        widget.filter
                          ..clear()
                          ..set(day: d);
                        widget.openTimeline();
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('แตะวันที่มีสีเพื่อดูใน Timeline · กรอบประ = แผนล่วงหน้า',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('แยกตามหมวด', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    for (final c in cats)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          widget.filter
                            ..clear()
                            ..set(cats: {c});
                          widget.openTimeline();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(children: [
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
                          ]),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
