import 'package:flutter/material.dart';
import '../services/app_prefs.dart';

class ThemeStore extends ChangeNotifier {
  static const _key = 'appTheme';
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    try {
      final sp = await AppPrefs.getInstance();
      final v = sp.getString(_key);
      _mode = (v == 'dark') ? ThemeMode.dark : ThemeMode.light;
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

  Future<void> toggle() => setDark(!isDark);
}
