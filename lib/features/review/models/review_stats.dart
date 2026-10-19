import 'package:flutter/foundation.dart';

import 'review_item.dart';

/// آمار یک روز.
@immutable
class DayStat {
  final int correct;
  final int wrong;
  final int learned;

  const DayStat({this.correct = 0, this.wrong = 0, this.learned = 0});

  int get total => correct + wrong;

  DayStat add({required bool isCorrect, required bool isLearned}) => DayStat(
        correct: correct + (isCorrect ? 1 : 0),
        wrong: wrong + (isCorrect ? 0 : 1),
        learned: learned + (isLearned ? 1 : 0),
      );

  Map<String, dynamic> toJson() => {'c': correct, 'w': wrong, 'l': learned};

  factory DayStat.fromJson(Map<dynamic, dynamic> j) => DayStat(
        correct: (j['c'] as num?)?.toInt() ?? 0,
        wrong: (j['w'] as num?)?.toInt() ?? 0,
        learned: (j['l'] as num?)?.toInt() ?? 0,
      );
}

/// آمار مرور به تفکیک روز (کلید: yyyy-MM-dd).
@immutable
class ReviewStats {
  final Map<String, DayStat> days;

  const ReviewStats([this.days = const {}]);

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DayStat dayStat(DateTime d) => days[keyOf(d)] ?? const DayStat();

  /// ثبت یک پاسخ در روز [now].
  ReviewStats record(
    DateTime now, {
    required bool correct,
    required bool learned,
  }) {
    final k = keyOf(now);
    final next = Map<String, DayStat>.from(days);
    next[k] = (next[k] ?? const DayStat()).add(
      isCorrect: correct,
      isLearned: learned,
    );
    // فقط ۱۲۰ روز اخیر نگه داشته می‌شود
    final cutoff = keyOf(dayPlus(now, -120));
    next.removeWhere((key, _) => key.compareTo(cutoff) < 0);
    return ReviewStats(next);
  }

  /// تاریخ‌های [n] روز اخیر؛ قدیمی‌ترین اول، آخری = امروز.
  List<DateTime> lastDates(DateTime now, {int n = 7}) => [
        for (var i = n - 1; i >= 0; i--) dayPlus(dayStart(now), -i),
      ];

  /// زنجیره‌ی روزهای پشت‌سرهم. اگر امروز هنوز مرور نکرده باشی، زنجیره‌ی
  /// تا دیروز حفظ می‌شود.
  int streak(DateTime now) {
    var d = dayStart(now);
    if (dayStat(d).total == 0) d = dayPlus(d, -1);
    var n = 0;
    while (dayStat(d).total > 0) {
      n++;
      d = dayPlus(d, -1);
    }
    return n;
  }

  Map<String, dynamic> toJson() => {
        'days': days.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory ReviewStats.fromJson(Map<String, dynamic> json) {
    final raw = json['days'];
    if (raw is! Map) return const ReviewStats();
    final out = <String, DayStat>{};
    raw.forEach((k, v) {
      if (v is Map) out[k.toString()] = DayStat.fromJson(v);
    });
    return ReviewStats(out);
  }
}
