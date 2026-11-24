import 'package:flutter/material.dart';

/// การ์ดตัวเลขสรุป: ป้ายเล็กด้านบน ตัวเลขใหญ่ตรงกลาง (จุดสี = สีของ metric/หมวด)
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.sub, this.color, this.onTap});
  final String value, label;
  final String? sub;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.35);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (color != null) ...[
                Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Expanded(child: Text(label, style: muted, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (sub != null) Text(sub!, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}
