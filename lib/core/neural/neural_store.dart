import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';
import 'neural_dates.dart';

// ═══════════════════════════════════════════════════════════════════
// 🧬 مسیرهای عصبی (Neural Paths) — معادلِ NeuralPath.jsx در Hope
//
// ایده: هر بار که کاربر یک لغت/جمله را (متنِ اصلی یا هر ترجمه‌اش) با پلیر
// گوش می‌دهد — یا دستی «امروز انجام دادم» می‌زند — یک «تکرار» ثبت می‌شود:
//   • در تقویمِ همان روز: «کدام لغت، به کدام زبان، چند بار»
//   • یک «رشته‌ی عصبی» به مسیرِ همان زبان اضافه می‌شود
//
// هر مورد با دو چیز شناخته می‌شود:
//   base = متنِ نرمال‌شده‌ی مورد (برای لغت‌ها/جمله‌های برنامه همیشه متنِ
//          انگلیسیِ آیتم) → همه‌ی زبان‌های یک آیتم یک تقویمِ مشترک دارند
//   lang = زبانِ همین ردیف (en / fa / fr / …) → هر زبان مسیر و رشته‌های
//          جدای خودش را دارد
// ═══════════════════════════════════════════════════════════════════

const String kNeuralStoreKey = 'zflut-neural-path-v1';

/// سقفِ نمایشی برای رنگِ نورونِ «تثبیت»
const int kNeuralFiberCap = 10;

const int kPeriodDefaultDays = 28;
const int kPeriodMaxDays = 365;
const int kPeriodBlockDays = 30;

/// متن‌های خیلی بلند (پاراگراف) مسیر عصبی نمی‌سازند
const int kNeuralMaxBaseLen = 240;

/// نرمال‌سازیِ متن برای ساختنِ کلیدِ مورد: حروف کوچک، بدون علامتِ نگارشیِ
/// کناره‌ها، فاصله‌های اضافه یکی.
String neuralBase(String s) {
  var t = s.trim().toLowerCase();
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  t = t.replaceAll(
      RegExp(r'^[\s.!?؟،,;:…"“”«»()\[\]\-–—]+|[\s.!?؟،,;:…"“”«»()\[\]\-–—]+$'),
      '');
  return t;
}

// ───────────────────────── مدل‌ها ─────────────────────────

class PastPeriod {
  final int days;
  final String startDate;
  const PastPeriod(this.days, this.startDate);

  Map<String, dynamic> toJson() => {'days': days, 'start': startDate};
  static PastPeriod? fromJson(dynamic j) {
    if (j is! Map) return null;
    final d = (j['days'] as num?)?.toInt() ?? 0;
    final s = j['start'];
    if (d < 1 || s is! String) return null;
    return PastPeriod(d, s);
  }
}

class NeuralPeriod {
  final int days;
  final String startDate;
  final List<PastPeriod> past;
  const NeuralPeriod({
    required this.days,
    required this.startDate,
    this.past = const [],
  });

  NeuralPeriod copyWith({int? days, String? startDate, List<PastPeriod>? past}) =>
      NeuralPeriod(
        days: days ?? this.days,
        startDate: startDate ?? this.startDate,
        past: past ?? this.past,
      );

  Map<String, dynamic> toJson() => {
        'days': days,
        'start': startDate,
        'past': past.map((e) => e.toJson()).toList(),
      };

  static NeuralPeriod? fromJson(dynamic j) {
    if (j is! Map) return null;
    final d = (j['days'] as num?)?.toInt() ?? kPeriodDefaultDays;
    final s = j['start'];
    if (s is! String) return null;
    final past = <PastPeriod>[];
    final raw = j['past'];
    if (raw is List) {
      for (final e in raw) {
        final p = PastPeriod.fromJson(e);
        if (p != null) past.add(p);
      }
    }
    return NeuralPeriod(
        days: d.clamp(1, kPeriodMaxDays).toInt(), startDate: s, past: past);
  }
}

/// همه‌ی داده‌ی یک مورد (لغت/جمله) — مشترک بینِ همه‌ی زبان‌هایش.
class NeuralRecord {
  /// dayKey → (lang → تعدادِ تکرار)
  final Map<String, Map<String, int>> days;

  /// تعدادِ رشته‌های اضافه/کم‌شده به‌ازای هر زبان
  final Map<String, int> adds;
  final Map<String, int> removes;

