import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/local_storage.dart';
import '../translate/translation_service.dart';

const String _kBackendUrlKey = 'phrasebook-backend-url';

/// مثل وب‌اپ: اگر کاربر آدرسی ذخیره نکرده باشد، Worker پیش‌فرض (kDefaultBackendUrl)
/// استفاده می‌شود — قبلاً state خالی بود و AI (تأیید/fallback ترجمه) اصلاً صدا زده نمی‌شد.
class AiSettingsNotifier extends StateNotifier<AiSettings> {
  final SharedPreferences _prefs;

  AiSettingsNotifier(this._prefs)
      : super(AiSettings(backendUrl: _read(_prefs)));

  static String _read(SharedPreferences p) {
    final saved = (p.getString(_kBackendUrlKey) ?? '').trim();
    return saved.isEmpty ? kDefaultBackendUrl : saved;
  }

  Future<void> setBackendUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _prefs.setString(_kBackendUrlKey, clean);
    state = AiSettings(backendUrl: clean.isEmpty ? kDefaultBackendUrl : clean);
  }
}

final aiSettingsProvider =
    StateNotifierProvider<AiSettingsNotifier, AiSettings>((ref) {
  return AiSettingsNotifier(ref.watch(sharedPrefsProvider));
});
