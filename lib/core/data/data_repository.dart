import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/filter_state.dart';
import '../models/word_entry.dart';

/// مخزن داده‌های آموزشی — فایل‌های JSON را از assets می‌خواند
/// و عملیات فیلتر/جستجو/مرتب‌سازی روی آن‌ها انجام می‌دهد.
class DataRepository {
  DataRepository._();
  static final DataRepository instance = DataRepository._();

  List<WordEntry> _words = const [];
  bool _loaded = false;
  String? _error;

  bool get isLoaded => _loaded;
  String? get error => _error;
  int get wordsCount => _words.length;

  /// بارگذاری از `assets/data/words.json`.
  /// فقط یک‌بار انجام می‌شود؛ فراخوانی‌های بعدی no-op هستند.
  Future<void>? _inflight;

  /// فقط یک‌بار اجرا می‌شود؛ فراخوانی‌های هم‌زمان همان Future را می‌گیرند.
  Future<void> load() => _inflight ??= _doLoad();

  Future<void> _doLoad() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/words.json');
      final List<dynamic> parsed = jsonDecode(raw) as List<dynamic>;
      _words = parsed
          .map((e) => WordEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      _loaded = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _loaded = false;
      _inflight = null; // بار بعد دوباره تلاش شود
    }
  }

  /// فیلتر کردن روی لیست فعلی — دقیقاً منطق نسخه‌ی وب.
  List<WordEntry> filterWords(WordsFilterState filter) {
    var list = [..._words];

    // ۱. فیلتر سطح
    if (filter.level != 'all') {
      list = list.where((w) => w.level == filter.level).toList();
    }

    // ۲. جستجو در انگلیسی، فارسی، و همه‌ی ترجمه‌ها
    if (filter.query.trim().isNotEmpty) {
      final q = filter.query.trim().toLowerCase();
      list = list
          .where((w) =>
              w.en.toLowerCase().contains(q) ||
              w.fa.contains(q) ||
              w.translations.values
                  .any((t) => t.toLowerCase().contains(q)))
          .toList();
    }

    // ۳. مرتب‌سازی
    switch (filter.sort) {
      case SortMode.defaultOrder:
        break;
      case SortMode.alphabetical:
        list.sort((a, b) => a.en.toLowerCase().compareTo(b.en.toLowerCase()));
        break;
      case SortMode.byLevel:
        list.sort((a, b) => a.level.compareTo(b.level));
        break;
      case SortMode.recent:
        break;
    }

    return list;
  }
}
