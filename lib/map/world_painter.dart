import 'dart:math' as math;
import 'dart:typed_data' show Float32List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/constants.dart' show hexColor;
import '../models/map_models.dart';
import 'camera.dart';
import '../theme/vazir_font.dart';
import 'geometry.dart' as geo;
import 'hit_registry.dart';
import 'seeded.dart';
import 'walk_marks.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  دنیای در حال رشد 🌱🏡🚗
//  بیابانِ خشک و خالی؛ با ساعت‌های کاری که کاربر روی هر هدف می‌گذارد (ماه‌ها و
//  سال‌ها) کنارِ جاده‌ی همان هدف آهسته سبزی، گیاه، خانه و ماشین پیدا می‌شود.
//  شکلِ نهایی از روی یک «دانه‌ی تصادفیِ» ثابتِ هر کاربر ساخته می‌شود
//  (state.extra['worldSeed']) و قابل پیش‌بینی نیست؛ هر کاربر دنیای خودش را دارد.
//  برای خاموش‌کردن: state.extra['worldOff'] = true
// ═══════════════════════════════════════════════════════════════════════════

double _c01(double x) => x < 0 ? 0.0 : (x > 1 ? 1.0 : x);
double _ease(double x) {
  final t = _c01(x);
  return t * t * (3 - 2 * t);
}

/// دقیقه‌های کارِ یک شاخه (ثبت‌شده + تایمرِ روشن) به‌همراهِ همه‌ی زیرشاخه‌هایش
double actionTotalMinutes(ActionNode a) {
  var sec = 0.0;
  for (final v in a.time.values) {
    if (v is num) sec += v.toDouble();
  }
  final ts = a.timerStart ?? 0;
  if (ts > 0) sec += (DateTime.now().millisecondsSinceEpoch - ts) / 1000.0;
  var m = sec / 60.0;
  for (final k in a.children) {
    m += actionTotalMinutes(k);
  }
  return m;
}

// ───────────────────────── رنگ‌ها ─────────────────────────
const List<Color> _kHouse = [
  Color(0xFFF2D7B6), Color(0xFFE9B7A0), Color(0xFFCFE3F1), Color(0xFFF6E7A8),
  Color(0xFFD9C8EA), Color(0xFFBFE0C8), Color(0xFFF4C6C6), Color(0xFFE8E2D2),
];
const List<Color> _kRoof = [
  Color(0xFFB5523B), Color(0xFF7A4B8C), Color(0xFF3F6F9E), Color(0xFF8B5A2B),
  Color(0xFF2F7D6B), Color(0xFFB8862F),
];
const List<Color> _kCar = [
  Color(0xFFE5484D), Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFF10B981),
  Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFFF3F4F6), Color(0xFF334155),
];
const List<Color> _kFlower = [
  Color(0xFFFF6B8B), Color(0xFFFFC145), Color(0xFFB57BFF), Color(0xFFFFFFFF),
  Color(0xFFFF8F3F), Color(0xFF5BC0FF),
];
const List<List<Color>> _kGreens = [
  [Color(0xFF2E7D32), Color(0xFF5FB05F)],
  [Color(0xFF3C8D40), Color(0xFF8CCB6B)],
  [Color(0xFF1F7A55), Color(0xFF58BE8E)],
  [Color(0xFF557A2B), Color(0xFFA2C95B)],
];

// ───────────────────────── مدلِ دنیا ─────────────────────────
// انواع: ۰ چمن ۱ گل ۲ بوته ۳ درخت ۴ کاج ۵ برکه ۶ سنگ ۷ قارچ ۸ کاه ۹ نرده
// ۱۰ چراغ ۱۱ آسیاب ۱۲ مزرعه ۲۰ خانه ۲۱ خانه‌ی دوطبقه ۲۲ برج ۲۳ انبار
// ۳۰ بالن ۳۱ رنگین‌کمان ۳۲ بشقاب‌پرنده
//
// اصلِ کار: دنیا از یک بیابانِ خشک شروع می‌شود. برای هر هدف، کنارِ تنه‌ی «من ← هدف»
// (همان مسیری که کاربر با انگشت می‌سازد) یک جاده ساخته می‌شود؛ طولِ جاده با
// وقتی که روی همان هدف گذاشته شده کم‌کم زیاد می‌شود. سبزی، گیاه، خانه و ماشین
// فقط دورِ جاده‌ی همان هدف و خیلی آهسته (ماه‌ها و سال‌ها) پیدا می‌شوند.
// اگر هدفی پاک شود جاده و سبزیِ آن هم برمی‌گردد به بیابان.

/// دقیقه‌ی کارِ روی یک هدف تا جاده‌اش به طولِ کامل برسد (۴۰۰ ساعت)
const double _kRoadFull = 24000.0;
double _hr(double h) => h * 60.0;

class _El {
  _El(this.k, this.x, this.y, this.s, this.at, this.v, this.a);
  final int k;
  final double x, y, s, at, a;
  final int v;
}

/// المانِ وابسته به جاده: [sd] فاصله از ابتدای جاده، [off] فاصله‌ی عمودی از جاده
class _GEl {
  _GEl(this.k, this.sd, this.off, this.s, this.at, this.v, this.a);
  final int k;
  final double sd, off, s, at, a;
  final int v;
}

class _Blob {
  _Blob(this.sd, this.off, this.r, this.at, this.deep);
  final double sd, off, r, at;
  final bool deep;
}

class _GPlan {
  final List<_GEl> els = [];
  final List<_Blob> blobs = [];
  int theme = 0; // ۰ روستا ۱ جنگل ۲ مزرعه ۳ دریاچه
  double side = 1.0;
  // پیچ‌وتابِ جاده (ثابت برای هر هدف)
  double wobA = 50, wobP1 = 0, wobP2 = 0;
}

class _Plan {
  final List<_El> skyFlat = []; // رنگین‌کمان
  final List<_El> skyTall = []; // بالن، بشقاب‌پرنده (مختصات نسبت به «من»)
  List<Color> houseColors = [], roofColors = [], carColors = [];
}

class _RoadPoly {
  _RoadPoly._(this.pts, this.cum, this.length, this.bounds);
  final List<Offset> pts;
  final List<double> cum;
  final double length;
  final Rect bounds;
  static const double start = 62.0;

  static _RoadPoly? build(geo.Cubic cp, double off, _GPlan gp) {
    const n = 64;
    // طولِ تقریبیِ تنه برای تعیین تعدادِ پیچ‌ها
    var rawL = 0.0;
    var prev = cp.at(0);
    for (var i = 1; i < n; i++) {
      final q = cp.at(i / (n - 1));
      rawL += (q - prev).distance;
      prev = q;
    }
    final amp = math.min(gp.wobA, rawL * 0.16);
    final f1 = math.max(0.8, rawL / 900.0);
    final f2 = f1 * 1.7 + 0.35;
    final pts = <Offset>[];
    final cum = <double>[0.0];
    var minX = 1e12, minY = 1e12, maxX = -1e12, maxY = -1e12;
    for (var i = 0; i < n; i++) {
      final t = i / (n - 1);
      final p = cp.at(t);
      final a = cp.tangent(t);
      final w = amp *
          math.sin(math.pi * t) *
          (0.65 * math.sin(2 * math.pi * f1 * t + gp.wobP1) +
              0.35 * math.sin(2 * math.pi * f2 * t + gp.wobP2));
      final q = p + Offset(-math.sin(a), math.cos(a)) * (off + w);
      pts.add(q);
      if (q.dx < minX) minX = q.dx;
      if (q.dx > maxX) maxX = q.dx;
      if (q.dy < minY) minY = q.dy;
      if (q.dy > maxY) maxY = q.dy;
      if (i > 0) cum.add(cum.last + (pts[i] - pts[i - 1]).distance);
    }
    final len = cum.last - start - 44.0;
    if (len < 40) return null;
    return _RoadPoly._(pts, cum, len, Rect.fromLTRB(minX, minY, maxX, maxY));
  }

  int _seg(double d) {
    var lo = 1, hi = pts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (cum[mid] >= d) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  Offset pos(double d) {
    final dd = (start + d).clamp(0.0, cum.last).toDouble();
    final i = _seg(dd);
    final seg = cum[i] - cum[i - 1];
    final f = seg == 0 ? 0.0 : (dd - cum[i - 1]) / seg;
    return Offset.lerp(pts[i - 1], pts[i], f)!;
  }

  double ang(double d) {
    final dd = (start + d).clamp(0.0, cum.last).toDouble();
    final i = _seg(dd);
    final v = pts[i] - pts[i - 1];
    return math.atan2(v.dy, v.dx);
  }

  /// مثلِ [trace] ولی موازیِ جاده با فاصله‌ی [off] (برای خطِ کنارِ آسفالت)
  void traceOff(Path p, double len, double off) {
    var first = true;
    void add(double d) {
      final a = ang(d);
      final q = pos(d) + Offset(-math.sin(a), math.cos(a)) * off;
      if (first) {
        p.moveTo(q.dx, q.dy);
        first = false;
      } else {
        p.lineTo(q.dx, q.dy);
      }
    }

    add(0);
    for (var i = 1; i < pts.length; i++) {
      final d = cum[i] - start;
      if (d <= 0) continue;
      if (d >= len) break;
      add(d);
    }
    add(len);
  }

  /// نزدیک‌ترین نقطه‌ی جاده به [p]: فاصله‌ی پیموده‌شده (مثل [pos]) و فاصله‌ی عمودی
  ({double d, double dist}) project(Offset p) {
    var best = double.infinity;
    var bd = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final v = b - a;
      final l2 = v.dx * v.dx + v.dy * v.dy;
      if (l2 < 1e-9) continue;
      final f = (((p.dx - a.dx) * v.dx + (p.dy - a.dy) * v.dy) / l2)
          .clamp(0.0, 1.0)
          .toDouble();
      final q = Offset(a.dx + v.dx * f, a.dy + v.dy * f);
      final dd = (p - q).distanceSquared;
      if (dd < best) {
        best = dd;
        bd = cum[i - 1] + f * (cum[i] - cum[i - 1]);
      }
    }
    return (d: bd - start, dist: math.sqrt(best));
  }

  /// مسیرِ دلخواه (مثلاً مسیرِ قدم‌زنِ یک شاخه) را به شکلِ «جاده» برای دوربین
  /// می‌سازد: کمی نرم می‌شود و با فاصله‌ی ثابت نمونه‌برداری می‌شود.
  static _RoadPoly? fromPath(List<Offset> raw) {
    var p = <Offset>[];
    for (final q in raw) {
      if (p.isEmpty || (q - p.last).distance > 0.5) p.add(q);
    }
    if (p.length < 2) return null;
    for (var it = 0; it < 2; it++) {
      if (p.length < 3) break;
      final n = <Offset>[p.first];
      for (var i = 0; i < p.length - 1; i++) {
        final a = p[i], b = p[i + 1];
        n.add(a * 0.75 + b * 0.25);
        n.add(a * 0.25 + b * 0.75);
      }
      n.add(p.last);
      p = n;
    }
    final c = <double>[0.0];
    for (var i = 1; i < p.length; i++) {
      c.add(c.last + (p[i] - p[i - 1]).distance);
    }
    final total = c.last;
    if (total < 40) return null;
    final cnt = math.max(2, (total / 6.0).ceil());
    final res = <Offset>[];
    var j = 1;
    for (var k = 0; k <= cnt; k++) {
      final dd = total * k / cnt;
      while (j < p.length - 1 && c[j] < dd) {
        j++;
      }
      final seg = c[j] - c[j - 1];
      final f = seg <= 0
          ? 0.0
          : ((dd - c[j - 1]) / seg).clamp(0.0, 1.0).toDouble();
      res.add(Offset.lerp(p[j - 1], p[j], f)!);
    }
    Offset unit(Offset v) {
      final l = v.distance;
      return l < 1e-6 ? const Offset(1, 0) : v / l;
    }

    final d0 = unit(res[1] - res[0]);
    final d1 = unit(res.last - res[res.length - 2]);
    final pts = <Offset>[res.first - d0 * start, ...res, res.last + d1 * 44.0];
    final cum = <double>[0.0];
    var minX = 1e12, minY = 1e12, maxX = -1e12, maxY = -1e12;
    for (var i = 0; i < pts.length; i++) {
      final q = pts[i];
      if (q.dx < minX) minX = q.dx;
      if (q.dx > maxX) maxX = q.dx;
      if (q.dy < minY) minY = q.dy;
      if (q.dy > maxY) maxY = q.dy;
      if (i > 0) cum.add(cum.last + (pts[i] - pts[i - 1]).distance);
    }
    final len = cum.last - start - 44.0;
    if (len < 40) return null;
    return _RoadPoly._(pts, cum, len, Rect.fromLTRB(minX, minY, maxX, maxY));
  }

  /// مسیرِ جاده را تا طولِ [len] در [p] می‌ریزد
  void trace(Path p, double len) {
    final a = pos(0);
    p.moveTo(a.dx, a.dy);
    for (var i = 1; i < pts.length; i++) {
      final d = cum[i] - start;
      if (d <= 0) continue;
      if (d >= len) break;
      p.lineTo(pts[i].dx, pts[i].dy);
    }
    final e = pos(len);
    p.lineTo(e.dx, e.dy);
  }
}

class _Fr {
  _Fr(this.pl, this.road, this.gm, this.rl, this.paved, this.gi, this.end);
  final _GPlan pl;
  final _RoadPoly road;
  final double gm, rl, paved;
  final int gi;
  final Offset end;
}

