import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_repository.dart';
import '../models/word_entry.dart';
import 'words_filter_provider.dart';

/// ریپازیتوری داده — الان خالی، بعداً از asset پر می‌شود.
final dataRepositoryProvider = Provider<DataRepository>((ref) {
  return DataRepository.instance;
});

/// لیست لغات فیلترشده بر اساس level/query/sort جاری.
final filteredWordsProvider = Provider<List<WordEntry>>((ref) {
  final repo = ref.watch(dataRepositoryProvider);
  final filter = ref.watch(wordsFilterProvider);
  return repo.filterWords(filter);
});
