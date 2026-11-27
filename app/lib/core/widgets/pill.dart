import 'package:material_ui/material_ui.dart';

/// ป้ายเล็ก: มีสี = พื้นสีจางตัวอักษรสีนั้น · ไม่มีสี = พื้นเทา · outlined = ข้อความเทาไม่มีพื้น (เงียบที่สุด)
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.outlined = false, this.icon});
  final String text;
  final Color? color;
  final bool outlined;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
      padding: EdgeInsets.symmetric(horizontal: outlined ? 0 : 8, vertical: outlined ? 0 : 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Flexible(child: Text(text, style: theme.textTheme.labelMedium?.copyWith(color: fg, height: 1.4))),
      ]),
    );
  }
}
