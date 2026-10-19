import 'package:flutter/material.dart';

import '../constants/app_fonts.dart';
import '../constants/app_themes.dart';
import 'app_theme_colors.dart';

/// تبدیلِ AppThemePreset + AppFontPreset به یک ThemeData واقعیِ Flutter.
/// توجه: فونت‌های فارسی/لاتین را در یک TextStyle ادغام می‌کنیم تا هر دو
/// اسکریپت هم‌زمان رندر شوند (Vazirmatn برای فارسی، latin family برای
/// کاراکترهای لاتین وقتی در جمله‌ی فارسی می‌آیند).
ThemeData buildAppTheme(AppThemePreset preset, AppFontPreset font) {
  final c = preset.colors;

  // استراتژی فونت: خانواده‌ی فارسی را در fontFamily می‌گذاریم و fontFamilyFallback
  // را روی فونت لاتین می‌گذاریم. در Flutter، برای هر کاراکتر اول از fontFamily
  // تلاش می‌شود و اگر نداشت به fallback می‌رود — دقیقاً همان رفتاری که
  // CSS font-family در وب داشت.
  final baseTextTheme = _buildTextTheme(c, font);

  return ThemeData(
    useMaterial3: true,
    brightness: _brightnessOf(preset.key),
    scaffoldBackgroundColor: c.paper,
    canvasColor: c.paper,
    cardColor: c.paperDark,
    dividerColor: c.cardBorder,
    fontFamily: font.faFamily,
    fontFamilyFallback: [font.latinFamily],
    colorScheme: ColorScheme(
      brightness: _brightnessOf(preset.key),
      primary: c.teal,
      onPrimary: c.headerText,
      secondary: c.gold,
      onSecondary: c.ink,
      surface: c.paper,
      onSurface: c.ink,
      error: c.rose,
      onError: Colors.white,
      outline: c.cardBorder,
    ),
    textTheme: baseTextTheme,
    extensions: [AppThemeColorsExt(c)],
    appBarTheme: AppBarTheme(
      backgroundColor: c.headerFrom,
      foregroundColor: c.headerText,
      elevation: 0,
      centerTitle: false,
    ),
  );
}

Brightness _brightnessOf(String themeKey) =>
    themeKey == 'midnight' ? Brightness.dark : Brightness.light;

TextTheme _buildTextTheme(AppThemeColors c, AppFontPreset font) {
  TextStyle base(double size, {FontWeight weight = FontWeight.w400}) => TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: c.ink,
        fontFamily: font.faFamily,
        fontFamilyFallback: [font.latinFamily],
      );

  return TextTheme(
    displayLarge:  base(34, weight: FontWeight.w700),
    displayMedium: base(28, weight: FontWeight.w700),
    displaySmall:  base(24, weight: FontWeight.w700),
    headlineLarge: base(22, weight: FontWeight.w700),
    headlineMedium:base(20, weight: FontWeight.w600),
    headlineSmall: base(18, weight: FontWeight.w600),
    titleLarge:    base(18, weight: FontWeight.w600),
    titleMedium:   base(16, weight: FontWeight.w600),
    titleSmall:    base(14, weight: FontWeight.w600),
    bodyLarge:     base(16),
    bodyMedium:    base(14),
    bodySmall:     base(12),
    labelLarge:    base(14, weight: FontWeight.w600),
    labelMedium:   base(12, weight: FontWeight.w500),
    labelSmall:    base(11, weight: FontWeight.w500),
  );
}
