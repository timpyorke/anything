import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/category_dot.dart';
import '../diary/diary_view_model.dart';
import '../entry_editor/entry_editor_page.dart';
import 'entry_card.dart';
import 'timeline_view_model.dart';

/// กล่องย่อเหนือ "วันนี้": รายการล่วงหน้าที่ใกล้ที่สุด ที่เหลืออยู่ในหน้าทั้งหมด
class UpcomingCard extends ConsumerWidget {
  const UpcomingCard({super.key, required this.view, required this.onShowAll});
  static const maxRows = 3;

  final TimelineViewState view;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final state = ref.watch(diaryViewModelProvider);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.page, 4, Insets.page, 0),
      child: Card(
        child: Column(
          children: [
            InkWell(
              onTap: onShowAll,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t.upcoming, style: theme.textTheme.titleSmall)),
                    Text(t.allCount(view.upcoming.length), style: theme.textTheme.bodySmall),
                    Icon(Icons.chevron_right_rounded, size: 20, color: muted),
                  ],
                ),
              ),
            ),
            for (final e in view.upcoming.take(maxRows))
              InkWell(
                onTap: () => openEditor(context, entry: e),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 18, child: Center(child: CategoryDot(state.category(e.category).color))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.title.isEmpty ? state.category(e.category).label : e.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // อยู่ท้ายแถวและกว้างตามข้อความ ชื่อรายการจึงได้พื้นที่ที่เหลือทั้งหมด
                      Text(
                        EntryCard.badgeOf(e, view.now, t) ?? '',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: daysBetween(view.now, e.shownDate(view.now)) <= 7 ? theme.colorScheme.primary : muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