class _Dr {
  _Dr(this.e, this.p);
  final _El e;
  final double p;
}

double _kindRadius(int k) {
  switch (k) {
    case 0:
    case 1:
    case 7:
      return 8;
    case 2:
      return 14;
    case 3:
      return 22;
    case 4:
      return 20;
    case 5:
      return 48;
    case 6:
      return 10;
    case 8:
      return 20;
    case 9:
      return 26;
    case 11:
      return 34;
    case 12:
      return 72;
    default:
      return 24;
  }
}

bool _isHeavy(int k) =>
    k == 3 || k == 4 || k == 8 || k == 11 || k == 20 || k == 21 || k == 22 || k == 23;

/// ساعتِ کارِ لازم روی هدف تا هر نوع پیدا شود (با کمی تصادفی)
double _baseHours(int k) {
  switch (k) {
    case 0:
      return 1.5;
    case 1:
      return 8;
    case 2:
      return 22;
    case 6:
      return 12;
    case 7:
      return 30;
    case 3:
      return 45;
    case 4:
      return 65;
    case 5:
      return 110;
    case 8:
      return 130;
    case 9:
      return 120;
    case 12:
      return 170;
    case 20:
      return 120;
    case 21:
      return 270;
    case 23:
      return 230;
    case 11:
      return 420;
    case 22:
      return 650;
    case 10:
      return 210;
    default:
      return 100;
  }
}

/// مدتی که هر نوع طول می‌کشد تا کاملاً بزرگ شود
double _rampMin(int k) {
  switch (k) {
    case 0:
    case 1:
    case 2:
    case 6:
    case 7:
      return _hr(4);
    case 3:
    case 4:
      return _hr(25);
    case 10:
      return _hr(3);
    default:
      return _hr(15);
  }
}

double _offFor(int k, double s, double Function() R) {
  switch (k) {
    case 0:
    case 1:
      return 24 + R() * 120;
    case 2:
      return 34 + R() * 90;
    case 6:
    case 7:
      return 30 + R() * 110;
    case 3:
    case 4:
      return 50 + R() * 110;
    case 8:
      return 50 + R() * 60;
    case 9:
      return 56 + R() * 8;
    case 11:
      return 85 + R() * 60;
    case 20:
    case 21:
    case 22:
      return 58 + R() * 22;
    case 23:
      return 72 + R() * 25;
    case 5:
    case 12:
      return 30 + _kindRadius(k) * s * 0.95 + R() * 25;
    default:
      return 50 + R() * 50;
  }
}

const List<int> _wKinds = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 20, 23];
const List<List<double>> _wTheme = [
  // روستا، جنگل، مزرعه، دریاچه
  [5, 5, 5, 5], // چمن
  [3, 2, 2, 3], // گل
  [1.5, 2, 1, 1.5], // بوته
  [1.5, 4, 1, 1.5], // درخت
  [0.5, 3, 0.3, 1], // کاج
  [0.2, 0.2, 0.2, 1.6], // برکه
  [1, 1, 1, 1], // سنگ
  [0.3, 1, 0.2, 0.3], // قارچ
  [0, 0, 1.3, 0], // کاه
  [0.3, 0, 1, 0.2], // نرده
  [0.06, 0, 0.3, 0.05], // آسیاب
  [0, 0, 1.2, 0], // مزرعه
  [1.6, 0.5, 0.8, 0.8], // خانه
  [0, 0, 0.7, 0], // انبار
];

int _pickKind(int theme, double Function() R) {
  var sum = 0.0;
  for (var i = 0; i < _wKinds.length; i++) {
    sum += _wTheme[i][theme];
  }
  var r = R() * sum;
  for (var i = 0; i < _wKinds.length; i++) {
    final w = _wTheme[i][theme];
    r -= w;
    if (r <= 0 && w > 0) return _wKinds[i];
  }
  return 0;
}

/// طرحِ ثابتِ دنیای یک هدف (فقط به شناسه‌ی هدف و دانه‌ی کاربر بستگی دارد)
_GPlan _genGoalPlan(String gid, int seed) {
  final rnd = seeded('w2-$seed-$gid');
  double R() => rnd();
  final pl = _GPlan();
  pl.theme = (R() * 4).floor().clamp(0, 3).toInt();
  pl.side = R() < 0.5 ? -1.0 : 1.0;
  pl.wobA = 12 + R() * 12;
  pl.wobP1 = R() * 6.28;
  pl.wobP2 = R() * 6.28;

  // لکه‌های سبزی کنارِ جاده: لایه‌ی روشن زودتر، لایه‌ی پررنگ خیلی دیرتر
  var sd = 30.0;
  while (sd < 4200) {
    final side = R() < 0.5 ? -1.0 : 1.0;
    pl.blobs.add(_Blob(
        sd, side * (10 + R() * 70), 55 + R() * 55, _hr(3 + R() * 30), false));
    if (R() < 0.55) {
      pl.blobs.add(_Blob(sd + R() * 30, -side * (10 + R() * 60),
          34 + R() * 36, _hr(70 + R() * 230), true));
    }
    sd += 48 + R() * 34;
  }

  // گیاه، خانه، برکه…
  var lastL = -999.0, lastR = -999.0, lastBig = -999.0;
  sd = 80 + R() * 20;
  while (sd < 4200) {
    final side = R() < 0.5 ? -1.0 : 1.0;
    var k = _pickKind(pl.theme, R);
    if (_isHeavy(k)) {
      final last = side < 0 ? lastL : lastR;
      if (sd - last < 70) {
        k = R() < 0.5 ? 0 : 1;
      } else if (side < 0) {
        lastL = sd;
      } else {
        lastR = sd;
      }
    }
    if ((k == 5 || k == 12)) {
      if (sd - lastBig < 260) {
        k = 2;
      } else {
        lastBig = sd;
      }
    }
    if (k == 20) {
      final q = R();
      if (q < 0.4) {
        k = 21;
      } else if (q > 0.93) {
        k = 22;
      }
    }
    final sz = (k == 5 || k == 12) ? 0.8 + R() * 0.8 : 0.8 + R() * 0.55;
    final at = _hr(_baseHours(k) * (0.7 + R() * 0.9));
    final off = side * _offFor(k, sz, R);
    pl.els.add(_GEl(k, sd, off, sz, at, (R() * 1000).floor(), R() * 6.28));
    if (R() < 0.45) {
      final k2 = R() < 0.6 ? 0 : 1;
      pl.els.add(_GEl(k2, sd + R() * 24, -side * (20 + R() * 70),
          0.8 + R() * 0.55, _hr(_baseHours(k2) * (0.7 + R() * 0.9)),
          (R() * 1000).floor(), R() * 6.28));
    }
    sd += 22 + R() * 30;
  }

  // چراغ‌های کنارِ جاده (فقط روی بخشِ آسفالت‌شده دیده می‌شوند)
  var ld = 150 + R() * 40;
  var ls = 1.0;
  while (ld < 4200) {
    pl.els.add(_GEl(10, ld, ls * 26.0, 1.0, _hr(210 + R() * 120), 0, R() * 6));
    ls = -ls;
    ld += 170 + R() * 60;
  }
  return pl;
}

/// رنگ‌ها و سورپرایزهای هر کاربر (نسبت به «من»؛ زمانشان بر حسبِ کلِ دقیقه‌ی کار)
_Plan _buildPlan(int seed) {
  final rnd = seeded('world-v2-$seed');
  double R() => rnd();
  final pl = _Plan();
  pl.houseColors = (List<Color>.from(_kHouse)..shuffle(math.Random(seed)))
      .take(4)
      .toList();
  pl.roofColors = (List<Color>.from(_kRoof)..shuffle(math.Random(seed + 7)))
      .take(3)
      .toList();
  pl.carColors = (List<Color>.from(_kCar)..shuffle(math.Random(seed + 13)))
      .take(5)
      .toList();

  Offset anyPos() {
    final ang = R() * math.pi * 2;
    final rr = 160 + R() * 420;
    return Offset(math.cos(ang) * rr, math.sin(ang) * rr);
  }

  if (R() < 0.75) {
    final at = _hr(300 + R() * 1200);
    final p = anyPos();
    pl.skyTall.add(_El(30, p.dx, p.dy, 1.0, at, 0, R() * 6));
  }
  if (R() < 0.6) {
    final at = _hr(150 + R() * 550);
    final p = anyPos();
    pl.skyFlat.add(_El(31, p.dx, p.dy, 0.9 + R() * 0.5, at, 0, R() * 6));
  }
  if (R() < 0.18) {
    final at = _hr(800 + R() * 1700);
    final p = anyPos();
    pl.skyTall.add(_El(32, p.dx, p.dy, 1.0, at, 0, R() * 6));
  }
  return pl;
}

// ───────────────────────── رسم ─────────────────────────
final Paint _p = Paint();
final Path _path = Path();

Paint _fill(Color c) => _p
  ..style = PaintingStyle.fill
  ..shader = null
  ..maskFilter = null
  ..color = c;

Paint _stroke(Color c, double w, {StrokeCap cap = StrokeCap.round}) => _p
  ..style = PaintingStyle.stroke
  ..shader = null
  ..maskFilter = null
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = StrokeJoin.round
  ..color = c;

class WorldLayer {
  /// مستطیلِ دیدِ فعلی به مختصاتِ «دنیا» (برای حذفِ چیزهای بیرون از صفحه)
  static Rect view = Rect.zero;

  static _Plan? _plan;
  static int _planSeed = 0;
  static final Map<String, _GPlan> _gPlans = {};
  static double _minutes = 0;
  static Map<String, double> _goalMin = {};
  static int _minMs = 0;

  /// کلِ دقیقه‌های کارِ کاربر روی همه‌ی هدف‌ها و حلقه‌ها (هر ۳۰۰ میلی‌ثانیه تازه می‌شود)
  static double totalMinutes(MapState s) {
    _refresh(s);
    return _minutes;
  }

