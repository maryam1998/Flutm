import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emotion.dart';
import '../models/gratitude_entry.dart';
import '../models/neural_container.dart';
import 'emotion_store.dart';

class GratitudeStore extends ChangeNotifier {
  static const _kEntries = 'gratitude_entries';
  static const _kJourneyDays = 'gratitude_journey_days';
  static const _kJourneyStart = 'gratitude_journey_start';
  static const _kNeural = 'gratitude_neural';
  static const _kJourneyPast = 'gratitude_journey_past';
  NeuralContainer neural = NeuralContainer();

  final List<GratitudeEntry> entries = [];
  int journeyDays = 28;
  String journeyStart = '';

  /// دوره‌های تمام‌شده‌ی قبلی — مثل gratitudePeriod.past در وب
  /// هر مورد: {'days': int, 'startDate': 'YYYY-MM-DD'}
  final List<Map<String, dynamic>> journeyPast = [];
  bool loaded = false;

  /// سقف منطقی تعداد روز یک دوره (وب سقف ندارد؛ این فقط جلوی هنگ کردن UI را می‌گیرد)
  static const int maxPeriodDays = 3650;

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
      final pRaw = sp.getString(_kJourneyPast);
      journeyPast.clear();
      if (pRaw != null && pRaw.isNotEmpty) {
        try {
          final pl = jsonDecode(pRaw);
          if (pl is List) {
            for (final it in pl) {
              if (it is Map) {
                final d = (it['days'] as num?)?.toInt() ?? 0;
                final st = it['startDate']?.toString() ?? '';
                if (d > 0 && st.isNotEmpty) {
                  journeyPast.add({'days': d, 'startDate': st});
                }
              }
            }
          }
        } catch (_) {}
      }
      final nRaw = sp.getString(_kNeural);
      if (nRaw != null && nRaw.isNotEmpty) {
        try {
          neural = NeuralContainer.fromJson(
            Map<String, dynamic>.from(jsonDecode(nRaw)),
          );
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
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        _kEntries,
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      );
      await sp.setInt(_kJourneyDays, journeyDays);
      await sp.setString(_kJourneyStart, journeyStart);
      await sp.setString(_kJourneyPast, jsonEncode(journeyPast));
      await sp.setString(_kNeural, jsonEncode(neural.toJson()));
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

  List<GratitudeEntry> get homeSlice =>
      allReversed.take(homeLimit).toList();

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
      final ids = emotions.selectedIds;
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

    // منطق وب (neuralAutoAddFiber): هر ثبتِ شکرگذاری دقیقاً یک رشته‌ی تازه می‌سازد.
    // اگر همین الان حسی انتخاب شده باشد، رشته به رنگِ فرکانسِ قوی‌ترین حس
    // (dominant) چسبانده می‌شود و بعد انتخاب ریست می‌شود (ادمک برای دفعه‌ی بعد خالی).
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
    if (felt != null) emotions?.reset();

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

  // ───────── احساسات روز ─────────

  Set<String> emotionIdsForDay(String dayKey) {
    final norm = _normDayKey(dayKey);
    final out = <String>{};
    for (final e in entries) {
      if (e.source == 'purchase') continue;
      if (isoToKey(e.iso) != norm) continue;
      out.addAll(e.emotionIds);
    }
    if (out.isEmpty) {
      out.addAll(neural.emotionIdsForDay(norm));
    }
    return out;
  }

  String? dominantEmotionColorForDay(String dayKey) {
    final ids = emotionIdsForDay(dayKey);
    if (ids.isEmpty) return null;
    final dom = dominantEmotion(ids);
    return dom?.color;
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

  /// تعداد روزهای دوره‌ی جاری (setGratitudePeriodDays وب)
  Future<void> setJourneyDays(int days) async {
    if (days < 1) return;
    journeyDays = days > maxPeriodDays ? maxPeriodDays : days;
    await _persist();
    notifyListeners();
  }

  /// شروع دوره‌ی بعدی (periodStartNext وب):
  /// دوره‌ی جاری به past اضافه می‌شود و دوره‌ی تازه از «امروز» با [days] روز شروع می‌شود.
  Future<void> startNewJourney({int? days}) async {
    var n = days ?? journeyDays;
    if (n < 1) n = journeyDays;
    if (n > maxPeriodDays) n = maxPeriodDays;
    journeyPast.add({'days': journeyDays, 'startDate': journeyStart});
    journeyDays = n;
    journeyStart = _todayKey();
    await _persist();
    notifyListeners();
  }

  /// روزهایی که حداقل یک شکرگذاری (غیر خرید) دارند — gratitudeDoneDaySet وب
  Set<String> get doneDayKeys {
    final out = <String>{};
    for (final e in entries) {
      if (e.source == 'purchase') continue;
      final k = isoToKey(e.iso);
      if (k.isNotEmpty) out.add(k);
    }
    return out;
  }

  /// کیفیت حس امروز برای بج مسیر عصبی — getTodayEmotionQualityFor('gratitude') وب:
  /// بیشینه‌ی فرکانس حس‌های ثبت‌شده‌ی امروز؛ اگر حسی نبود null
  int? get todayEmotionQuality {
    final ids = emotionIdsForDay(_todayKey());
    if (ids.isEmpty) return null;
    var maxFreq = 0;
    for (final id in ids) {
      final e = emotionById(id);
      if (e != null && e.freq > maxFreq) maxFreq = e.freq;
    }
    return maxFreq;
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
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _faWeekday(DateTime d) => _faWeekdays[d.weekday - 1];

  static String _faTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
