import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/grammar_note.dart';
import '../models/saved_word.dart';
import '../storage/local_storage.dart';
import '../translate/translation_service.dart' show looksLikeGuardOutput;

// ═══════════════════════════════════════════════════════════════════
// ذخیره‌ی ماندگار برای سه دکمه‌ی «کارت مشترکِ انتخاب» (SelectionCard):
//   • ذخیره برای داستان بعدی   → savedWordsProvider
//   • افزودن به یادگیری گرامر  → grammarNotesProvider
//   • افزودن به جعبه‌ی لایتنر   → leitnerProvider
// قبلاً هر سه فقط در حافظه بودند و با بستن برنامه پاک می‌شدند.
// ═══════════════════════════════════════════════════════════════════

const String _kSavedKey = 'zflut-saved-story-words-v1';
const String _kGrammarKey = 'zflut-grammar-notes-v1';
const String _kLeitnerKey = 'zflut-leitner-words-v1';

/// جوابِ خالی / خروجیِ گارد (مثل «User Safety: safe») جواب حساب نمی‌شود و
/// هرگز در یادداشت‌های گرامر ذخیره نمی‌شود.
bool isBadGrammarAnswer(String answer) {
  final a = answer.trim();
  return a.isEmpty || looksLikeGuardOutput(a);
}

/// نرمال‌سازی برای مقایسه‌ی لغت‌ها (بدون حساسیت به حروف بزرگ/فاصله‌ی کناره‌ها).
String normWord(String s) => s.trim().toLowerCase();

List<Map<String, dynamic>> _readItems(LocalStorage s, String key) {
  final raw = s.readJson(key)['items'];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}

List<SavedWord> _readWords(LocalStorage s, String key) {
  final out = <SavedWord>[];
  for (final m in _readItems(s, key)) {
    try {
      out.add(SavedWord.fromJson(m));
    } catch (_) {
      // ردیف خراب را نادیده بگیر
    }
  }
  return out;
}

// ───────────────────────── ذخیره برای داستان بعدی ─────────────────────────
class SavedWordsNotifier extends StateNotifier<List<SavedWord>> {
  final LocalStorage _storage;

  SavedWordsNotifier(this._storage) : super(_readWords(_storage, _kSavedKey));

  void _set(List<SavedWord> next) {
    state = next;
    unawaited(_storage.writeJson(
        _kSavedKey, {'items': next.map((e) => e.toJson()).toList()}));
  }

  bool _same(SavedWord w, String word, String langCode) =>
      w.langCode == langCode && normWord(w.word) == normWord(word);

  void toggleSave(SavedWord word) {
    final exists = state.any((w) => _same(w, word.word, word.langCode));
    if (exists) {
      _set(state.where((w) => !_same(w, word.word, word.langCode)).toList());
    } else {
      _set([...state, word]);
    }
  }

  bool isSaved(String word, String langCode) =>
      state.any((w) => _same(w, word, langCode));

  /// حذفِ چندتایی (برای «پاک کردن همه» / «حذف انتخاب‌شده‌ها» در تب لغات ذخیره‌شده).
  void removeWords(Iterable<SavedWord> words) {
    final list = words.toList();
    if (list.isEmpty) return;
    _set(state
        .where((w) => !list.any((x) => _same(w, x.word, x.langCode)))
        .toList());
  }
}

final savedWordsProvider =
    StateNotifierProvider<SavedWordsNotifier, List<SavedWord>>(
  (ref) => SavedWordsNotifier(ref.read(localStorageProvider)),
);

// ───────────────────────── یادداشت‌های گرامر ─────────────────────────
class GrammarNotesNotifier extends StateNotifier<List<GrammarNote>> {
  final LocalStorage _storage;

  GrammarNotesNotifier(this._storage) : super(_read(_storage));

  static List<GrammarNote> _read(LocalStorage s) {
    final out = <GrammarNote>[];
    for (final m in _readItems(s, _kGrammarKey)) {
      try {
        final n = GrammarNote.fromJson(m);
        // پرسش‌وپاسخ‌های خراب/بی‌جوابِ ذخیره‌شده‌ی قبلی پاک می‌شوند
        final clean = n.thread.where((t) => !isBadGrammarAnswer(t.answer)).toList();
        out.add(clean.length == n.thread.length ? n : n.copyWith(thread: clean));
      } catch (_) {}
    }
    return out;
  }

  void _set(List<GrammarNote> next) {
    state = next;
    unawaited(_storage.writeJson(
        _kGrammarKey, {'items': next.map((e) => e.toJson()).toList()}));
  }

  bool hasNote(String word, String langCode) => state.any(
      (n) => n.langCode == langCode && normWord(n.word) == normWord(word));

  /// اگر همین لغت/عبارت قبلاً ذخیره شده باشد چیزی اضافه نمی‌شود.
  /// (یادداشت‌های بدون لغت — مثل تصحیحات «تمرین مکالمه» — همیشه اضافه می‌شوند.)
  void addNote(GrammarNote note) {
    if (note.word.trim().isNotEmpty && hasNote(note.word, note.langCode)) {
      return;
    }
    _set([note, ...state]);
  }

  void removeNote(String id) => _set(state.where((n) => n.id != id).toList());

  /// یک پرسش‌وپاسخ را به رشته‌ی همان یادداشت اضافه می‌کند (فوراً ذخیره می‌شود).
  /// ویرایش/رفرشِ یک پرسش: از ایندکسِ [index] به بعد حذف و با [item] جایگزین می‌شود.
  void replaceThreadFrom(String id, int index, GrammarThreadItem item) {
    if (isBadGrammarAnswer(item.answer)) return;
    _set([
        for (final n in state)
          if (n.id == id)
            n.copyWith(thread: [
              ...n.thread.take(index.clamp(0, n.thread.length)),
              item,
            ])
          else
            n,
      ]);
  }

  void appendThread(String id, GrammarThreadItem item) {
    if (isBadGrammarAnswer(item.answer)) return;
    _set([
      for (final n in state)
        if (n.id == id) n.copyWith(thread: [...n.thread, item]) else n,
    ]);
  }
}

final grammarNotesProvider =
    StateNotifierProvider<GrammarNotesNotifier, List<GrammarNote>>(
  (ref) => GrammarNotesNotifier(ref.read(localStorageProvider)),
);

// ───────────────────────── جعبه‌ی لایتنر (ساده) ─────────────────────────
class LeitnerNotifier extends StateNotifier<List<SavedWord>> {
  final LocalStorage _storage;

  LeitnerNotifier(this._storage) : super(_readWords(_storage, _kLeitnerKey));

  void _set(List<SavedWord> next) {
    state = next;
    unawaited(_storage.writeJson(
        _kLeitnerKey, {'items': next.map((e) => e.toJson()).toList()}));
  }

  bool contains(String word, String langCode) => state.any(
      (w) => w.langCode == langCode && normWord(w.word) == normWord(word));

  void addToLeitner(SavedWord word) {
    if (contains(word.word, word.langCode)) return;
    _set([...state, word]);
  }
}

final leitnerProvider = StateNotifierProvider<LeitnerNotifier, List<SavedWord>>(
  (ref) => LeitnerNotifier(ref.read(localStorageProvider)),
);
