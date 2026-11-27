import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/category_dot.dart';
import '../../core/widgets/markdown_view.dart';
import '../../core/widgets/pill.dart';
import '../../core/widgets/swipe_actions.dart';
import '../../domain/entry.dart';
import '../../domain/recurrence.dart';
import '../diary/deleted_snack_bar.dart';
import '../diary/diary_state.dart';
import '../diary/diary_view_model.dart';
import '../photos/photo_widgets.dart';

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

    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final radius = BorderRadius.circular(Corners.card);

    // แถวแบบ journal: คอลัมน์วันที่อยู่บนพื้นหน้า เนื้อหาอยู่ในการ์ดของแต่ละรายการ
    final card = Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (rel != null) ...[
              Align(alignment: Alignment.centerLeft, child: Pill(rel, color: soon ? scheme.primary : null)),
              const SizedBox(height: 6),
            ],
            if (e.title.isNotEmpty) Text(e.title, style: theme.textTheme.titleMedium),
            if (e.body.isNotEmpty) ...[
              const SizedBox(height: 2),
              MarkdownView(e.body, accent: cat.color, onToggle: (i, done) => _toggle(context, ref, i, done)),
            ],
            if (rs != null) _RecurrenceInfo(entry: e, rs: rs, state: state, color: cat.color),
            if (e.photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              PhotoStrip(e.photos, size: 64, max: 4),
            ],
            if (rs == null && e.metrics.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in e.metrics)
                  Pill('${state.metricLabel(m.key)} ${fmtNum(m.value)} ${state.metricUnit(m.key, m.unit)}'.trim()),
              ]),
            ],
            const SizedBox(height: 8),
            // บรรทัดข้อมูลกำกับ: หมวดมาก่อนเสมอ ที่เหลือมีเฉพาะเมื่อเกี่ยวข้อง
            Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                CategoryDot(cat.color),
                const SizedBox(width: 6),
                Flexible(child: Text(cat.label, style: theme.textTheme.labelMedium?.copyWith(color: muted))),
              ]),
              if (e.endDate != null) Pill(fmtRange(e.date, e.endDate), outlined: true, icon: Icons.date_range_rounded),
              if (e.recurrence != null) Pill(e.recurrence!.label, outlined: true, icon: Icons.repeat_rounded),
              if (cl != null) Pill('${cl.done}/${cl.total}', outlined: true, icon: Icons.checklist_rounded),
              if (e.source == 'ai') const Pill('AI', outlined: true, icon: Icons.auto_awesome_rounded),
            ]),
          ]),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.page, 4, Insets.page, 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // กว้างตามตัวอักษร: ผู้ใช้ขยายตัวอักษรแล้วเลขวันต้องไม่ถูกตัด
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(40),
          child: showDate
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(children: [
                    Text('${shown.day}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5)),
                    Text(thMonthsShort[shown.month - 1], style: theme.textTheme.bodySmall),
                  ]),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SwipeActions(
            // key ตามรายการ: ลบแล้วแถวถัดไปต้องไม่รับสถานะ "เปิดอยู่" ต่อ
            key: ValueKey(e.id),
            borderRadius: radius,
            actions: [
              if (onTap != null)
                SwipeAction(
                  label: 'แก้ไข',
                  icon: Icons.edit_outlined,
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurface,
                  onPressed: onTap!,
                ),
              SwipeAction(
                label: 'ลบ',
                icon: Icons.delete_outline_rounded,
                background: scheme.error,
                foreground: scheme.onError,
                onPressed: () => _delete(context, ref),
              ),
            ],
            child: card,
          ),
        ),
      ]),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final diary = ref.read(diaryViewModelProvider.notifier);
    try {
      await diary.delete(entry);
      showDeletedSnackBar(messenger, diary, entry);
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $err')));
    }
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
    final theme = Theme.of(context);
    final progress = rs.next == null
        ? 'ครบ ${rs.done} ครั้ง'
        : total == null
            ? 'ครั้งที่ ${rs.done + 1} · ผ่านไป ${rs.done} ครั้ง'
            : 'ครั้งที่ ${rs.done + 1}/$total · ครั้งสุดท้าย ${fmtDate(rs.last)}';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (total != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: rs.done / total,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
              // semanticsValue ต้องเป็นตัวเลข จึงปล่อยให้เป็นเปอร์เซ็นต์ แล้วบอกจำนวนครั้งในป้าย
              semanticsLabel: 'ความคืบหน้า ${rs.done} จาก $total ครั้ง',
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(progress, style: theme.textTheme.bodySmall),
        for (final m in entry.metrics)
          () {
            final u = state.metricUnit(m.key, m.unit);
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${state.metricLabel(m.key)} ครั้งละ ${fmtNum(m.value)} $u'.trim(), style: theme.textTheme.bodyMedium),
                Text(
                  'สะสม ${fmtNum(m.value * rs.done)} $u'
                          '${total == null ? '' : ' · คงเหลือ ${fmtNum(m.value * (total - rs.done))} $u'}'
                      .trim(),
                  style: theme.textTheme.bodySmall,
                ),
              ]),
            );
          }(),
      ]),
    );
  }
}
