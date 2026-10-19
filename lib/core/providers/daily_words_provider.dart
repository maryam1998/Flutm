import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_word.dart';

class DailyWordsRepository {
  DailyWordsRepository._();
  static final DailyWordsRepository instance = DailyWordsRepository._();

  List<DailyWord> _words = const [];
  bool _loaded = false;
  List<DailyWord> get words => _words;

  Future<void>? _inflight;

  /// فقط یک‌بار اجرا می‌شود؛ فراخوانی‌های هم‌زمان همان Future را می‌گیرند.
  Future<void> load() => _inflight ??= _doLoad();

  Future<void> _doLoad() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/daily_words.json');
      _words = (jsonDecode(raw) as List<dynamic>)
          .map((e) => DailyWord.fromJson(e as Map<String, dynamic>))
          .toList();
      _loaded = true;
    } catch (_) {
      _loaded = false;
    }
  }
}

final dailyWordsRepoProvider = Provider<DailyWordsRepository>((ref) {
  return DailyWordsRepository.instance;
});

final dailyWordsLoaderProvider = FutureProvider<void>((ref) async {
  await ref.watch(dailyWordsRepoProvider).load();
});

final allDailyWordsProvider = Provider<List<DailyWord>>((ref) {
  ref.watch(dailyWordsLoaderProvider);
  return ref.watch(dailyWordsRepoProvider).words;
});
