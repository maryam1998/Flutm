// lib/models/shenakht/schema.dart
// مدلهای پایه طرحواره — معادل SCHEMAS.js وب

class SchemaItem {
  final String id;
  final String text;
  const SchemaItem(this.id, this.text);
}

class SchemaExerciseColumn {
  final String key;
  final String label;
  const SchemaExerciseColumn(this.key, this.label);
}

/// نوع تمرین یکی از اینهاست:
/// two_column | three_column | timer | single_choice
/// single_input | reflection | list
class SchemaExercise {
  final String id;
  final String title;
  final String type;
  final List<SchemaExerciseColumn>? columns;
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

class SchemaRuleWhen {
  final String? trigger;
  final String? behavior;
  const SchemaRuleWhen({this.trigger, this.behavior});
}

class SchemaRule {
  final SchemaRuleWhen when;
  final String then; // مثل "showExercise:reality_vs_assumption"
  const SchemaRule(this.when, this.then);
}

class ReplacementResponse {
  final String behaviorId;
  final String text;
  const ReplacementResponse(this.behaviorId, this.text);
}

class RealLifeMission {
  final String id;
  final String text;
  const RealLifeMission(this.id, this.text);
}

class ProgressMetric {
  final String id;
  final String label;
  const ProgressMetric(this.id, this.label);
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
  final List<RealLifeMission> realLifeMissions;
  final List<ProgressMetric> progressMetrics;
  final List<SchemaRule> rules;

  /// این دو فیلد بعداً از SIMPLE_LANGUAGE پر میشن (مثل web که merge میکنه)
  final String? namePlain;
  final String? oneLiner;

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
    this.namePlain,
    this.oneLiner,
  });

  Schema copyWith({String? namePlain, String? oneLiner}) => Schema(
        id: id,
        nameFa: nameFa,
        nameEn: nameEn,
        domain: domain,
        color: color,
        shortDescription: shortDescription,
        coreNeed: coreNeed,
        triggers: triggers,
        automaticThoughts: automaticThoughts,
        emotionalSignals: emotionalSignals,
        behavioralPatterns: behavioralPatterns,
        avoidancePatterns: avoidancePatterns,
        overcompensationPatterns: overcompensationPatterns,
        consequences: consequences,
        pauseQuestions: pauseQuestions,
        healthyResponse: healthyResponse,
        replacementResponses: replacementResponses,
        exercises: exercises,
        realLifeMissions: realLifeMissions,
        progressMetrics: progressMetrics,
        rules: rules,
        namePlain: namePlain ?? this.namePlain,
        oneLiner: oneLiner ?? this.oneLiner,
      );
}
