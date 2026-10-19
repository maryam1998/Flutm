import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conversation_provider.dart';
import 'word_sources_provider.dart';

bool _started = false;

/// داده‌ی همه‌ی تب‌ها را همان اولِ اجرای اپ (پشتِ صفحه‌ی ورود/اولین تب) بارگذاری
/// می‌کند تا هنگام عوض‌کردنِ تب، لیست «همان لحظه» آماده باشد.
/// قبلاً بارگذاری تازه با باز شدنِ تب شروع می‌شد و تا چند ثانیه خالی می‌ماند.
void startDataPreload(ProviderContainer c) {
  if (_started) return;
  _started = true;
  // سبک‌ها فوراً
  unawaited(c.read(dailyWordsLoaderProvider.future));
  unawaited(c.read(conversationLoaderProvider.future));
  // فایل‌های سنگین (اسلنگ ۳۶۰KB، Vocab in use ۱٫۲MB) کمی بعد تا اولین فریم‌ها نپرند
  Future.delayed(const Duration(milliseconds: 500), () {
    unawaited(c.read(slangWordsProvider.future));
    Future.delayed(const Duration(milliseconds: 300), () {
      unawaited(c.read(vocabInUseWordsProvider.future));
    });
  });
}
