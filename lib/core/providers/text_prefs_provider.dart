import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/text_prefs.dart';
import '../storage/local_storage.dart';
import '../storage/prefs_keys.dart';

class TextPrefsNotifier extends StateNotifier<TargetTextPrefs> {
  final LocalStorage _storage;

  TextPrefsNotifier(this._storage)
      : super(TargetTextPrefs.fromJson(
          _storage.readJson(PrefsKeys.targetTextPrefs),
        ));

  Future<void> _persist(TargetTextPrefs next) async {
    state = next;
    await _storage.writeJson(PrefsKeys.targetTextPrefs, next.toJson());
  }

  Future<void> setScale(int scale) =>
      _persist(state.copyWith(scale: scale.clamp(50, 250)));

  Future<void> setBold(TargetBoldMode mode) =>
      _persist(state.copyWith(bold: mode));

  Future<void> setSentenceGap(int v) => _persist(state.copyWith(
      sentenceGap: v.clamp(
          TargetTextPrefs.minSentenceGap, TargetTextPrefs.maxSentenceGap)));

  Future<void> setLangGap(int v) => _persist(state.copyWith(
      langGap:
          v.clamp(TargetTextPrefs.minLangGap, TargetTextPrefs.maxLangGap)));

  Future<void> resetGaps() => _persist(state.copyWith(
      sentenceGap: TargetTextPrefs.defaultSentenceGap,
      langGap: TargetTextPrefs.defaultLangGap));
}

final textPrefsProvider =
    StateNotifierProvider<TextPrefsNotifier, TargetTextPrefs>((ref) {
  return TextPrefsNotifier(ref.watch(localStorageProvider));
});
