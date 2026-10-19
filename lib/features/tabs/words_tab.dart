import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/conversation_provider.dart';
import '../../core/providers/my_dictionary_provider.dart';
import '../words/widgets/word_list_view.dart';

/// تبِ «دیکشنری من»: لغات روزمره + لغات/عبارت‌های شخصی‌ای که کاربر با
/// «ذخیره برای داستان بعدی» نشان کرده (با برچسب «شخصی» و ✕).
class WordsTab extends ConsumerWidget {
  const WordsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(wordsTabItemsProvider);
    final all = ref.watch(allDailyWordsProvider);
    final personal = ref.watch(myDictionaryWordsProvider);
    return WordListView(
      listId: 'words',
      words: words,
      hasAnyData: all.isNotEmpty || personal.isNotEmpty,
      loading: ref.watch(dailyWordsLoaderProvider).isLoading,
    );
  }
}
