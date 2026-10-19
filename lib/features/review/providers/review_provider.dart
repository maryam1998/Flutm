import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/filter_state.dart';
import '../../../core/models/saved_word.dart';
import '../../../core/models/word_entry.dart';
import '../../../core/providers/data_repository_provider.dart';
import '../../../core/providers/reader_providers.dart';
import '../../../core/storage/local_storage.dart';
import '../models/review_item.dart';
import '../models/review_stats.dart';

const String _kItemsKey = 'zflut-review-items-v1';
const String _kStatsKey = 'zflut-review-stats-v1';

// ═══════════════════════════════════════════════════════════════════
// آیتم‌های مرور (جعبه‌ی لایتنر ۵ تایی)
// ═══════════════════════════════════════════════════════════════════
class ReviewNotifier extends StateNotifier<List<ReviewItem>> {
  final LocalStorage _storage;

  /// [leitner]: لغت‌های موجود در LeitnerNotifier قدیمی — هر کدام که هنوز
  /// در سیستم مرور نیست با box=1 و موعد = روز افزودن اضافه می‌شود.
  ReviewNotifier(this._storage, List<SavedWord> leitner)
      : super(_read(_storage)) {
    syncFrom(leitner);
  }

  static List<ReviewItem> _read(LocalStorage s) {
    final raw = s.readJson(_kItemsKey)['items'];
    if (raw is! List) return const [];
    final out = <ReviewItem>[];
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        out.add(ReviewItem.fromJson(Map<String, dynamic>.from(e)));
      } catch (_) {
        // ردیف خراب را نادیده بگیر
      }
    }
    return out;
  }

  void _set(List<ReviewItem> next) {
    state = next;
    unawaited(_storage
        .writeJson(_kItemsKey, {'items': next.map((e) => e.toJson()).toList()}));
  }

  /// همگام‌سازی با جعبه‌ی لایتنر موجود (پاپ‌آپ «افزودن به جعبه‌ی لایتنر»).
  void syncFrom(List<SavedWord> leitner) {
    if (leitner.isEmpty) return;
    final known = {for (final it in state) it.key};
    final added = <ReviewItem>[];
    for (final w in leitner) {
      final k = ReviewItem.makeKey(w.langCode, w.word);
      if (known.contains(k)) continue;
      known.add(k);
      added.add(ReviewItem.fresh(
        word: w.word,
        langCode: w.langCode,
        meaning: w.meaning,
        storyId: w.storyId,
        addedAt: w.savedAt,
      ));
    }
    if (added.isNotEmpty) _set([...state, ...added]);
  }

  /// ارزیابی یک لغت را اعمال و ذخیره می‌کند؛ آیتم به‌روز را برمی‌گرداند.
  ReviewItem? rate(String key, ReviewRating rating) {
    final idx = state.indexWhere((e) => e.key == key);
    if (idx < 0) return null;
    final updated = state[idx].rated(rating, DateTime.now());
    final next = [...state];
    next[idx] = updated;
    _set(next);
    return updated;
  }

  void remove(String key) => _set(state.where((e) => e.key != key).toList());
}

final reviewProvider =
    StateNotifierProvider<ReviewNotifier, List<ReviewItem>>((ref) {
  final n = ReviewNotifier(
    ref.read(localStorageProvider),
    ref.read(leitnerProvider),
  );
  // هر لغتی که بعداً به لایتنر اضافه شود، همین‌جا هم با box=1 اضافه می‌شود.
  ref.listen<List<SavedWord>>(leitnerProvider, (_, next) => n.syncFrom(next));
  return n;
});

// ═══════════════════════════════════════════════════════════════════
// آمار روزانه
// ═══════════════════════════════════════════════════════════════════
class ReviewStatsNotifier extends StateNotifier<ReviewStats> {
  final LocalStorage _storage;

  ReviewStatsNotifier(this._storage)
      : super(ReviewStats.fromJson(_storage.readJson(_kStatsKey)));

  void record({required bool correct, required bool learned}) {
    state = state.record(DateTime.now(), correct: correct, learned: learned);
    unawaited(_storage.writeJson(_kStatsKey, state.toJson()));
  }
}

final reviewStatsProvider =
    StateNotifierProvider<ReviewStatsNotifier, ReviewStats>(
  (ref) => ReviewStatsNotifier(ref.read(localStorageProvider)),
);

