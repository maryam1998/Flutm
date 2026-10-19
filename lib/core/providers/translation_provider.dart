import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../translate/translation_service.dart';
import 'ai_settings_provider.dart';

final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService();
});

/// ترجمه‌ی یک متن به یک زبان مقصد (معادلِ translateFree وب).
/// autoDispose: اگر همه‌ی سرویس‌ها شکست خوردند و متن اصلی برگشت، نتیجه‌ی
/// ناموفق تا آخر نشست نمی‌چسبد؛ دفعه‌ی بعد دوباره تلاش می‌شود (موفق‌ها از کش می‌آیند).
final translationProvider = FutureProvider.autoDispose.family<String,
    ({String text, String to, String from, bool verify})>((ref, args) async {
  if (args.text.trim().isEmpty) return '';
  final service = ref.watch(translationServiceProvider);
  final ai = ref.watch(aiSettingsProvider);
  return service.translate(
    text: args.text,
    targetLang: args.to,
    sourceLang: args.from,
    aiSettings: ai,
    forceVerify: args.verify,
  );
});
