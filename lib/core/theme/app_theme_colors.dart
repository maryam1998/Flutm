import 'package:flutter/material.dart';

import '../constants/app_themes.dart';

/// ThemeExtension تا هر جای ویجت‌ها بتوانیم به رنگ‌های اختصاصی تم
/// (paper/paperDark/ink/gold/...) دسترسی داشته باشیم — معادل CSS variables.
@immutable
class AppThemeColorsExt extends ThemeExtension<AppThemeColorsExt> {
  final AppThemeColors colors;
  const AppThemeColorsExt(this.colors);

  @override
  AppThemeColorsExt copyWith({AppThemeColors? colors}) =>
      AppThemeColorsExt(colors ?? this.colors);

  @override
  AppThemeColorsExt lerp(ThemeExtension<AppThemeColorsExt>? other, double t) {
    if (other is! AppThemeColorsExt) return this;
    // رنگ‌ها گسسته‌اند؛ در زمان ت بین دو تم، انتخاب نزدیک‌ترین کافی است.
    return t < 0.5 ? this : other;
  }

  Color get paper => colors.paper;
  Color get paperDark => colors.paperDark;
  Color get ink => colors.ink;
  Color get inkSoft => colors.inkSoft;
  Color get gold => colors.gold;
  Color get goldSoft => colors.goldSoft;
  Color get teal => colors.teal;
  Color get rose => colors.rose;
  Color get cardBorder => colors.cardBorder;
  Color get headerFrom => colors.headerFrom;
  Color get headerTo => colors.headerTo;
  Color get headerText => colors.headerText;
}

extension AppThemeX on BuildContext {
  AppThemeColorsExt get appColors =>
      Theme.of(this).extension<AppThemeColorsExt>()!;
}
