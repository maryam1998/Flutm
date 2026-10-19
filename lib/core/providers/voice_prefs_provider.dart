import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';
import '../storage/prefs_keys.dart';

/// Map<langCode, voiceId> — پیش‌فرض خالی؛ انتخاب صدا در فاز ۳ پر می‌شود.
class VoicePrefsNotifier extends StateNotifier<Map<String, String>> {
  final LocalStorage _storage;

  VoicePrefsNotifier(this._storage)
      : super(_read(_storage));

  static Map<String, String> _read(LocalStorage s) {
    final json = s.readJson(PrefsKeys.voicePrefs);
    return json.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<void> setVoiceForLang(String langCode, String? voiceId) async {
    final next = {...state};
    if (voiceId == null || voiceId.isEmpty) {
      next.remove(langCode);
    } else {
      next[langCode] = voiceId;
    }
    state = next;
    await _storage.writeJson(PrefsKeys.voicePrefs, next);
  }
}

final voicePrefsProvider =
    StateNotifierProvider<VoicePrefsNotifier, Map<String, String>>((ref) {
  return VoicePrefsNotifier(ref.watch(localStorageProvider));
});
