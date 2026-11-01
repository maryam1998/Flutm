import 'dart:math' as math;

import '../models/jalali.dart';
import '../models/map_models.dart';
import 'map_ops.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  تخمینِ زمان و سرسبزیِ نقشه
//  کاربر برای هدف/شاخه/زیرشاخه می‌گوید «فکر می‌کنم چند روز/هفته/ماه طول می‌کشد».
//  سرسبزی = زمانِ گذشته نسبت به تخمین × پایبندیِ واقعی (روزهای انجام‌شده).
//  اگر از تخمین گذشت، تاریخِ تازه از روی سرعتِ واقعی حساب می‌شود.
//  ذخیره: extra['estDays'] (تعداد روز) و extra['estStart'] (تاریخِ شروعِ شمارش)
// ═══════════════════════════════════════════════════════════════════════════

/// هر ۱٫۰ سرسبزیِ یک شاخه معادلِ این‌همه «دقیقه کار» برای رشدِ برگ و زمینِ سبز است
const double kEstGreenMinutes = 480.0;

int estDaysOf(Map<String, dynamic> ex) {
  final v = ex['estDays'];
  final n = v is num ? v.toInt() : 0;
  return n > 0 ? n : 0;
}

DateTime? estStartOf(Map<String, dynamic> ex) {
  final v = ex['estStart'];
  if (v is String && v.isNotEmpty) return parseLocalKey(v);
  return null;
}

/// [days] ≤ ۰ یعنی حذفِ تخمین. تغییرِ تعداد روز، تاریخِ شروع را عوض نمی‌کند.
void setEstimate(Map<String, dynamic> ex, int days) {
  if (days <= 0) {
    ex.remove('estDays');
    ex.remove('estStart');
    return;
  }
  ex['estDays'] = math.min(days, 3650);
  if (estStartOf(ex) == null) ex['estStart'] = localKey(DateTime.now());
}

void restartEstimate(Map<String, dynamic> ex) {
  if (estDaysOf(ex) > 0) ex['estStart'] = localKey(DateTime.now());
}

/// عددِ فارسی/عربی/انگلیسی → int
int? parseFaInt(String s) {
  var t = s.trim();
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  return int.tryParse(t);
}

class EstInfo {
  EstInfo({
    required this.estDays,
    required this.start,
    required this.elapsed,
    required this.progress,
    required this.projectedEnd,
    required this.overdue,
  });
  final int estDays;
  final DateTime start;

  /// روزهای گذشته از شروع (اعشاری)
  final double elapsed;

  /// سرسبزی/پیشرفتِ واقعی ۰..۱
  final double progress;

  /// تاریخِ تخمینیِ پایان با سرعتِ واقعی
  final DateTime projectedEnd;

  /// زمانِ تخمینی تمام شده ولی کار تمام نشده
  final bool overdue;
}

int _ord(String jk) {
  final p = jk.split('-');
  if (p.length != 3) return 0;
  final y = int.tryParse(p[0]) ?? 0, m = int.tryParse(p[1]) ?? 0;
  final d = int.tryParse(p[2]) ?? 0;
  return y * 10000 + m * 100 + d;
}

int _doneDaysSince(ActionNode a, DateTime start, DateTime now) {
  final s = _ord(jKey(start)), t = _ord(jKey(now));
  final keys = <String>{...a.logs.keys, ...a.time.keys, ...a.entries.keys};
  var n = 0;
  for (final k in keys) {
    final o = _ord(k);
    if (o >= s && o <= t && footDoneOn(a, k)) n++;
  }
  return n;
}

bool _subtreeHasEst(ActionNode a) {
  if (estDaysOf(a.extra) > 0) return true;
  for (final k in a.children) {
    if (_subtreeHasEst(k)) return true;
  }
  return false;
}

/// پیشرفتِ خودِ گره (بدون زیرشاخه‌ها): زمانِ گذشته × پایبندی
({double progress, double eng, double elapsed, int days, DateTime start})?
    _own(ActionNode a, DateTime now) {
  final days = estDaysOf(a.extra);
  if (days <= 0) return null;
  final start = estStartOf(a.extra) ?? DateTime(now.year, now.month, now.day);
  final elapsed = math.max(0.0, now.difference(start).inMinutes / 1440.0);
  final e = (elapsed / days).clamp(0.0, 1.0).toDouble();
  final since = elapsed.floor() + 1;
  final done = _doneDaysSince(a, start, now);
  // حداقل هر دو روز یک بار کار = پایبندیِ کامل
  final eng = ((done / since) / 0.5).clamp(0.0, 1.0).toDouble();
  return (progress: math.min(0.95, e * eng), eng: eng, elapsed: elapsed, days: days, start: start);
}

/// سرسبزیِ یک شاخه ۰..۱؛ null = هیچ تخمینی در این شاخه نیست
double? nodeGreen(ActionNode a, [DateTime? at]) {
  if (!_subtreeHasEst(a)) return null;
  if (nodeFinished(a)) return 1.0;
  final now = at ?? DateTime.now();
  final own = _own(a, now);
  if (a.children.isEmpty) return own?.progress;
  var sum = 0.0;
  for (final k in a.children) {
    sum += nodeGreen(k, now) ?? (nodeFinished(k) ? 1.0 : 0.0);
  }
  final avg = sum / a.children.length;
  return own == null ? avg : math.max(avg, own.progress);
}

EstInfo _build(int days, DateTime start, DateTime now, double progress,
    bool finished) {
  final elapsed = math.max(0.0, now.difference(start).inMinutes / 1440.0);
  double total;
  if (finished) {
    total = elapsed;
  } else if (progress < 0.03) {
    total = days.toDouble();
  } else {
    // با همین سرعتِ واقعی کلِ کار چند روز می‌شود
    total = math.max(elapsed / progress, elapsed + 1);
  }
  total = total.clamp(1.0, 3650.0).toDouble();
  var end = start.add(Duration(minutes: (total * 1440).round()));
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (!finished && end.isBefore(tomorrow)) end = tomorrow;
  return EstInfo(
    estDays: days,
    start: start,
    elapsed: elapsed,
    progress: finished ? 1.0 : progress,
    projectedEnd: end,
    overdue: !finished && elapsed >= days,
  );
}

/// اطلاعاتِ تخمین برای یک شاخه/زیرشاخه (null اگر تخمین ندارد)
EstInfo? nodeEstInfo(ActionNode a, [DateTime? at]) {
  final days = estDaysOf(a.extra);
  if (days <= 0) return null;
  final now = at ?? DateTime.now();
  final start = estStartOf(a.extra) ?? DateTime(now.year, now.month, now.day);
  final g = nodeGreen(a, now) ?? 0.0;
  return _build(days, start, now, g, nodeFinished(a));
}

/// اطلاعاتِ تخمین برای کلِ هدف (null اگر تخمین ندارد)
EstInfo? goalEstInfo(Goal g, [DateTime? at]) {
  final days = estDaysOf(g.extra);
  if (days <= 0) return null;
  final now = at ?? DateTime.now();
  final start = estStartOf(g.extra) ?? DateTime(now.year, now.month, now.day);
  var sum = 0.0;
  for (final k in g.actions) {
    sum += nodeGreen(k, now) ?? (nodeFinished(k) ? 1.0 : 0.0);
  }
  final p = g.actions.isEmpty ? 0.0 : sum / g.actions.length;
  return _build(days, start, now, p, g.reached);
}
