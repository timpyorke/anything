import 'package:flutter/material.dart';

/// ป้ายเล็ก: มีสี = พื้นสีจางตัวอักษรสีหมวด · outlined = ข้อความเทาไม่มีกรอบ (เงียบที่สุด)
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.outlined = false, this.icon});
  final String text;
  final Color? color;
  final bool outlined;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color bg, fg;
    if (outlined) {
      bg = Colors.transparent;
      fg = scheme.onSurfaceVariant;
    } else if (color != null) {
      bg = color!.withValues(alpha: 0.12);
      // ผสมกับสีตัวอักษรหลักให้อ่านชัดทั้งโหมดสว่าง/มืด
      fg = Color.lerp(color, scheme.onSurface, 0.3)!;
    } else {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurfaceVariant;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: outlined ? 0 : 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 3)],
        Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: fg, height: 1.4, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
