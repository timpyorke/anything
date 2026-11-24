import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/markdown_view.dart';
import '../../core/widgets/pill.dart';
import '../../domain/entry.dart';
import '../../domain/recurrence.dart';
import '../../state/app_state.dart';

/// การ์ดรายการบน Timeline
class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry, required this.state, required this.now, this.onTap});
  final Entry entry;
  final AppState state;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final cat = state.category(e.category);
    final scheme = Theme.of(context).colorScheme;
    final rs = e.recState(now);
    final shown = e.shownDate(now);
    final rel = relativeLabel(shown, e.lastDate(now), now, isRange: e.endDate != null);
    final soon = rel != null && daysBetween(now, shown) <= 7;
    final cl = e.checklist;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: cat.color, width: 4))),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(rs != null ? fmtDay(shown) : fmtRange(e.date, e.endDate),
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              Pill(cat.label, color: cat.color),
              if (e.recurrence != null) Pill(e.recurrence!.label, outlined: true, icon: Icons.repeat),
              if (rel != null) Pill(rel, color: soon ? scheme.primary : null),
              if (rs != null && rs.next == null) const Pill('ครบแล้ว', outlined: true),
              if (cl != null) Pill('${cl.done}/${cl.total}', outlined: true, icon: Icons.checklist),
              if (e.source == 'ai') const Pill('AI', outlined: true, icon: Icons.auto_awesome),
              if (rs == null)
                for (final m in e.metrics)
                  Pill('${state.metricLabel(m.key)} ${fmtNum(m.value)} ${state.metricUnit(m.key, m.unit)}'.trim(), outlined: true),
            ]),
            if (e.title.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(e.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
            if (rs != null) _RecurrenceInfo(entry: e, rs: rs, state: state, color: cat.color),
            if (e.body.isNotEmpty) ...[
              const SizedBox(height: 4),
              MarkdownView(e.body, accent: cat.color, onToggle: (i, done) => _toggle(context, i, done)),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, int index, bool done) async {
    try {
      await state.toggleCheck(entry, index, done);
    } catch (err) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $err')));
    }
  }
}

class _RecurrenceInfo extends StatelessWidget {
  const _RecurrenceInfo({required this.entry, required this.rs, required this.state, required this.color});
  final Entry entry;
  final RecState rs;
  final AppState state;
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
