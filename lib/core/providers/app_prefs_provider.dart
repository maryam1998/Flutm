import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_languages.dart';
import '../models/app_prefs.dart';
import '../storage/local_storage.dart';
import '../storage/prefs_keys.dart';

/// Riverpod Notifier که AppPrefs را می‌خواند/می‌نویسد.
class AppPrefsNotifier extends StateNotifier<AppPrefs> {
  final LocalStorage _storage;

  AppPrefsNotifier(this._storage) : super(_read(_storage));

  static AppPrefs _read(LocalStorage s) {
    final json = s.readJson(PrefsKeys.appPrefs);
    if (json.isEmpty) return AppPrefs.defaults;
    return AppPrefs.fromJson(json);
  }

  Future<void> _persist(AppPrefs next) async {
    state = next;
    await _storage.writeJson(PrefsKeys.appPrefs, next.toJson());
  }

  Future<void> setTheme(String key) => _persist(state.copyWith(theme: key));

  Future<void> setFont(String key) => _persist(state.copyWith(font: key));

  Future<void> setFontSize(String key) =>
      _persist(state.copyWith(fontSize: key));

  Future<void> setUiLang(String code) =>
      _persist(state.copyWith(uiLang: code));

  Future<void> setCalendarSystem(CalendarSystem c) =>
      _persist(state.copyWith(calendarSystem: c));

  Future<void> setHighlightColor(String color) =>
      _persist(state.copyWith(highlightColor: color));

  Future<void> setMascotOutfit(String key) =>
      _persist(state.copyWith(mascotOutfit: key));

  Future<void> setMascotEnabled(bool v) =>
      _persist(state.copyWith(mascotEnabled: v));

  Future<void> setMascotCharacter(String key) =>
      _persist(state.copyWith(mascotCharacter: key));

  Future<void> setCustomBgEnabled(bool v) =>
      _persist(state.copyWith(customBgEnabled: v));

  Future<void> setCustomBgOpacity(int v) =>
      _persist(state.copyWith(customBgOpacity: v.clamp(15, 90)));

  Future<void> setTabOrder(TabOrder order) =>
      _persist(state.copyWith(tabOrder: order));
}

final appPrefsProvider =
    StateNotifierProvider<AppPrefsNotifier, AppPrefs>((ref) {
  return AppPrefsNotifier(ref.watch(localStorageProvider));
});
