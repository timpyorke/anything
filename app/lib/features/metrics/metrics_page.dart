import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/stat_tile.dart';
import '../../state/app_state.dart';
import 'metric_colors.dart';
import 'trend_chart.dart';

class MetricsPage extends StatefulWidget {
  const MetricsPage({super.key, required this.state});
  final AppState state;

  @override
  State<MetricsPage> createState() => _MetricsPageState();
}

class _MetricsPageState extends State<MetricsPage> {
  String _range = 'all';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state, now = today();
        final all = s.series(now);
        final keys = all.keys.toList()..sort((a, b) => all[b]!.last.$1.compareTo(all[a]!.last.$1));
        final multi = keys.where((k) => all[k]!.length > 1).toList();
        final since = switch (_range) {
          '3m' => addMonths(now, -3),
          '1y' => addMonths(now, -12),
          _ => null,
        };

        return Scaffold(
          appBar: AppBar(title: const Text('ตัวเลข')),
          body: keys.isEmpty
              ? const EmptyState(
                  icon: Icons.show_chart,
                  text: 'ยังไม่มีตัวเลข\nลองบอก AI ว่า "วันนี้น้ำหนัก 74.5 นอน 7 ชม."',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                  children: [
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // ความสูงตามขนาดตัวอักษรของระบบ ไม่ล็อกอัตราส่วน (กันข้อความล้น)
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        mainAxisExtent: 108 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
                      ),
                      children: [
                        for (final k in keys)
                          StatTile(
                            value: '${fmtNum(all[k]!.last.$2)} ${all[k]!.last.$3}'.trim(),
                            label: s.metricLabel(k),
                            sub: '${fmtDate(all[k]!.last.$1)}${all[k]!.length > 1 ? ' · ${all[k]!.length} ค่า' : ''}',
                            color: seriesColor(k),
                          ),
                      ],
                    ),
                    if (multi.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('บันทึกค่าเดิมซ้ำในวันอื่น แล้วกราฟแนวโน้มจะขึ้นที่นี่',
                            style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                        child: Row(children: [
                          Text('แนวโน้ม', style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(visualDensity: VisualDensity.compact),
                            segments: const [
                              ButtonSegment(value: '3m', label: Text('3 เดือน')),
                              ButtonSegment(value: '1y', label: Text('1 ปี')),
                              ButtonSegment(value: 'all', label: Text('ทั้งหมด')),
                            ],
                            selected: {_range},
                            onSelectionChanged: (v) => setState(() => _range = v.first),
                          ),
                        ]),
                      ),
                      for (final k in multi) _chartCard(context, s, k, all[k]!.where((p) => since == null || !p.$1.isBefore(since)).toList()),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _chartCard(BuildContext context, AppState s, String key, List<(DateTime, double, String)> pts) {
    final unit = pts.isEmpty ? '' : pts.last.$3;
    final vals = pts.map((p) => p.$2).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.metricLabel(key), style: Theme.of(context).textTheme.titleMedium),
          if (pts.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('ไม่มีข้อมูลในช่วงนี้')))
          else ...[
            Text(
              [
                'ล่าสุด ${fmtNum(vals.last)} $unit',
                if (vals.length > 1) 'เปลี่ยน ${vals.last - vals.first >= 0 ? '+' : ''}${fmtNum(vals.last - vals.first)}',
                if (vals.length > 1) 'ต่ำสุด ${fmtNum(vals.reduce(min))} – สูงสุด ${fmtNum(vals.reduce(max))}',
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'กราฟ ${s.metricLabel(key)} ${pts.length} ค่า ล่าสุด ${fmtNum(vals.last)} $unit',
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: CustomPaint(
                  painter: TrendLinePainter(
                    pts: pts,
                    color: seriesColor(key),
                    grid: Theme.of(context).colorScheme.outlineVariant,
                    text: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
