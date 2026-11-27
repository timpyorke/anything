import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/language.dart';
import '../../core/widgets/empty_state.dart';
import 'entry_section.dart';
import 'timeline_view_model.dart';

/// รายการล่วงหน้าทั้งหมด เรียงจากใกล้ไปไกล จัดกลุ่มตามเดือน
class UpcomingPage extends ConsumerWidget {
  const UpcomingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final view = ref.watch(timelineViewProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.upcoming)),
      body: view.upcoming.isEmpty
          ? EmptyState(
              icon: Icons.event_available_rounded,
              text: t.noUpcoming,
              detail: t.noUpcomingDetail,
            )
          : CustomScrollView(
              slivers: [
                for (final MapEntry(key: month, value: items) in view.upcomingByMonth.entries)
                  EntrySection(
                    title: t.monthsLong[month.month - 1],
                    subtitle: t.yearLabel(month.year),
                    items: items,
                    now: view.now,
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
              ],
            ),
    );
  }
}
