import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// หัวข้อกลุ่มในหน้าตั้งค่า
class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.page + 4, 4, Insets.page, 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }
}
