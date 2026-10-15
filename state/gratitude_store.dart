import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/app_prefs.dart';

import '../models/emotion.dart';
import '../models/gratitude_entry.dart';
import '../models/neural_container.dart';
import 'emotion_store.dart';

class GratitudeStore extends ChangeNotifier {
  static const _kEntries = 'gratitude_entries';
  static const _kJourneyDays = 'gratitude_journey_days';
  static const _kJourneyStart = 'gratitude_journey_start';
  static const _kNeural = 'gratitude_neural';
  static const _kDayAfter = 'gratitude_day_after';
  static const _kJourneyPast = 'gratitude_journey_past';

  NeuralContainer neural = NeuralContainer();

  /// حسِ «ثبت‌شده» برای هر روز (practiceEmotions[day].gratitude.after در وب)
  final Map<String, List<String>> dayAfter = {};

  /// دوره‌های تمام‌شده‌ی قبلی: [{days: int, startDate: 'yyyy-MM-dd'}]
  final List<Map<String, dynamic>> pastPeriods = [];

  final List<GratitudeEntry> entries = [];
  int journeyDays = 28;
  String journeyStart = '';
  bool loaded = false;

  int homeLimit = 40;
  int histLimit = 40;

  Future<void> load() async {
    try {
      final sp = await AppPrefs.getInstance();
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
      final nRaw = sp.getString(_kNeural);
      if (nRaw != null && nRaw.isNotEmpty) {
        try {
          neural = NeuralContainer.fromJson(
            Map<String, dynamic>.from(jsonDecode(nRaw)),
          );
        } catch (_) {}
      }
      final daRaw = sp.getString(_kDayAfter);
      if (daRaw != null && daRaw.isNotEmpty) {
        try {
          final m = jsonDecode(daRaw);
          if (m is Map) {
            dayAfter.clear();
            m.forEach((k, v) {
              if (v is List) {
                dayAfter[k.toString()] = v.map((e) => e.toString()).toList();
              }
            });
          }
        } catch (_) {}
      }
      final pRaw = sp.getString(_kJourneyPast);
      if (pRaw != null && pRaw.isNotEmpty) {
        try {
          final l = jsonDecode(pRaw);
          if (l is List) {
            pastPeriods
              ..clear()
              ..addAll(l.whereType<Map>().map((m) => {
                    'days': (m['days'] as num?)?.toInt() ?? 28,
                    'startDate': m['startDate']?.toString() ?? '',
                  }));
          }
        } catch (_) {}
      }
      neural.autoSync();
      await _persist();
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setString(
        _kEntries,
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      );
      await sp.setInt(_kJourneyDays, journeyDays);
      await sp.setString(_kJourneyStart, journeyStart);
      await sp.setString(_kNeural, jsonEncode(neural.toJson()));
      await sp.setString(_kDayAfter, jsonEncode(dayAfter));
      await sp.setString(_kJourneyPast, jsonEncode(pastPeriods));
    } catch (_) {}
  }

  int get totalCount => entries.length;

  int get todayCount {
    final k = _todayKey();
    return entries
        .where((e) => e.source != 'purchase' && isoToKey(e.iso) == k)
        .length;
  }

  List<GratitudeEntry> get allReversed => entries.reversed.toList();

  List<GratitudeEntry> get homeSlice => allReversed.take(homeLimit).toList();

  List<GratitudeEntry> get histSlice => allReversed.take(histLimit).toList();

  bool get hasMoreHome => entries.length > homeLimit;
  bool get hasMoreHist => entries.length > histLimit;

  GratitudeEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  int get journeyDay {
    final start = _parseKey(journeyStart);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final passed = today
            .difference(DateTime(start.year, start.month, start.day))
            .inDays +
        1;
    return passed < 1 ? 1 : passed;
  }

  bool get journeyFinished {
    final start = _parseKey(journeyStart);
    final end = DateTime(start.year, start.month, start.day + journeyDays);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(end);
  }

