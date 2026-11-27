import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../../core/widgets/empty_state.dart';
import 'entry_section.dart';
import 'timeline_view_model.dart';

/// รายการล่วงหน้าทั้งหมด เรียงจากใกล้ไปไกล จัดกลุ่มตามเดือน
class UpcomingPage extends ConsumerWidget {
  const UpcomingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(timelineViewProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('กำลังจะมาถึง')),
      body: view.upcoming.isEmpty
          ? const EmptyState(icon: Icons.event_available, text: 'ไม่มีรายการล่วงหน้า')
          : CustomScrollView(
              slivers: [
                for (final MapEntry(key: month, value: items) in view.upcomingByMonth.entries)
                  EntrySection(
                    title: thMonthsLong[month.month - 1],
                    subtitle: 'พ.ศ. ${be(month.year)}',
                    items: items,
                    now: view.now,
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }
}