  static void _refresh(MapState s) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _minMs <= 300) return;
    final gm = <String, double>{};
    var tot = 0.0;
    for (final g in s.goals) {
      var m = 0.0;
      for (final a in g.actions) {
        m += actionTotalMinutes(a);
      }
      gm[g.id] = m;
      tot += m;
    }
    for (final r in s.rings) {
      for (final a in r.actions) {
        tot += actionTotalMinutes(a);
      }
    }
    _goalMin = gm;
    _minutes = tot;
    _minMs = now;
  }

  // لکه‌ی سبز: گرادیانِ واحد (کش‌شده) که با scale بزرگ می‌شود؛ ۸ سطحِ شفافیت
  static final Map<int, Paint> _blobPaints = {};
  static Paint _blobPaint(int level, bool deep, bool dark) {
    final key = level + (deep ? 10 : 0) + (dark ? 100 : 0);
    return _blobPaints.putIfAbsent(key, () {
      final a = level / 8.0 * (deep ? 0.34 : 0.38);
      final c0 = deep
          ? (dark
              ? Color.fromRGBO(40, 120, 60, a)
              : Color.fromRGBO(63, 150, 76, a))
          : (dark
              ? Color.fromRGBO(70, 150, 80, a)
              : Color.fromRGBO(120, 196, 106, a));
      final c1 = c0.withOpacity(0.0);
      return Paint()
        ..shader = ui.Gradient.radial(
            Offset.zero, 1.0, [c0, c1], const [0.0, 1.0]);
    });
  }

  static void _blob(Canvas c, Rect vv, Offset ce, double r, double k,
      bool deep, bool dark) {
    if (r < 4 || k <= 0.02) return;
    if (!vv.overlaps(Rect.fromCircle(center: ce, radius: r))) return;
    final level = (k * 8).ceil().clamp(1, 8).toInt();
    c.save();
    c.translate(ce.dx, ce.dy);
    c.scale(r, r);
    c.drawCircle(Offset.zero, 1.0, _blobPaint(level, deep, dark));
    c.restore();
  }

  static double _hf(int x, int y, int s, double k) {
    final v =
        math.sin(x * 12.9898 + y * 78.233 + s * 0.001237 + k * 37.719) *
            43758.5453;
    return v - v.floorToDouble();
  }

  /// جزئیاتِ بیابان: سنگ‌ریزه، بوته‌ی خشک، ترک؛ دورِ سبزی‌ها محو می‌شوند
  static void _desert(
      Canvas c, Rect vv, int seed, bool dark, List<double> gc) {
    const cell = 120.0;
    final x0 = (vv.left / cell).floor(), x1 = (vv.right / cell).floor();
    final y0 = (vv.top / cell).floor(), y1 = (vv.bottom / cell).floor();
    if ((x1 - x0 + 1) * (y1 - y0 + 1) > 1400) return;
    final dry = dark ? const Color(0x88A58E62) : const Color(0xAA9C8458);
    final peb = dark ? const Color(0x77746A58) : const Color(0x88B9AC93);
    final crk = dark ? const Color(0x55766A50) : const Color(0x66A89572);
    for (var ix = x0; ix <= x1; ix++) {
      for (var iy = y0; iy <= y1; iy++) {
        if (_hf(ix, iy, seed, 1.0) > 0.42) continue;
        final px = (ix + _hf(ix, iy, seed, 2.0)) * cell;
        final py = (iy + _hf(ix, iy, seed, 3.0)) * cell;
        var green = false;
        for (var i = 0; i < gc.length; i += 3) {
          final dx = gc[i] - px, dy = gc[i + 1] - py, rr = gc[i + 2];
          if (dx * dx + dy * dy < rr * rr) {
            green = true;
            break;
          }
        }
        if (green) continue;
        final ty = _hf(ix, iy, seed, 4.0);
        final sz = 0.7 + _hf(ix, iy, seed, 5.0) * 0.8;
        if (ty < 0.4) {
          c.drawOval(
              Rect.fromCenter(
                  center: Offset(px, py), width: 9 * sz, height: 5 * sz),
              _fill(peb));
        } else if (ty < 0.75) {
          final pa = _stroke(dry, 1.3);
          for (var j = -1; j <= 1; j++) {
            c.drawLine(Offset(px + j * 2.5 * sz, py),
                Offset(px + j * 5 * sz, py - (7 + (j == 0 ? 3 : 0)) * sz), pa);
          }
        } else {
          _path
            ..reset()
            ..moveTo(px - 14 * sz, py)
            ..lineTo(px - 5 * sz, py + 3 * sz)
            ..lineTo(px + 2 * sz, py - 2 * sz)
            ..lineTo(px + 12 * sz, py + 2 * sz);
          c.drawPath(_path, _stroke(crk, 1.1));
        }
      }
    }
  }

  static void paint(Canvas canvas, MapState s, CameraController cam,
      Size size, double t, bool isDark) {
    final sc = cam.scale <= 0 ? 1.0 : cam.scale;
    view = Rect.fromLTWH(
        -cam.x / sc, -cam.y / sc, size.width / sc, size.height / sc);
    if (s.extra['worldOff'] == true) return;

    var seed = 0;
    final sv = s.extra['worldSeed'];
    if (sv is num) {
      seed = sv.toInt();
    } else {
      seed = math.Random().nextInt(1 << 30) + 1;
      s.extra['worldSeed'] = seed;
    }
    if (_plan == null || _planSeed != seed) {
      _plan = _buildPlan(seed);
      _planSeed = seed;
      _gPlans.clear();
    }
    if (_gPlans.length > 80) _gPlans.clear();
    final pl = _plan!;
    _refresh(s);
    final tot = _minutes;
    final lod = sc < 0.22;
    final vv = view.inflate(100);
    final me = Offset(s.me.x, s.me.y);

    // ── جاده‌ی هر هدف ──
    final frs = <_Fr>[];
    for (var gi = 0; gi < s.goals.length; gi++) {
      final g = s.goals[gi];
      final gm = _goalMin[g.id] ?? 0.0;
      final gp = _gPlans.putIfAbsent(g.id, () => _genGoalPlan(g.id, seed));
      final cp = geo.trunkControlPoints(g, s.me);
      final road = _RoadPoly.build(cp, gp.side * 30.0, gp);
      if (road == null) continue;
      if (!vv.overlaps(road.bounds.inflate(260))) continue;
      // جاده همان لحظه‌ی ثبتِ هدف کامل و آسفالت‌شده است
      final rl = road.length;
      final paved = road.length;
      frs.add(_Fr(gp, road, gm, rl, paved, gi, Offset(g.x, g.y)));
    }

    // ── زمینِ خشک ──
    canvas.drawRect(
        vv,
        _fill(isDark
            ? const Color.fromRGBO(150, 125, 80, 0.10)
            : const Color.fromRGBO(214, 190, 140, 0.16)));

    // مرکزهای سبزی (برای محوِ جزئیاتِ بیابان)
    final gc = <double>[];
    final meK = _ease((tot - _hr(5)) / _hr(100));
    final meR = 70 + 170 * _ease(tot / _hr(500));
    if (meK > 0.02) gc.addAll([me.dx, me.dy, meR * 0.8]);
    for (final f in frs) {
      final rg = 50 + 130 * _ease(f.gm / _hr(120));
      for (var d = 0.0; d < f.rl; d += 80) {
        final q = f.road.pos(d);
        gc.addAll([q.dx, q.dy, rg]);
      }
    }
    if (!lod) _desert(canvas, vv, seed, isDark, gc);

    // ── سبزیِ آهسته: دورِ «من» و دورِ جاده‌ها ──
    _blob(canvas, vv, me, meR * (0.45 + 0.55 * meK), meK, false, isDark);
    for (final f in frs) {
      for (final b in f.pl.blobs) {
        if (b.sd > f.rl + 20) continue;
        final k = _ease((f.gm - b.at) / _hr(b.deep ? 100 : 60));
        if (k <= 0.02) continue;
        final base = f.road.pos(b.sd);
        final a = f.road.ang(b.sd);
        final ce = base + Offset(-math.sin(a), math.cos(a)) * b.off;
        _blob(canvas, vv, ce, b.r * (0.45 + 0.55 * k), k, b.deep, isDark);
      }
      // دورِ خودِ هدف
      final ke = _ease((f.gm - _hr(20)) / _hr(120));
      _blob(canvas, vv, f.end, 60 + 90 * _ease(f.gm / _hr(300)), ke, false,
          isDark);
    }

    // ── برکه‌ها، مزرعه‌ها، رنگین‌کمان (زیرِ همه) ──
    for (final f in frs) {
      for (final e in f.pl.els) {
        if (e.k != 5 && e.k != 12) continue;
        if (e.sd > f.rl - 6 || f.gm < e.at) continue;
        final a = f.road.ang(e.sd);
        final pos = f.road.pos(e.sd) +
            Offset(-math.sin(a), math.cos(a)) * e.off;
        if (!vv.contains(pos)) continue;
        final p = _ease((f.gm - e.at) / _rampMin(e.k));
        final el = _El(e.k, pos.dx, pos.dy, e.s, e.at, e.v, e.a);
        if (e.k == 5) {
          _pond(canvas, el, p, t);
        } else {
          _field(canvas, el, p);
        }
      }
    }
    for (final e in pl.skyFlat) {
      if (tot < e.at) continue;
      final p = _ease((tot - e.at) / _hr(8));
      _rainbow(canvas,
          _El(e.k, me.dx + e.x, me.dy + e.y, e.s, e.at, e.v, e.a), p);
    }

    // ── جاده‌ها (خاکی ← آسفالت) و ماشین‌ها ──
    for (final f in frs) {
      final road = f.road;
      _path.reset();
      road.trace(_path, f.paved);
      // شانه‌ی جاده و بدنه‌ی آسفالت
      canvas.drawPath(
          _path,
          _stroke(
              isDark ? const Color(0xFF8A8F98) : const Color(0xFFC9CDD3),
              31));
      canvas.drawPath(
          _path,
          _stroke(
              isDark ? const Color(0xFF3F4452) : const Color(0xFF5B6270),
              25));
      {
        // خطِ ممتدِ سفید دو کنارِ جاده
        _path.reset();
        road.traceOff(_path, f.paved, -10.6);
        canvas.drawPath(_path, _stroke(const Color(0xE6FFFFFF), 1.5));
        _path.reset();
        road.traceOff(_path, f.paved, 10.6);
        canvas.drawPath(_path, _stroke(const Color(0xE6FFFFFF), 1.5));
        // خط‌چینِ زردِ وسطِ جاده
        final dl = <double>[];
        for (var d = 10.0; d + 12 < f.paved; d += 28) {
          final a = road.pos(d), b = road.pos(d + 14);
          dl.addAll([a.dx, a.dy, b.dx, b.dy]);
        }
        if (dl.isNotEmpty) {
          canvas.drawRawPoints(ui.PointMode.lines, Float32List.fromList(dl),
              _stroke(const Color(0xFFFFD54F), 2.2, cap: StrokeCap.butt));
        }
        // ماشین‌ها: فقط وقتی جاده آسفالت شده؛ با طولِ آسفالت بیشتر می‌شوند
        final nCar = math.min(4, (f.paved / 280).floor());
        if (f.paved > 140 && f.gm > _hr(200)) {
          for (var c = 0; c < nCar; c++) {
            final hsh =
                ((math.sin(f.gi * 7.31 + c * 12.9898) * 43758.5453) % 1.0)
                    .abs();
            final speed = 38 + hsh * 40;
            final dir = c.isEven ? 1.0 : -1.0;
            var d = (hsh * 1000 + t * speed * dir) % f.paved;
            if (d < 0) d += f.paved;
            final a = road.ang(d);
            final nrm = Offset(-math.sin(a), math.cos(a));
            final ps = road.pos(d) + nrm * (dir > 0 ? 7.0 : -7.0);
            if (!vv.contains(ps)) continue;
            _car(canvas, ps, dir > 0 ? a : a + math.pi,
                pl.carColors[(c + f.gi) % pl.carColors.length]);
          }
        }
      }
    }

    // ── بقیه‌ی چیزها (از بالا به پایین) ──
    final tall = <_Dr>[];
    for (final f in frs) {
      for (final e in f.pl.els) {
        if (e.k == 5 || e.k == 12) continue;
        if (f.gm < e.at) continue;
        if (e.k == 10) {
          if (e.sd > f.paved - 6) continue;
        } else if (e.sd > f.rl - 6) {
          continue;
        }
        if (lod && (e.k == 0 || e.k == 1 || e.k == 6 || e.k == 7)) continue;
        final p = _ease((f.gm - e.at) / _rampMin(e.k));
        if (p < 0.02) continue;
        final a = f.road.ang(e.sd);
        final pos = f.road.pos(e.sd) +
            Offset(-math.sin(a), math.cos(a)) * e.off;
        if (pos.dx < vv.left ||
            pos.dx > vv.right ||
            pos.dy < vv.top - 120 ||
            pos.dy > vv.bottom + 40) {
          continue;
        }
        tall.add(_Dr(_El(e.k, pos.dx, pos.dy, e.s, e.at, e.v, e.a), p));
      }
    }
    tall.sort((a, b) => a.e.y.compareTo(b.e.y));
    for (final d in tall) {
      final e = d.e;
      final p = d.p;
      switch (e.k) {
        case 0:
          _grass(canvas, e, p, t);
          break;
        case 1:
          _flower(canvas, e, p, t);
          break;
        case 2:
          _bush(canvas, e, p);
          break;
        case 3:
          _tree(canvas, e, p, t);
          break;
        case 4:
          _pine(canvas, e, p);
          break;
        case 6:
          _rock(canvas, e, p);
          break;
        case 7:
          _mushroom(canvas, e, p);
          break;
        case 8:
          _hay(canvas, e, p);
          break;
        case 9:
          _fence(canvas, e, p);
          break;
        case 10:
          _lamp(canvas, e, p, t);
          break;
        case 11:
          _windmill(canvas, e, p, t);
          break;
        case 20:
        case 21:
          _house(canvas, e, p, t, pl);
          break;
        case 22:
          _tower(canvas, e, p, t);
          break;
        case 23:
          _barn(canvas, e, p);
          break;
      }
    }

    // ── سورپرایزها: بالن و بشقاب‌پرنده ──
    for (final e in pl.skyTall) {
      if (tot < e.at) continue;
      final p = _ease((tot - e.at) / _hr(8));
      final el = _El(e.k, me.dx + e.x, me.dy + e.y, e.s, e.at, e.v, e.a);
      if (e.k == 30) {
        _balloon(canvas, el, p, t);
      } else {
        _ufo(canvas, el, p, t);
      }
    }

    // ── پرنده و ابر: خیلی دیر ──
    if (tot > _hr(200)) _birds(canvas, tot / 20.0, t, vv);
    if (tot > _hr(400)) _clouds(canvas, tot / 20.0, t, isDark, vv);
  }

  // ───────────── اجزا ─────────────

  static void _grass(Canvas c, _El e, double p, double t) {
    final s = e.s * p;
    final sw = math.sin(t * 1.5 + e.a) * 2 * s;
    final col = _kGreens[e.v % 4][0];
    final pa = _stroke(col, 1.6 * s);
    for (var i = -1; i <= 1; i++) {
      c.drawLine(Offset(e.x + i * 3 * s, e.y),
          Offset(e.x + i * 5 * s + sw, e.y - (8 + (i == 0 ? 3 : 0)) * s), pa);
    }
  }

  static void _flower(Canvas c, _El e, double p, double t) {
    final s = e.s * p;
    final sw = math.sin(t * 1.3 + e.a) * 1.5 * s;
    final top = Offset(e.x + sw, e.y - 12 * s);
    c.drawLine(Offset(e.x, e.y), top, _stroke(_kGreens[e.v % 4][0], 1.4 * s));
    final col = _kFlower[e.v % _kFlower.length];
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5;
      c.drawCircle(top + Offset(math.cos(a), math.sin(a)) * 2.6 * s, 2.1 * s,
          _fill(col));
    }
    c.drawCircle(top, 1.7 * s, _fill(const Color(0xFFFFD54F)));
  }

  static void _bush(Canvas c, _El e, double p) {
    final s = e.s * p;
    final g = _kGreens[e.v % 4];
    c.drawOval(
        Rect.fromCenter(
            center: Offset(e.x, e.y + 1.5 * s), width: 30 * s, height: 7 * s),
        _fill(const Color(0x22000000)));
    c.drawCircle(Offset(e.x - 7 * s, e.y - 5 * s), 7 * s, _fill(g[0]));
    c.drawCircle(Offset(e.x + 7 * s, e.y - 5 * s), 7 * s, _fill(g[0]));
    c.drawCircle(Offset(e.x, e.y - 8 * s), 9 * s, _fill(g[1]));
  }

  static void _tree(Canvas c, _El e, double p, double t) {
    final s = e.s * p;
    final g = _kGreens[e.v % 4];
    final sw = math.sin(t * 1.1 + e.a) * 1.6 * s;
    c.drawOval(
        Rect.fromCenter(
            center: Offset(e.x, e.y + 1.5 * s), width: 34 * s, height: 8 * s),
        _fill(const Color(0x25000000)));
    c.drawRect(Rect.fromLTWH(e.x - 2.5 * s, e.y - 16 * s, 5 * s, 16 * s),
        _fill(const Color(0xFF7A5230)));
    c.drawCircle(Offset(e.x - 9 * s + sw, e.y - 22 * s), 11 * s, _fill(g[0]));
    c.drawCircle(Offset(e.x + 9 * s + sw, e.y - 22 * s), 11 * s, _fill(g[0]));
    c.drawCircle(Offset(e.x + sw, e.y - 30 * s), 14 * s, _fill(g[1]));
    c.drawCircle(Offset(e.x + sw * 0.6, e.y - 24 * s), 10 * s, _fill(g[0]));
  }

  static void _pine(Canvas c, _El e, double p) {
    final s = e.s * p;
    final g = _kGreens[(e.v + 1) % 4];
    c.drawOval(
        Rect.fromCenter(
            center: Offset(e.x, e.y + 1.5 * s), width: 28 * s, height: 7 * s),
        _fill(const Color(0x25000000)));
    c.drawRect(Rect.fromLTWH(e.x - 2 * s, e.y - 8 * s, 4 * s, 8 * s),
        _fill(const Color(0xFF6B4423)));
    for (var i = 0; i < 3; i++) {
      final by = e.y - (6 + i * 11) * s;
      final w = (16 - i * 3.5) * s;
      _path
        ..reset()
        ..moveTo(e.x - w, by)
        ..lineTo(e.x, by - 18 * s)
        ..lineTo(e.x + w, by)
        ..close();
      c.drawPath(_path, _fill(i.isEven ? g[0] : g[1]));
    }
  }

  static void _rock(Canvas c, _El e, double p) {
    final s = e.s * p;
    c.drawOval(
        Rect.fromCenter(
            center: Offset(e.x, e.y - 3 * s), width: 16 * s, height: 10 * s),
        _fill(const Color(0xFF9AA3AE)));
    c.drawOval(
        Rect.fromCenter(
            center: Offset(e.x - 2 * s, e.y - 5 * s), width: 8 * s, height: 4 * s),
        _fill(const Color(0x66FFFFFF)));
  }

  static void _mushroom(Canvas c, _El e, double p) {
    final s = e.s * p;
    c.drawRect(Rect.fromLTWH(e.x - 1.5 * s, e.y - 6 * s, 3 * s, 6 * s),
        _fill(const Color(0xFFF3E9DC)));
    c.drawOval(
        Rect.fromCenter(
            center: Offset(e.x, e.y - 7 * s), width: 11 * s, height: 7 * s),
        _fill(const Color(0xFFE5484D)));
    c.drawCircle(Offset(e.x - 2 * s, e.y - 8 * s), 1 * s, _fill(Colors.white));
    c.drawCircle(Offset(e.x + 2 * s, e.y - 7 * s), 0.9 * s, _fill(Colors.white));
  }

  static void _hay(Canvas c, _El e, double p) {
    final s = e.s * p;
    c.drawOval(
        Rect.fromCenter(
            center: Offset(e.x, e.y - 6 * s), width: 24 * s, height: 16 * s),
        _fill(const Color(0xFFE5C158)));
    c.drawLine(Offset(e.x - 8 * s, e.y - 6 * s), Offset(e.x + 8 * s, e.y - 6 * s),
        _stroke(const Color(0x55A07A1E), 1.2 * s));
  }

  static void _fence(Canvas c, _El e, double p) {
    final s = e.s * p;
    final col = const Color(0xFFB98B5E);
    c.drawLine(Offset(e.x - 22 * s, e.y - 8 * s), Offset(e.x + 22 * s, e.y - 8 * s),
        _stroke(col, 1.6 * s));
    c.drawLine(Offset(e.x - 22 * s, e.y - 4 * s), Offset(e.x + 22 * s, e.y - 4 * s),
        _stroke(col, 1.6 * s));
    for (var i = -2; i <= 2; i++) {
      c.drawLine(Offset(e.x + i * 11 * s, e.y), Offset(e.x + i * 11 * s, e.y - 11 * s),
          _stroke(col, 2.4 * s));
    }
  }

  static void _lamp(Canvas c, _El e, double p, double t) {
    final s = e.s * p;
    c.drawLine(Offset(e.x, e.y), Offset(e.x, e.y - 22 * s),
        _stroke(const Color(0xFF4B5563), 2 * s));
    final glow = 0.55 + 0.25 * math.sin(t * 2 + e.a);
    c.drawCircle(Offset(e.x, e.y - 24 * s), 8 * s,
        _fill(Color.fromRGBO(255, 224, 130, 0.22 * glow)));
    c.drawCircle(
        Offset(e.x, e.y - 24 * s), 3 * s, _fill(const Color(0xFFFFE082)));
  }

  static void _windmill(Canvas c, _El e, double p, double t) {
    final s = e.s * p;
    _path
      ..reset()
      ..moveTo(e.x - 9 * s, e.y)
      ..lineTo(e.x - 5 * s, e.y - 40 * s)
      ..lineTo(e.x + 5 * s, e.y - 40 * s)
      ..lineTo(e.x + 9 * s, e.y)
      ..close();
    c.drawPath(_path, _fill(const Color(0xFFF1E4CF)));
    final hub = Offset(e.x, e.y - 42 * s);
    for (var i = 0; i < 4; i++) {
      final a = t * 0.8 + e.a + i * math.pi / 2;
      final tip = hub + Offset(math.cos(a), math.sin(a)) * 26 * s;
      c.drawLine(hub, tip, _stroke(const Color(0xFF8B6B4A), 2.2 * s));
      final a2 = a + 0.25;
      final tip2 = hub + Offset(math.cos(a2), math.sin(a2)) * 22 * s;
      c.drawLine(hub + Offset(math.cos(a), math.sin(a)) * 8 * s, tip2,
          _stroke(const Color(0xFFFFFFFF), 3 * s));
    }
    c.drawCircle(hub, 3 * s, _fill(const Color(0xFF6B4423)));
  }

  static void _house(Canvas c, _El e, double p, double t, _Plan pl) {
    final s = e.s * p;
    if (s < 0.03) return;
    final two = e.k == 21;
    final wall = pl.houseColors[e.v % pl.houseColors.length];
    final roof = pl.roofColors[(e.v ~/ 3) % pl.roofColors.length];
    final w = 34 * s, h = (two ? 38 : 24) * s;
    c.drawOval(
        Rect.fromCenter(
            center: Offset(e.x, e.y + 2 * s), width: 46 * s, height: 9 * s),
        _fill(const Color(0x25000000)));
    // دودکش و دود
    if (e.v % 3 == 0) {
      final cx = e.x + w * 0.28;
      c.drawRect(Rect.fromLTWH(cx - 2.5 * s, e.y - h - 17 * s, 5 * s, 12 * s),
          _fill(const Color(0xFF8D6E63)));
      if (p > 0.95) {
        for (var q = 0; q < 3; q++) {
          final ph = (t * 0.35 + q / 3 + e.a) % 1.0;
          c.drawCircle(
              Offset(cx + math.sin(ph * 6 + e.a) * 3, e.y - h - 18 * s - ph * 26 * s),
              (2 + ph * 4) * s,
              _fill(Color.fromRGBO(190, 190, 195, (1 - ph) * 0.35)));
        }
      }
    }
    c.drawRect(Rect.fromLTWH(e.x - w / 2, e.y - h, w, h), _fill(wall));
    _path
      ..reset()
      ..moveTo(e.x - w / 2 - 4 * s, e.y - h)
      ..lineTo(e.x, e.y - h - 17 * s)
      ..lineTo(e.x + w / 2 + 4 * s, e.y - h)
      ..close();
    c.drawPath(_path, _fill(roof));
    c.drawRect(Rect.fromLTWH(e.x - 4 * s, e.y - 12 * s, 8 * s, 12 * s),
        _fill(const Color(0xFF7B4B2A)));
    final win = _fill(const Color(0xFFBFE3F5));
    c.drawRect(Rect.fromLTWH(e.x - w / 2 + 4 * s, e.y - 19 * s, 7 * s, 7 * s), win);
    c.drawRect(Rect.fromLTWH(e.x + w / 2 - 11 * s, e.y - 19 * s, 7 * s, 7 * s),
        _fill(const Color(0xFFBFE3F5)));
    if (two) {
      c.drawRect(
          Rect.fromLTWH(e.x - w / 2 + 4 * s, e.y - 33 * s, 7 * s, 7 * s),
          _fill(const Color(0xFFFFE9A8)));
      c.drawRect(
          Rect.fromLTWH(e.x + w / 2 - 11 * s, e.y - 33 * s, 7 * s, 7 * s),
          _fill(const Color(0xFFBFE3F5)));
    }
  }

  static void _tower(Canvas c, _El e, double p, double t) {
    final s = e.s * p;
    if (s < 0.03) return;
    final w = 28 * s, h = (62 + (e.v % 4) * 14) * s;
    c.drawOval(
        Rect.fromCenter(
            center: Offset(e.x, e.y + 2 * s), width: 40 * s, height: 8 * s),
        _fill(const Color(0x25000000)));
    c.drawRect(Rect.fromLTWH(e.x - w / 2, e.y - h, w, h),
        _fill(const Color(0xFF8FA3B8)));
    c.drawRect(Rect.fromLTWH(e.x - w / 2 - 2 * s, e.y - h - 4 * s, w + 4 * s, 5 * s),
        _fill(const Color(0xFF64748B)));
    final rows = (h / (12 * s)).floor() - 1;
    for (var i = 0; i < rows; i++) {
      for (var j = 0; j < 3; j++) {
        final lit = ((i * 7 + j * 13 + e.v) % 3) == 0;
        c.drawRect(
            Rect.fromLTWH(e.x - w / 2 + (3 + j * 8) * s, e.y - h + (6 + i * 12) * s,
                5 * s, 6 * s),
            _fill(lit ? const Color(0xFFFFE9A8) : const Color(0xFF3B556E)));
      }
    }
  }

  static void _barn(Canvas c, _El e, double p) {
    final s = e.s * p;
    if (s < 0.03) return;
    final w = 40 * s, h = 26 * s;
    c.drawOval(
        Rect.fromCenter(
            center: Offset(e.x, e.y + 2 * s), width: 52 * s, height: 9 * s),
        _fill(const Color(0x25000000)));
    c.drawRect(Rect.fromLTWH(e.x - w / 2, e.y - h, w, h),
        _fill(const Color(0xFFC2453B)));
    _path
      ..reset()
      ..moveTo(e.x - w / 2 - 3 * s, e.y - h)
      ..lineTo(e.x - w * 0.3, e.y - h - 14 * s)
      ..lineTo(e.x + w * 0.3, e.y - h - 14 * s)
      ..lineTo(e.x + w / 2 + 3 * s, e.y - h)
      ..close();
    c.drawPath(_path, _fill(const Color(0xFF7F2A24)));
    c.drawRect(Rect.fromLTWH(e.x - 7 * s, e.y - 16 * s, 14 * s, 16 * s),
        _fill(const Color(0xFFF3E9DC)));
    final x = _stroke(const Color(0xFFC2453B), 1.4 * s);
    c.drawLine(Offset(e.x - 7 * s, e.y - 16 * s), Offset(e.x + 7 * s, e.y), x);
    c.drawLine(Offset(e.x + 7 * s, e.y - 16 * s), Offset(e.x - 7 * s, e.y), x);
  }

  static void _pond(Canvas c, _El e, double p, double t) {
    final s = e.s * p;
    final w = 90 * s, h = 52 * s;
    final r = Rect.fromCenter(center: Offset(e.x, e.y), width: w, height: h);
    c.drawOval(r.inflate(3 * s), _fill(const Color(0x338BC48A)));
    c.drawOval(r, _fill(const Color(0xFF6EC1E4)));
    c.drawOval(r.deflate(7 * s), _fill(const Color(0xFF8AD3F0)));
    final rp = (t * 0.25 + e.a) % 1.0;
    c.drawOval(
        Rect.fromCenter(
            center: Offset(e.x - 8 * s, e.y - 2 * s),
            width: w * 0.5 * rp,
            height: h * 0.4 * rp),
        _stroke(Color.fromRGBO(255, 255, 255, (1 - rp) * 0.55), 1.2));
  }

  static void _field(Canvas c, _El e, double p) {
    final s = e.s * p;
    c.save();
    c.translate(e.x, e.y);
    c.rotate((e.v % 7 - 3) * 0.08);
    final w = 130 * s, h = 80 * s;
    final golden = e.v % 2 == 0;
    c.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: h),
        _fill(golden ? const Color(0x55E5C158) : const Color(0x558CCB6B)));
    final pa = _stroke(
        golden ? const Color(0x88C9A227) : const Color(0x884C9A3A), 1.6);
    for (var i = -3; i <= 3; i++) {
      c.drawLine(Offset(-w / 2, i * h / 7), Offset(w / 2, i * h / 7), pa);
    }
    c.restore();
  }

  static void _rainbow(Canvas c, _El e, double p) {
    const cols = [
      Color(0xFFFF6B6B), Color(0xFFFFA94D), Color(0xFFFFE066),
      Color(0xFF69DB7C), Color(0xFF4DABF7), Color(0xFF9775FA),
    ];
    final ce = Offset(e.x, e.y);
    for (var i = 0; i < cols.length; i++) {
      final r = (190 - i * 9) * e.s * p;
      c.drawArc(
          Rect.fromCircle(center: ce, radius: r),
          math.pi,
          math.pi,
          false,
          _stroke(cols[i].withAlpha(90), 7 * e.s, cap: StrokeCap.butt));
    }
  }

  static void _balloon(Canvas c, _El e, double p, double t) {
    final s = e.s * p;
    final ce = Offset(e.x + math.sin(t * 0.15 + e.a) * 60,
        e.y - 110 - math.sin(t * 0.1 + e.a) * 18);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(ce.dx, ce.dy + 70 * s), width: 30 * s, height: 8 * s),
        _fill(const Color(0x18000000)));
    c.drawOval(Rect.fromCenter(center: ce, width: 34 * s, height: 42 * s),
        _fill(const Color(0xFFE5484D)));
    c.drawOval(Rect.fromCenter(center: ce, width: 14 * s, height: 42 * s),
        _fill(const Color(0xFFFFD54F)));
    final pa = _stroke(const Color(0xFF6B4423), 1 * s);
    c.drawLine(ce + Offset(-8 * s, 20 * s), ce + Offset(-4 * s, 32 * s), pa);
    c.drawLine(ce + Offset(8 * s, 20 * s), ce + Offset(4 * s, 32 * s), pa);
    c.drawRect(Rect.fromLTWH(ce.dx - 5 * s, ce.dy + 32 * s, 10 * s, 7 * s),
        _fill(const Color(0xFF8B5A2B)));
  }

  static void _ufo(Canvas c, _El e, double p, double t) {
    final s = e.s * p;
    final ce = Offset(e.x + math.sin(t * 0.2 + e.a) * 120,
        e.y - 170 + math.sin(t * 0.7) * 6);
    _path
      ..reset()
      ..moveTo(ce.dx - 8 * s, ce.dy + 4 * s)
      ..lineTo(ce.dx - 26 * s, ce.dy + 70 * s)
      ..lineTo(ce.dx + 26 * s, ce.dy + 70 * s)
      ..lineTo(ce.dx + 8 * s, ce.dy + 4 * s)
      ..close();
    c.drawPath(_path, _fill(const Color(0x14B8F2FF)));
    c.drawOval(
        Rect.fromCenter(
            center: ce + Offset(0, -5 * s), width: 18 * s, height: 14 * s),
        _fill(const Color(0xAA9AE6FF)));
    c.drawOval(Rect.fromCenter(center: ce, width: 44 * s, height: 13 * s),
        _fill(const Color(0xFF94A3B8)));
    for (var i = -1; i <= 1; i++) {
      final on = ((t * 3).floor() + i) % 2 == 0;
      c.drawCircle(
          ce + Offset(i * 12 * s, 1 * s),
          1.7 * s,
          _fill(on ? const Color(0xFFFFE066) : const Color(0xFFE5484D)));
    }
  }

  static void _car(Canvas c, Offset pos, double ang, Color col) {
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(ang);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-9, -4.5, 18, 9), const Radius.circular(2.5)),
        _fill(col));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3, -3.4, 7, 6.8), const Radius.circular(1.6)),
        _fill(const Color(0xBBDFF3FF)));
    c.drawCircle(const Offset(-5, -4.7), 1.7, _fill(const Color(0xFF1F2937)));
    c.drawCircle(const Offset(5, -4.7), 1.7, _fill(const Color(0xFF1F2937)));
    c.drawCircle(const Offset(-5, 4.7), 1.7, _fill(const Color(0xFF1F2937)));
    c.drawCircle(const Offset(5, 4.7), 1.7, _fill(const Color(0xFF1F2937)));
    c.drawCircle(const Offset(9, 0), 1.3, _fill(const Color(0xFFFFE9A8)));
    c.restore();
  }

  static void _birds(Canvas c, double m, double t, Rect vv) {
    final n = math.min(9, 3 + (m / 80).floor());
    final pa = _stroke(const Color(0xFF475569), 1.4);
    for (var j = 0; j < n; j++) {
      final x = -1100 + ((t * 28 + j * 70) % 2200);
      final y = -330 + 110 * math.sin(t * 0.3 + j) - j * 16;
      if (!vv.contains(Offset(x, y))) continue;
      final f = math.sin(t * 8 + j * 1.7) * 4;
      c.drawLine(Offset(x - 7, y - f), Offset(x, y), pa);
      c.drawLine(Offset(x, y), Offset(x + 7, y - f), pa);
    }
  }

  static void _clouds(Canvas c, double m, double t, bool dark, Rect vv) {
    final n = math.min(6, 2 + (m / 120).floor());
    final col = dark
        ? const Color.fromRGBO(255, 255, 255, 0.10)
        : const Color.fromRGBO(190, 208, 226, 0.32);
    for (var i = 0; i < n; i++) {
      final x = -2100 + ((i * 617 + t * (6 + i * 1.7)) % 4200);
      final y = -420 - i * 140.0;
      if (!vv.contains(Offset(x, y))) continue;
      c.drawCircle(Offset(x, y), 26, _fill(col));
      c.drawCircle(Offset(x + 26, y + 6), 20, _fill(col));
      c.drawCircle(Offset(x - 26, y + 7), 19, _fill(col));
      c.drawOval(Rect.fromCenter(center: Offset(x, y + 12), width: 92, height: 22),
          _fill(col));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  رشدِ برگ روی تنه / شاخه / زیرشاخه
//  هر چه کاربر وقتِ بیشتری روی یک شاخه بگذارد، برگ‌های بیشتری روی مسیرش
//  (از نوکِ شاخه تا تنه‌ی هدف) درمی‌آید؛ تازه‌ترین برگ آهسته بزرگ می‌شود.
// ═══════════════════════════════════════════════════════════════════════════
void drawTrunkGrowth(
  Canvas c,
  Offset Function(double) at,
  double Function(double) tangent,
  String id,
  double minutes,
  double t, {
  double scale = 1.0,
}) {
  final nf = math.min(26.0, 0.35 * math.pow(minutes, 0.6));
  if (nf < 0.05) return;
  final n = nf.floor();
  final frac = nf - n;
  final off = seeded('tg-$id')();
  final vv = WorldLayer.view.inflate(40);
  final count = frac > 0.01 ? n + 1 : n;
  for (var i = 0; i < count; i++) {
    final g = i < n ? 1.0 : frac;
    final u = ((off + (i + 1) * 0.6180339887) % 1.0) * 0.86 + 0.07;
    final p = at(u);
    if (WorldLayer.view != Rect.zero && !vv.contains(p)) continue;
    final side = i.isEven ? 1.0 : -1.0;
    final a = tangent(u) + math.pi + side * (0.75 + 0.3 * math.sin(i * 1.7)) +
        math.sin(t * 1.1 + i * 0.9) * 0.08;
    final len = (7 + 5 * ((i * 37) % 10) / 10) * scale * _ease(g);
    if (len < 0.5) continue;
    final gr = _kGreens[i % 4];
    final dir = Offset(math.cos(a), math.sin(a));
    final nrm = Offset(-dir.dy, dir.dx);
    final tip = p + dir * len;
    final mid = p + dir * (len * 0.5);
    _path
      ..reset()
      ..moveTo(p.dx, p.dy)
      ..quadraticBezierTo(mid.dx + nrm.dx * len * 0.38,
          mid.dy + nrm.dy * len * 0.38, tip.dx, tip.dy)
      ..quadraticBezierTo(mid.dx - nrm.dx * len * 0.38,
          mid.dy - nrm.dy * len * 0.38, p.dx, p.dy)
      ..close();
    c.drawPath(_path, _fill(i.isEven ? gr[0] : gr[1]));
  }
}


// ═══════════════════════════════════════════════════════════════════════════
//  نمای اول‌شخص 🚶  (انگار خودِ کاربر روی جاده‌ی هدف راه می‌رود)
//  همان جاده، همان گیاه و خانه و ماشین‌های نقشه، ولی از چشمِ آدمی که روی جاده
//  ایستاده: افق، آسمان، تپه‌ها، چپ و راستِ جاده. ورودی: WalkLayer.prepare
// ═══════════════════════════════════════════════════════════════════════════

/// حالتِ دوربینِ نمای اول‌شخص (UI آن را تغییر می‌دهد و painter می‌خواند)
class WalkCam {
  double d = 0; // فاصله‌ی پیموده‌شده از ابتدای جاده
  double yaw = 0; // چرخشِ سر نسبت به جهتِ جاده (رادیان؛ آزاد، ۳۶۰ درجه)
  double pitch = 0; // نگاه به بالا (+) / پایین (-) (رادیان)
  double t = 0; // زمان بر حسبِ ثانیه
  double phase = 0; // فازِ قدم‌ها (برای تکانِ دوربین)
  bool walking = true;
  double dir = 1.0; // ۱ = به سمتِ هدف، ‎-۱ = برگشت به «من»
}

class WalkData {
  WalkData(this.gp, this.road, this.pal, this.gm, this.reach, this.paved,
      this.name, this.icon,
      [this.marks = const <WalkMark>[]]);

  /// ثبت‌های نقشه (غنچه/گل روزها) که کنارِ جاده دیده می‌شوند
  final List<WalkMark> marks;

  /// جای نشانه‌ها روی صفحه در آخرین فریم (برای لمسِ طولانی)
  final List<WalkHit> hits = <WalkHit>[];
  final _GPlan gp;
  final _RoadPoly road;
  final _Plan pal;
  final double gm, reach, paved;
  final String name, icon;
  TextPainter? _iconTp;

  /// نمای «دنبالِ پاهای یک شاخه»: مسیرِ دوربین (از جاده‌ی اصلی تا سرِ شاخه).
  /// اگر null باشد دوربین روی خودِ جاده‌ی هدف راه می‌رود (رفتارِ قبلی).
  _RoadPoly? camRoad;

  /// فاصله‌ی روی [camRoad] که از آن‌جا جاده‌ی شاخه (نه جاده‌ی اصلی) شروع می‌شود
  double branchFrom = 0;
  Color branchColor = const Color(0xFFF2B33D);

  /// رفت و برگشتِ بی‌پایان (مثلِ انیمیشنِ پا)
  bool loop = false;

  /// شناسه‌ی هدف و (در نمای شاخه) شاخه؛ برای هماهنگیِ پاهای نمای ۳بعدی
  String goalId = '';
  String? branchId;

  bool get isBranch => camRoad != null;

  double get length => (camRoad ?? road).length;

  /// جای شروعِ دوربین (در نمای شاخه: کمی قبل از محلِ پیچیدن به شاخه)
  double startD = 0;

  /// آیکونِ هدفِ اصلی (برای تابلوی انتهای جاده‌ی اصلی در نمای شاخه)
  String goalIcon = '🎯';
  TextPainter? _goalTp;

  /// شاخه‌ها و زیرشاخه‌های هدف، همان‌طور که روی نقشه کنارِ جاده‌اند
  final List<_WalkSide> sides = <_WalkSide>[];

  /// کمترین جایی که می‌شود رفت: قدم‌زنِ نقشه روی جاده‌ی اصلی بین ۶٪ تا ۹۴٪ می‌رود
  double get minD => (!isBranch && loop) ? road.length * 0.06 : 0.0;

  /// دورترین جایی که می‌شود رفت (کمی مانده به تابلوی هدف / سرِ شاخه)
  double get maxD => isBranch
      ? math.max(0.0, camRoad!.length - 45.0)
      : (loop
          ? math.max(minD, road.length * 0.94)
          : math.max(0.0, road.length - 110.0));
}

/// یک شاخه/زیرشاخه‌ی کنارِ جاده در نمای اول‌شخص
class _WalkSide {
  _WalkSide(this.id, this.poly, this.color, this.name);
  final String id;
  final _RoadPoly poly;
  final Color color;
  final String name;
  TextPainter? tp;
}

class WalkLayer {
  /// خط‌وسطِ دقیقِ جاده‌ی کشیده‌شده‌ی یک هدف (از ابتدا تا انتهای آسفالت)؛
  /// قدم‌زنِ هدف روی همین مسیر راه می‌رود تا بیرونِ جاده نیفتد.
  static List<Offset>? roadRoute(MapState s, Goal g) {
    if (s.extra['worldOff'] == true) return null; // جاده کشیده نمی‌شود
    var seed = 0;
    final sv = s.extra['worldSeed'];
    if (sv is num) {
      seed = sv.toInt();
    } else {
      seed = math.Random().nextInt(1 << 30) + 1;
      s.extra['worldSeed'] = seed;
    }
    if (WorldLayer._plan == null || WorldLayer._planSeed != seed) {
      WorldLayer._plan = _buildPlan(seed);
      WorldLayer._planSeed = seed;
      WorldLayer._gPlans.clear();
    }
    final gp = WorldLayer._gPlans
        .putIfAbsent(g.id, () => _genGoalPlan(g.id, seed));
    final cp = geo.trunkControlPoints(g, s.me);
    final road = _RoadPoly.build(cp, gp.side * 30.0, gp);
    if (road == null) return null;
    final out = <Offset>[road.pos(0)];
    for (var i = 1; i < road.pts.length; i++) {
      final d = road.cum[i] - _RoadPoly.start;
      if (d <= 0) continue;
      if (d >= road.length) break;
      out.add(road.pts[i]);
    }
    out.add(road.pos(road.length));
    return out;
  }

  /// نقاطِ موازیِ جاده‌ی یک هدف (۶۴ نقطه از «من» تا هدف) با فاصله‌ی [off]
  /// از خط‌وسطِ جاده؛ [off] مثبت یک سمت و منفی سمتِ دیگر.
  /// برای اینکه شاخه‌ها کنارِ جاده شروع شوند، نه روی آن.
  static List<Offset>? roadSidePoints(MapState s, Goal g, double off) {
    var seed = 0;
    final sv = s.extra['worldSeed'];
    if (sv is num) {
      seed = sv.toInt();
    } else {
      seed = math.Random().nextInt(1 << 30) + 1;
      s.extra['worldSeed'] = seed;
    }
    if (WorldLayer._plan == null || WorldLayer._planSeed != seed) {
      WorldLayer._plan = _buildPlan(seed);
      WorldLayer._planSeed = seed;
      WorldLayer._gPlans.clear();
    }
    final gp = WorldLayer._gPlans
        .putIfAbsent(g.id, () => _genGoalPlan(g.id, seed));
    final cp = geo.trunkControlPoints(g, s.me);
    final road = _RoadPoly.build(cp, gp.side * 30.0, gp);
    if (road == null) return null;
    final pts = road.pts;
    final out = <Offset>[];
    for (var i = 0; i < pts.length; i++) {
      final a = pts[math.max(0, i - 1)];
      final b = pts[math.min(pts.length - 1, i + 1)];
      final v = b - a;
      final ang = v.distance < 0.001 ? 0.0 : math.atan2(v.dy, v.dx);
      out.add(pts[i] + Offset(-math.sin(ang), math.cos(ang)) * off);
    }
    return out;
  }

  static WalkData? prepare(MapState s, Goal g) {
    WorldLayer._minMs = 0;
    WorldLayer._refresh(s);
    var seed = 0;
    final sv = s.extra['worldSeed'];
    if (sv is num) {
      seed = sv.toInt();
    } else {
      seed = math.Random().nextInt(1 << 30) + 1;
      s.extra['worldSeed'] = seed;
    }
    if (WorldLayer._plan == null || WorldLayer._planSeed != seed) {
      WorldLayer._plan = _buildPlan(seed);
      WorldLayer._planSeed = seed;
      WorldLayer._gPlans.clear();
    }
    final gp = WorldLayer._gPlans
        .putIfAbsent(g.id, () => _genGoalPlan(g.id, seed));
    final cp = geo.trunkControlPoints(g, s.me);
    final road = _RoadPoly.build(cp, gp.side * 30.0, gp);
    if (road == null) return null;
    final gm = WorldLayer._goalMin[g.id] ?? 0.0;
    // جاده همان لحظه‌ی ثبتِ هدف کامل و آسفالت‌شده است
    final reach = road.length;
    final paved = road.length;
    final marks = List<WalkMark>.of(
        layoutWalkMarks(collectWalkMarks(s, g), road.length));
    marks.addAll(_otherMarks(s, g));
    // جای هر غنچه/گل همان جای نقشه است؛ کارتِ توضیح فقط وقتی کنارش رد می‌شوی
    for (final m in marks) {
      final wp = m.wpos;
      if (wp == null) continue;
      final pr = road.project(wp);
      m.sd = pr.dist < 40 ? pr.d : -1e6;
    }
    final data = WalkData(gp, road, WorldLayer._plan!, gm, reach, paved, g.name,
        g.icon.isEmpty ? '🎯' : g.icon, marks);
    // مثلِ قدم‌زنِ نقشه: روی جاده‌ی اصلی رفت و برگشتِ بی‌پایان
    data.loop = true;
    data.goalId = g.id;
    data.goalIcon = data.icon;
    data.sides.addAll(_sideBranches(g));
    data.sides.addAll(_otherGoals(s, g));
    return data;
  }

  /// بقیه‌ی هدف‌های نقشه (جاده‌ی هر کدام + شاخه‌هایشان) تا همه‌چیز نقشه در نمای
  /// راه‌رفتن هم دیده شود
  static List<_WalkSide> _otherGoals(MapState s, Goal g) {
    final out = <_WalkSide>[];
    for (final o in s.goals) {
      if (o.id == g.id) continue;
      final r = roadRoute(s, o);
      if (r != null && r.length >= 2) {
        final poly = _RoadPoly.fromPath(r);
        if (poly != null) {
          out.add(_WalkSide(
              o.id, poly, hexColor(o.color ?? '', const Color(0xFFF2B33D)),
              o.name.isEmpty ? 'هدف' : o.name));
        }
      }
      out.addAll(_sideBranches(o));
    }
    return out;
  }

  /// غنچه/گل‌های بقیه‌ی هدف‌ها، سرِ جای خودشان روی نقشه
  static List<WalkMark> _otherMarks(MapState s, Goal g) {
    final out = <WalkMark>[];
    for (final o in s.goals) {
      if (o.id == g.id) continue;
      for (final m in collectWalkMarks(s, o)) {
        if (m.wpos == null) continue;
        m.sd = -1e6;
        out.add(m);
      }
    }
    return out;
  }

  /// همه‌ی شاخه/زیرشاخه‌های هدف (به شکلِ جاده‌ی کوچک) از روی آخرین رسمِ نقشه
  static List<_WalkSide> _sideBranches(Goal g, {String? skipId}) {
    final reg = HitRegistry.current;
    final out = <_WalkSide>[];
    if (reg == null) return out;
    void walk(List<ActionNode> list) {
      for (final a in list) {
        final tw = reg.twigs[a.id];
        if (tw != null && a.id != skipId && tw.pts.length >= 2) {
          final poly = _RoadPoly.fromPath(tw.pts.reversed.toList());
          if (poly != null) out.add(_WalkSide(a.id, poly, tw.color, tw.name));
        }
        walk(a.children);
      }
    }

    walk(g.actions);
    return out;
  }

  /// نمای اول‌شخص از چشمِ پاهای یک شاخه: دوربین از جاده‌ی اصلی (کمی قبل از
  /// محلِ اتصال) وارد شاخه می‌شود، تا سرِ شاخه می‌رود و برمی‌گردد.
  /// [route] همان مسیرِ قدم‌زنِ شاخه روی نقشه است (نوکِ شاخه ← … ← جاده‌ی اصلی).
  static WalkData? prepareBranch(
      MapState s, Goal g, ActionNode a, List<Offset> route) {
    final base = prepare(s, g);
    if (base == null) return null;
    final rv = <Offset>[];
    for (final q in route.reversed) {
      if (rv.isEmpty || (q - rv.last).distance > 0.5) rv.add(q);
    }
    if (rv.length < 2) return null;
    // کلِ مسیری که پا روی نقشه می‌رود (هدف ← جاده‌ی اصلی ← سرِ شاخه) برای دوربین
    // ساخته می‌شود، نه فقط چند قدمِ قبل از شاخه
    final cr = _RoadPoly.fromPath(rv);
    if (cr == null) return null;
    // جایی که مسیر از خط‌وسطِ جاده‌ی اصلی جدا می‌شود (دوربین کمی قبل‌ترش شروع می‌کند)
    var jd = -1.0;
    for (var d = 0.0; d <= cr.length; d += 3.0) {
      if (base.road.project(cr.pos(d)).dist > 2.5) {
        jd = d;
        break;
      }
    }
    if (jd < 0) return null;

    // جایی که جاده‌ی شاخه (جدا از جاده‌ی اصلی) شروع می‌شود
    var from = cr.length;
    for (var d = 0.0; d <= cr.length; d += 3.0) {
      if (base.road.project(cr.pos(d)).dist >= 19.0) {
        from = d;
        break;
      }
    }

    // ثبت‌های همین شاخه و همه‌ی زیرشاخه‌هایش کنارِ مسیرش (قدیمی‌ترین نزدیکِ جاده‌ی اصلی)
    final ids = <String>{a.id};
    void addIds(ActionNode n) {
      for (final c in n.children) {
        ids.add(c.id);
        addIds(c);
      }
    }

    addIds(a);
    final mine = collectWalkMarks(s, g)
        .where((m) => ids.contains(m.actionId) || m.wpos != null)
        .toList();
    // آن‌هایی که جایشان روی نقشه معلوم است دقیقاً همان‌جا؛ بقیه مثلِ قبل کنارِ مسیر
    final placed = mine.where((m) => m.wpos != null).toList();
    for (final m in placed) {
      final pr = cr.project(m.wpos!);
      m.sd = pr.dist < 60 ? pr.d : -1e6;
    }
    final lb = cr.length - from;
    var keep = mine
        .where((m) => m.wpos == null && ids.contains(m.actionId))
        .toList();
    final cap = math.max(1, ((lb - 70) / 26).floor() + 1);
    if (keep.length > cap) keep = keep.sublist(keep.length - cap);
    final lo = from + 28.0;
    final hi = math.max(lo, cr.length - 60.0);
    final gap = keep.length <= 1
        ? 0.0
        : ((hi - lo) / (keep.length - 1)).clamp(26.0, 90.0).toDouble();
    // مثلِ نقشه: قدیمی‌ترین ثبت نزدیکِ نوکِ شاخه (جایی که پا شروع می‌کند) و
    // جدیدترین به سمتِ جاده‌ی اصلی؛ در برگشت همین ترتیب طبیعتاً وارونه دیده می‌شود
    for (var i = 0; i < keep.length; i++) {
      final m = keep[i];
      m.sd = math.max(lo, math.min(hi - gap * i, cr.length - 40.0));
      m.side = ((m.seed >> 3) & 1) == 0 ? 1.0 : -1.0;
      if (i > 0 && keep[i - 1].side == m.side && (m.seed & 3) != 0) {
        m.side = -m.side;
      }
    }
    keep = [...placed, ...keep, ..._otherMarks(s, g)];

    final gName = g.name.isEmpty ? 'هدف' : g.name;
    final data = WalkData(
        base.gp,
        base.road,
        base.pal,
        base.gm,
        base.reach,
        base.paved,
        a.text.trim().isEmpty ? gName : '$gName › ${a.text.trim()}',
        '🌱',
        keep);
    data.camRoad = cr;
    data.goalId = g.id;
    data.branchId = a.id;
    data.branchFrom = from;
    // رفت‌وبرگشت فقط روی خودِ شاخه: از کمی قبل از محلِ اتصال تا سرِ شاخه
    data.startD = math.max(0.0, jd - 30.0);
    data.goalIcon = base.icon;
    data.sides.addAll(_sideBranches(g, skipId: a.id));
    data.sides.addAll(_otherGoals(s, g));
    data.loop = true;
    final c0 = (a.color != null && a.color!.isNotEmpty)
        ? a.color
        : (g.color ?? '');
    data.branchColor = hexColor(c0, const Color(0xFFF2B33D));
    return data;
  }
}

class _WItem {
  _WItem(this.type, this.f, this.sx, this.sy, this.sc);
  final int type; // ۰ المان ۱ ماشین ۲ تابلوی هدف ۳ ثبتِ نقشه ۴ تابلوی شاخه‌ی کناری ۵ تابلوی هدفِ اصلی
  final double f, sx, sy, sc;
  _El? e;
  WalkMark? m;
  _WalkSide? sb;
  double p = 1.0;
  Color col = const Color(0xFFE5484D);
  bool onc = false;
}

class WalkPainter extends CustomPainter {
  WalkPainter(this.data, this.cam, this.dark, Listenable repaint)
      : super(repaint: repaint);
  final WalkData data;
  final WalkCam cam;
  final bool dark;

  // دوربین
  double _cpx = 0, _cpy = 0, _dx = 1, _dy = 0, _rx = 0, _ry = 1;
  double _focal = 1, _cx = 0, _hor = 0, _camH = 17;
  // خروجیِ _pr
  double _f = 0, _x = 0, _y = 0, _r = 0;

  static final Paint _flat = Paint()..isAntiAlias = false;

  // نزدیک‌ترین عمقی که رسم می‌شود (چندضلعی‌های جاده روی این صفحه بریده می‌شوند)
  static const double _near = 3.0;
  final List<double> _qf = List<double>.filled(4, 0.0);
  final List<double> _qr = List<double>.filled(4, 0.0);

  /// فقط عمق (_f) و فاصله‌ی چپ/راست (_r) را نسبت به دوربین حساب می‌کند
  /// (بدونِ حذفِ نقطه‌های پشتِ دوربین؛ برای دیدِ ۳۶۰ درجه)
  void _cam(Offset p) {
    final rx = p.dx - _cpx, ry = p.dy - _cpy;
    _f = rx * _dx + ry * _dy;
    _r = rx * _rx + ry * _ry;
  }

  void _pr(Offset p) {
    final rx = p.dx - _cpx, ry = p.dy - _cpy;
    _f = rx * _dx + ry * _dy;
    if (_f < 0.01) {
      _x = 0;
      _y = 0;
      return;
    }
    final r = rx * _rx + ry * _ry;
    _x = _cx + r / _f * _focal;
    _y = _hor + _camH * _focal / _f;
  }

  double _gk(double sd) {
    if (sd > data.reach) return 0.0;
    final k = _ease((data.gm - _hr(3 + 0.02 * sd)) / _hr(70));
    return 0.9 * k * (0.75 + 0.25 * math.sin(sd * 0.013 + data.gp.wobP1));
  }

  void _quad(Canvas c, List<double> sf, List<double> sr, int i, int a, int b,
      Color col) {
    const w = 10;
    final i0 = i * w, i1 = (i + 1) * w;
    _qf[0] = sf[i0 + a];
    _qf[1] = sf[i0 + b];
    _qf[2] = sf[i1 + b];
    _qf[3] = sf[i1 + a];
    if (_qf[0] < _near && _qf[1] < _near && _qf[2] < _near && _qf[3] < _near) {
      return; // کاملاً پشتِ دوربین
    }
    _qr[0] = sr[i0 + a];
    _qr[1] = sr[i0 + b];
    _qr[2] = sr[i1 + b];
    _qr[3] = sr[i1 + a];
    _path.reset();
    var started = false;
    for (var k = 0; k < 4; k++) {
      final k2 = (k + 1) % 4;
      final fa = _qf[k], fb = _qf[k2];
      final ina = fa >= _near, inb = fb >= _near;
      if (ina) {
        final x = _cx + _qr[k] / fa * _focal;
        final y = _hor + _camH * _focal / fa;
        if (started) {
          _path.lineTo(x, y);
        } else {
          _path.moveTo(x, y);
          started = true;
        }
      }
      if (ina != inb) {
        final t = (_near - fa) / (fb - fa);
        final rr = _qr[k] + (_qr[k2] - _qr[k]) * t;
        final x = _cx + rr / _near * _focal;
        final y = _hor + _camH * _focal / _near;
        if (started) {
          _path.lineTo(x, y);
        } else {
          _path.moveTo(x, y);
          started = true;
        }
      }
    }
    if (!started) return;
    _path.close();
    c.drawPath(_path, _flat..color = col);
  }

  void _haze(Canvas c, double w, double hor, double yLim, double alpha,
      Color col) {
    final top = hor - 220;
    final stop = (hor - top) / (yLim - top);
    final r = Rect.fromLTRB(0, top, w, yLim);
    c.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, yLim), [
            col.withValues(alpha: 0.0),
            col.withValues(alpha: alpha),
            col.withValues(alpha: 0.0),
          ], [
            0.0,
            stop.clamp(0.05, 0.95).toDouble(),
            1.0
          ]));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final road = data.road;
    final L = road.length;
    // نمای شاخه: دوربین روی مسیرِ شاخه می‌رود؛ وگرنه روی خودِ جاده‌ی هدف
    final bm = data.isBranch;
    final cr = data.camRoad ?? road;
    final Lc = cr.length;
    _focal = w * 0.95;
    _cx = w / 2;
    final pitch = cam.pitch.clamp(-0.6, 0.6).toDouble();
    _hor = (h * 0.40 + pitch * _focal).clamp(40.0, h * 0.95).toDouble();
    final dc = cam.d.clamp(0.0, Lc).toDouble();
    // فاصله‌ی معادل روی جاده‌ی اصلی (برای سبزی و نمونه‌برداریِ جاده)؛
    // در نمای معمولی همان dc است
    final d = bm ? road.project(cr.pos(dc)).d.clamp(0.0, L).toDouble() : dc;

    // ── دوربین: روی جاده، کمی سمتِ راست؛ نگاه به جهتِ حرکت ──
    final c0 = cr.pos(dc);
    final pA = cr.pos(math.max(0.0, dc - 16));
    final pB = cr.pos(math.min(Lc, dc + 16));
    final rv = pB - pA;
    final roadYaw = rv.distance < 0.01 ? 0.0 : math.atan2(rv.dy, rv.dx);
    final fwd = cam.dir >= 0 ? 1.0 : -1.0;
    final face = cam.dir >= 0 ? roadYaw : roadYaw + math.pi;
    final bob = cam.walking ? math.sin(cam.phase) * 0.55 : 0.0;
    final sway = cam.walking ? math.cos(cam.phase * 0.5) * 0.8 : 0.0;
    final nr = Offset(-math.sin(roadYaw), math.cos(roadYaw));
    final cp = c0 + nr * (((bm ? 2.5 : 5.0) + sway) * fwd);
    final yaw = face + cam.yaw;
    _cpx = cp.dx;
    _cpy = cp.dy;
    _dx = math.cos(yaw);
    _dy = math.sin(yaw);
    _rx = -math.sin(yaw);
    _ry = math.cos(yaw);
    _camH = 17.0 + bob;
    final hor = _hor, focal = _focal, cx = _cx;

    final G = _ease(data.gm / _hr(200)); // سبزیِ کلیِ هدف

    // ── آسمان ──
    final skyTop = dark ? const Color(0xFF0B1226) : const Color(0xFF86C1EE);
    final skyLow = dark ? const Color(0xFF2B3558) : const Color(0xFFEAF4FB);
    canvas.drawRect(
        Rect.fromLTRB(0, 0, w, hor + 2),
        Paint()
          ..shader = ui.Gradient.linear(
              Offset.zero, Offset(0, hor), [skyTop, skyLow]));
    if (dark) {
      for (var i = 0; i < 40; i++) {
        final a = i * 2.399;
        final x = cx + (((a * 1.7 - yaw + math.pi) % (2 * math.pi)) - math.pi) *
            focal;
        final y = (math.sin(i * 12.9898) * 0.5 + 0.5) * hor * 0.85;
        if (x < 0 || x > w) continue;
        canvas.drawCircle(Offset(x, y), 0.9,
            _fill(const Color(0xAAFFFFFF)));
      }
    } else {
      final sunX = cx + (((-0.55 - yaw + math.pi) % (2 * math.pi)) - math.pi) *
          focal;
      if (sunX > -60 && sunX < w + 60) {
        canvas.drawCircle(Offset(sunX, hor * 0.42), 44,
            _fill(const Color(0x33FFE9A8)));
        canvas.drawCircle(Offset(sunX, hor * 0.42), 24,
            _fill(const Color(0xFFFFF1B8)));
      }
    }
    // ابرها
    final cloud = dark
        ? const Color.fromRGBO(255, 255, 255, 0.07)
        : const Color.fromRGBO(255, 255, 255, 0.75);
    for (var i = 0; i < 6; i++) {
      final a = i * 1.07 + cam.t * 0.004;
      final x = cx + (((a - yaw + math.pi) % (2 * math.pi)) - math.pi) * focal;
      if (x < -160 || x > w + 160) continue;
      final y = hor * (0.16 + 0.11 * (i % 3));
      final k = 0.8 + 0.2 * (i % 2);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 150 * k, height: 26 * k),
          _fill(cloud));
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x + 26 * k, y - 10 * k),
              width: 70 * k,
              height: 24 * k),
          _fill(cloud));
    }

    // ── تپه‌ها / تپه‌ماهورِ دور ──
    void hills(double amp, double k, double ph, double par, Color col) {
      _path.reset();
      _path.moveTo(0, hor + 3);
      for (var x = 0.0; x <= w + 16; x += 16) {
        final a = yaw * par + (x - cx) / focal;
        final y = hor -
            amp *
                (0.5 +
                    0.5 * math.sin(a * k + ph) +
                    0.3 * math.sin(a * k * 2.3 + ph * 1.7));
        _path.lineTo(x, y);
      }
      _path.lineTo(w + 16, hor + 3);
      _path.close();
      canvas.drawPath(_path, _fill(col));
    }

    final h1 = Color.lerp(
        dark ? const Color(0xFF3A3A4D) : const Color(0xFFD9C3A5),
        dark ? const Color(0xFF284A47) : const Color(0xFFA9CFA0),
        G)!;
    final h2 = Color.lerp(
        dark ? const Color(0xFF45402F) : const Color(0xFFCDB48F),
        dark ? const Color(0xFF2B5A3C) : const Color(0xFF86B97A),
        G)!;
    hills(34, 3.1, data.gp.wobP1, 1.0, h1);
    hills(20, 5.3, data.gp.wobP2, 1.0, h2);

    // ── زمینِ پایه ──
    final sand = dark ? const Color(0xFF6B5E43) : const Color(0xFFE6D3A8);
    final grass = dark ? const Color(0xFF2F6B3F) : const Color(0xFF7FBF6A);
    canvas.drawRect(Rect.fromLTRB(0, hor, w, h),
        _fill(Color.lerp(sand, grass, _gk(d))!));

    // ── نمونه‌های جاده (هم جلو و هم پشتِ سر؛ برای چرخشِ ۳۶۰ درجه) ──
    final ss = <double>[];
    var s = math.max(0.0, d - 1100);
    final sEnd = math.min(L, d + 1100);
    while (s < sEnd) {
      ss.add(s);
      s += 6.0 + (s - d).abs() * 0.05;
    }
    ss.add(sEnd);
    final n = ss.length;
    const W = 10;
    final sf = List<double>.filled(n * W, 0.0);
    final sr = List<double>.filled(n * W, 0.0);
    for (var i = 0; i < n; i++) {
      final si = ss[i];
      final a = road.pos(math.max(0.0, si - 2));
      final b = road.pos(math.min(L, si + 2));
      var tv = b - a;
      final tl = tv.distance;
      tv = tl < 1e-6 ? const Offset(1, 0) : tv / tl;
      final nrm = Offset(-tv.dy, tv.dx);
      final cpos = road.pos(si);
      final hw = si <= data.paved ? 15.0 : 13.0;
      final offs = [
        -450.0,
        -(hw + 7),
        -hw,
        -(hw - 1.7),
        -1.1,
        1.1,
        hw - 1.7,
        hw,
        hw + 7,
        450.0
      ];
      for (var j = 0; j < W; j++) {
        _cam(cpos + nrm * offs[j]);
        sf[i * W + j] = _f;
        sr[i * W + j] = _r;
      }
    }

    // کنارِ جاده: بیابان ← سبزی (آهسته و تکه‌تکه)
    for (var i = 0; i < n - 1; i++) {
      final si = ss[i];
      final stripe = ((si / 45).floor() % 2 == 0) ? 0.035 : -0.035;
      var g = Color.lerp(sand, grass, _gk(si))!;
      g = stripe > 0
          ? Color.lerp(g, Colors.white, stripe)!
          : Color.lerp(g, Colors.black, -stripe)!;
      _quad(canvas, sf, sr, i, 0, 1, g);
      _quad(canvas, sf, sr, i, 8, 9, g);
    }
    // لبه‌ی جاده، خودِ جاده و خطِ وسط
    for (var i = 0; i < n - 1; i++) {
      final si = ss[i];
      // جاده همیشه آسفالت است: شانه، بدنه، خطِ سفیدِ کنار و خط‌چینِ زردِ وسط
      final verge = dark ? const Color(0xFF8A8F98) : const Color(0xFFC9CDD3);
      final body = dark ? const Color(0xFF3F4452) : const Color(0xFF5B6270);
      _quad(canvas, sf, sr, i, 1, 2, verge);
      _quad(canvas, sf, sr, i, 7, 8, verge);
      _quad(canvas, sf, sr, i, 3, 6, body);
      _quad(canvas, sf, sr, i, 2, 3, const Color(0xEEFFFFFF));
      _quad(canvas, sf, sr, i, 6, 7, const Color(0xEEFFFFFF));
      if ((si / 26).floor() % 2 == 0) {
        _quad(canvas, sf, sr, i, 4, 5, const Color(0xFFFFD54F));
      }
    }

    // جاده‌ی شاخه (فقط در نمای شاخه): از لبه‌ی جاده‌ی اصلی تا سرِ شاخه
    if (bm) _branchStrip(canvas, cr, dc);
    // بقیه‌ی شاخه/زیرشاخه‌ها هم مثلِ نقشه کنارِ جاده دیده می‌شوند
    for (final sb in data.sides) {
      final pr = sb.poly.project(cp);
      if (pr.dist > 1100) continue;
      _strip(canvas, sb.poly, 0.0, pr.d, sb.color);
    }

    // مه‌ی افق
    final hazeCol = dark ? const Color(0xFF2B3558) : const Color(0xFFF4EBD8);
    canvas.drawRect(
        Rect.fromLTRB(0, hor - 30, w, hor + 120),
        Paint()
          ..shader = ui.Gradient.linear(
              Offset(0, hor - 30), Offset(0, hor + 120), [
            hazeCol.withValues(alpha: 0.0),
            hazeCol.withValues(alpha: 0.55),
            hazeCol.withValues(alpha: 0.0)
          ], const [
            0.0,
            0.25,
            1.0
          ]));

    // ── چیزهای کنارِ جاده (از دور به نزدیک) ──
    final items = <_WItem>[];
    data.hits.clear();
    final pal = data.pal;
    for (final e in data.gp.els) {
      if (e.k == 5 || e.k == 12) continue;
      if (data.gm < e.at) continue;
      if (e.k == 10) {
        if (e.sd > data.paved - 6) continue;
      } else if (e.sd > data.reach - 6) {
        continue;
      }
      final a = road.ang(e.sd);
      final pos = road.pos(e.sd) + Offset(-math.sin(a), math.cos(a)) * e.off;
      _pr(pos);
      if (_f < 12 || _f > 1000) continue;
      final sc = focal / _f;
      final half = 30 * e.s * sc;
      if (_x < -half || _x > w + half) continue;
      if (_y < hor - 2) continue;
      final p = _ease((data.gm - e.at) / _rampMin(e.k));
      if (p < 0.02) continue;
      final it = _WItem(0, _f, _x, _y, sc);
      it.e = _El(e.k, _x, _y, e.s * sc, e.at, e.v, e.a);
      it.p = p;
      items.add(it);
    }
    // ماشین‌ها
    if (data.paved > 140 && data.gm > _hr(200)) {
      final nCar = math.min(4, (data.paved / 280).floor());
      for (var c = 0; c < nCar; c++) {
        final hsh =
            ((math.sin(c * 12.9898 + data.gp.wobP1) * 43758.5453) % 1.0).abs();
        final speed = 38 + hsh * 40;
        final dr = c.isEven ? 1.0 : -1.0;
        var dd = (hsh * 1000 + cam.t * speed * dr) % data.paved;
        if (dd < 0) dd += data.paved;
        final a = road.ang(dd);
        final pos = road.pos(dd) +
            Offset(-math.sin(a), math.cos(a)) * (dr > 0 ? 7.0 : -7.0);
        _pr(pos);
        if (_f < 8 || _f > 900) continue;
        final it = _WItem(1, _f, _x, _y, focal / _f);
        it.col = pal.carColors[c % pal.carColors.length];
        final hd = dr > 0 ? a : a + math.pi;
        it.onc = math.cos(hd) * _dx + math.sin(hd) * _dy < 0;
        items.add(it);
      }
    }
    // ثبت‌های نقشه: غنچه/گلِ هر روزِ انجام‌شده، کنارِ جاده به ترتیبِ تاریخ
    final hwAll = 15.0 + 7.0;
    for (final m in data.marks) {
      final Offset pos;
      if (m.wpos != null) {
        pos = m.wpos!; // همان جایی که روی نقشه است
      } else {
        final a = cr.ang(m.sd);
        pos = cr.pos(m.sd) +
            Offset(-math.sin(a), math.cos(a)) *
                ((bm ? 20.0 : (hwAll + 14.0)) * m.side);
      }
      _pr(pos);
      if (_f < 6 || _f > 700) continue;
      final sc = focal / _f;
      if (_x < -90 * sc || _x > w + 90 * sc) continue;
      if (_y < hor - 2) continue;
      final it = _WItem(3, _f, _x, _y, sc);
      it.m = m;
      items.add(it);
    }
    // تابلوی نامِ شاخه‌های کناری (سرِ هر شاخه)
    for (final sb in data.sides) {
      final pos = sb.poly.pos(sb.poly.length);
      _pr(pos);
      if (_f < 12 || _f > 650) continue;
      if (_x < -140 || _x > w + 140) continue;
      if (_y < hor - 2) continue;
      final it = _WItem(4, _f, _x, _y, focal / _f);
      it.sb = sb;
      items.add(it);
    }
    // در نمای شاخه: تابلوی هدفِ اصلی هم سرِ جاده‌ی اصلی دیده می‌شود
    if (bm) {
      _pr(road.pos(L));
      if (_f > 10 && _f < 1400) {
        items.add(_WItem(5, _f, _x, _y, focal / _f));
      }
    }
    // تابلوی هدف (در نمای شاخه: تابلوی سرِ شاخه)
    {
      final a = cr.ang(Lc);
      final pos = cr.pos(Lc) + Offset(-math.sin(a), math.cos(a)) * 0.0;
      _pr(pos);
      if (_f > 10 && _f < 1400) {
        items.add(_WItem(2, _f, _x, _y, focal / _f));
      }
    }
    items.sort((a, b) => b.f.compareTo(a.f));

    var hz1 = false, hz2 = false;
    for (final it in items) {
      if (!hz1 && it.f < 520) {
        hz1 = true;
        _haze(canvas, w, hor, hor + _camH * focal / 520, 0.40, hazeCol);
      }
      if (!hz2 && it.f < 260) {
        hz2 = true;
        _haze(canvas, w, hor, hor + _camH * focal / 260, 0.28, hazeCol);
      }
      if (it.type == 0) {
        _drawSprite(canvas, it.e!, it.p, cam.t, pal);
      } else if (it.type == 1) {
        _carBB(canvas, it.sx, it.sy, it.sc, it.col, it.onc);
      } else if (it.type == 3) {
        // نوشته‌ها فقط وقتی نزدیک‌ایم دیده می‌شوند (۳۴۰ → ۱۸۰ واحد: کم‌کم پدیدار)
        final near = _c01((340 - it.f) / 160);
        drawWalkMark(canvas, it.m!, it.sx, it.sy, it.sc, cam.t, dark, near);
        data.hits.add(WalkHit(
            it.m!,
            Rect.fromLTRB(it.sx - 16 * it.sc, it.sy - 46 * it.sc,
                    it.sx + 16 * it.sc, it.sy + 4 * it.sc)
                .inflate(10),
            it.sc));
      } else if (it.type == 4) {
        _branchSign(canvas, it.sx, it.sy, it.sc, it.sb!);
      } else if (it.type == 5) {
        var gtp = data._goalTp;
        if (gtp == null) {
          gtp = _emojiTp(data.goalIcon);
          data._goalTp = gtp;
        }
        _goalSign(canvas, it.sx, it.sy, it.sc, gtp);
      } else {
        var tp = data._iconTp;
        if (tp == null) {
          tp = _emojiTp(data.icon);
          data._iconTp = tp;
        }
        _goalSign(canvas, it.sx, it.sy, it.sc, tp);
      }
    }
  }

  /// ایموجی با فونتِ ایموجیِ برنامه (بدونش روی وب مربعِ خالی کشیده می‌شد)
  TextPainter _emojiTp(String t) => TextPainter(
      text: TextSpan(
          text: t,
          style: walkTextStyle(size: 40, color: const Color(0xFF000000))),
      textDirection: TextDirection.rtl)
    ..layout();

  /// تابلوی کوچکِ نامِ شاخه سرِ هر شاخه‌ی کناری
  void _branchSign(Canvas c, double x, double y, double sc, _WalkSide sb) {
    var tp = sb.tp;
    if (tp == null) {
      tp = TextPainter(
          text: TextSpan(
              text: sb.name.isEmpty ? 'شاخه' : sb.name,
              style: walkTextStyle(
                  size: 13,
                  color: const Color(0xFF1F2937),
                  w: FontWeight.w700)),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          maxLines: 2,
          ellipsis: '…')
        ..layout(maxWidth: 110);
      sb.tp = tp;
    }
    const pad = 6.0;
    final bw = tp.width + pad * 2, bh = tp.height + pad * 2;
    c.save();
    c.translate(x, y);
    c.scale(sc, sc);
    c.drawOval(Rect.fromCenter(center: const Offset(0, 1), width: 22, height: 5),
        _fill(const Color(0x33000000)));
    c.drawLine(const Offset(0, 0), const Offset(0, -34),
        _stroke(const Color(0xFF6B4423), 2.2));
    final panel = RRect.fromRectAndRadius(
        Rect.fromLTWH(-bw / 2, -34 - bh, bw, bh), const Radius.circular(8));
    c.drawRRect(panel, _fill(const Color(0xF2FFFFFF)));
    c.drawRRect(panel, _stroke(sb.color, 2.5));
    tp.paint(c, Offset(-tp.width / 2, -34 - bh + pad));
    c.restore();
  }

  /// جاده‌ی خاکی/رنگیِ شاخه (باریک‌تر از جاده‌ی اصلی) از جایی که از جاده‌ی اصلی جدا
  /// می‌شود تا سرِ شاخه؛ فقط نزدیکِ دوربین نمونه‌برداری می‌شود.
  void _branchStrip(Canvas canvas, _RoadPoly cr, double dc) =>
      _strip(canvas, cr, data.branchFrom, dc, data.branchColor);

  void _strip(Canvas canvas, _RoadPoly cr, double from, double dc, Color bc) {
    final lc = cr.length;
    if (from >= lc) return;
    final ss = <double>[];
    var s = math.max(from, dc - 800);
    final sEnd = math.min(lc, dc + 900);
    if (s >= sEnd) return;
    while (s < sEnd) {
      ss.add(s);
      s += 5.0 + (s - dc).abs() * 0.05;
    }
    ss.add(sEnd);
    final n = ss.length;
    if (n < 2) return;
    const w = 10;
    const hw = 9.0;
    final sf = List<double>.filled(n * w, 0.0);
    final sr = List<double>.filled(n * w, 0.0);
    const offs = [-60.0, -(hw + 3), -hw, -(hw - 1.2), -0.8, 0.8, hw - 1.2, hw, hw + 3, 60.0];
    for (var i = 0; i < n; i++) {
      final si = ss[i];
      final a = cr.pos(math.max(0.0, si - 2));
      final b = cr.pos(math.min(lc, si + 2));
      var tv = b - a;
      final tl = tv.distance;
      tv = tl < 1e-6 ? const Offset(1, 0) : tv / tl;
      final nrm = Offset(-tv.dy, tv.dx);
      final cpos = cr.pos(si);
      for (var j = 0; j < w; j++) {
        _cam(cpos + nrm * offs[j]);
        sf[i * w + j] = _f;
        sr[i * w + j] = _r;
      }
    }
    final dirt = dark ? const Color(0xFF6B5A3E) : const Color(0xFFD9B77E);
    final body = Color.lerp(bc, dirt, 0.4)!;
    final bodyC = dark ? Color.lerp(body, Colors.black, 0.35)! : body;
    final verge = dark
        ? Color.lerp(bc, Colors.black, 0.5)!
        : Color.lerp(bc, Colors.white, 0.6)!;
    final edge = dark ? const Color(0x55FFFFFF) : const Color(0xAAFFFFFF);
    for (var i = 0; i < n - 1; i++) {
      final si = ss[i];
      _quad(canvas, sf, sr, i, 1, 2, verge);
      _quad(canvas, sf, sr, i, 7, 8, verge);
      _quad(canvas, sf, sr, i, 3, 6, bodyC);
      _quad(canvas, sf, sr, i, 2, 3, edge);
      _quad(canvas, sf, sr, i, 6, 7, edge);
      if ((si / 16).floor() % 2 == 0) {
        _quad(canvas, sf, sr, i, 4, 5, edge);
      }
    }
  }

  void _drawSprite(Canvas canvas, _El e, double p, double t, _Plan pl) {
    switch (e.k) {
      case 0:
        WorldLayer._grass(canvas, e, p, t);
        break;
      case 1:
        WorldLayer._flower(canvas, e, p, t);
        break;
      case 2:
        WorldLayer._bush(canvas, e, p);
        break;
      case 3:
        WorldLayer._tree(canvas, e, p, t);
        break;
      case 4:
        WorldLayer._pine(canvas, e, p);
        break;
      case 6:
        WorldLayer._rock(canvas, e, p);
        break;
      case 7:
        WorldLayer._mushroom(canvas, e, p);
        break;
      case 8:
        WorldLayer._hay(canvas, e, p);
        break;
      case 9:
        WorldLayer._fence(canvas, e, p);
        break;
      case 10:
        WorldLayer._lamp(canvas, e, p, t);
        break;
      case 11:
        WorldLayer._windmill(canvas, e, p, t);
        break;
      case 20:
      case 21:
        WorldLayer._house(canvas, e, p, t, pl);
        break;
      case 22:
        WorldLayer._tower(canvas, e, p, t);
        break;
      case 23:
        WorldLayer._barn(canvas, e, p);
        break;
    }
  }

  /// ماشین از پشت (دور می‌شود) یا از روبه‌رو (می‌آید)
  void _carBB(Canvas c, double x, double y, double sc, Color col, bool onc) {
    c.save();
    c.translate(x, y);
    c.scale(sc, sc);
    c.drawOval(Rect.fromCenter(center: const Offset(0, 0.5), width: 22, height: 4),
        _fill(const Color(0x33000000)));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-9, -9, 18, 7), const Radius.circular(1.8)),
        _fill(col));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-6.5, -14, 13, 6), const Radius.circular(2)),
        _fill(Color.lerp(col, Colors.black, 0.12)!));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-5, -13, 10, 4), const Radius.circular(1.2)),
        _fill(const Color(0xCCDFF3FF)));
    c.drawRect(const Rect.fromLTWH(-8.5, -3, 3, 3.2),
        _fill(const Color(0xFF1F2937)));
    c.drawRect(const Rect.fromLTWH(5.5, -3, 3, 3.2),
        _fill(const Color(0xFF1F2937)));
    final lamp = onc ? const Color(0xFFFFF3B0) : const Color(0xFFFF4444);
    c.drawCircle(const Offset(-6.5, -6), 1.3, _fill(lamp));
    c.drawCircle(const Offset(6.5, -6), 1.3, _fill(lamp));
    c.restore();
  }

  void _goalSign(Canvas c, double x, double y, double sc, TextPainter tp) {
    c.save();
    c.translate(x, y);
    c.scale(sc, sc);
    c.drawOval(Rect.fromCenter(center: const Offset(0, 1), width: 40, height: 7),
        _fill(const Color(0x33000000)));
    c.drawLine(const Offset(0, 0), const Offset(0, -64),
        _stroke(const Color(0xFF6B4423), 3));
    final panel = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-34, -122, 68, 60), const Radius.circular(10));
    c.drawRRect(panel, _fill(const Color(0xF2FFFFFF)));
    c.drawRRect(panel, _stroke(const Color(0xFFC9962B), 3));
    tp.paint(c, Offset(-tp.width / 2, -122 + (60 - tp.height) / 2));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant WalkPainter old) => true;
}
