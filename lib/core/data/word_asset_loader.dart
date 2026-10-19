import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../models/daily_word.dart';

List<DailyWord> _parseWords(String raw) {
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((e) => DailyWord.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// خواندنِ فایلِ لغات از assets. دیکُد کردنِ JSON (مثلاً ۱٫۲ مگابایتِ
/// Vocabulary in Use) در isolate جدا انجام می‌شود تا رابط کاربری هنگ نکند؛
/// خودِ نمایشِ لیست هم ۶۰تا۶۰تا (صفحه‌بندیِ تدریجی) است.
Future<List<DailyWord>> loadWordsAsset(String asset) async {
  final raw = await rootBundle.loadString(asset);
  return compute(_parseWords, raw);
}