  /// آخرین تکرار (میلی‌ثانیه) به‌ازای هر زبان
  final Map<String, int> last;

  /// زبان‌هایی که کاربر «تثبیت‌شده» قفلشان کرده
  final Set<String> habit;

  NeuralPeriod? period;

  NeuralRecord({
    Map<String, Map<String, int>>? days,
    Map<String, int>? adds,
    Map<String, int>? removes,
    Map<String, int>? last,
    Set<String>? habit,
    this.period,
  })  : days = days ?? {},
        adds = adds ?? {},
        removes = removes ?? {},
        last = last ?? {},
        habit = habit ?? {};

  int fibers(String lang) =>
      math.max(0, (adds[lang] ?? 0) - (removes[lang] ?? 0));

  int total(String lang) {
    var n = 0;
    for (final m in days.values) {
      n += m[lang] ?? 0;
    }
    return n;
  }

  int totalAll() {
    var n = 0;
    for (final m in days.values) {
      for (final v in m.values) {
        n += v;
      }
    }
    return n;
  }

  int dayTotal(String dayKey) {
    final m = days[dayKey];
    if (m == null) return 0;
    var n = 0;
    for (final v in m.values) {
      n += v;
    }
    return n;
  }

  bool isHabit(String lang) => habit.contains(lang);

  Map<String, dynamic> toJson() => {
        'days': days,
        'adds': adds,
        'removes': removes,
        'last': last,
        'habit': habit.toList(),
        if (period != null) 'period': period!.toJson(),
      };

  static Map<String, int> _intMap(dynamic j) {
    final out = <String, int>{};
    if (j is Map) {
      j.forEach((k, v) {
        if (v is num) out['$k'] = v.toInt();
      });
    }
    return out;
  }

  factory NeuralRecord.fromJson(Map<String, dynamic> j) {
    final days = <String, Map<String, int>>{};
    final rawDays = j['days'];
    if (rawDays is Map) {
      rawDays.forEach((k, v) {
        final m = _intMap(v);
        if (m.isNotEmpty) days['$k'] = m;
      });
    }
    return NeuralRecord(
      days: days,
      adds: _intMap(j['adds']),
      removes: _intMap(j['removes']),
      last: _intMap(j['last']),
      habit: {
        if (j['habit'] is List)
          for (final e in j['habit'] as List) '$e',
      },
      period: NeuralPeriod.fromJson(j['period']),
    );
  }
}

// ───────────────────────── state + notifier ─────────────────────────

/// هر تغییر یک نمونه‌ی تازه می‌سازد؛ ویجت‌ها با
/// `ref.watch(neuralPathProvider.select((s) => s.versionOf(base)))`
/// فقط وقتی بازسازی می‌شوند که «همان مورد» عوض شده باشد.
class NeuralState {
  final Map<String, int> _ver;
  final int tick;
  const NeuralState._(this._ver, this.tick);
  const NeuralState.empty()
      : _ver = const {},
        tick = 0;

  int versionOf(String base) => _ver[base] ?? 0;
}

class NeuralPathNotifier extends StateNotifier<NeuralState> {
  final LocalStorage _storage;
  final Map<String, NeuralRecord> _records = {};
  final Map<String, int> _ver = {};
  int _tick = 0;
  Timer? _saveTimer;
  bool _dirty = false;

  NeuralPathNotifier(this._storage) : super(const NeuralState.empty()) {
    _load();
  }

  void _load() {
    final json = _storage.readJson(kNeuralStoreKey);
    final recs = json['records'];
    if (recs is Map) {
      recs.forEach((k, v) {
        if (v is Map) {
          try {
            _records['$k'] = NeuralRecord.fromJson(Map<String, dynamic>.from(v));
          } catch (_) {}
        }
      });
    }
  }

  NeuralRecord? recordOf(String base) => _records[base];

  // «راهنما»ی پخش: وقتی صدا از داخلِ یک کارت (مثلاً ترجمه‌ی لغتِ انتخاب‌شده)
  // پخش می‌شود، تکرار باید به مسیرِ «لغتِ انتخاب‌شده» برود نه به متنِ ترجمه.
  final Map<String, String> _hints = {};
  void hint(String speechKey, String base) {
    if (_hints.length > 60) _hints.clear();
    _hints[speechKey] = base;
  }

  String? hintFor(String? speechKey) =>
      speechKey == null ? null : _hints[speechKey];

