import 'package:flutter/material.dart';

/// หัวข้อกลุ่มในหน้าตั้งค่า
class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
