import 'package:flutter/material.dart';

@immutable
class AppFontPreset {
  final String key;
  final Map<String, String> label;
  final String faFamily;   // نام family در pubspec
  final String latinFamily;

  const AppFontPreset({
    required this.key,
    required this.label,
    required this.faFamily,
    required this.latinFamily,
  });
}

/// نگاشتِ فونت‌های Google Fonts نسخه‌ی وب به familyهای Flutter.
/// فونت‌ها باید در pubspec.yaml و assets/fonts/ تعریف شوند.
/// فعلاً همه به فونت پیش‌فرض Vazirmatn برمی‌گردند تا زمانِ اضافه‌کردن
/// فایل‌های ttf، فقط این map را به‌روز کنیم.
const Map<String, AppFontPreset> kAppFonts = {
  'default': AppFontPreset(
    key: 'default',
    label: {'fa': 'پیش‌فرض', 'en': 'Default'},
    faFamily: 'Vazirmatn',
    latinFamily: 'Lora',
  ),
  'modern': AppFontPreset(
    key: 'modern',
    label: {'fa': 'مدرن', 'en': 'Modern'},
    faFamily: 'Vazirmatn',
    latinFamily: 'Inter',
  ),
  'classic': AppFontPreset(
    key: 'classic',
    label: {'fa': 'کلاسیک', 'en': 'Classic'},
    faFamily: 'NotoNaskhArabic',
    latinFamily: 'Merriweather',
  ),
  'elegant': AppFontPreset(
    key: 'elegant',
    label: {'fa': 'شیک', 'en': 'Elegant'},
    faFamily: 'ArefRuqaa',
    latinFamily: 'PlayfairDisplay',
  ),
  'rounded': AppFontPreset(
    key: 'rounded',
    label: {'fa': 'گرد', 'en': 'Rounded'},
    faFamily: 'NotoKufiArabic',
    latinFamily: 'Poppins',
  ),
  'warm': AppFontPreset(
    key: 'warm',
    label: {'fa': 'گرم', 'en': 'Warm'},
    faFamily: 'NotoSansArabic',
    latinFamily: 'Nunito',
  ),
};
