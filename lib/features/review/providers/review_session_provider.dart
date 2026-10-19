import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review_item.dart';
import 'review_provider.dart';

@immutable
class ReviewSessionState {
  /// نسخه‌ی ثابتِ صفِ مرور در لحظه‌ی شروع جلسه
  final List<ReviewItem> queue;
  final int index;
  final bool revealed;
  final int correct;
  final int wrong;
  final int learned;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const ReviewSessionState({
    this.queue = const [],
    this.index = 0,
    this.revealed = false,
    this.correct = 0,
    this.wrong = 0,
    this.learned = 0,
    this.startedAt,
    this.endedAt,
  });

  bool get active => queue.isNotEmpty;
  bool get finished => queue.isNotEmpty && index >= queue.length;
  ReviewItem? get current =>
      (index >= 0 && index < queue.length) ? queue[index] : null;

  Duration get elapsed {
    final s = startedAt;
    if (s == null) return Duration.zero;
    return (endedAt ?? DateTime.now()).difference(s);
  }

  ReviewSessionState copyWith({
    int? index,
    bool? revealed,
    int? correct,
    int? wrong,
    int? learned,
    DateTime? endedAt,
  }) =>
      ReviewSessionState(
        queue: queue,
        index: index ?? this.index,
        revealed: revealed ?? this.revealed,
        correct: correct ?? this.correct,
        wrong: wrong ?? this.wrong,
        learned: learned ?? this.learned,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
      );
}

class ReviewSessionNotifier extends StateNotifier<ReviewSessionState> {
  final Ref _ref;

  ReviewSessionNotifier(this._ref) : super(const ReviewSessionState());

  /// شروع جلسه‌ی جدید با [items].
  void start(List<ReviewItem> items) {
    state = ReviewSessionState(
      queue: List.unmodifiable(items),
      startedAt: DateTime.now(),
    );
  }

  void reveal() {
    if (state.current == null || state.revealed) return;
    state = state.copyWith(revealed: true);
  }

  /// ثبت ارزیابی لغت فعلی و رفتن به لغت بعدی.
  void rate(ReviewRating rating) {
    final cur = state.current;
    if (cur == null) return;

    final updated = _ref.read(reviewProvider.notifier).rate(cur.key, rating);
    final isCorrect = rating != ReviewRating.hard;
    final newlyLearned =
        updated != null && updated.isMastered && !cur.isMastered;

    _ref
        .read(reviewStatsProvider.notifier)
        .record(correct: isCorrect, learned: newlyLearned);

    final nextIndex = state.index + 1;
    final done = nextIndex >= state.queue.length;
    state = state.copyWith(
      index: nextIndex,
      revealed: false,
      correct: state.correct + (isCorrect ? 1 : 0),
      wrong: state.wrong + (isCorrect ? 0 : 1),
      learned: state.learned + (newlyLearned ? 1 : 0),
      endedAt: done ? DateTime.now() : null,
    );
  }
}

final reviewSessionProvider =
    StateNotifierProvider<ReviewSessionNotifier, ReviewSessionState>(
  (ref) => ReviewSessionNotifier(ref),
);
