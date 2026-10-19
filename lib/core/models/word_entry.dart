import 'package:flutter/foundation.dart';

@immutable
class WordEntry {
  /// شناسه‌ی یکتا — مثل 'w_00123'
  final String id;

  /// سطح CEFR: 'A1'..'C2'
  final String level;

  /// نقش دستوری — مثل 'noun', 'verb'
  final String pos;

  /// معنی انگلیسی
  final String en;

  /// معنی فارسی
  final String fa;

  /// ترجمه‌های چندزبانه — کلید: کد زبان، مقدار: ترجمه
  final Map<String, String> translations;

  /// مثال‌ها (اختیاری — در فاز بعد پر می‌شود)
  final List<String> examples;

  const WordEntry({
    required this.id,
    required this.level,
    required this.pos,
    required this.en,
    required this.fa,
    this.translations = const {},
    this.examples = const [],
  });

  /// معنی در زبان مقصد را برمی‌گرداند (اگر بود)، وگرنه زبان داده‌شده.
  String meaningFor(String langCode) {
    return translations[langCode] ?? (langCode == 'fa' ? fa : en);
  }

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    return WordEntry(
      id: json['id']?.toString() ?? '',
      level: json['level']?.toString() ?? 'A1',
      pos: json['pos']?.toString() ?? 'other',
      en: json['en']?.toString() ?? '',
      fa: json['fa']?.toString() ?? '',
      translations: (json['translations'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          const {},
      examples: (json['examples'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'pos': pos,
        'en': en,
        'fa': fa,
        'translations': translations,
        'examples': examples,
      };
}
