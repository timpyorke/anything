import 'package:flutter/material.dart';

import '../../domain/entry.dart';
import '../entry_editor/entry_editor_page.dart';
import 'entry_card.dart';

/// หัวข้อ + รายการแบบ journal (sliver) ใช้ทั้ง Timeline และหน้าค้นหา
class EntrySection extends StatelessWidget {
  const EntrySection({super.key, required this.title, required this.subtitle, required this.items, required this.now});
  final String title, subtitle;
  final List<Entry> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 8),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              // วันเดียวกันหลายรายการ แสดงวันที่และป้ายเฉพาะแถวแรก
              // (ป้ายที่ต่างออกไป เช่น ช่วงหลายวันที่เริ่มวันเดียวกัน ยังต้องแสดง)
              final newDay = i == 0 || items[i - 1].shownDate(now) != items[i].shownDate(now);
              return EntryCard(
                entry: items[i],
                now: now,
                showDate: newDay,
                showBadge: newDay || EntryCard.badgeOf(items[i - 1], now) != EntryCard.badgeOf(items[i], now),
                onTap: () => openEditor(context, entry: items[i]),
              );
            },
          ),
        ],
      );
}
