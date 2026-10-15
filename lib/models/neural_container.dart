import 'dart:math';

/// نتیجه‌ی اعمال «حس ثبت‌شده» روی یک مسیر عصبی (echwApplyFeelingToContainer وب)
enum FeelingApply { skipped, doneNoChange, applied }

/// احساسِ همراهِ یک رشته‌ی عصبی
class NeuralFiberEmotion {
  final List<String> ids;
  final String color;
  final int freq;

  const NeuralFiberEmotion({
    required this.ids,
    required this.color,
    required this.freq,
  });

  Map<String, dynamic> toJson() => {
        'ids': ids,
        'color': color,
        'freq': freq,
      };

  factory NeuralFiberEmotion.fromJson(Map<String, dynamic> j) =>
      NeuralFiberEmotion(
        ids: (j['ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
        color: j['color'] as String? ?? '#2bbfab',
        freq: (j['freq'] as num?)?.toInt() ?? 0,
      );
}

class PendingManual {
  final int ts;
  final String dayKey;
  const PendingManual({required this.ts, required this.dayKey});

  Map<String, dynamic> toJson() => {'ts': ts, 'dayKey': dayKey};

  factory PendingManual.fromJson(Map<String, dynamic> j) => PendingManual(
        ts: (j['ts'] as num).toInt(),
        dayKey: j['dayKey'] as String,
      );
}

/// کانتینر مسیر عصبی — یکی برای هر تمرین
class NeuralContainer {
  Map<String, bool> logs = {};
  Map<String, PendingManual> pendingManual = {};
  String? lastSyncKey;
  bool habitFormed = false;
  Map<String, NeuralFiberEmotion> fiberEmotions = {};
  Map<String, bool> autoDays = {};

  NeuralContainer();

  // ---------------- fiber count ----------------

  int get fiberCount {
    int n = 0;
    for (final v in logs.values) {
      if (v) {
        n++;
      } else {
        n--;
      }
    }
    return n < 0 ? 0 : n;
  }

  // ---------------- mutations ----------------

  String addFiber({
    bool calendarLinked = false,
    NeuralFiberEmotion? emotion,
  }) {
    final key = _newFiberKey();
    logs[key] = true;

    if (calendarLinked) {
      pendingManual[key] = PendingManual(
        ts: DateTime.now().millisecondsSinceEpoch,
        dayKey: todayKey(),
      );
    }

    if (emotion != null) {
      fiberEmotions[key] = emotion;
    }

    return key;
  }

  String removeFiber() {
    final key = _newFiberKey();
    logs[key] = false;
    return key;
  }

  String addAutoFiber({NeuralFiberEmotion? emotion}) =>
      addFiber(calendarLinked: false, emotion: emotion);

  /// وقتی کاربر ادمک رو با حس انتخاب‌شده می‌بنده («ثبت حس»):
  ///  • اگه امروز رشته‌ای هست، فقط رشته‌های امروزِ بدون‌حس رنگ حس می‌گیرن
  ///  • اگه رشته‌ای نیست و تمرین امروز واقعاً انجام شده ([createIfConfirmed])،
  ///    یک رشته‌ی جدید با همون حس ساخته می‌شه
  ///  • وگرنه تمرین انجام نشده و [FeelingApply.skipped] برمی‌گرده
  FeelingApply applyFeelingToToday(
    NeuralFiberEmotion felt, {
    bool createIfConfirmed = false,
  }) {
    final today = todayKey();
    final keys = logs.keys
        .where((k) => logs[k] == true && (k == today || _isFiberFromToday(k)))
        .toList();
    if (keys.isEmpty) {
      if (!createIfConfirmed) return FeelingApply.skipped;
      final nk = _newFiberKey();
      logs[nk] = true;
      fiberEmotions[nk] = felt;
      return FeelingApply.applied;
    }
    var applied = false;
    for (final k in keys) {
      if (!fiberEmotions.containsKey(k)) {
        fiberEmotions[k] = felt;
        applied = true;
      }
    }
    return applied ? FeelingApply.applied : FeelingApply.doneNoChange;
  }

  void markDay(String key, bool done) {
    if (logs[key] == done) {
      logs.remove(key);
    } else {
      logs[key] = done;
    }
  }

  // ---------------- fiber emotions ----------------

  /// آخرین رشته‌ی بدون‌احساس را رنگ می‌کند.
  /// اگر همه‌ی رشته‌ها رنگی بودند، `false` برمی‌گرداند
  /// (یعنی caller باید یک رشته‌ی جدید بسازد).
  bool colorLatestUncolored(NeuralFiberEmotion emotion) {
    final keys = logs.keys.toList();
    for (int i = keys.length - 1; i >= 0; i--) {
      final k = keys[i];
      if (logs[k] != true) continue;
      if (fiberEmotions.containsKey(k)) continue;
      fiberEmotions[k] = emotion;
      return true;
    }
    return false;
  }

  void updateFiberEmotion(String fiberKey, NeuralFiberEmotion? emotion) {
    if (logs[fiberKey] != true) return;
    if (emotion == null) {
      fiberEmotions.remove(fiberKey);
    } else {
      fiberEmotions[fiberKey] = emotion;
    }
  }

  void recolorTodayFibers(NeuralFiberEmotion? emotion) {
    final today = todayKey();
    for (final key in logs.keys.toList()) {
      if (logs[key] != true) continue;
      final isToday = key == today || _isFiberFromToday(key);
      if (!isToday) continue;
      updateFiberEmotion(key, emotion);
    }
  }

  void clearTodayFiberEmotions() {
    recolorTodayFibers(null);
  }

  // ──────────────── احساسات یک روز مشخص ────────────────

  Set<String> emotionIdsForDay(String dayKey) {
    final out = <String>{};
    final norm = _normDay(dayKey);
    for (final entry in fiberEmotions.entries) {
      if (logs[entry.key] != true) continue;
      if (!_isFiberOfDay(entry.key, norm)) continue;
      out.addAll(entry.value.ids);
    }
    return out;
  }

  void recolorFibersForDay(String dayKey, NeuralFiberEmotion? emotion) {
    final norm = _normDay(dayKey);
    for (final key in logs.keys.toList()) {
      if (logs[key] != true) continue;
      if (!_isFiberOfDay(key, norm)) continue;
      updateFiberEmotion(key, emotion);
    }
  }

  // ---------------- sync ----------------

  bool autoSync({bool noMissPenalty = false}) {
    if (noMissPenalty) return false;
    final yesterday = dayKeyOffset(-1);
    var changed = false;

    // «انجام‌نشده» فقط بعد از اولین رشته‌ی واقعی معنی داره؛ روزهای قبل از
    // شروع تمرین نباید رشته‌های ساخته‌شده رو کم کنن (وگرنه ۳ ثبتِ امروز با ۳ روز
    // «نیومدنِ» قبلی صفر می‌شد).
    final first = _firstActiveDay();
    final dayRe = RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$');
    for (final k in logs.keys.toList()) {
      if (logs[k] != false || !dayRe.hasMatch(k)) continue;
      final d = _dayOf(k);
      if (first == null || d.isBefore(first)) {
        logs.remove(k);
        changed = true;
      }
    }

    if (lastSyncKey == null) {
      lastSyncKey = yesterday;
      return changed;
    }
    if (first == null) {
      if (lastSyncKey != yesterday) {
        lastSyncKey = yesterday;
        changed = true;
      }
      return changed;
    }

    // جریمه از روزِ بعد از اولین فعالیت شروع می‌شه
    final dayBefore = DateTime(first.year, first.month, first.day - 1);
    final lastSync = _dayOf(lastSyncKey!);
    if (lastSync.isBefore(dayBefore)) {
      lastSyncKey = '${dayBefore.year}-${dayBefore.month}-${dayBefore.day}';
      changed = true;
    }

    if (lastSyncKey == yesterday) return changed;

    String cursor = lastSyncKey!;
    int guard = 0;
    while (cursor != yesterday && guard < 3650) {
      cursor = ndKeyNext(cursor);
      guard++;
      if (!logs.containsKey(cursor)) {
        logs[cursor] = false;
        changed = true;
      }
    }
    lastSyncKey = yesterday;
    return changed;
  }

  /// اولین روزی که یک رشته‌ی «انجام‌شده» داشته (تاریخ بدون ساعت)
  DateTime? _firstActiveDay() {
    DateTime? best;
    final dayRe = RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$');
    for (final e in logs.entries) {
      if (e.value != true) continue;
      DateTime? d;
      if (dayRe.hasMatch(e.key)) {
        d = _dayOf(e.key);
      } else {
        final m = RegExp(r'^f(\d{10,})-').firstMatch(e.key);
        if (m != null) {
          final ts = int.tryParse(m.group(1) ?? '');
          if (ts != null) {
            final t = DateTime.fromMillisecondsSinceEpoch(ts);
            d = DateTime(t.year, t.month, t.day);
          }
        }
      }
      if (d != null && (best == null || d.isBefore(best))) best = d;
    }
    return best;
  }

  static DateTime _dayOf(String key) {
    final p = key.split('-').map((e) => int.tryParse(e) ?? 1).toList();
    if (p.length != 3) return DateTime.now();
    return DateTime(p[0], p[1], p[2]);
  }

  bool cleanupPending({
    required bool calendarLinked,
    required bool Function(String dayKey) isConfirmed,
  }) {
    if (!calendarLinked) return false;
    bool changed = false;
    const oneHour = 60 * 60 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;

    pendingManual.removeWhere((key, entry) {
      if (now - entry.ts < oneHour) return false;
      final confirmed = isConfirmed(entry.dayKey);
      if (confirmed) return true;
      if (logs[key] == true) logs.remove(key);
      fiberEmotions.remove(key);
      changed = true;
      return true;
    });

    return changed;
  }

  // ---------------- json ----------------

  factory NeuralContainer.fromJson(Map<String, dynamic>? j) {
    final c = NeuralContainer();
    if (j == null) return c;

    final logsRaw = j['logs'];
    if (logsRaw is Map) {
      logsRaw.forEach((k, v) {
        if (v is bool) c.logs[k.toString()] = v;
      });
    }

    final pmRaw = j['pendingManual'];
    if (pmRaw is Map) {
      pmRaw.forEach((k, v) {
        if (v is Map) {
          c.pendingManual[k.toString()] =
              PendingManual.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }

    c.lastSyncKey = j['lastSyncKey'] as String?;
    c.habitFormed = j['habitFormed'] == true;

    final feRaw = j['fiberEmotions'];
    if (feRaw is Map) {
      feRaw.forEach((k, v) {
        if (v is Map) {
          c.fiberEmotions[k.toString()] =
              NeuralFiberEmotion.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }

    final adRaw = j['autoDays'];
    if (adRaw is Map) {
      adRaw.forEach((k, v) {
        if (v is bool) c.autoDays[k.toString()] = v;
      });
    }

    return c;
  }

  Map<String, dynamic> toJson() => {
        'logs': logs,
        'pendingManual':
            pendingManual.map((k, v) => MapEntry(k, v.toJson())),
        'lastSyncKey': lastSyncKey,
        'habitFormed': habitFormed,
        'fiberEmotions':
            fiberEmotions.map((k, v) => MapEntry(k, v.toJson())),
        'autoDays': autoDays,
      };

  // ---------------- helpers ----------------

  static String _newFiberKey() {
    final r = Random();
    return 'f${DateTime.now().millisecondsSinceEpoch}-${r.nextInt(1 << 30).toRadixString(36).padLeft(6, '0').substring(0, 6)}';
  }

  static String todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  static String dayKeyOffset(int off) {
    final d = DateTime.now().add(Duration(days: off));
    return '${d.year}-${d.month}-${d.day}';
  }

  static String ndKeyNext(String key) {
    final parts = key.split('-').map((e) => int.tryParse(e) ?? 0).toList();
    if (parts.length != 3) return key;
    final d = DateTime(parts[0], parts[1], parts[2]);
    return '${d.year}-${d.month}-${d.day}';
  }

  static bool _isFiberFromToday(String key) {
    final m = RegExp(r'^f(\d{10,})-').firstMatch(key);
    if (m == null) return false;
    final ts = int.tryParse(m.group(1) ?? '');
    if (ts == null) return false;
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  static String _normDay(String k) {
    final p = k.split('-').map((e) => int.tryParse(e) ?? 0).toList();
    if (p.length != 3) return k;
    return '${p[0]}-${_pad2(p[1])}-${_pad2(p[2])}';
  }

  static bool _isFiberOfDay(String key, String normDayKey) {
    if (_normDay(key) == normDayKey) return true;
    final m = RegExp(r'^f(\d{10,})-').firstMatch(key);
    if (m == null) return false;
    final ts = int.tryParse(m.group(1) ?? '');
    if (ts == null) return false;
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final n = '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';
    return n == normDayKey;
  }
}
