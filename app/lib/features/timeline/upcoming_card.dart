import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final state = ref.watch(diaryViewModelProvider);
    final theme = Theme.of(context);
    final muted = TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: onShowAll,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(child: Text('กำลังจะมาถึง', style: theme.textTheme.titleSmall)),
                    Text('ทั้งหมด ${view.upcoming.length}', style: muted),
                    Icon(Icons.chevron_right, size: 20, color: muted.color),
                  ],
                ),
              ),
            ),
            for (final e in view.upcoming.take(maxRows))
              InkWell(
                onTap: () => openEditor(context, entry: e),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      SizedBox(width: 96, child: Text(EntryCard.badgeOf(e, view.now) ?? '', style: muted)),
                      Expanded(
                        child: Text(
                          e.title.isEmpty ? state.category(e.category).label : e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
