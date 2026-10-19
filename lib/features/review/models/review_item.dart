import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// وضعیت یک لغت در سیستم مرور.
enum ReviewState { learning, review, mastered }

/// امتیاز کاربر بعد از دیدن جواب.
enum ReviewRating { hard, good, easy }

/// فاصله‌ی مرور هر جعبه (به روز): جعبه ۱ تا ۵.
const List<int> kBoxIntervals = [1, 3, 7, 14, 30];

/// جعبه را به بازه‌ی ۱..۵ می‌رساند.
int clampBox(int box) => math.min(5, math.max(1, box));

int intervalForBox(int box) => kBoxIntervals[clampBox(box) - 1];

/// شروع روز (۰۰:۰۰ به وقت محلی).
DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// [n] روز بعد (یا قبل، اگر منفی باشد) — از ۰۰:۰۰ همان روز.
DateTime dayPlus(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

@immutable
class ReviewItem {
  final String word;
  final String langCode;
  final String meaning;

  /// جعبه‌ی لایتنر: ۱ تا ۵
  final int box;
  final DateTime nextReviewAt;
  final DateTime? lastReviewedAt;
  final int reviewCount;
  final int correctCount;
  final int wrongCount;

  /// ضریب SM-2 بین ۱٫۳ و ۲٫۵
  final double easiness;
  final int intervalDays;
  final ReviewState state;
  final List<String> tags;

  /// منبع داستان (اختیاری)
  final String? storyId;

  const ReviewItem({
    required this.word,
    required this.langCode,
    required this.meaning,
    required this.box,
    required this.nextReviewAt,
    required this.lastReviewedAt,
    required this.reviewCount,
    required this.correctCount,
    required this.wrongCount,
    required this.easiness,
    required this.intervalDays,
    required this.state,
    this.tags = const [],
    this.storyId,
  });

  /// لغتِ تازه‌اضافه‌شده: جعبه‌ی ۱ و موعد مرور = امروز.
  factory ReviewItem.fresh({
    required String word,
    required String langCode,
    required String meaning,
    String? storyId,
    DateTime? addedAt,
  }) {
    return ReviewItem(
      word: word,
      langCode: langCode,
      meaning: meaning,
      box: 1,
      nextReviewAt: dayStart(addedAt ?? DateTime.now()),
      lastReviewedAt: null,
      reviewCount: 0,
      correctCount: 0,
      wrongCount: 0,
      easiness: 2.5,
      intervalDays: kBoxIntervals.first,
      state: ReviewState.learning,
      storyId: storyId,
    );
  }

  static String makeKey(String langCode, String word) =>
      '$langCode::${word.trim().toLowerCase()}';

  /// کلید یکتا — با normWord در reader_providers هم‌خوان است.
  String get key => makeKey(langCode, word);

  bool get isMastered => state == ReviewState.mastered;

  /// آیا تا پایان امروز باید مرور شود؟ (لغت‌های «یاد گرفته» هیچ‌وقت)
  bool isDue(DateTime now) =>
      !isMastered && nextReviewAt.isBefore(dayPlus(now, 1));

  bool get isFresh => reviewCount == 0;

  /// «سخت‌ها»: حداقل یک بار مرور شده و یا ضریب کم است یا غلط‌هایش بیشتر.
  bool get isHard =>
      !isMastered &&
      reviewCount > 0 &&
      (easiness < 2.0 || wrongCount > correctCount);

  /// نتیجه‌ی ارزیابی را روی نسخه‌ی جدیدی از آیتم اعمال می‌کند.
  ///
  /// سخت  → box=1،  easiness=max(1.3, easiness-0.2)
  /// خوب  → box+1 (سقف ۵)، easiness ثابت
  /// آسان → box+2 (سقف ۵)، easiness=min(2.5, easiness+0.15)
  /// اگر لغت پیش از پاسخ در جعبه‌ی ۵ بوده و جواب درست باشد → mastered
  ReviewItem rated(ReviewRating rating, DateTime now) {
    final wasInTopBox = box >= 5;
    int newBox;
    double newEasiness = easiness;

    switch (rating) {
      case ReviewRating.hard:
        newBox = 1;
        newEasiness = math.max(1.3, easiness - 0.2);
        break;
      case ReviewRating.good:
        newBox = math.min(5, box + 1);
        break;
      case ReviewRating.easy:
        newBox = math.min(5, box + 2);
        newEasiness = math.min(2.5, easiness + 0.15);
        break;
    }
    newEasiness = (newEasiness * 100).round() / 100;

    final correct = rating != ReviewRating.hard;
    final ReviewState newState;
    if (correct && wasInTopBox) {
      newState = ReviewState.mastered;
    } else if (newBox == 1) {
      newState = ReviewState.learning;
    } else {
      newState = ReviewState.review;
    }

    final interval = intervalForBox(newBox);
    return copyWith(
      box: newBox,
      easiness: newEasiness,
      intervalDays: interval,
      nextReviewAt: dayPlus(now, interval),
      lastReviewedAt: now,
      reviewCount: reviewCount + 1,
      correctCount: correctCount + (correct ? 1 : 0),
      wrongCount: wrongCount + (correct ? 0 : 1),
      state: newState,
    );
  }

  ReviewItem copyWith({
    String? meaning,
    int? box,
    DateTime? nextReviewAt,
    DateTime? lastReviewedAt,
    int? reviewCount,
    int? correctCount,
    int? wrongCount,
    double? easiness,
    int? intervalDays,
    ReviewState? state,
    List<String>? tags,
    String? storyId,
  }) {
    return ReviewItem(
      word: word,
      langCode: langCode,
      meaning: meaning ?? this.meaning,
      box: box ?? this.box,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      reviewCount: reviewCount ?? this.reviewCount,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      easiness: easiness ?? this.easiness,
      intervalDays: intervalDays ?? this.intervalDays,
      state: state ?? this.state,
      tags: tags ?? this.tags,
      storyId: storyId ?? this.storyId,
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'langCode': langCode,
        'meaning': meaning,
        'box': box,
        'nextReviewAt': nextReviewAt.toIso8601String(),
        'lastReviewedAt': lastReviewedAt?.toIso8601String(),
        'reviewCount': reviewCount,
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'easiness': easiness,
        'intervalDays': intervalDays,
        'state': state.name,
        'tags': tags,
        'storyId': storyId,
      };

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v, int fallback) => v is num ? v.toInt() : fallback;
    final box = clampBox(asInt(json['box'], 1));
    final state = ReviewState.values.firstWhere(
      (s) => s.name == json['state'],
      orElse: () => ReviewState.learning,
    );
    return ReviewItem(
      word: json['word'].toString(),
      langCode: json['langCode'].toString(),
      meaning: (json['meaning'] ?? '').toString(),
      box: box,
      nextReviewAt: DateTime.tryParse(json['nextReviewAt']?.toString() ?? '') ??
          dayStart(DateTime.now()),
      lastReviewedAt:
          DateTime.tryParse(json['lastReviewedAt']?.toString() ?? ''),
      reviewCount: asInt(json['reviewCount'], 0),
      correctCount: asInt(json['correctCount'], 0),
      wrongCount: asInt(json['wrongCount'], 0),
      easiness: json['easiness'] is num
          ? (json['easiness'] as num).toDouble().clamp(1.3, 2.5).toDouble()
          : 2.5,
      intervalDays: asInt(json['intervalDays'], intervalForBox(box)),
      state: state,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      storyId: json['storyId']?.toString(),
    );
  }
}
