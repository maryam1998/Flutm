import 'package:flutter/foundation.dart';

/// یک پرسش و پاسخِ پیگیری درباره‌ی یک یادداشت گرامر
@immutable
class GrammarThreadItem {
  final String question;
  final String answer;

  const GrammarThreadItem({required this.question, required this.answer});

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};

  factory GrammarThreadItem.fromJson(Map<String, dynamic> json) =>
      GrammarThreadItem(
        question: (json['question'] ?? '').toString(),
        answer: (json['answer'] ?? '').toString(),
      );
}

@immutable
class GrammarNote {
  final String id;
  final String word;
  final String sentence;
  final String markdown;
  final String langCode;
  final DateTime savedAt;

  /// پرسش‌وپاسخ‌های همین یادداشت (مثل `thread` در Hope)
  final List<GrammarThreadItem> thread;

  const GrammarNote({
    required this.id,
    required this.word,
    required this.sentence,
    required this.markdown,
    required this.langCode,
    required this.savedAt,
    this.thread = const <GrammarThreadItem>[],
  });

  GrammarNote copyWith({List<GrammarThreadItem>? thread}) => GrammarNote(
        id: id,
        word: word,
        sentence: sentence,
        markdown: markdown,
        langCode: langCode,
        savedAt: savedAt,
        thread: thread ?? this.thread,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'sentence': sentence,
        'markdown': markdown,
        'langCode': langCode,
        'savedAt': savedAt.toIso8601String(),
        'thread': thread.map((t) => t.toJson()).toList(),
      };

  factory GrammarNote.fromJson(Map<String, dynamic> json) => GrammarNote(
        id: json['id'],
        word: json['word'],
        sentence: json['sentence'],
        markdown: json['markdown'],
        langCode: json['langCode'],
        savedAt: DateTime.parse(json['savedAt']),
        thread: (json['thread'] is List)
            ? (json['thread'] as List)
                .whereType<Map>()
                .map((m) =>
                    GrammarThreadItem.fromJson(Map<String, dynamic>.from(m)))
                .toList()
            : const <GrammarThreadItem>[],
      );
}
