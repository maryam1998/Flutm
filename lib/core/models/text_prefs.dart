import 'package:flutter/foundation.dart';

enum TargetBoldMode { both, text, translation, none }

@immutable
class TargetTextPrefs {
  /// مقادیر پیش‌فرضِ فاصله‌ها (پیکسل منطقی)
  static const int defaultSentenceGap = 14;
  static const int defaultLangGap = 8;
  static const int minSentenceGap = 4;
  static const int maxSentenceGap = 40;
  static const int minLangGap = 0;
  static const int maxLangGap = 24;

  /// درصد مقیاس (۱۰۰ = پیش‌فرض). در Dart به‌صورت scale = value/100 استفاده می‌شود.
  final int scale;
  final TargetBoldMode bold;

  /// فاصله‌ی بین دو جمله (کارت) در لیست
  final int sentenceGap;

  /// فاصله‌ی بین زبان‌ها (ردیف‌های ترجمه) داخل یک کارت
  final int langGap;

  const TargetTextPrefs({
    this.scale = 100,
    this.bold = TargetBoldMode.both,
    this.sentenceGap = defaultSentenceGap,
    this.langGap = defaultLangGap,
  });

  double get scaleFactor => scale / 100.0;

  TargetTextPrefs copyWith({
    int? scale,
    TargetBoldMode? bold,
    int? sentenceGap,
    int? langGap,
  }) =>
      TargetTextPrefs(
        scale: scale ?? this.scale,
        bold: bold ?? this.bold,
        sentenceGap: sentenceGap ?? this.sentenceGap,
        langGap: langGap ?? this.langGap,
      );

  Map<String, dynamic> toJson() => {
        'scale': scale,
        'bold': bold.name,
        'sentenceGap': sentenceGap,
        'langGap': langGap,
      };

  factory TargetTextPrefs.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TargetTextPrefs();
    final boldName = json['bold'] as String?;
    int gap(String k, int d, int lo, int hi) =>
        (json[k] is num) ? (json[k] as num).toInt().clamp(lo, hi) : d;
    return TargetTextPrefs(
      scale: (json['scale'] is num) ? (json['scale'] as num).toInt() : 100,
      bold: TargetBoldMode.values.firstWhere(
        (b) => b.name == boldName,
        orElse: () => TargetBoldMode.both,
      ),
      sentenceGap: gap('sentenceGap', defaultSentenceGap, minSentenceGap,
          maxSentenceGap),
      langGap: gap('langGap', defaultLangGap, minLangGap, maxLangGap),
    );
  }
}
