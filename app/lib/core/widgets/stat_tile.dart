import 'package:flutter/material.dart';

/// การ์ดตัวเลขสรุป: ตัวเลขใหญ่ด้านบน คำอธิบายด้านล่าง
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.icon});
  final String value, label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: MergeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20, color: theme.colorScheme.primary), const SizedBox(height: 8)],
            // ตัวเลขยาวหรือตัวอักษรใหญ่: ย่อแทนการตัดท้าย
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}
