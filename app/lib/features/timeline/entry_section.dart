import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../domain/entry.dart';
import '../entry_editor/entry_editor_page.dart';
import 'entry_card.dart';

/// หัวข้อ + รายการแบบ journal (sliver) ใช้ทั้ง Timeline, หน้ารายการล่วงหน้า และหน้าค้นหา
class EntrySection extends ConsumerWidget {
  const EntrySection({
    super.key,
    required this.title,
    required this.items,
    required this.now,
    this.subtitle,
    this.emptyText,
    this.impliedBadge,
  });
  final String title;
  final String? subtitle;
  final List<Entry> items;
  final DateTime now;

  /// ข้อความใต้หัวข้อเมื่อไม่มีรายการ
  final String? emptyText;

  /// ป้ายที่หัวข้อบอกอยู่แล้ว ไม่ต้องแสดงซ้ำบนแถว
  final String? impliedBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Insets.page + 4, 24, Insets.page, 8),
            child: Semantics(
              header: true,
              // ตัวอักษรใหญ่: หัวข้อรองตกบรรทัดแทนการล้น
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(subtitle!, style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (items.isEmpty && emptyText != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Insets.page, 4, Insets.page, 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Icon(Icons.edit_note_rounded, size: 36, color: theme.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text(emptyText!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(t.entryExamples,
                        textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  ]),
                ),
              ),
            ),
          ),
        SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            // วันเดียวกันหลายรายการ แสดงวันที่และป้ายเฉพาะแถวแรก
            // (ป้ายที่ต่างออกไป เช่น ช่วงหลายวันที่เริ่มวันเดียวกัน ยังต้องแสดง)
            final newDay = i == 0 || items[i - 1].shownDate(now) != items[i].shownDate(now);
            final badge = EntryCard.badgeOf(items[i], now, t);
            return EntryCard(
              entry: items[i],
              now: now,
              showDate: newDay,
              showBadge: badge != impliedBadge && (newDay || EntryCard.badgeOf(items[i - 1], now, t) != badge),
              onTap: () => openEditor(context, entry: items[i]),
            );
          },
        ),
      ],
    );
  }
}
