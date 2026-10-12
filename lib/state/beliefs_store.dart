import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/future_text_format.dart';
import '../models/future_version.dart';

/// مقدار پیش‌فرض دوره‌ی خواندن (۹۰ روز طبق وب)
const int kFutureDefaultDays = 90;
const int kFutureMaxDays = 365;

class BeliefsStore extends ChangeNotifier {
  static const _kVersions = 'beliefs_versions';
  static const _kActiveId = 'beliefs_active_id';
  static const _kFormat = 'beliefs_format';
  static const _kCycleDays = 'beliefs_cycle_days';
  static const _kAlarmEnabled = 'beliefs_alarm_enabled';
  static const _kAlarmTime = 'beliefs_alarm_time';

  final List<FutureVersion> versions = [];
  String? activeVersionId;
  FutureTextFormat format = FutureTextFormat();
  int cycleDays = kFutureDefaultDays;

  bool alarmEnabled = false;
  String alarmTime = '20:00';

  bool loaded = false;

  // ---------- load / persist ----------

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();

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
    } catch (_) {}

    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
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
    } catch (_) {}
  }

  // ---------- version management ----------

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

  /// ثبت یا ویرایش متن خواسته. اگه نسخه‌ی فعال وجود داشته باشه، متنش رو
  /// آپدیت می‌کنه (و نسخه‌ی قبلی متن رو توی prevTexts نگه می‌داره).
  /// وگرنه یه نسخه‌ی جدید می‌سازه.
  Future<void> saveText(String newText) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    final cur = activeVersion;
    if (cur == null) {
      final v = FutureVersion(
        text: trimmed,
        startDate: _todayKey(),
      );
      versions.add(v);
      activeVersionId = v.id;
    } else {
      if (cur.text == trimmed) return;
      cur.prevTexts.add(PrevText(text: cur.text, at: DateTime.now().millisecondsSinceEpoch));
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

  /// تنظیم تعداد روزهای دوره
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

  // ---------- read tracking ----------

  /// روز چندم دوره‌ی فعلی
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

  /// تعداد روزهای خوانده‌شده (برای نمایش در progress bar)
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

  /// ثبت «امروز خواندم»
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

  /// ریست تقویم (دوره‌ی جدید از امروز)
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

  // ---------- archive ----------

  /// آرشیو کردن نسخه‌ی فعلی و ساخت نسخه‌ی جدید خالی
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

  /// فعال‌کردن یک نسخه‌ی آرشیوی
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

  // ---------- helpers ----------

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
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
