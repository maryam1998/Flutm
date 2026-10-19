import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_word.dart';
import '../models/filter_state.dart';
import 'conversation_provider.dart';

class WordsFilterNotifier extends StateNotifier<WordsFilterState> {
  WordsFilterNotifier() : super(const WordsFilterState());

  void setLevel(String level) => state = state.copyWith(level: level);
  void setQuery(String q) => state = state.copyWith(query: q);
  void setSort(SortMode sort) => state = state.copyWith(sort: sort);
  void reset() => state = const WordsFilterState();
}

final wordsFilterProvider =
    StateNotifierProvider<WordsFilterNotifier, WordsFilterState>((ref) {
  return WordsFilterNotifier();
});

/// لیست فیلترشده‌ی لغات روزمره — memoized.
/// فقط وقتی level یا query عوض بشه، دوباره محاسبه می‌شه.
final filteredDailyWordsProvider = Provider<List<DailyWord>>((ref) {
  final all = ref.watch(allDailyWordsProvider);
  final filter = ref.watch(wordsFilterProvider);

  // Fast path — بدون فیلتر
  if (filter.level == 'all' && filter.query.trim().isEmpty) {
    return all;
  }

  final q = filter.query.trim().toLowerCase();
  return all.where((w) {
    if (filter.level != 'all' && w.level != filter.level) return false;
    if (q.isNotEmpty) {
      if (!w.en.toLowerCase().contains(q) && !w.fa.contains(q)) return false;
    }
    return true;
  }).toList(growable: false);
});
