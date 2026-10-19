import 'package:flutter/foundation.dart';

@immutable
class DailyWord {
  final int id;
  final String level;
  final String pos;
  final String en;
  final String fa;

  /// فقط برای «لغات شخصی» (لغت/عبارتی که کاربر با «ذخیره برای داستان بعدی»
  /// نشان کرده): شناسه‌ی رشته‌ای یکتا (مثل Hope: `saved:<لغت>`).
  final String? key;

  /// لغت/عبارت شخصی در «دیکشنری من» (برچسب «شخصی» + دکمه‌ی ✕).
  final bool isPersonal;

  /// ترجمه‌هایی که از قبل معلوم‌اند (کد زبان ← متن) — برای لغات شخصی.
  final Map<String, String> translations;

  const DailyWord({
    required this.id,
    required this.level,
    required this.pos,
    required this.en,
    required this.fa,
    this.key,
    this.isPersonal = false,
    this.translations = const <String, String>{},
  });

  /// شناسه‌ی رشته‌ای که برای ⭐ / پلیر / کارت استفاده می‌شود.
  String get sid => key ?? id.toString();

  factory DailyWord.fromJson(Map<String, dynamic> j) {
    return DailyWord(
      id: (j['id'] as num?)?.toInt() ?? 0,
      level: j['level']?.toString() ?? 'A1',
      pos: j['pos']?.toString() ?? 'other',
      en: j['en']?.toString() ?? '',
      fa: j['fa']?.toString() ?? '',
    );
  }
}
