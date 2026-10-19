// lib/models/shenakht/checkin.dart
import 'progress_entry.dart' show generateShenakhtId;

/// یک رکورد چک‌این روزانه — سازگار با `ysq_checkins_v1` وب
class CheckIn {
  final String id;
  final String mood; // 'good' | 'meh' | 'hard'
  final String? schemaId;
  final String note;
  final DateTime createdAt;

  CheckIn({
    required this.id,
    required this.mood,
    this.schemaId,
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'mood': mood,
        'schemaId': schemaId,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CheckIn.fromJson(Map<String, dynamic> j) => CheckIn(
        id: j['id'] as String? ?? generateShenakhtId(),
        mood: j['mood'] as String? ?? 'meh',
        schemaId: j['schemaId'] as String?,
        note: j['note'] as String? ?? '',
        createdAt: _parseDate(j['createdAt']),
      );
}

DateTime _parseDate(dynamic v) {
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}