  Future<void> markNeuralForToday(EmotionStore emotions) async {
    final today = NeuralContainer.todayKey();
    if (neural.autoDays[today] == true) return;
    neural.autoDays[today] = true;

    NeuralFiberEmotion? felt;
    if (emotions.hasSelection) {
      final ids = emotions.selectedIds.toList();
      final dom = dominantEmotion(ids);
      if (dom != null) {
        felt = NeuralFiberEmotion(
          ids: ids,
          color: dom.color,
          freq: dom.freq,
        );
      }
    }

    neural.addAutoFiber(emotion: felt);
    await _persist();
    notifyListeners();
  }

  Future<void> saveNeural() async {
    await _persist();
    notifyListeners();
  }

  Future<GratitudeEntry> add({
    required String text,
    String icon = '🙏',
    List<GratitudeImage>? images,
    List<GratitudeAudio>? audios,
    List<GratitudeVideo>? videos,
    bool shared = false,
    double? amount,
    String source = 'manual',
    double? txId,
    EmotionStore? emotions,
  }) async {
    final now = DateTime.now();

    final emoIds = (emotions != null && emotions.hasSelection)
        ? emotions.selectedIds
            .where((id) => emotionById(id) != null)
            .toList()
        : <String>[];

    final e = GratitudeEntry(
      text: text,
      icon: icon,
      image: (images != null && images.isNotEmpty) ? images.first.src : null,
      images: images ?? [],
      audios: audios ?? [],
      videos: videos ?? [],
      amount: amount,
      date: _faDate(now),
      day: _faWeekday(now),
      time: _faTime(now),
      iso: now.toIso8601String(),
      source: source,
      shared: shared,
      txId: txId,
      emotionIds: emoIds,
    );
    entries.add(e);

    // ─── ثبت خودکار مسیر عصبی (neuralAutoAddFiber در وب) ───
    // هر ثبتِ شکرگذاری همیشه یک رشته‌ی «جدید» می‌سازه. اگه روی ادمک حسی
    // انتخاب شده باشه، رشته به رنگِ قوی‌ترین حس (بالاترین فرکانس) ساخته می‌شه و
    // بعدش ادمک ریست می‌شه تا برای دفعه‌ی بعد آماده باشه.
    NeuralFiberEmotion? felt;
    if (emoIds.isNotEmpty) {
      final dom = dominantEmotion(emoIds);
      if (dom != null) {
        felt = NeuralFiberEmotion(
          ids: List.of(emoIds),
          color: dom.color,
          freq: dom.freq,
        );
      }
    }
    neural.addAutoFiber(emotion: felt);
    if (felt != null) emotions?.clear();

    await _persist();
    notifyListeners();
    return e;
  }

