import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../services/app_prefs.dart';

import '../models/future_text_format.dart';
import '../models/future_version.dart';
import '../models/emotion.dart';
import '../models/neural_container.dart';

const int kFutureDefaultDays = 90;
const int kFutureMaxDays = 365;

// ═══════════════ مدل‌های مأموریت ذهن (RAS) ═══════════════
class RasSignal {
  final String id;
  final DateTime ts;
  final String text;
  final String feel;
  const RasSignal({
    required this.id,
    required this.ts,
    required this.text,
    required this.feel,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts.millisecondsSinceEpoch,
        'text': text,
        'feel': feel,
      };
  factory RasSignal.fromJson(Map<String, dynamic> j) => RasSignal(
        id: j['id'] as String,
        ts: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
        text: j['text'] as String? ?? '',
        feel: j['feel'] as String? ?? 'normal',
      );
}

class RasMissionData {
  final String label;
  final String? chipId;
  final String startDate;
  const RasMissionData({
    required this.label,
    this.chipId,
    required this.startDate,
  });
  Map<String, dynamic> toJson() => {
        'label': label,
        'chip': chipId,
        'startDate': startDate,
      };
  factory RasMissionData.fromJson(Map<String, dynamic> j) => RasMissionData(
        label: j['label'] as String? ?? '',
        chipId: j['chip'] as String?,
        startDate: j['startDate'] as String? ?? '',
      );
}

class BeliefsStore extends ChangeNotifier {
  static const _kVersions = 'beliefs_versions';
  static const _kActiveId = 'beliefs_active_id';
  static const _kFormat = 'beliefs_format';
  static const _kCycleDays = 'beliefs_cycle_days';
  static const _kAlarmEnabled = 'beliefs_alarm_enabled';
  static const _kAlarmTime = 'beliefs_alarm_time';
  static const _kRasMission = 'ras_mission_v1';
  static const _kRasSignals = 'ras_signals_v1';
  static const _kSeedNotes = 'beliefs_seed_notes_v1';
  static const _kNeural = 'beliefs_neural_v1';
  static const _kMissionNeural = 'beliefs_mission_neural_v1';
  static const _kTodaySteps = 'beliefs_today_steps_v1';
  static const _kTodayNothing = 'beliefs_today_nothing_v1';

  final List<FutureVersion> versions = [];
  String? activeVersionId;
  FutureTextFormat format = FutureTextFormat();
  int cycleDays = kFutureDefaultDays;

  bool alarmEnabled = false;
  String alarmTime = '20:00';

  // ═══ مأموریت ذهن ═══
  RasMissionData? rasMission;
  final List<RasSignal> rasSignals = [];

  // ═══ تمرین روزانه ═══
  final Set<String> _todaySteps = {};
  final Set<String> _todayNothingLayers = {};
  final Map<String, String> seedNotes = {};
  NeuralContainer neural = NeuralContainer();
  NeuralContainer missionNeural = NeuralContainer();

  bool loaded = false;

  // ═══ Getters ═══
  Set<String> get todaySteps => _todaySteps;
  Set<String> get todayNothingLayers => _todayNothingLayers;

  // ═══ Actions ═══
  void toggleStep(String key) {
    if (_todaySteps.contains(key)) {
      _todaySteps.remove(key);
    } else {
      _todaySteps.add(key);
    }
    _persist();
    notifyListeners();
  }

  void toggleNothingLayer(String key) {
    if (_todayNothingLayers.contains(key)) {
      _todayNothingLayers.remove(key);
    } else {
      _todayNothingLayers.add(key);
    }
    _persist();
    notifyListeners();
  }

  void setSeedNote(String key, String value) {
    seedNotes[key] = value;
    _persist();
  }

