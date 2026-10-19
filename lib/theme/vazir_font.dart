import 'package:flutter/material.dart';

/// جایگزین محلیِ پکیج google_fonts.
///
/// چرا؟ پکیج google_fonts اگه فونت رو توی assets پیدا نکنه، از اینترنت
/// (fonts.gstatic.com) دانلود می‌کنه و روی اینترنت ضعیف/فیلترشده شروع برنامه
/// رو کند می‌کرد. وزیرمتن داخل خود برنامه است (pubspec → family: Vazirmatn)،
/// پس اینجا فقط اسمش رو به TextStyle می‌دیم؛ بدون دانلود و بدون انتظار.
///
/// اسم کلاس عمداً GoogleFonts مونده تا بقیه‌ی کدها دست نخورن.
class GoogleFonts {
  GoogleFonts._();

  static const String family = 'Vazirmatn';

  static TextStyle vazirmatn({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    Paint? foreground,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    List<String>? fontFamilyFallback,
  }) {
    return (textStyle ?? const TextStyle()).copyWith(
      fontFamily: family,
      color: foreground == null ? color : null,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      foreground: foreground,
      shadows: shadows,
      fontFeatures: fontFeatures,
      fontFamilyFallback: fontFamilyFallback,
    );
  }

  static TextTheme vazirmatnTextTheme([TextTheme? base]) =>
      (base ?? ThemeData.light().textTheme).apply(fontFamily: family);
}
