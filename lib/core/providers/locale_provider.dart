import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_languages.dart';
import 'app_prefs_provider.dart';

/// زبان رابط — از AppPrefs.uiLang خوانده می‌شود.
final localeProvider = Provider<Locale>((ref) {
  final code = ref.watch(appPrefsProvider.select((p) => p.uiLang));
  return Locale(code);
});

/// جهت اپ بر اساس زبان رابط.
final appDirectionProvider = Provider<TextDirection>((ref) {
  final code = ref.watch(appPrefsProvider.select((p) => p.uiLang));
  return kAppLanguages[code]?.dir ?? TextDirection.rtl;
});
