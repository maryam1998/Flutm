import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/conversation_repository.dart';
import '../data/daily_words_repository.dart';
import '../models/conversation.dart';
import '../models/daily_word.dart';

// ═══════════════════════════════════════════════════════════════════
// Conversation
// ═══════════════════════════════════════════════════════════════════
final conversationRepoProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository.instance;
});

final conversationLoaderProvider = FutureProvider<void>((ref) async {
  await ref.watch(conversationRepoProvider).load();
});

final allTopicsProvider = Provider<List<ConversationTopic>>((ref) {
  ref.watch(conversationLoaderProvider);
  return ref.watch(conversationRepoProvider).all;
});

// ═══════════════════════════════════════════════════════════════════
// Daily Words
// ═══════════════════════════════════════════════════════════════════
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
