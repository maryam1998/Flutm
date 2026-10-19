import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_word.dart';
import '../storage/local_storage.dart';
import '../storage/prefs_keys.dart';
import 'conversation_provider.dart';
import 'my_dictionary_provider.dart';
import 'word_sources_provider.dart';
import 'words_filter_provider.dart';

/// مثل wordFavorites در Hope: مجموعه‌ی idِ لغاتی که با ⭐ علاقه‌مند شده‌اند.
/// idها بین لغات روزمره / اسلنگ / Vocabulary in Use یکتا هستند، پس یک
/// مجموعه‌ی مشترک کافی است و روی دستگاه ذخیره می‌شود.
class WordFavoritesNotifier extends StateNotifier<Set<String>> {
  final LocalStorage _storage;

  WordFavoritesNotifier(this._storage) : super(_read(_storage));

  static Set<String> _read(LocalStorage s) {
    final json = s.readJson(PrefsKeys.wordFavorites);
    final ids = json['ids'];
    if (ids is List) return ids.map((e) => e.toString()).toSet();
    return <String>{};
  }

  Future<void> toggle(String id) async {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
    await _storage.writeJson(PrefsKeys.wordFavorites, {'ids': next.toList()});
  }
}

final wordFavoritesProvider =
    StateNotifierProvider<WordFavoritesNotifier, Set<String>>((ref) {
  return WordFavoritesNotifier(ref.watch(localStorageProvider));
});

/// لغاتِ علاقه‌مندشده از هر سه تب، بدون تکرار (مثل favoritedWords در Hope)،
/// با همان فیلترِ سطح/جستجوی بقیه‌ی تب‌ها.
final favoritedWordsProvider = Provider<List<DailyWord>>((ref) {
  final favs = ref.watch(wordFavoritesProvider);
  if (favs.isEmpty) return const <DailyWord>[];

  final sources = <List<DailyWord>>[
    ref.watch(myDictionaryWordsProvider),
    ref.watch(allDailyWordsProvider),
    ref.watch(slangWordsProvider).valueOrNull ?? const <DailyWord>[],
    ref.watch(vocabInUseWordsProvider).valueOrNull ?? const <DailyWord>[],
  ];
  final filter = ref.watch(wordsFilterProvider);
  final q = filter.query.trim().toLowerCase();

  final seen = <String>{};
  final out = <DailyWord>[];
  for (final list in sources) {
    for (final w in list) {
      final id = w.sid;
      if (!favs.contains(id) || !seen.add(id)) continue;
      if (filter.level != 'all' && w.level != filter.level) continue;
      if (q.isNotEmpty &&
          !w.en.toLowerCase().contains(q) &&
          !w.fa.contains(q) &&
          !w.translations.values.any((t) => t.toLowerCase().contains(q))) {
        continue;
      }
      out.add(w);
    }
  }
  return out;
});
