import 'package:flutter/material.dart';

/// ฟอนต์ไทยมีหัว อ่านยาวได้สบาย (ประกาศใน pubspec.yaml)
const appFontFamily = 'PlexThai';

/// ระยะและมุมโค้งกลางของแอป — ใช้ค่าจากที่นี่ ทุกหน้าจะเรียงตรงแนวกัน
abstract final class Insets {
  /// ขอบซ้ายขวาของหน้าจอ
  static const page = 16.0;
}

abstract final class Corners {
  static const control = 12.0;
  static const card = 16.0;
  static const sheet = 24.0;
}

/// ธีม "สมุดบันทึกเรียบๆ": พื้นกระดาษโทนอุ่น การ์ดแบนเส้นบาง สีเน้นสีเดียวสำหรับสิ่งที่กดได้
/// สีสันที่เหลือมาจากสีหมวดของผู้ใช้ เพื่อให้ข้อมูลเป็นพระเอก
ThemeData buildAppTheme(Brightness b) {
  final dark = b == Brightness.dark;
  const accent = Color(0xff3b5bd9);
  final bg = dark ? const Color(0xff111110) : const Color(0xfff7f6f3);
  final surface = dark ? const Color(0xff1b1b19) : Colors.white;
  final line = dark ? const Color(0xff302f2b) : const Color(0xffe5e2db);
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: b).copyWith(
    primary: dark ? const Color(0xffa5b6ff) : accent,
    onPrimary: dark ? const Color(0xff14204d) : Colors.white,
    primaryContainer: dark ? const Color(0xff27335c) : const Color(0xffe7ebfb),
    onPrimaryContainer: dark ? const Color(0xffdde3ff) : const Color(0xff1f357f),
    error: dark ? const Color(0xffffb4ab) : const Color(0xffb3261e),
    onError: dark ? const Color(0xff4a0904) : Colors.white,
    errorContainer: dark ? const Color(0xff4d1c18) : const Color(0xfffce9e7),
    onErrorContainer: dark ? const Color(0xffffdad5) : const Color(0xff7a1710),
    surface: bg,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: surface,
    surfaceContainerHighest: dark ? const Color(0xff272724) : const Color(0xffedebe5),
    outline: dark ? const Color(0xff807d75) : const Color(0xff8a867d),
    outlineVariant: line,
    onSurface: dark ? const Color(0xfff1efea) : const Color(0xff1d1c1a),
    onSurfaceVariant: dark ? const Color(0xffa8a49b) : const Color(0xff66625a),
    inverseSurface: dark ? const Color(0xffefede8) : const Color(0xff2b2a27),
    onInverseSurface: dark ? const Color(0xff1d1c1a) : const Color(0xfff4f2ed),
    inversePrimary: dark ? accent : const Color(0xffb7c4ff),
  );

  // อักษรไทยมีสระและวรรณยุกต์ซ้อนบนล่าง: บรรทัดต้องสูงพอ และห้ามบีบช่องไฟ (letterSpacing ติดลบ)
  TextStyle style(double size, FontWeight weight, double height, [Color? color]) => TextStyle(
        fontFamily: appFontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: 0,
        color: color ?? scheme.onSurface,
        leadingDistribution: TextLeadingDistribution.even,
      );

  final text = TextTheme(
    displayLarge: style(48, FontWeight.w700, 1.25),
    displayMedium: style(40, FontWeight.w700, 1.25),
    displaySmall: style(34, FontWeight.w700, 1.3),
    headlineLarge: style(30, FontWeight.w700, 1.3),
    headlineMedium: style(26, FontWeight.w700, 1.3),
    headlineSmall: style(22, FontWeight.w700, 1.35),
    titleLarge: style(19, FontWeight.w700, 1.4),
    titleMedium: style(16, FontWeight.w600, 1.45),
    titleSmall: style(14, FontWeight.w600, 1.45),
    bodyLarge: style(16, FontWeight.w400, 1.5),
    bodyMedium: style(14.5, FontWeight.w400, 1.55),
    bodySmall: style(12.5, FontWeight.w400, 1.5, scheme.onSurfaceVariant),
    labelLarge: style(14, FontWeight.w600, 1.4),
    labelMedium: style(12.5, FontWeight.w500, 1.4),
    labelSmall: style(11.5, FontWeight.w500, 1.4),
  );

  final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corners.control));
  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.control),
        borderSide: BorderSide(color: color, width: width),
      );
  const buttonSize = Size(48, 48);

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: appFontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    dividerColor: line,
    splashFactory: InkRipple.splashFactory,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 4,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corners.card), side: BorderSide(color: line)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: line),
      shape: const StadiumBorder(),
      showCheckmark: false,
      // ชิปรองรับเฉพาะ "สี" ที่เปลี่ยนตามสถานะ (WidgetStateTextStyle ทั้งก้อนจะถูกรวมจนฟอนต์และสีหาย)
      labelStyle: text.labelLarge!.copyWith(
        fontWeight: FontWeight.w500,
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurface,
        ),
      ),
      secondaryLabelStyle: text.labelLarge!.copyWith(color: scheme.onPrimaryContainer),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: inputBorder(line),
      enabledBorder: inputBorder(line),
      disabledBorder: inputBorder(line),
      focusedBorder: inputBorder(scheme.primary, 1.5),
      errorBorder: inputBorder(scheme.error),
      focusedErrorBorder: inputBorder(scheme.error, 1.5),
      hintStyle: text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
      helperStyle: text.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        minimumSize: buttonSize,
        shape: controlShape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        foregroundColor: scheme.onSurface,
        backgroundColor: surface,
        side: BorderSide(color: line),
        shape: controlShape,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: buttonSize, shape: controlShape, textStyle: text.labelLarge),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: line)),
        shape: WidgetStatePropertyAll(controlShape),
        minimumSize: const WidgetStatePropertyAll(buttonSize),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? scheme.primaryContainer : surface),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: Insets.page, vertical: 2),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corners.sheet)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.sheet))),
    ),
    popupMenuTheme: PopupMenuThemeData(color: surface, surfaceTintColor: Colors.transparent, shape: controlShape),
    progressIndicatorTheme: ProgressIndicatorThemeData(linearTrackColor: scheme.surfaceContainerHighest),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium!.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      shape: controlShape,
    ),
  );
}
