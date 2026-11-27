import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../core/widgets/category_dot.dart';
import '../../core/widgets/empty_state.dart';
import '../assistant/anything_button.dart';
import '../diary/diary_state.dart';
import '../diary/diary_view_model.dart';
import '../overview/overview_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';
import 'entry_section.dart';
import 'timeline_filter.dart';
import 'timeline_view_model.dart';
import 'upcoming_card.dart';
import 'upcoming_page.dart';

class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(diaryViewModelProvider);
    final f = ref.watch(timelineFilterProvider);
    final view = ref.watch(timelineViewProvider);
    final diary = ref.read(diaryViewModelProvider.notifier);
    final now = view.now;
    final theme = Theme.of(context);
    // รีเฟรชพังตอนที่มีข้อมูลเดิมอยู่: หน้าไม่เปลี่ยน จึงต้องบอกว่าที่เห็นอาจไม่ใช่ล่าสุด
    ref.listen(diaryViewModelProvider.select((s) => s.error), (_, error) {
      if (error == null || ref.read(diaryViewModelProvider).entries.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.refreshFailed),
        persist: false,
        action: SnackBarAction(label: t.retry, onPressed: diary.load),
      ));
    });
    void push(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    // ที่ว่างท้ายรายการ ให้เลื่อนพ้นกล่องพิมพ์ที่ลอยอยู่
    final composerSpace = 112 + MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Insets.page,
        // จอแคบ: ย่อชื่อให้พอดีแทนการถูกตัดท้าย
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Anything ~ diaries'),
        ),
        actions: [
          IconButton(
            tooltip: t.search,
            icon: const Icon(Icons.search_rounded),
            onPressed: () => push(const SearchPage()),
          ),
          IconButton(
            tooltip: t.overview,
            icon: const Icon(Icons.insights_rounded),
            onPressed: () =>
                push(OverviewPage(openTimeline: () => Navigator.pop(context))),
          ),
          IconButton(
            tooltip: t.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => push(const SettingsPage()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const AnythingButton(),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: diary.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                if (f.active)
                  SliverToBoxAdapter(
                    child: _FilterBar(
                      filter: f,
                      state: s,
                      count: view.count,
                      onClear: ref.read(timelineFilterProvider.notifier).clear,
                    ),
                  ),
                if (s.loading && s.entries.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (s.error != null && s.entries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      text: t.loadFailed,
                      detail: s.error,
                      action: FilledButton.icon(
                        onPressed: diary.load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(t.retry),
                      ),
                    ),
                  )
                else if (f.active && view.count == 0)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      text: t.noFilterMatches,
                    ),
                  )
                else ...[
                  // กรองอยู่: เส้นเวลาเดียว ไม่ย่ออนาคต เพื่อไม่ให้วันที่เลือกถูกซ่อน
                  if (f.active)
                    for (final MapEntry(key: y, value: items)
                        in view.allByYear.entries)
                      EntrySection(title: t.yearLabel(y), items: items, now: now)
                  else ...[
                    if (view.upcoming.isNotEmpty)
                      SliverToBoxAdapter(
                        child: UpcomingCard(
                          view: view,
                          onShowAll: () => push(const UpcomingPage()),
                        ),
                      ),
                    EntrySection(
                      title: t.today,
                      subtitle: '${t.weekdays[now.weekday - 1]} ${t.fmtDay(now)}',
                      items: view.current,
                      now: now,
                      impliedBadge: t.today,
                      emptyText: t.todayEmpty,
                    ),
                    for (final MapEntry(key: y, value: items)
                        in view.pastByYear.entries)
                      EntrySection(
                        title: y == now.year ? t.earlier : t.yearLabel(y),
                        subtitle: y == now.year ? t.yearLabel(y) : null,
                        items: items,
                        now: now,
                      ),
                  ],
                  SliverToBoxAdapter(child: SizedBox(height: composerSpace)),
                ],
              ],
            ),
          ),
          // ไล่พื้นจางด้านล่าง เนื้อหาที่เลื่อนผ่านใต้กล่องพิมพ์จะไม่แย่งสายตา
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: composerSpace,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.scaffoldBackgroundColor.withValues(alpha: 0),
                      theme.scaffoldBackgroundColor,
                    ],
                    stops: const [0, 0.75],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// บอกว่ากำลังกรองด้วยอะไร เจอกี่รายการ และล้างได้จากที่เดียว
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter, required this.state, required this.count, required this.onClear});
  final TimelineFilter filter;
  final DiaryState state;
  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.page, 4, Insets.page, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (filter.day != null) Text(t.fmtDate(filter.day!), style: theme.textTheme.titleSmall),
                  for (final key in filter.cats ?? const <String>{})
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      CategoryDot(state.category(key).color),
                      const SizedBox(width: 6),
                      Flexible(child: Text(state.category(key).label, style: theme.textTheme.titleSmall)),
                    ]),
                ]),
                Text(t.itemCount(count), style: theme.textTheme.bodySmall),
              ]),
            ),
            TextButton(onPressed: onClear, child: Text(t.clearFilter)),
          ]),
        ),
      ),
    );
  }
}
