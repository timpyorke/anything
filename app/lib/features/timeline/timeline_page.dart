import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../../core/widgets/empty_state.dart';
import '../assistant/anything_button.dart';
import '../diary/diary_view_model.dart';
import '../overview/overview_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';
import 'entry_section.dart';
import 'timeline_filter.dart';
import 'timeline_view_model.dart';

class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(diaryViewModelProvider);
    final f = ref.watch(timelineFilterProvider);
    final fvm = ref.read(timelineFilterProvider.notifier);
    final view = ref.watch(timelineViewProvider);
    final now = view.now,
        list = [...view.upcoming, ...view.past],
        upcoming = view.upcoming,
        past = view.past;
    void push(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          IconButton(
            tooltip: 'ค้นหา',
            icon: const Icon(Icons.search),
            onPressed: () => push(const SearchPage()),
          ),
          IconButton(
            tooltip: 'ภาพรวม',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () =>
                push(OverviewPage(openTimeline: () => Navigator.pop(context))),
          ),
          IconButton(
            tooltip: 'ตั้งค่า',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => push(const SettingsPage()),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const AnythingButton(),
      body: RefreshIndicator(
        onRefresh: ref.read(diaryViewModelProvider.notifier).load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Summary(view: view)),
            if (f.active)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                  child: Row(
                    children: [
                      if (f.day != null)
                        Text(
                          '${fmtDate(f.day!)} · ',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      Text(
                        '${list.length} รายการ',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: fvm.clear,
                        child: const Text('ล้างตัวกรอง'),
                      ),
                    ],
                  ),
                ),
              ),
            if (s.loading && s.entries.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (s.error != null && s.entries.isEmpty)
              SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.cloud_off,
                  text: 'โหลดข้อมูลไม่สำเร็จ\n${s.error}',
                  action: FilledButton(
                    onPressed: ref.read(diaryViewModelProvider.notifier).load,
                    child: const Text('ลองใหม่'),
                  ),
                ),
              )
            else if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: f.active ? Icons.filter_alt_off : Icons.edit_note,
                  text: f.active
                      ? 'ไม่พบรายการที่ตรงกับตัวกรอง'
                      : 'ยังไม่มีบันทึก\nกดค้างที่ปุ่ม "กดค้างเพื่อคุย" แล้วเล่าให้ AI ฟังได้เลย',
                ),
              )
            else ...[
              if (upcoming.isNotEmpty)
                EntrySection(
                  title: 'กำลังจะมาถึง',
                  subtitle: '${upcoming.length} รายการ',
                  items: upcoming,
                  now: now,
                ),
              if (upcoming.isNotEmpty && past.isNotEmpty)
                SliverToBoxAdapter(child: _TodayDivider(now: now)),
              for (final MapEntry(key: y, value: items) in view.pastByYear.entries)
                EntrySection(title: '$y', subtitle: 'พ.ศ. ${be(y)}', items: items, now: now),
              const SliverToBoxAdapter(child: SizedBox(height: 144)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayDivider extends StatelessWidget {
  const _TodayDivider({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.withValues(alpha: 0.5))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'วันนี้ · ${fmtDate(now)}',
              style: TextStyle(
                color: c,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: c.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.view});
  final TimelineViewState view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(diaryViewModelProvider);
    final now = view.now, birth = view.birth, next = view.next;
    final facts = [if (birth != null) 'อายุ ${ageOn(birth.date, now)} ปี'];
    final nextRel = next == null
        ? null
        : relativeLabel(
            next.shownDate(now),
            next.lastDate(now),
            now,
            isRange: next.endDate != null,
          );
    // ไม่ล็อกความสูง: ข้อความยาวแค่ขึ้นบรรทัดใหม่ ไม่มีวันล้นทับ
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (facts.isNotEmpty)
            Text(
              facts.join(' · '),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (next != null) ...[
            if (facts.isNotEmpty) const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ถัดไป${nextRel == null ? '' : ' · $nextRel'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    next.title.isEmpty
                        ? state.category(next.category).label
                        : next.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