  Future<void> update(
    String id, {
    String? text,
    List<GratitudeImage>? images,
    List<GratitudeAudio>? audios,
    List<GratitudeVideo>? videos,
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
    if (videos != null) e.videos = videos;
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

  // ───────── احساسات روز ─────────
  /// کیفیت حس امروز (بالاترین فرکانسِ حسِ ثبت‌شده) — برای بج مسیر عصبی.
  /// مثل وب فقط بعد از «ثبت حس» (بستن ادمک یا ویرایش حس روز) مقدار دارد.
  int? get emotionQualityToday {
    final ids = dayAfter[_todayKey()];
    if (ids == null || ids.isEmpty) return null;
    int max = 0;
    for (final id in ids) {
      final e = emotionById(id);
      if (e != null && e.freq > max) max = e.freq;
    }
    return max;
  }

  /// «ثبت حس» از ادمک (رویداد echw:commit وب) برای شکرگذاری.
  Future<FeelingApply> applyCommittedFeeling(List<String> ids) async {
    final valid = ids.where((id) => emotionById(id) != null).toList();
    final dom = dominantEmotion(valid);
    if (dom == null) return FeelingApply.skipped;
    final felt = NeuralFiberEmotion(ids: valid, color: dom.color, freq: dom.freq);
    final today = _todayKey();
    final confirmed = entries
        .any((e) => e.source != 'purchase' && isoToKey(e.iso) == today);
    final r = neural.applyFeelingToToday(felt, createIfConfirmed: confirmed);
    if (r == FeelingApply.skipped) return r;
    dayAfter[today] = valid;
    await _persist();
    notifyListeners();
    return r;
  }

  Set<String> emotionIdsForDay(String dayKey) {
    final norm = _normDayKey(dayKey);
    final after = dayAfter[norm];
    if (after != null && after.isNotEmpty) return after.toSet();
    final out = <String>{};
    for (final e in entries) {
      if (e.source == 'purchase') continue;
      if (isoToKey(e.iso) != norm) continue;
      out.addAll(e.emotionIds);
    }
    if (out.isEmpty) out.addAll(neural.emotionIdsForDay(norm));
    return out;
  }

  /// ⭐️ متد جدید: لیست رنگ‌های یکتای احساسات یک روز
  /// مرتب‌شده از پرفرکانس به کم‌فرکانس — برای رسم حلقه‌ی گرادیان روی تقویم
  List<Color> emotionColorsForDay(String dayKey) {
    final ids = emotionIdsForDay(dayKey);
    if (ids.isEmpty) return const [];

    final emos = ids.map(emotionById).whereType<Emotion>().toList()
      ..sort((a, b) => b.freq.compareTo(a.freq));

    final seen = <String>{};
    final out = <Color>[];
    for (final e in emos) {
      final hex = e.color.toLowerCase();
      if (seen.add(hex)) out.add(_hexToColor(hex));
    }
    return out;
  }

  static Color _hexToColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF2BBFAB);
    }
  }

  String? dominantEmotionColorForDay(String dayKey) {
    final ids = emotionIdsForDay(dayKey);
    if (ids.isEmpty) return null;
    return dominantEmotion(ids)?.color;
  }

  Future<void> updateDayEmotions(
    String dayKey,
    List<String> emotionIds,
  ) async {
    final norm = _normDayKey(dayKey);
    final valid =
        emotionIds.where((id) => emotionById(id) != null).toSet().toList();

    for (final e in entries) {
      if (e.source == 'purchase') continue;
      if (isoToKey(e.iso) != norm) continue;
      e.emotionIds = List.of(valid);
      e.editedAt = DateTime.now().millisecondsSinceEpoch;
    }

    NeuralFiberEmotion? felt;
    if (valid.isNotEmpty) {
      final dom = dominantEmotion(valid);
      if (dom != null) {
        felt = NeuralFiberEmotion(
          ids: valid,
          color: dom.color,
          freq: dom.freq,
        );
      }
    }
    neural.recolorFibersForDay(norm, felt);
    if (valid.isEmpty) {
      dayAfter.remove(norm);
    } else {
      dayAfter[norm] = valid;
    }

    await _persist();
    notifyListeners();
  }

  static String _normDayKey(String k) {
    final p = k.split('-').map((e) => int.tryParse(e) ?? 0).toList();
    if (p.length != 3) return k;
    return '${p[0]}-${p[1].toString().padLeft(2, '0')}-${p[2].toString().padLeft(2, '0')}';
  }

  // ───────── صفحه‌بندی ─────────
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

  /// شروع دوره‌ی بعدی (periodStartNext وب): دوره‌ی فعلی می‌ره توی لیست
  /// دوره‌های قبلی و دوره‌ی تازه از امروز با [days] روز شروع می‌شه.
  Future<void> startNewJourney({int? days}) async {
    pastPeriods.add({'days': journeyDays, 'startDate': journeyStart});
    if (days != null && days >= 1) journeyDays = days;
    journeyStart = _todayKey();
    await _persist();
    notifyListeners();
  }

  /// روزهایی که حداقل یک شکرگذاری (غیر از خرید) ثبت شده — gratitudeDoneDaySet وب
  Set<String> get doneDayKeys {
    final out = <String>{};
    for (final e in entries) {
      if (e.source == 'purchase') continue;
      var k = isoToKey(e.iso);
      if (k.isEmpty) k = _normDayKey(e.date);
      if (k.isNotEmpty) out.add(k);
    }
    return out;
  }

  /// رنگ حلقه‌ی روز در تقویم = قوی‌ترین حسِ آن روز (مثل وب)
  String? dayRingColor(String dayKey) => dominantEmotionColorForDay(dayKey);

  // ───────── helpers ─────────
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
    'جمعه', 'شنبه', 'یکشنبه',
  ];

  static String _faDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _faWeekday(DateTime d) => _faWeekdays[d.weekday - 1];

  static String _faTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
