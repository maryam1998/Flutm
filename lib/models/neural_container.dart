import 'dart:math';

/// احساسِ همراهِ یک رشته‌ی عصبی (وقتی کاربر با ادمکِ شناور حس ثبت کرده باشه)
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

/// ثبتِ دستیِ «امروز انجام دادم» برای تقویم‌های متصل (هنوز تأیید نشده)
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

/// کانتینر مسیر عصبی — یکی برای هر تمرین (شکرگذاری، باور، دیسپنزا، ...)
class NeuralContainer {
  /// کلید → true (انجام دادم) / false (انجام ندادم)
  /// کلید یا روز است (`2026-10-12`) یا رشته‌ی تصادفی (`f1712...-abc123`)
  Map<String, bool> logs = {};

  /// ثبت‌های دستیِ در انتظارِ تأییدِ تقویم
  Map<String, PendingManual> pendingManual = {};

  /// آخرین روزی که autoSync تا اون‌جا رو حساب کرده
  String? lastSyncKey;

  /// آیا کاربر خودش تأیید کرده که این عادت جاافتاده؟
  bool habitFormed = false;

  /// رنگ/فرکانسِ همراه هر رشته (اختیاری)
  Map<String, NeuralFiberEmotion> fiberEmotions = {};

  /// جلوگیری از ثبت تکراری در یک روز (برای ثبت خودکار)
  Map<String, bool> autoDays = {};

  NeuralContainer();

  // ---------------- fiber count ----------------

  /// تعداد رشته‌های ساخته‌شده = (تعداد true) − (تعداد false)، هیچ سقفی نداره، فقط منفی نمی‌شه
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

  /// «امروز انجام دادم» — هر بار کلیک یک رشته‌ی جدید می‌سازه
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

  /// «یک روز گذشت، انجام ندادم» — هر کلیک یک رشته کم می‌کنه
  String removeFiber() {
    final key = _newFiberKey();
    logs[key] = false;
    return key;
  }

  /// ثبت خودکار (وقتی خودِ اقدام مربوطه در یک روز انجام می‌شه)
  String addAutoFiber({NeuralFiberEmotion? emotion}) =>
      addFiber(calendarLinked: false, emotion: emotion);

  /// علامت‌زدن یک روز خاص (برای تقویم‌های متصل)
  void markDay(String key, bool done) {
    if (logs[key] == done) {
      logs.remove(key);
    } else {
      logs[key] = done;
    }
  }

  // ---------------- sync ----------------

  /// روزهایی که گذشته ولی نه دستی ثبت شدن نه خودکار → «انجام نشد»
  bool autoSync({bool noMissPenalty = false}) {
    if (noMissPenalty) return false;
    final yesterday = dayKeyOffset(-1);

    if (lastSyncKey == null) {
      lastSyncKey = yesterday;
      return false;
    }
    if (lastSyncKey == yesterday) return false;

    String cursor = lastSyncKey!;
    bool changed = false;
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

  /// پاک‌سازیِ ثبت‌های دستیِ در انتظارِ تأیید که بعد از ۱ ساعت هنوز تأیید نشدن
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
}
