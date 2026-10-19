import 'package:flutter/foundation.dart';

@immutable
class ConversationLine {
  final String en;
  final String fa;
  final String level;

  const ConversationLine({
    required this.en,
    required this.fa,
    required this.level,
  });

  factory ConversationLine.fromJson(Map<String, dynamic> j) {
    return ConversationLine(
      en: j['en']?.toString() ?? '',
      fa: j['fa']?.toString() ?? '',
      level: j['level']?.toString() ?? 'A1',
    );
  }
}

@immutable
class ConversationScenario {
  final String scenario;
  final String? context;
  final List<ConversationLine> speakerA;
  final List<ConversationLine> speakerB;

  const ConversationScenario({
    required this.scenario,
    this.context,
    required this.speakerA,
    required this.speakerB,
  });

  factory ConversationScenario.fromJson(Map<String, dynamic> j) {
    return ConversationScenario(
      scenario: j['scenario']?.toString() ?? '',
      context: j['context']?.toString(),
      speakerA: (j['speakerA'] as List<dynamic>? ?? [])
          .map((e) => ConversationLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      speakerB: (j['speakerB'] as List<dynamic>? ?? [])
          .map((e) => ConversationLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

@immutable
class ConversationTopic {
  final String topic;
  final List<ConversationScenario> scenarios;

  const ConversationTopic({
    required this.topic,
    required this.scenarios,
  });

  factory ConversationTopic.fromJson(Map<String, dynamic> j) {
    return ConversationTopic(
      topic: j['topic']?.toString() ?? '',
      scenarios: (j['scenarios'] as List<dynamic>? ?? [])
          .map((e) => ConversationScenario.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