// ═══════════════════════════════════════════════════════════════════
// اطلاعات لغت (سطح CEFR و مثال) از words.json
// کلید = ReviewItem.key  ('<lang>::<word lowercase>')
// ═══════════════════════════════════════════════════════════════════
final wordInfoProvider = FutureProvider<Map<String, WordEntry>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  await repo.load();
  final map = <String, WordEntry>{};
  for (final w in repo.filterWords(const WordsFilterState())) {
    map.putIfAbsent(ReviewItem.makeKey('en', w.en), () => w);
    w.translations.forEach((lang, text) {
      if (text.trim().isEmpty) return;
      map.putIfAbsent(ReviewItem.makeKey(lang, text), () => w);
    });
  }
  return map;
});

// ═══════════════════════════════════════════════════════════════════
// فیلترها
// ═══════════════════════════════════════════════════════════════════
enum ReviewFilter { today, week, learned, all, hard, fresh }

// برچسبِ ترجمه‌شده‌ی فیلترها: context.rvFilterLabel(f) در review_i18n.dart

enum ReviewSource { any, story, words }

class ReviewFilterState {
  final ReviewFilter chip;

  /// 'A1'..'C2' یا null = همه
  final String? level;

  /// کد زبان یا null = همه
  final String? lang;
  final ReviewSource source;

  const ReviewFilterState({
    this.chip = ReviewFilter.today,
    this.level,
    this.lang,
    this.source = ReviewSource.any,
  });

  ReviewFilterState withChip(ReviewFilter v) =>
      ReviewFilterState(chip: v, level: level, lang: lang, source: source);
  ReviewFilterState withLevel(String? v) =>
      ReviewFilterState(chip: chip, level: v, lang: lang, source: source);
  ReviewFilterState withLang(String? v) =>
      ReviewFilterState(chip: chip, level: level, lang: v, source: source);
  ReviewFilterState withSource(ReviewSource v) =>
      ReviewFilterState(chip: chip, level: level, lang: lang, source: v);
}

final reviewFilterProvider =
    StateProvider<ReviewFilterState>((ref) => const ReviewFilterState());

bool matchesReviewChip(ReviewItem it, ReviewFilter f, DateTime now) {
  switch (f) {
    case ReviewFilter.today:
      return it.isDue(now);
    case ReviewFilter.week:
      return !it.isMastered && it.nextReviewAt.isBefore(dayPlus(now, 7));
    case ReviewFilter.learned:
      return it.isMastered;
    case ReviewFilter.all:
      return true;
    case ReviewFilter.hard:
      return it.isHard;
    case ReviewFilter.fresh:
      return it.isFresh && !it.isMastered;
  }
}

int _byDue(ReviewItem a, ReviewItem b) {
  final c = a.nextReviewAt.compareTo(b.nextReviewAt);
  if (c != 0) return c;
  final bx = a.box.compareTo(b.box);
  if (bx != 0) return bx;
  return a.word.compareTo(b.word);
}

/// لغت‌هایی که امروز باید مرور شوند (بدون فیلتر).
final dueReviewProvider = Provider<List<ReviewItem>>((ref) {
  final now = DateTime.now();
  final list = ref.watch(reviewProvider).where((e) => e.isDue(now)).toList();
  list.sort(_byDue);
  return list;
});

/// تعداد لغت‌های هر چیپ (برای نمایش روی چیپ‌ها).
final reviewChipCountsProvider = Provider<Map<ReviewFilter, int>>((ref) {
  final now = DateTime.now();
  final items = ref.watch(reviewProvider);
  return {
    for (final f in ReviewFilter.values)
      f: items.where((e) => matchesReviewChip(e, f, now)).length,
  };
});

/// لیست نهایی بعد از اعمال چیپ + سطح + زبان + منبع.
final filteredReviewProvider = Provider<List<ReviewItem>>((ref) {
  final now = DateTime.now();
  final items = ref.watch(reviewProvider);
  final f = ref.watch(reviewFilterProvider);
  final info = ref.watch(wordInfoProvider).valueOrNull ?? const {};

  final out = items.where((e) {
    if (!matchesReviewChip(e, f.chip, now)) return false;
    if (f.lang != null && e.langCode != f.lang) return false;
    if (f.source == ReviewSource.story && e.storyId == null) return false;
    if (f.source == ReviewSource.words && e.storyId != null) return false;
    if (f.level != null && info[e.key]?.level != f.level) return false;
    return true;
  }).toList();
  out.sort(_byDue);
  return out;
});

/// تعداد لغت‌های هر جعبه (index 0 = جعبه‌ی ۱). «یاد گرفته‌ها» در جعبه‌ی ۵ حساب می‌شوند.
final boxCountsProvider = Provider<List<int>>((ref) {
  final counts = List<int>.filled(5, 0);
  for (final e in ref.watch(reviewProvider)) {
    counts[clampBox(e.box) - 1]++;
  }
  return counts;
});
