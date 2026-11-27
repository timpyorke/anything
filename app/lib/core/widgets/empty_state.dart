import 'package:flutter/material.dart';

/// หน้าว่าง: ไอคอนในวงกลมจาง ข้อความหลัก คำอธิบายรอง (ถ้ามี) และปุ่มสิ่งที่ทำต่อได้
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.detail, this.action});
  final IconData icon;
  final String text;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      // เลื่อนได้: จอเตี้ย คีย์บอร์ดเปิด หรือตัวอักษรใหญ่ต้องไม่ล้น
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DecoratedBox(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}
