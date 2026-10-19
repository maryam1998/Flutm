import 'package:flutter/foundation.dart';

@immutable
class SavedWord {
  final String word;
  final String langCode;
  final String meaning;
  final String? storyId;
  final int? pi;
  final int? si;
  final DateTime savedAt;

  const SavedWord({
    required this.word,
    required this.langCode,
    required this.meaning,
    this.storyId,
    this.pi,
    this.si,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'langCode': langCode,
        'meaning': meaning,
        'storyId': storyId,
        'pi': pi,
        'si': si,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedWord.fromJson(Map<String, dynamic> json) => SavedWord(
        word: json['word'],
        langCode: json['langCode'],
        meaning: json['meaning'],
        storyId: json['storyId'],
        pi: json['pi'],
        si: json['si'],
        savedAt: DateTime.parse(json['savedAt']),
      );
}
