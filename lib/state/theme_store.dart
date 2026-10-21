import 'package:flutter/material.dart';
import '../services/app_prefs.dart';

class ThemeStore extends ChangeNotifier {
  static const _key = 'appTheme';
  static const _scaleKey = 'appTextScale';

  /// حدودِ «اندازه‌ی نوشته‌های برنامه» (۱٫۰ = ۱۴px = پیش‌فرض)
  static const double kTextScaleMin = 11 / 14; // ۱۱px
  static const double kTextScaleMax = 22 / 14; // ۲۲px

  ThemeMode _mode = ThemeMode.light;
  double _textScale = 1.0;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// ضریب اندازه‌ی نوشته‌ی کل برنامه (همه‌ی صفحه‌ها، کادرها و دکمه‌ها)
  double get textScale => _textScale;

  Future<void> load() async {
    try {
      final sp = await AppPrefs.getInstance();
      final v = sp.getString(_key);
      _mode = (v == 'dark') ? ThemeMode.dark : ThemeMode.light;
      final sc = sp.getDouble(_scaleKey);
      if (sc != null) {
        _textScale = sc.clamp(kTextScaleMin, kTextScaleMax).toDouble();
      }
    } catch (_) {
      _mode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> setDark(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setString(_key, dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> setTextScale(double v) async {
    final nv = v.clamp(kTextScaleMin, kTextScaleMax).toDouble();
    if ((nv - _textScale).abs() < 0.001) return;
    _textScale = nv;
    notifyListeners();
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setDouble(_scaleKey, nv);
    } catch (_) {}
  }

  Future<void> toggle() => setDark(!isDark);
}
