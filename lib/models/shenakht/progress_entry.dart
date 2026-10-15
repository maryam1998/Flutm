// lib/models/shenakht/progress_entry.dart
import 'dart:math';

String generateShenakhtId() =>
    'e_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_'
    '${Random().nextInt(1 << 32).toRadixString(36).padLeft(7, '0')}';

/// یک رکورد ثبت چرخه — سازگار با `ysq_progress_v3` وب
class ProgressEntry {
  final String id;
  final String? schemaId;
  final String? triggerId;
  final String? thoughtId;
  final String? emotionId;
  final String? behaviorId;
  final List<String> triggerIds;
  final List<String> thoughtIds;
  final List<String> emotionIds;
  final List<String> behaviorIds;
  final String? reactionType; // old | paused | new
  final int? pauseDurationMs;
  final String? exerciseId;
  final Map<String, dynamic>? exerciseResult;
  final String? missionId;
  final bool missionDone;
  final bool isWin;
  final String notes;
  final DateTime createdAt;

  ProgressEntry({
    required this.id,
    this.schemaId,
    this.triggerId,
    this.thoughtId,
    this.emotionId,
    this.behaviorId,
    this.triggerIds = const [],
    this.thoughtIds = const [],
    this.emotionIds = const [],
    this.behaviorIds = const [],
    this.reactionType,
    this.pauseDurationMs,
    this.exerciseId,
    this.exerciseResult,
    this.missionId,
    this.missionDone = false,
    this.isWin = false,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'schemaId': schemaId,
        'triggerId': triggerId,
        'thoughtId': thoughtId,
        'emotionId': emotionId,
        'behaviorId': behaviorId,
        if (triggerIds.isNotEmpty) 'triggerIds': triggerIds,
        if (thoughtIds.isNotEmpty) 'thoughtIds': thoughtIds,
        if (emotionIds.isNotEmpty) 'emotionIds': emotionIds,
        if (behaviorIds.isNotEmpty) 'behaviorIds': behaviorIds,
        'reactionType': reactionType,
        if (pauseDurationMs != null) 'pauseDurationMs': pauseDurationMs,
        'exerciseId': exerciseId,
        if (exerciseResult != null) 'exerciseResult': exerciseResult,
        'missionId': missionId,
        'missionDone': missionDone,
        'isWin': isWin,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ProgressEntry.fromJson(Map<String, dynamic> j) => ProgressEntry(
        id: j['id'] as String? ?? generateShenakhtId(),
        schemaId: j['schemaId'] as String?,
        triggerId: j['triggerId'] as String?,
        thoughtId: j['thoughtId'] as String?,
        emotionId: j['emotionId'] as String?,
        behaviorId: j['behaviorId'] as String?,
        triggerIds: _stringList(j['triggerIds']),
        thoughtIds: _stringList(j['thoughtIds']),
        emotionIds: _stringList(j['emotionIds']),
        behaviorIds: _stringList(j['behaviorIds']),
        reactionType: j['reactionType'] as String?,
        pauseDurationMs: (j['pauseDurationMs'] as num?)?.toInt(),
        exerciseId: j['exerciseId'] as String?,
        exerciseResult: j['exerciseResult'] is Map
            ? Map<String, dynamic>.from(j['exerciseResult'] as Map)
            : null,
        missionId: j['missionId'] as String?,
        missionDone: j['missionDone'] == true,
        isWin: j['isWin'] == true,
        notes: j['notes'] as String? ?? '',
        createdAt: _parseDate(j['createdAt']),
      );
}

List<String> _stringList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

DateTime _parseDate(dynamic v) {
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}