  /// «ثبت حس» از ادمک برای مسیرهای عصبیِ این تب:
  /// تمرین باور (اگه امروز خونده شده باشه رشته‌ی جدید هم می‌سازه) و ردیابی RAS.
  Future<FeelingApply> applyCommittedFeeling(List<String> ids) async {
    final valid = ids.where((id) => emotionById(id) != null).toList();
    final dom = dominantEmotion(valid);
    if (dom == null) return FeelingApply.skipped;
    final felt = NeuralFiberEmotion(ids: valid, color: dom.color, freq: dom.freq);
    final r1 = neural.applyFeelingToToday(felt, createIfConfirmed: hasReadToday);
    final r2 = missionNeural.applyFeelingToToday(felt);
    if (r1 == FeelingApply.skipped && r2 == FeelingApply.skipped) {
      return FeelingApply.skipped;
    }
    await _persist();
    notifyListeners();
    return (r1 == FeelingApply.applied || r2 == FeelingApply.applied)
        ? FeelingApply.applied
        : FeelingApply.doneNoChange;
  }

  Future<void> saveNeural() async {
    await _persist();
    notifyListeners();
  }
  // ═══════════════ load ═══════════════
Future<void> load() async {
  try {
    final sp = await AppPrefs.getInstance();

    final rawV = sp.getString(_kVersions);
    if (rawV != null && rawV.isNotEmpty) {
      final list = jsonDecode(rawV);
      if (list is List) {
        versions
          ..clear()
          ..addAll(list.map(
              (e) => FutureVersion.fromJson(Map<String, dynamic>.from(e))));
      }
    }

    activeVersionId = sp.getString(_kActiveId);

    final rawF = sp.getString(_kFormat);
    if (rawF != null && rawF.isNotEmpty) {
      format = FutureTextFormat.fromJson(
        Map<String, dynamic>.from(jsonDecode(rawF)),
      );
    }

    cycleDays = sp.getInt(_kCycleDays) ?? kFutureDefaultDays;
    if (cycleDays < 1) cycleDays = kFutureDefaultDays;
    if (cycleDays > kFutureMaxDays) cycleDays = kFutureMaxDays;

    alarmEnabled = sp.getBool(_kAlarmEnabled) ?? false;
    alarmTime = sp.getString(_kAlarmTime) ?? '20:00';

    // ═══ RAS Mission ═══
    final rmRaw = sp.getString(_kRasMission);
    if (rmRaw != null && rmRaw.isNotEmpty) {
      try {
        rasMission = RasMissionData.fromJson(
          Map<String, dynamic>.from(jsonDecode(rmRaw)),
        );
      } catch (_) {}
    }
    final rsRaw = sp.getString(_kRasSignals);
    if (rsRaw != null && rsRaw.isNotEmpty) {
      try {
        rasSignals
          ..clear()
          ..addAll((jsonDecode(rsRaw) as List).map(
              (e) => RasSignal.fromJson(Map<String, dynamic>.from(e))));
      } catch (_) {}
    }

    // ═══ Seed Notes ═══
    final snRaw = sp.getString(_kSeedNotes);
    if (snRaw != null && snRaw.isNotEmpty) {
      try {
        final m = jsonDecode(snRaw) as Map;
        seedNotes
          ..clear()
          ..addAll(m.map((k, v) => MapEntry(k.toString(), v.toString())));
      } catch (_) {}
    }

    // ═══ Neural Containers ═══
    final nRaw = sp.getString(_kNeural);
    if (nRaw != null && nRaw.isNotEmpty) {
      try {
        neural = NeuralContainer.fromJson(
            Map<String, dynamic>.from(jsonDecode(nRaw)));
      } catch (_) {}
    }
    final mnRaw = sp.getString(_kMissionNeural);
    if (mnRaw != null && mnRaw.isNotEmpty) {
      try {
        missionNeural = NeuralContainer.fromJson(
            Map<String, dynamic>.from(jsonDecode(mnRaw)));
      } catch (_) {}
    }

    // ═══ Today's steps ═══
    final tsRaw = sp.getString(_kTodaySteps);
    if (tsRaw != null && tsRaw.isNotEmpty) {
      try {
        final today = todayKey();
        final m = jsonDecode(tsRaw) as Map;
        if (m['day'] == today && m['steps'] is List) {
          _todaySteps
            ..clear()
            ..addAll((m['steps'] as List).map((e) => e.toString()));
        }
      } catch (_) {}
    }
    final tnRaw = sp.getString(_kTodayNothing);
    if (tnRaw != null && tnRaw.isNotEmpty) {
      try {
        final today = todayKey();
        final m = jsonDecode(tnRaw) as Map;
        if (m['day'] == today && m['layers'] is List) {
          _todayNothingLayers
            ..clear()
            ..addAll((m['layers'] as List).map((e) => e.toString()));
        }
      } catch (_) {}
    }

  } catch (_) {}

  loaded = true;
  notifyListeners();
}

// ═══════════════ persist ═══════════════
Future<void> _persist() async {
  try {
    final sp = await AppPrefs.getInstance();
    await sp.setString(
        _kVersions, jsonEncode(versions.map((v) => v.toJson()).toList()));
    if (activeVersionId != null) {
      await sp.setString(_kActiveId, activeVersionId!);
    } else {
      await sp.remove(_kActiveId);
    }
    await sp.setString(_kFormat, jsonEncode(format.toJson()));
    await sp.setInt(_kCycleDays, cycleDays);
    await sp.setBool(_kAlarmEnabled, alarmEnabled);
    await sp.setString(_kAlarmTime, alarmTime);

    // RAS
    await sp.setString(_kRasMission,
        rasMission == null ? '' : jsonEncode(rasMission!.toJson()));
    await sp.setString(_kRasSignals,
        jsonEncode(rasSignals.map((e) => e.toJson()).toList()));

    // Seed notes / Neural
    await sp.setString(_kSeedNotes, jsonEncode(seedNotes));
    await sp.setString(_kNeural, jsonEncode(neural.toJson()));
    await sp.setString(
        _kMissionNeural, jsonEncode(missionNeural.toJson()));

    // Today's steps
    await sp.setString(
        _kTodaySteps,
        jsonEncode({
          'day': todayKey(),
          'steps': _todaySteps.toList(),
        }));
    await sp.setString(
        _kTodayNothing,
        jsonEncode({
          'day': todayKey(),
          'layers': _todayNothingLayers.toList(),
        }));
  } catch (_) {}
}
    // ═══════════════ نسخهها ═══════════════
  FutureVersion? get activeVersion {
    if (activeVersionId == null) return null;
    for (final v in versions) {
      if (v.id == activeVersionId) return v;
    }
    return null;
  }

