import 'package:flutter/material.dart';

/// ธีมมินิมอล: พื้นเรียบ โทนกลาง สีเน้นสีเดียว การ์ดแบนไม่มีเงา เส้นขอบบางมาก
/// สีสันที่เหลือมาจากสีหมวดของผู้ใช้เท่านั้น เพื่อให้ข้อมูลเป็นพระเอก
ThemeData buildAppTheme(Brightness b) {
  final dark = b == Brightness.dark;
  const accent = Color(0xff3e63dd);
  final base = ColorScheme.fromSeed(seedColor: accent, brightness: b);
  final bg = dark ? const Color(0xff0f0f10) : const Color(0xfffafaf9);
  final surface = dark ? const Color(0xff18181a) : Colors.white;
  final line = dark ? const Color(0xff2a2a2d) : const Color(0xffebebe8);
  final scheme = base.copyWith(
    primary: dark ? const Color(0xff9eb1ff) : accent,
    surface: bg,
    surfaceContainerLow: surface,
    surfaceContainerHighest: dark ? const Color(0xff232326) : const Color(0xfff1f1ee),
    outlineVariant: line,
    onSurface: dark ? const Color(0xfff2f2f0) : const Color(0xff1a1a1c),
    onSurfaceVariant: dark ? const Color(0xff9a9aa0) : const Color(0xff6b6b72),
  );

  final text = Typography.material2021(platform: TargetPlatform.android).black.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    dividerColor: line,
    splashFactory: InkRipple.splashFactory,
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.5),
      bodySmall: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: line)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
          )),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: scheme.onSurface,
      side: BorderSide(color: line),
      shape: const StadiumBorder(),
      showCheckmark: false,
      labelStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(fontSize: 13, color: scheme.surface),
      checkmarkColor: scheme.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.4)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.onSurface,
        foregroundColor: scheme.surface,
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      backgroundColor: scheme.onSurface,
      foregroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.all(BorderSide(color: line)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? scheme.onSurface : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? scheme.surface : scheme.onSurfaceVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.onSurface,
      contentTextStyle: TextStyle(color: scheme.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
