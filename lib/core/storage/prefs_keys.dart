/// کلیدهای localStorage نسخه‌ی وب — عیناً حفظ شده تا مهاجرت داده‌ی
/// کاربرهای قدیمی ممکن باشد (در فاز مهاجرت).
class PrefsKeys {
  static const String appPrefs = 'phrasebook-app-prefs';
  static const String state = 'phrasebook-state-v1';
  static const String targetTextPrefs = 'phrasebook-target-text-prefs-v1';
  static const String voicePrefs = 'phrasebook-voice-prefs-v1';
  static const String languageSelection = 'phrasebook-language-selection-v1';
  static const String wordFavorites = 'phrasebook-word-favorites-v1';

  // رویدادها (فقط در نسخه‌ی وب) — در Dart با Riverpod provider تغییرات propagate می‌شوند.
  static const String appPrefsChangedEvent = 'phrasebook:appPrefsChanged';
  static const String targetTextPrefsChangedEvent = 'phrasebook:targetTextPrefsChanged';
  static const String voicePrefsChangedEvent = 'phrasebook:voicePrefsChanged';
}
