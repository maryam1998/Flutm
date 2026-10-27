import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/app_prefs.dart';
import '../services/persist_engine.dart';

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
  static const _kSeeded = 'gratitude_neural_seeded_v1';

  NeuralContainer neural = NeuralContainer();

  /// حسِ «ثبت‌شده» برای هر روز (practiceEmotions[day].gratitude.after در وب)
  final Map<String, List<String>> dayAfter = {};

  /// دوره‌های تمام‌شده‌ی قبلی: [{days: int, startDate: 'yyyy-MM-dd'}]
  final List<Map<String, dynamic>> pastPeriods = [];

  final List<GratitudeEntry> entries = [];
  int journeyDays = 28;
  String journeyStart = '';
  bool loaded = false;

  /// آخرین ذخیره‌سازی کامل موفق بود؟ (عکس/صدای زیاد می‌تونه سهمیه‌ی حافظه رو پر کنه)
  bool lastPersistOk = true;

  int homeLimit = 40;
  int histLimit = 40;

  Future<void> load() async {
    try {
      final sp = await AppPrefs.getInstance();
      final raw = sp.getString(_kEntries);
      if (raw != null && raw.isNotEmpty) {
        final list = await BlobOffload.rehydrate(jsonDecode(raw));
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
      // شکرگذاری جریمه ندارد: روزِ بدون ثبت چیزی کم نمی‌کند و
      // «انجام نشد»های قبلی هم پاک می‌شوند تا رشته‌ها همان‌طور که هستند بمانند.
      neural.logs.removeWhere((_, v) => v == false);
      neural.lastSyncKey = NeuralContainer.dayKeyOffset(-1);
      await _persist();
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  /// هر کلید جدا و در try/catch خودش ذخیره می‌شه تا اگه «entries» (که عکس/صدای
  /// base64 داره) از سهمیه‌ی حافظه بزرگ‌تر شد، مسیر عصبی و بقیه‌ی state گم نشن.
  /// اول چیزهای کوچک (عصبی، دوره‌ها، حس روز)، آخر لیست ثبت‌ها.
  /// ذخیره‌ی تک‌صف (ثبت‌های پشت‌سرهم ادغام می‌شن؛ نوشتنِ هم‌زمان ممکن نیست)
  late final CoalescedTask _persistSaver = CoalescedTask(_persistNow);

  Future<void> _persist() => _persistSaver.request();

  Future<void> _persistNow() async {
    _syncEntryFibers();
    var ok = true;
    AppPrefs sp;
    try {
      sp = await AppPrefs.getInstance();
    } catch (e) {
      debugPrint('GratitudeStore: prefs unavailable: $e');
      lastPersistOk = false;
      return;
    }
    Future<void> put(String key, String value) async {
      try {
        final r = await sp.setString(key, value);
        if (!r) ok = false;
      } catch (e) {
        ok = false;
        debugPrint('GratitudeStore: persist $key failed: $e');
      }
    }

    try {
      await sp.setInt(_kJourneyDays, journeyDays);
      await sp.setString(_kJourneyStart, journeyStart);
    } catch (e) {
      ok = false;
    }
    await put(_kNeural, jsonEncode(neural.toJson()));
    await put(_kDayAfter, jsonEncode(dayAfter));
    await put(_kJourneyPast, jsonEncode(pastPeriods));
    // عکس/صدا/GIFِ ثبت‌ها بیرون JSON ذخیره می‌شن (فقط یک‌بار برای هر فایل)
    await put(
        _kEntries,
        jsonEncode(await BlobOffload.offload(
            entries.map((e) => e.toJson()).toList())));
    lastPersistOk = ok;
  }

  /// یک‌بار: ثبت‌هایی که قبل از سیم‌کشی مسیر عصبی ساخته شدن، رشته ندارن.
  /// برای هر «ثبت» که رشته‌ای براش نیست (قدیمی‌ترین‌ها اول) یک رشته‌ی انجام‌شده
  /// با زمان خودِ ثبت و رنگِ حسِ همون ثبت ساخته می‌شه.
  Future<void> _seedFibersFromEntries(AppPrefs sp) async {
    try {
      if (sp.getBool(_kSeeded) == true) return;
      final real = entries.where((e) => e.source != 'purchase').toList()
        ..sort((a, b) => a.iso.compareTo(b.iso));
      var have = 0;
      for (final v in neural.logs.values) {
        if (v == true) have++;
      }
      final missing = real.length - have;
      if (missing > 0) {
        for (var i = 0; i < missing && i < real.length; i++) {
          final e = real[i];
          DateTime t;
          try {
            t = DateTime.parse(e.iso).toLocal();
          } catch (_) {
            continue;
          }
          final key =
              'f${t.millisecondsSinceEpoch}-s${i.toString().padLeft(5, '0')}';
          if (neural.logs.containsKey(key)) continue;
          neural.logs[key] = true;
          final valid =
              e.emotionIds.where((id) => emotionById(id) != null).toList();
          final dom = valid.isEmpty ? null : dominantEmotion(valid);
          if (dom != null) {
            neural.fiberEmotions[key] = NeuralFiberEmotion(
                ids: valid, color: mixedEmotionHex(valid) ?? dom.color, freq: dom.freq);
          }
        }
      }
      await sp.setBool(_kSeeded, true);
    } catch (e) {
      debugPrint('GratitudeStore: seed failed: $e');
    }
  }


  /// یک‌بار: رشته‌های اضافه (مثلاً ۱۵۶ رشته برای ۷ ثبت) پاک می‌شن.
  /// هر ثبتِ شکرگذاری دقیقاً یک رشته داره (با رنگ حسِ خودش)؛ رشته‌ی بی‌ثبت حذف می‌شه.
  Future<void> _reconcileFibersWithEntries(AppPrefs sp) async {
    const flag = 'gratitude_neural_reconcile_v2';
    try {
      if (sp.getBool(flag) == true) return;
      final real = entries.where((e) => e.source != 'purchase').toList()
        ..sort((a, b) => a.iso.compareTo(b.iso));
      final fiberRe = RegExp(r'^f(\d{10,})-');
      final oldKeys = neural.logs.entries
          .where((e) => e.value == true)
          .map((e) => e.key)
          .toList();
      final used = <String>{};
      final newLogs = <String, bool>{};
      final newEmo = <String, NeuralFiberEmotion>{};
      var i = 0;
      for (final e in real) {
        DateTime t;
        try {
          t = DateTime.parse(e.iso).toLocal();
        } catch (_) {
          continue;
        }
        final ms = t.millisecondsSinceEpoch;
        String? match;
        for (final k in oldKeys) {
          if (used.contains(k)) continue;
          final m = fiberRe.firstMatch(k);
          final ts = m == null ? null : int.tryParse(m.group(1) ?? '');
          if (ts != null && (ts - ms).abs() <= 10000) {
            match = k;
            break;
          }
        }
        final key = match ??
            'f$ms-r${(i++).toString().padLeft(5, '0')}';
        if (match != null) used.add(match);
        newLogs[key] = true;
        final old = neural.fiberEmotions[key];
        if (old != null) {
          newEmo[key] = old;
        } else {
          final valid =
              e.emotionIds.where((id) => emotionById(id) != null).toList();
          final dom = valid.isEmpty ? null : dominantEmotion(valid);
          if (dom != null) {
            newEmo[key] = NeuralFiberEmotion(
                ids: valid, color: mixedEmotionHex(valid) ?? dom.color, freq: dom.freq);
          }
        }
      }
      neural.logs = newLogs;
      neural.fiberEmotions = newEmo;
      neural.pendingManual.clear();
      await sp.setBool(flag, true);
    } catch (e) {
      debugPrint('GratitudeStore: reconcile failed: $e');
    }
  }


  /// کلیدِ ثابتِ رشته‌ی هر ثبت
  static String _fiberKeyFor(GratitudeEntry e, int ms) => 'f$ms-e${e.id}';

  /// همیشه (idempotent): هر ثبتِ شکرگذاریِ واقعی ⇄ دقیقاً یک رشته.
  ///  • رشته‌ی بی‌ثبت (تکراری، خرید، داده‌ی قدیمیِ خراب) حذف می‌شه
  ///  • ثبتِ بدون رشته، رشته می‌گیره
  ///  • رنگ رشته = قوی‌ترین حسِ همون ثبت (بدون حس = فیروزه‌ای)
  ///  • رشته‌ی دستیِ بی‌ثبت (کلید -man) هم حذف می‌شه: بدون ثبت، رشته‌ای نیست
  void _syncEntryFibers() {
    try {
      final real = entries.where((e) => e.source != 'purchase').toList();
      final want = <String, GratitudeEntry>{};
      for (final e in real) {
        DateTime t;
        try {
          t = DateTime.parse(e.iso).toLocal();
        } catch (_) {
          continue;
        }
        want[_fiberKeyFor(e, t.millisecondsSinceEpoch)] = e;
      }

      // حذف رشته‌های بی‌ثبت
      for (final k in neural.logs.keys.toList()) {
        if (neural.logs[k] != true) continue;
        if (want.containsKey(k)) continue;
        neural.logs.remove(k);
        neural.fiberEmotions.remove(k);
        neural.pendingManual.remove(k);
      }
      for (final k in neural.fiberEmotions.keys.toList()) {
        if (neural.logs[k] != true) neural.fiberEmotions.remove(k);
      }

      // ساخت/به‌روزرسانی رشته‌ی هر ثبت
      want.forEach((k, e) {
        neural.logs[k] = true;
        final valid =
            e.emotionIds.where((id) => emotionById(id) != null).toList();
        final dom = valid.isEmpty ? null : dominantEmotion(valid);
        if (dom != null) {
          neural.fiberEmotions[k] = NeuralFiberEmotion(
              ids: valid, color: mixedEmotionHex(valid) ?? dom.color, freq: dom.freq);
        } else {
          neural.fiberEmotions.remove(k);
        }
      });
    } catch (e) {
      debugPrint('GratitudeStore: sync fibers failed: $e');
    }
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
          color: mixedEmotionHex(ids) ?? dom.color,
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

    // رشته‌ی عصبی از روی خودِ ثبت ساخته می‌شه (_syncEntryFibers در _persist):
    // هر ثبتِ شکرگذاری دقیقاً یک رشته؛ خرید (purchase) رشته نمی‌سازه.
    // اگه روی ادمک حسی انتخاب شده بود، همراه ثبت ذخیره شده و ادمک ریست می‌شه.
    if (emoIds.isNotEmpty) emotions?.clear();

    notifyListeners(); // اول نشون بده؛ ذخیره‌ی سنگین بعدش
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
    notifyListeners();
    await _persist();
    notifyListeners();
  }

  /// بعد از تغییر مستقیم عکس‌ها (مثلاً حذف از آلبوم) ذخیره و اعلام کن
  Future<void> commitMedia() async {
    notifyListeners();
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    entries.removeWhere((e) => e.id == id);
    notifyListeners();
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
    final felt = NeuralFiberEmotion(ids: valid, color: mixedEmotionHex(valid) ?? dom.color, freq: dom.freq);
    final today = _todayKey();
    final confirmed = entries
        .any((e) => e.source != 'purchase' && isoToKey(e.iso) == today);
    final r = neural.applyFeelingToToday(felt, createIfConfirmed: confirmed);
    if (r == FeelingApply.skipped) return r;
    dayAfter[today] = valid;
    // حس‌ها روی ثبت‌های امروز که هنوز حسی ندارن هم نوشته می‌شه تا تو لیست دیده بشن
    for (final e in entries) {
      if (e.source == 'purchase') continue;
      if (isoToKey(e.iso) != today) continue;
      if (e.emotionIds.isEmpty) e.emotionIds = List.of(valid);
    }
    await _persist();
    notifyListeners();
    return r;
  }

  /// ویرایشِ حسِ یک ثبتِ مشخص (از لیست شکرگذاری): رشته‌ی عصبیِ همان ثبت و
  /// حلقه‌ی روزش در تقویم هم به‌روز می‌شن.
  Future<bool> setEntryEmotions(String id, List<String> emotionIds,
      {bool allowEmpty = false}) async {
    final e = byId(id);
    if (e == null) return false;
    final valid =
        emotionIds.where((x) => emotionById(x) != null).toSet().toList();
    if (valid.isEmpty && !allowEmpty) return false;
    e.emotionIds = valid;
    // خریدِ بازی فراوانی: فقط حسِ همین ثبت ذخیره می‌شه؛ تقویم و رشته‌های
    // شکرگذاری دست نمی‌خورن.
    if (e.source == 'purchase') {
      notifyListeners();
      await _persist();
      notifyListeners();
      return true;
    }
    e.editedAt = DateTime.now().millisecondsSinceEpoch;

    // حسِ روز = ترکیبِ حسِ همه‌ی ثبت‌های همان روز (تقویم از این می‌خونه)
    final day = isoToKey(e.iso);
    if (day.isNotEmpty) {
      final union = <String>{};
      for (final x in entries) {
        if (x.source == 'purchase' || isoToKey(x.iso) != day) continue;
        union.addAll(x.emotionIds);
      }
      if (union.isEmpty) {
        dayAfter.remove(day);
      } else {
        dayAfter[day] = union.toList();
      }
    }
    notifyListeners();
    await _persist(); // رشته‌ها در _syncEntryFibers از روی ثبت‌ها ساخته می‌شن
    notifyListeners();
    return true;
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
    return mixedEmotionHex(ids) ?? dominantEmotion(ids)?.color;
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
          color: mixedEmotionHex(valid) ?? dom.color,
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