  NeuralRecord _ensure(String base) => _records.putIfAbsent(base, NeuralRecord.new);

  void _touch(String base, {bool saveNow = false}) {
    _ver[base] = (_ver[base] ?? 0) + 1;
    _tick++;
    state = NeuralState._(_ver, _tick);
    _dirty = true;
    _saveTimer?.cancel();
    if (saveNow) {
      flush();
    } else {
      _saveTimer = Timer(const Duration(milliseconds: 800), flush);
    }
  }

  /// ذخیره‌ی فوری (در dispose و بعد از کارهای دستیِ کاربر)
  void flush() {
    _saveTimer?.cancel();
    if (!_dirty) return;
    _dirty = false;
    final out = <String, dynamic>{
      for (final e in _records.entries) e.key: e.value.toJson(),
    };
    unawaited(_storage.writeJson(kNeuralStoreKey, {'records': out}));
  }

  @override
  void dispose() {
    flush();
    super.dispose();
  }

  // ─────────────── ثبتِ تکرار ───────────────

  /// یک (یا چند) تکرار + یک رشته‌ی عصبی برای (base, lang).
  /// [manual] = دکمه‌ی «امروز انجام دادم»؛ وگرنه از پلیر آمده.
  void addRepeat(String base, String lang, {bool manual = false, int count = 1}) {
    if (base.isEmpty || base.length > kNeuralMaxBaseLen || lang.isEmpty) return;
    final r = _ensure(base);
    final today = dayKeyOf(DateTime.now());
    final day = r.days.putIfAbsent(today, () => <String, int>{});
    day[lang] = (day[lang] ?? 0) + count;
    r.adds[lang] = (r.adds[lang] ?? 0) + count;
    r.last[lang] = DateTime.now().millisecondsSinceEpoch;
    _touch(base, saveNow: manual);
  }

  /// «یک روز گذشت، انجام ندادم»: یک رشته کم می‌شود (تا صفر)
  void removeFiber(String base, String lang) {
    final r = _records[base];
    if (r == null || r.fibers(lang) <= 0) return;
    r.removes[lang] = (r.removes[lang] ?? 0) + 1;
    _touch(base, saveNow: true);
  }

  /// «همینه، رفت تو حافظه‌ی دائمیم» — قفلِ toggle‌شونده
  void toggleHabit(String base, String lang) {
    final r = _ensure(base);
    if (!r.habit.add(lang)) r.habit.remove(lang);
    _touch(base, saveNow: true);
  }

  /// مسیر و تقویمِ این مورد را کاملاً پاک می‌کند
  void clear(String base) {
    if (_records.remove(base) == null) return;
    _touch(base, saveNow: true);
  }

  // ─────────────── دوره‌ی تقویم ───────────────

  /// اولین باری که تقویمِ یک مورد باز می‌شود، دوره‌اش از «امروز» ثبت می‌شود
  /// (تا روزِ شروع هر روز عقب/جلو نرود).
  NeuralPeriod ensurePeriod(String base) {
    final r = _ensure(base);
    var p = r.period;
    if (p == null) {
      p = NeuralPeriod(
          days: kPeriodDefaultDays, startDate: dayKeyOf(DateTime.now()));
      r.period = p;
      _touch(base, saveNow: true);
    }
    return p;
  }

  void setPeriodDays(String base, int days) {
    final r = _ensure(base);
    final p = r.period ??
        NeuralPeriod(days: days, startDate: dayKeyOf(DateTime.now()));
    r.period = p.copyWith(days: days.clamp(1, kPeriodMaxDays).toInt());
    _touch(base, saveNow: true);
  }

  /// دوره‌ی تمام‌شده به «قبلی‌ها» می‌رود (پاک نمی‌شود) و دوره‌ی تازه از امروز
  void startNextPeriod(String base, int days) {
    final r = _ensure(base);
    final p = r.period ??
        NeuralPeriod(days: kPeriodDefaultDays, startDate: dayKeyOf(DateTime.now()));
    r.period = NeuralPeriod(
      days: days.clamp(1, kPeriodMaxDays).toInt(),
      startDate: dayKeyOf(DateTime.now()),
      past: [...p.past, PastPeriod(p.days, p.startDate)],
    );
    _touch(base, saveNow: true);
  }
}

final neuralPathProvider =
    StateNotifierProvider<NeuralPathNotifier, NeuralState>((ref) {
  return NeuralPathNotifier(ref.watch(localStorageProvider));
});
