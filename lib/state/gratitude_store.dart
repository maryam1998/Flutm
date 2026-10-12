import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gratitude_entry.dart';

class GratitudeStore extends ChangeNotifier {
  static const _kEntries = 'gratitude_entries';
  static const _kJourneyDays = 'gratitude_journey_days';
  static const _kJourneyStart = 'gratitude_journey_start';

  final List<GratitudeEntry> entries = [];
  int journeyDays = 28;
  String journeyStart = '';
  bool loaded = false;

  // صفحه‌بندی
  int homeLimit = 40;
  int histLimit = 40;

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kEntries);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          entries
            ..clear()
            ..addAll(list.map(GratitudeEntry.fromJson));
        }
      }
      journeyDays = sp.getInt(_kJourneyDays) ?? 28;
      if (journeyDays < 1) journeyDays = 28;
      journeyStart = sp.getString(_kJourneyStart) ?? '';
      if (journeyStart.isEmpty) journeyStart = _todayKey();
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        _kEntries,
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      );
      await sp.setInt(_kJourneyDays, journeyDays);
      await sp.setString(_kJourneyStart, journeyStart);
    } catch (_) {}
  }

  int get totalCount => entries.length;

  /// تعداد شکرگذاری‌های امروز (بدون خرید)
  int get todayCount {
    final k = _todayKey();
    return entries
        .where((e) => e.source != 'purchase' && isoToKey(e.iso) == k)
        .length;
  }

  List<GratitudeEntry> get allReversed => entries.reversed.toList();

  /// لیست برای صفحه‌ی خانه (محدود به homeLimit)
  List<GratitudeEntry> get homeSlice =>
      allReversed.take(homeLimit).toList();

  /// لیست برای تب شکرگذاری (محدود به histLimit)
  List<GratitudeEntry> get histSlice =>
      allReversed.take(histLimit).toList();

  bool get hasMoreHome => entries.length > homeLimit;
  bool get hasMoreHist => entries.length > histLimit;

  GratitudeEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// روز چندم مسیر
  int get journeyDay {
    final start = _parseKey(journeyStart);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final passed =
        today.difference(DateTime(start.year, start.month, start.day)).inDays + 1;
    return passed < 1 ? 1 : passed;
  }

  bool get journeyFinished {
    final start = _parseKey(journeyStart);
    final end = DateTime(start.year, start.month, start.day + journeyDays);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(end);
  }

  Future<GratitudeEntry> add({
    required String text,
    String icon = '🙏',
    List<GratitudeImage>? images,
    List<GratitudeAudio>? audios,
    bool shared = false,
    double? amount,
    String source = 'manual',
    double? txId,
  }) async {
    final now = DateTime.now();
    final e = GratitudeEntry(
      text: text,
      icon: icon,
      image: (images != null && images.isNotEmpty) ? images.first.src : null,
      images: images ?? [],
      audios: audios ?? [],
      amount: amount,
      date: _faDate(now),
      day: _faWeekday(now),
      time: _faTime(now),
      iso: now.toIso8601String(),
      source: source,
      shared: shared,
      txId: txId,
    );
    entries.add(e);
    await _persist();
    notifyListeners();
    return e;
  }

  Future<void> update(
    String id, {
    String? text,
    List<GratitudeImage>? images,
    List<GratitudeAudio>? audios,
    bool? shared,
  }) async {
    final e = byId(id);
    if (e == null) return;
    if (text != null) e.text = text;
    if (images != null) {
      e.images = images;
      e.image = images.isNotEmpty ? images.first.src : null;
    }
    if (audios != null) e.audios = audios;
    if (shared != null) e.shared = shared;
    e.editedAt = DateTime.now().millisecondsSinceEpoch;
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    entries.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> showMoreHome() async {
    homeLimit += 40;
    notifyListeners();
  }

  Future<void> showMoreHist() async {
    histLimit += 40;
    notifyListeners();
  }

  Future<void> setJourneyDays(int days) async {
    if (days < 1) days = 28;
    journeyDays = days;
    await _persist();
    notifyListeners();
  }

  Future<void> startNewJourney() async {
    journeyStart = _todayKey();
    await _persist();
    notifyListeners();
  }

  // ---------- helpers ----------

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String isoToKey(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  static DateTime _parseKey(String k) {
    final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
    if (p.length != 3) return DateTime.now();
    return DateTime(p[0], p[1], p[2]);
  }

  static const _faWeekdays = [
    'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه',
    'جمعه', 'شنبه', 'یکشنبه'
  ];

  static String _faDate(DateTime d) {
    // میلادی ذخیره می‌شه، توی UI جلالی نشون داده می‌شه
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _faWeekday(DateTime d) => _faWeekdays[d.weekday - 1];

  static String _faTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
