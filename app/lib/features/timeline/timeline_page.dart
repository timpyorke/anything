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
import 'upcoming_card.dart';
import 'upcoming_page.dart';

class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(diaryViewModelProvider);
    final f = ref.watch(timelineFilterProvider);
    final fvm = ref.read(timelineFilterProvider.notifier);
    final view = ref.watch(timelineViewProvider);
    final now = view.now;
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
                        '${view.count} รายการ',
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
            else if (f.active && view.count == 0)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(icon: Icons.filter_alt_off, text: 'ไม่พบรายการที่ตรงกับตัวกรอง'),
              )
            else ...[
              // กรองอยู่: เส้นเวลาเดียว ไม่ย่ออนาคต เพื่อไม่ให้วันที่เลือกถูกซ่อน
              if (f.active)
                for (final MapEntry(key: y, value: items) in view.allByYear.entries)
                  EntrySection(title: '$y', subtitle: 'พ.ศ. ${be(y)}', items: items, now: now)
              else ...[
                if (view.upcoming.isNotEmpty)
                  SliverToBoxAdapter(
                    child: UpcomingCard(view: view, onShowAll: () => push(const UpcomingPage())),
                  ),
                EntrySection(
                  title: 'วันนี้',
                  subtitle: '${thWeekdays[now.weekday - 1]} ${fmtDay(now)}',
                  items: view.current,
                  now: now,
                  impliedBadge: 'วันนี้',
                  emptyText: 'ยังไม่ได้บันทึก พิมพ์หรือกดไมค์เล่าให้ AI ฟังได้เลย',
                ),
                for (final MapEntry(key: y, value: items) in view.pastByYear.entries)
                  EntrySection(
                    title: y == now.year ? 'ก่อนหน้านี้' : '$y',
                    subtitle: 'พ.ศ. ${be(y)}',
                    items: items,
                    now: now,
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 144)),
            ],
          ],
        ),
      ),
    );
  }
}
