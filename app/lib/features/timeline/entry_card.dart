import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/markdown_view.dart';
import '../../core/widgets/pill.dart';
import '../../domain/entry.dart';
import '../../domain/recurrence.dart';
import '../diary/diary_state.dart';
import '../diary/diary_view_model.dart';

/// การ์ดรายการบน Timeline
class EntryCard extends ConsumerWidget {
  const EntryCard({super.key, required this.entry, required this.now, this.showDate = true, this.showBadge = true, this.onTap});
  final Entry entry;
  final DateTime now;

  /// false = วันเดียวกับแถวก่อนหน้า เว้นคอลัมน์วันที่ว่างไว้ให้เนื้อหายังตรงแนว
  final bool showDate;

  /// false = ป้ายซ้ำกับแถวก่อนหน้าของวันเดียวกัน
  final bool showBadge;
  final VoidCallback? onTap;

  /// ป้ายบอกเวลาเทียบกับวันนี้ เช่น "วันนี้" (null = ไม่มีป้าย)
  static String? badgeOf(Entry e, DateTime now) =>
      relativeLabel(e.shownDate(now), e.lastDate(now), now, isRange: e.endDate != null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(diaryViewModelProvider);
    final e = entry;
    final cat = state.category(e.category);
    final scheme = Theme.of(context).colorScheme;
    final rs = e.recState(now);
    final shown = e.shownDate(now);
    final rel = showBadge ? badgeOf(e, now) : null;
    final soon = rel != null && daysBetween(now, shown) <= 7;
    final cl = e.checklist;

    // แถวแบบ journal: คอลัมน์วันที่ซ้าย เนื้อหาขวา คั่นด้วยเส้นบาง (ไม่ใช้กรอบการ์ด)
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 44,
            child: showDate
                ? Column(children: [
                    Text('${shown.day}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5)),
                    Text(thMonthsShort[shown.month - 1], style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ])
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (rel != null) ...[
                Pill(rel, color: soon ? scheme.primary : null),
                const SizedBox(height: 4),
              ],
              if (e.title.isNotEmpty) ...[
                Text(e.title, style: Theme.of(context).textTheme.titleMedium),
              ],
              if (rs != null) _RecurrenceInfo(entry: e, rs: rs, state: state, color: cat.color),
              if (e.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                MarkdownView(e.body, accent: cat.color, onToggle: (i, done) => _toggle(context, ref, i, done)),
              ],
              if (e.endDate != null || e.recurrence != null || (rs != null && rs.next == null) || cl != null || e.source == 'ai' || (rs == null && e.metrics.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (e.endDate != null) Pill(fmtRange(e.date, e.endDate), outlined: true, icon: Icons.date_range),
                  if (e.recurrence != null) Pill(e.recurrence!.label, outlined: true, icon: Icons.repeat),
                  if (rs != null && rs.next == null) const Pill('ครบแล้ว', outlined: true),
                  if (cl != null) Pill('${cl.done}/${cl.total}', outlined: true, icon: Icons.checklist),
                  if (e.source == 'ai') const Pill('AI', outlined: true, icon: Icons.auto_awesome),
                  if (rs == null)
                    for (final m in e.metrics)
                      Pill('${state.metricLabel(m.key)} ${fmtNum(m.value)} ${state.metricUnit(m.key, m.unit)}'.trim(), outlined: true),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, int index, bool done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(diaryViewModelProvider.notifier).toggleCheck(entry, index, done);
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $err')));
    }
  }
}

class _RecurrenceInfo extends StatelessWidget {
  const _RecurrenceInfo({required this.entry, required this.rs, required this.state, required this.color});
  final Entry entry;
  final RecState rs;
  final DiaryState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final r = entry.recurrence!;
    final total = r.times ?? (r.until != null ? rs.dates.length : null);
    final muted = TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant);
    final lines = <String>[
      rs.next != null
          ? 'ครั้งที่ ${rs.done + 1}${total == null ? '' : '/$total'} · ผ่านไป ${rs.done} ครั้ง${total == null ? '' : ' · ครั้งสุดท้าย ${fmtDate(rs.last)}'}'
          : 'ครบ ${rs.done} ครั้ง',
      for (final m in entry.metrics)
        () {
          final u = state.metricUnit(m.key, m.unit);
          return '${state.metricLabel(m.key)} ${fmtNum(m.value)} $u/ครั้ง · สะสม ${fmtNum(m.value * rs.done)} $u'
              '${total == null ? '' : ' · คงเหลือ ${fmtNum(m.value * (total - rs.done))} $u'}';
        }(),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in lines) Text(l, style: muted),
        if (total != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: rs.done / total,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
              semanticsLabel: 'ความคืบหน้า',
              semanticsValue: '${rs.done} จาก $total',
            ),
          ),
        ],
      ]),
    );
  }
}
