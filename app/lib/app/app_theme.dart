import 'package:flutter/material.dart';


ThemeData buildAppTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xff2f62e0), brightness: b);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
    ),
  );
}