  bool get hasActiveText {
    final v = activeVersion;
    return v != null && v.text.trim().isNotEmpty;
  }

  Future<void> saveText(String newText) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    final cur = activeVersion;
    if (cur == null) {
      final v = FutureVersion(text: trimmed, startDate: _todayKey());
      versions.add(v);
      activeVersionId = v.id;
    } else {
      if (cur.text == trimmed) return;
      cur.prevTexts.add(
          PrevText(text: cur.text, at: DateTime.now().millisecondsSinceEpoch));
      cur.text = trimmed;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setFormat(FutureTextFormat f) async {
    format = f;
    await _persist();
    notifyListeners();
  }

  Future<void> setCycleDays(int days) async {
    if (days < 1) days = kFutureDefaultDays;
    if (days > kFutureMaxDays) days = kFutureMaxDays;
    cycleDays = days;
    await _persist();
    notifyListeners();
  }

  Future<void> setAlarm({bool? enabled, String? time}) async {
    if (enabled != null) alarmEnabled = enabled;
    if (time != null) alarmTime = time;
    await _persist();
    notifyListeners();
  }

  // ═══════════════ خواندن روزانه ═══════════════
  int get currentDay {
    final v = activeVersion;
    if (v == null) return 1;
    final start = _parseKey(v.startDate);
    final today = _today();
    final diff = today.difference(start).inDays + 1;
    if (diff < 1) return 1;
    if (diff > cycleDays) return cycleDays;
    return diff;
  }

  bool get cycleFinished {
    final v = activeVersion;
    if (v == null) return false;
    final start = _parseKey(v.startDate);
    final end = start.add(Duration(days: cycleDays));
    return !_today().isBefore(end);
  }

  int get readDayCount {
    final v = activeVersion;
    if (v == null) return 0;
    return v.readDays.length.clamp(0, cycleDays);
  }

  bool get hasReadToday {
    final v = activeVersion;
    if (v == null) return false;
    return v.readDays.contains(_todayKey());
  }

  Future<void> markReadToday() async {
    final v = activeVersion;
    if (v == null) return;
    final k = _todayKey();
    if (v.readDays.contains(k)) return;
    v.readDays.add(k);
    v.readTimes[k] = DateTime.now().millisecondsSinceEpoch;
    await _persist();
    notifyListeners();
  }

  Future<void> resetCalendar() async {
    final v = activeVersion;
    if (v == null) return;
    v.cycles.add(FutureReadCycle(
      startDate: v.startDate,
      endDate: _todayKey(),
      readDays: List.of(v.readDays),
      readTimes: Map.of(v.readTimes),
    ));
    v.startDate = _todayKey();
    v.readDays = [];
    v.readTimes = {};
    await _persist();
    notifyListeners();
  }

  // ═══════════════ آرشیو ═══════════════
  Future<void> archiveAndStartNew() async {
    final cur = activeVersion;
    if (cur != null) {
      cur.endDate = _todayKey();
    }
    final v = FutureVersion(startDate: _todayKey());
    versions.add(v);
    activeVersionId = v.id;
    await _persist();
    notifyListeners();
  }

  Future<void> activateVersion(String id) async {
    final chosen = versions.firstWhere((v) => v.id == id,
        orElse: () => FutureVersion(startDate: _todayKey()));
    if (chosen.id != id) return;
    for (final v in versions) {
      if (v.id != id && v.isActive) {
        v.endDate = _todayKey();
      }
    }
    chosen.endDate = null;
    activeVersionId = chosen.id;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteVersion(String id) async {
    if (id == activeVersionId) return;
    versions.removeWhere((v) => v.id == id);
    await _persist();
    notifyListeners();
  }

  // ═══════════════ RAS Mission ═══════════════
  static String todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int get rasMissionDay {
    if (rasMission == null) return 0;
    final parts = rasMission!.startDate
        .split('-')
        .map((e) => int.tryParse(e) ?? 1)
        .toList();
    if (parts.length != 3) return 1;
    final start = DateTime(parts[0], parts[1], parts[2]);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(start).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  void startRasMission({String? chipId, required String label}) {
    rasMission = RasMissionData(
      label: label,
      chipId: chipId,
      startDate: todayKey(),
    );
    _persist();
    notifyListeners();
  }

  void endRasMission() {
    rasMission = null;
    _persist();
    notifyListeners();
  }

  void addRasSignal(String text, String feel) {
    rasSignals.add(RasSignal(
      id: 'sig_${DateTime.now().millisecondsSinceEpoch}_${rasSignals.length}',
      ts: DateTime.now(),
      text: text,
      feel: feel,
    ));
    _persist();
    notifyListeners();
  }

  void removeRasSignal(String id) {
    rasSignals.removeWhere((s) => s.id == id);
    _persist();
    notifyListeners();
  }

  List<RasSignal> rasSignalsForDay(String key) {
    return rasSignals.where((s) {
      final d = s.ts;
      final k =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return k == key;
    }).toList();
  }

  List<({DateTime date, String key, int count})> rasSignalsForLast7Days() {
    final out = <({DateTime date, String key, int count})>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final k =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      out.add((date: d, key: k, count: rasSignalsForDay(k).length));
    }
    return out;
  }

  // ═══════════════ helpers ═══════════════
  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime _today() {
    final d = DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime _parseKey(String k) {
    final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
    if (p.length != 3) return DateTime.now();
    return DateTime(p[0], p[1], p[2]);
  }
}
