// مدلهای پایه طرحواره
class SchemaItem {
  final String id;
  final String text;
  const SchemaItem(this.id, this.text);
}

class SchemaExercise {
  final String id;
  final String title;
  final String type; // two_column | three_column | timer | single_choice | single_input | reflection | list
  final List<List<String>>? columns; // [[key,label], ...]
  final String? question;
  final List<String>? answers;
  final String? ifNo;
  final int? durationSeconds;
  final String? description;
  final List<String>? options;
  final List<String>? prompts;
  final String? prompt;

  const SchemaExercise({
    required this.id,
    required this.title,
    required this.type,
    this.columns,
    this.question,
    this.answers,
    this.ifNo,
    this.durationSeconds,
    this.description,
    this.options,
    this.prompts,
    this.prompt,
  });
}

class SchemaRule {
  final String? trigger;
  final String? behavior;
  final String then;
  const SchemaRule({this.trigger, this.behavior, required this.then});
}

class ReplacementResponse {
  final String behaviorId;
  final String text;
  const ReplacementResponse(this.behaviorId, this.text);
}

class Schema {
  final String id;
  final String nameFa;
  final String nameEn;
  final String domain;
  final String color;
  final String shortDescription;
  final String coreNeed;
  final List<SchemaItem> triggers;
  final List<SchemaItem> automaticThoughts;
  final List<SchemaItem> emotionalSignals;
  final List<SchemaItem> behavioralPatterns;
  final List<String> avoidancePatterns;
  final List<String> overcompensationPatterns;
  final List<String> consequences;
  final List<String> pauseQuestions;
  final String healthyResponse;
  final List<ReplacementResponse> replacementResponses;
  final List<SchemaExercise> exercises;
  final List<List<String>> realLifeMissions; // [[id,text], ...]
  final List<List<String>> progressMetrics;  // [[id,label], ...]
  final List<SchemaRule> rules;

  const Schema({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.domain,
    required this.color,
    required this.shortDescription,
    required this.coreNeed,
    required this.triggers,
    required this.automaticThoughts,
    required this.emotionalSignals,
    required this.behavioralPatterns,
    required this.avoidancePatterns,
    required this.overcompensationPatterns,
    required this.consequences,
    required this.pauseQuestions,
    required this.healthyResponse,
    required this.replacementResponses,
    required this.exercises,
    required this.realLifeMissions,
    required this.progressMetrics,
    required this.rules,
  });
}
