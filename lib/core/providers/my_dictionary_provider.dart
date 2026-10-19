import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_word.dart';
import '../models/filter_state.dart';
import '../storage/local_storage.dart';
import '../translate/translation_service.dart' show textMatchesScript;
import 'conversation_provider.dart';
import 'language_selection_provider.dart';
import 'reader_providers.dart';
import 'word_sources_provider.dart';
import 'words_filter_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// «دیکشنری من» (تبِ لغات) — مثل Hope:
//   • هر لغت/عبارتِ انگلیسی که کاربر با «ذخیره برای داستان بعدی» نشان
//     می‌کند، هم در «لغات ذخیره‌شده» می‌ماند و هم این‌جا (تبِ دیکشنری من)
//     با برچسب «شخصی» دیده می‌شود.
//   • ✕ روی کارتِ شخصی فقط از همین تب پنهانش می‌کند؛ از «لغات ذخیره‌شده»
//     پاک نمی‌شود. اگر کاربر دوباره همان لغت را ذخیره کند، خودکار برمی‌گردد.
// ═══════════════════════════════════════════════════════════════════

const String _kHiddenKey = 'zflut-words-tab-hidden-v1';

/// کلیدِ نرمال‌شده ← لحظه‌ی پنهان‌کردن.
/// (لغتِ ذخیره‌شده فقط وقتی پنهان است که savedAt اش قدیمی‌تر از لحظه‌ی
/// پنهان‌کردن باشد؛ ذخیره‌ی دوباره = savedAt تازه ⇒ خودکار از پنهان درمی‌آید.)
class WordsTabHiddenNotifier extends StateNotifier<Map<String, DateTime>> {
  final LocalStorage _storage;

  WordsTabHiddenNotifier(this._storage) : super(_read(_storage));

  static Map<String, DateTime> _read(LocalStorage s) {
    final raw = s.readJson(_kHiddenKey)['items'];
    final out = <String, DateTime>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final t = DateTime.tryParse(v.toString());
        if (t != null) out[k.toString()] = t;
      });
    }
    return out;
  }

  void hide(String word) {
    final k = normWord(word);
    if (k.isEmpty) return;
    final next = {...state, k: DateTime.now()};
    state = next;
    unawaited(_storage.writeJson(_kHiddenKey, {
      'items': next.map((key, v) => MapEntry(key, v.toIso8601String())),
    }));
  }
}

final wordsTabHiddenProvider =
    StateNotifierProvider<WordsTabHiddenNotifier, Map<String, DateTime>>(
  (ref) => WordsTabHiddenNotifier(ref.read(localStorageProvider)),
);

const List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

String _cleanToken(String s) => s
    .toLowerCase()
    .replaceAll(_edgePunct, '')
    .trim();

final RegExp _edgePunct = RegExp(
    r'''^[«»"'.,!?;:()\u060C\u061B\u061F]+|[«»"'.,!?;:()\u060C\u061B\u061F]+$''');

/// ایندکسِ سطحِ لغاتِ شناخته‌شده (لغات روزمره + اسلنگ + Vocabulary in Use).
final _levelIndexProvider = Provider<Map<String, String>>((ref) {
  final lists = <List<DailyWord>>[
    ref.watch(allDailyWordsProvider),
    ref.watch(slangWordsProvider).valueOrNull ?? const <DailyWord>[],
    ref.watch(vocabInUseWordsProvider).valueOrNull ?? const <DailyWord>[],
  ];
  final idx = <String, String>{};
  for (final l in lists) {
    for (final w in l) {
      final k = _cleanToken(w.en);
      if (k.isNotEmpty) idx.putIfAbsent(k, () => w.level);
    }
  }
  return idx;
});

/// کلیدِ لغاتِ روزمره (برای این‌که لغتِ تکراری دوباره اضافه نشود).
final _dailyKeysProvider = Provider<Set<String>>((ref) {
  return ref
      .watch(allDailyWordsProvider)
      .map((w) => normWord(w.en))
      .toSet();
});

String _estimateLevel(String text, Map<String, String> idx) {
  final k = _cleanToken(text);
  final direct = idx[k];
  if (direct != null) return direct;
  final toks =
      k.split(RegExp(r'\s+')).map(_cleanToken).where((t) => t.isNotEmpty);
  var best = -1;
  for (final t in toks) {
    final lv = idx[t];
    if (lv == null) continue;
    final r = _levels.indexOf(lv);
    if (r > best) best = r;
  }
  return best >= 0 ? _levels[best] : '';
}

/// لغات/عبارات شخصیِ دیکشنری من (جدیدترین اول)، بدون موارد پنهان‌شده.
final myDictionaryWordsProvider = Provider<List<DailyWord>>((ref) {
  final saved = ref.watch(savedWordsProvider);
  if (saved.isEmpty) return const <DailyWord>[];
  final hidden = ref.watch(wordsTabHiddenProvider);
  final existing = ref.watch(_dailyKeysProvider);
  final idx = ref.watch(_levelIndexProvider);
  final native = ref.watch(languageSelectionProvider.select((s) => s.native));

  final sorted = [...saved]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  final seen = <String>{};
  final out = <DailyWord>[];
  for (final e in sorted) {
    if (e.langCode != 'en') continue;
    final k = normWord(e.word);
    if (k.isEmpty || existing.contains(k) || !seen.add(k)) continue;
    final hiddenAt = hidden[k];
    if (hiddenAt != null && !e.savedAt.isAfter(hiddenAt)) continue;
    final meaning = e.meaning.trim();
    out.add(DailyWord(
      id: -1,
      key: 'saved:$k',
      isPersonal: true,
      level: _estimateLevel(e.word, idx),
      pos: '',
      en: e.word,
      fa: '',
      translations: (meaning.isNotEmpty &&
              native != 'en' &&
              textMatchesScript(meaning, native))
          ? {native: meaning}
          : const <String, String>{},
    ));
  }
  return out;
});

bool _matches(DailyWord w, WordsFilterState f) {
  if (f.level != 'all' && w.level != f.level) return false;
  final q = f.query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return w.en.toLowerCase().contains(q) ||
      w.fa.contains(q) ||
      w.translations.values.any((t) => t.toLowerCase().contains(q));
}

/// لیستِ نهایی تبِ «دیکشنری من»: اول لغاتِ شخصی، بعد لغاتِ روزمره.
final wordsTabItemsProvider = Provider<List<DailyWord>>((ref) {
  final daily = ref.watch(filteredDailyWordsProvider);
  final personal = ref.watch(myDictionaryWordsProvider);
  if (personal.isEmpty) return daily;
  final f = ref.watch(wordsFilterProvider);
  final mine = personal.where((w) => _matches(w, f)).toList(growable: false);
  if (mine.isEmpty) return daily;
  return [...mine, ...daily];
});
