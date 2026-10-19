// lib/state/shenakht_store.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/shenakht/schemas.dart';
import '../data/shenakht/ysq_questions.dart';
import '../models/shenakht/checkin.dart';
import '../models/shenakht/progress_entry.dart';
import '../services/storage.dart';

class ShenakhtStore extends ChangeNotifier {
  ShenakhtStore(this._storage);
  final StorageService _storage;

  YsqAnalysis? analysis;
  List<ProgressEntry> entries = [];
  List<CheckIn> checkins = [];

  Timer? _timer;
  bool loaded = false;

  // ── Load ────────────────────────────────────────────────
  Future<void> load() async {
    try {
      final pRaw = await _storage.readKey(kYsqProfileKey);
      if (pRaw != null) analysis = _analysisFromJson(jsonDecode(pRaw));
    } catch (_) {
      analysis = null;
    }
    try {
      final eRaw = await _storage.readKey(kYsqProgressKey);
      if (eRaw != null) {
        final list = jsonDecode(eRaw);
        if (list is List) {
          entries = list
              .whereType<Map>()
              .map((m) => ProgressEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      }
    } catch (_) {
      entries = [];
    }
    try {
      final cRaw = await _storage.readKey(kYsqCheckinKey);
      if (cRaw != null) {
        final list = jsonDecode(cRaw);
        if (list is List) {
          checkins = list
              .whereType<Map>()
              .map((m) => CheckIn.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      }
    } catch (_) {
      checkins = [];
    }
    loaded = true;
    notifyListeners();
  }

  // ── Save (debounced) ────────────────────────────────────
  void _touch() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), _flush);
  }

  Future<void> _flush() async {
    _timer?.cancel();
    if (analysis != null) {
      await _storage.writeKey(
          kYsqProfileKey, jsonEncode(_analysisToJson(analysis!)));
    }
    await _storage.writeKey(
      kYsqProgressKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
    await _storage.writeKey(
      kYsqCheckinKey,
      jsonEncode(checkins.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> flush() => _flush();

  // ── Profile ────────────────────────────────────────────
  bool get hasProfile => analysis != null;

  Future<void> saveProfile(YsqAnalysis a) async {
    analysis = a;
    notifyListeners();
    await _flush();
  }

  Future<void> clearProfile() async {
    analysis = null;
    notifyListeners();
    await _storage.removeKey(kYsqProfileKey);
  }

  // ── Entries ────────────────────────────────────────────
  Future<void> addEntry(ProgressEntry e) async {
    entries.add(e);
    notifyListeners();
    _touch();
  }

  Future<void> recordCycle({
    String? schemaId,
    String? triggerId,
    String? thoughtId,
    String? emotionId,
    String? behaviorId,
    List<String> triggerIds = const [],
    List<String> thoughtIds = const [],
    List<String> emotionIds = const [],
    List<String> behaviorIds = const [],
    String? reactionType,
    String? exerciseId,
    Map<String, dynamic>? exerciseResult,
    String? missionId,
    bool missionDone = false,
    String notes = '',
  }) async {
    await addEntry(ProgressEntry(
      id: generateShenakhtId(),
      schemaId: schemaId,
      triggerId: triggerId,
      thoughtId: thoughtId,
      emotionId: emotionId,
      behaviorId: behaviorId,
      triggerIds: triggerIds,
      thoughtIds: thoughtIds,
      emotionIds: emotionIds,
      behaviorIds: behaviorIds,
      reactionType: reactionType,
      exerciseId: exerciseId,
      exerciseResult: exerciseResult,
      missionId: missionId,
      missionDone: missionDone,
      notes: notes,
      createdAt: DateTime.now(),
    ));
  }

  List<ProgressEntry> entriesForSchema(String? schemaId) {
    if (schemaId == null) return entries;
    return entries.where((e) => e.schemaId == schemaId).toList();
  }

  // ── CheckIn ────────────────────────────────────────────
  Future<void> addCheckIn({
    required String mood,
    String? schemaId,
    String note = '',
  }) async {
    checkins.add(CheckIn(
      id: generateShenakhtId(),
      mood: mood,
      schemaId: schemaId,
      note: note,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    _touch();
  }

  bool get hasCheckedInToday {
    final today = _dayKey(DateTime.now());
    return checkins.any((c) => _dayKey(c.createdAt) == today);
  }

  CheckIn? get todayCheckIn {
    final today = _dayKey(DateTime.now());
    for (final c in checkins.reversed) {
      if (_dayKey(c.createdAt) == today) return c;
    }
    return null;
  }

  // ── Wins / Streak ──────────────────────────────────────
  List<ProgressEntry> get wins {
    final w = entries
        .where((e) =>
            e.reactionType == 'paused' ||
            e.reactionType == 'new' ||
            e.missionDone ||
            e.isWin)
        .toList();
    w.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return w;
  }

  int get streak {
    if (entries.isEmpty) return 0;
    final days = entries.map((e) => _dayKey(e.createdAt)).toSet();
    final now = DateTime.now();
    var start = DateTime(now.year, now.month, now.day);
    if (!days.contains(_dayKey(start))) {
      start = start.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (days.contains(_dayKey(start))) {
      count++;
      start = start.subtract(const Duration(days: 1));
    }
    return count;
  }
}

// ── Helpers ─────────────────────────────────────────────
String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// تبدیل YSQ برای ذخیره — سازگار با وب (ysq_profile_v2)
Map<String, dynamic> _analysisToJson(YsqAnalysis a) => {
      'version': '2.0',
      'completedAt': DateTime.now().toIso8601String(),
      'scores': a.all
          .map((s) => {
                'schemaId': s.schemaId,
                'percentage': s.percentage,
                'mean': s.mean,
                'priority': s.priority.level,
                'elevatedCount': s.elevatedCount,
              })
          .toList(),
      'recommendedSchemaId': a.recommended?.schemaId,
    };

YsqAnalysis? _analysisFromJson(dynamic decoded) {
  if (decoded is! Map) return null;
  final scoresRaw = decoded['scores'];
  if (scoresRaw is! List) return null;

  final scores = <SchemaScore>[];
  for (final r in scoresRaw) {
    if (r is! Map) continue;
    final schemaId = r['schemaId'] as String?;
    if (schemaId == null) continue;
    final pct = (r['percentage'] as num?)?.toInt() ?? 0;
    final mean = (r['mean'] as num?)?.toDouble() ?? 0.0;
    final elevated = (r['elevatedCount'] as num?)?.toInt() ?? 0;
    final schema = findSchemaById(schemaId);
    scores.add(SchemaScore(
      schemaId: schemaId,
      name: schema?.nameFa ?? schemaId,
      domain: schema?.domain ?? 'unknown',
      mean: mean,
      percentage: pct,
      answered: 5,
      total: 5,
      elevatedCount: elevated,
      priority: getPriority(pct),
    ));
  }
  scores.sort((a, b) => b.percentage.compareTo(a.percentage));

  final high = scores.where((s) => s.priority.level == 'high').toList();
  final medium = scores.where((s) => s.priority.level == 'medium').toList();
  final low = scores.where((s) => s.priority.level == 'low').toList();

  SchemaScore? recommended;
  final recId = decoded['recommendedSchemaId'] as String?;
  if (recId != null) {
    for (final s in scores) {
      if (s.schemaId == recId) {
        recommended = s;
        break;
      }
    }
  }
  recommended ??= high.isNotEmpty
      ? high.first
      : medium.isNotEmpty
          ? medium.first
          : (scores.isNotEmpty ? scores.first : null);

  return YsqAnalysis(
    all: scores,
    high: high,
    medium: medium,
    low: low,
    active: [...high, ...medium],
    recommended: recommended,
    answeredCount: 90,
    totalCount: 90,
  );
}
