import 'package:flutter/material.dart';

import '../utils/format.dart';

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.outlined = false, this.icon});
  final String text;
  final Color? color;
  final bool outlined;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = outlined ? Colors.transparent : (color ?? scheme.secondaryContainer);
    final fg = outlined ? scheme.onSurfaceVariant : (color == null ? scheme.onSecondaryContainer : onColor(color!));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: outlined ? Border.all(color: scheme.outlineVariant) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 3)],
        Text(text, style: TextStyle(fontSize: 12, color: fg, height: 1.4)),
      ]),
    );
  }
}
