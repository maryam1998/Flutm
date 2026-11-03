import 'package:flutter/material.dart';
import '../services/app_prefs.dart';

class ThemeStore extends ChangeNotifier {
  static const _key = 'appTheme';
  static const _scaleKey = 'appTextScale';

  /// یک‌بار: تمِ تاریکِ مانده از نسخه‌های قبل (وقتی دکمه‌ی ماه/خورشید تب هدف‌گذاری
  /// تمِ کل برنامه را عوض می‌کرد) پاک می‌شود. بعد از آن فقط انتخابِ خودِ کاربر
  /// (تنظیمات ← ظاهر برنامه) تم را عوض می‌کند؛ ساعت هیچ نقشی ندارد.
  static const _migKey = 'appThemeUserChoiceV2';

  /// حدودِ «اندازه‌ی نوشته‌های برنامه» (۱٫۰ = ۱۴px = پیش‌فرض)
  static const double kTextScaleMin = 11 / 14; // ۱۱px
  static const double kTextScaleMax = 22 / 14; // ۲۲px

  static const _choiceKey = 'appThemeChoiceV3';

  ThemeMode _mode = ThemeMode.light;
  double _textScale = 1.0;

  /// 'auto' = کاربر تمی انتخاب نکرده؛ نقشه طبق ساعتِ گوشی روشن/تیره می‌شود
  /// 'dark' / 'light' = انتخابِ دستیِ کاربر (ساعت نادیده گرفته می‌شود)
  String _choice = 'auto';

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// تیکِ «تم تاریک» خاموش و انتخابِ دستی در کار نیست ← نقشه با ساعت هماهنگ است
  bool get isAuto => _choice == 'auto';

  /// انتخابِ دستیِ روشن (نقشه همیشه روشن)
  bool get forcedLight => _choice == 'light';

  /// ضریب اندازه‌ی نوشته‌ی کل برنامه (همه‌ی صفحه‌ها، کادرها و دکمه‌ها)
  double get textScale => _textScale;

  Future<void> load() async {
    try {
      final sp = await AppPrefs.getInstance();
      var v = sp.getString(_key);
      if (sp.getBool(_migKey) != true) {
        await sp.setBool(_migKey, true);
        if (v == 'dark') {
          v = 'light';
          await sp.setString(_key, 'light');
        }
      }
      final ch = sp.getString(_choiceKey);
      if (ch == 'dark' || ch == 'light' || ch == 'auto') {
        _choice = ch.toString();
      } else {
        // کاربرانِ قبلی: فقط اگر تمِ تاریک را خودشان زده بودند دستی بماند
        _choice = (v == 'dark') ? 'dark' : 'auto';
      }
      _mode = (_choice == 'dark') ? ThemeMode.dark : ThemeMode.light;
      final sc = sp.getDouble(_scaleKey);
      if (sc != null) {
        _textScale = sc.clamp(kTextScaleMin, kTextScaleMax).toDouble();
      }
    } catch (_) {
      _mode = ThemeMode.light;
    }
    notifyListeners();
  }

  /// تیکِ «تم تاریک»: روشن = همیشه تیره؛ خاموش = خودکار (نقشه طبق ساعتِ گوشی)
  Future<void> setDark(bool dark) => setChoice(dark ? 'dark' : 'auto');

  Future<void> setChoice(String choice) async {
    if (choice != 'dark' && choice != 'light') choice = 'auto';
    _choice = choice;
    _mode = choice == 'dark' ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setString(_choiceKey, choice);
      await sp.setString(_key, choice == 'dark' ? 'dark' : 'light');
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
