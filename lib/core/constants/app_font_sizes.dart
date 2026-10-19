import 'package:flutter/material.dart';

@immutable
class AppFontSizePreset {
  final String key;
  final Map<String, String> label;
  /// ضریب مقیاسِ فونت — معادلِ CSS zoom در نسخه‌ی وب.
  final double scale;

  const AppFontSizePreset({
    required this.key,
    required this.label,
    required this.scale,
  });
}

const Map<String, AppFontSizePreset> kAppFontSizes = {
  'small': AppFontSizePreset(
    key: 'small',
    label: {'fa': 'کوچک', 'en': 'Small'},
    scale: 0.9,
  ),
  'medium': AppFontSizePreset(
    key: 'medium',
    label: {'fa': 'متوسط (پیش‌فرض)', 'en': 'Medium (default)'},
    scale: 1.0,
  ),
  'large': AppFontSizePreset(
    key: 'large',
    label: {'fa': 'بزرگ', 'en': 'Large'},
    scale: 1.15,
  ),
  'xlarge': AppFontSizePreset(
    key: 'xlarge',
    label: {'fa': 'خیلی بزرگ', 'en': 'Extra large'},
    scale: 1.3,
  ),
};
