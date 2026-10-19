import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/word_asset_loader.dart';
import '../models/daily_word.dart';
import '../models/filter_state.dart';
import 'words_filter_provider.dart';

/// منبع‌های داده‌ی جدا برای تب‌های «اسلنگ» و «Vocabulary in Use»
/// (قبلاً هر دو لیست «لغات روزمره» را نشان می‌دادند).
/// فایل‌ها با scripts/convert-data.mjs از hope_data/*.js ساخته می‌شوند.
Future<List<DailyWord>> _loadWords(String asset) => loadWordsAsset(asset);

final slangWordsProvider = FutureProvider<List<DailyWord>>(
    (ref) => _loadWords('assets/data/slang_words.json'));

final vocabInUseWordsProvider = FutureProvider<List<DailyWord>>(
    (ref) => _loadWords('assets/data/vocab_in_use_words.json'));

List<DailyWord> _applyFilter(List<DailyWord> all, WordsFilterState f) {
  final q = f.query.trim().toLowerCase();
  if (f.level == 'all' && q.isEmpty) return all;
  return all.where((w) {
    if (f.level != 'all' && w.level != f.level) return false;
    if (q.isNotEmpty &&
        !w.en.toLowerCase().contains(q) &&
        !w.fa.contains(q)) {
      return false;
    }
    return true;
  }).toList(growable: false);
}

final filteredSlangWordsProvider = Provider<List<DailyWord>>((ref) {
  final all = ref.watch(slangWordsProvider).valueOrNull ?? const <DailyWord>[];
  return _applyFilter(all, ref.watch(wordsFilterProvider));
});

final filteredVocabInUseWordsProvider = Provider<List<DailyWord>>((ref) {
  final all =
      ref.watch(vocabInUseWordsProvider).valueOrNull ?? const <DailyWord>[];
  return _applyFilter(all, ref.watch(wordsFilterProvider));
});
