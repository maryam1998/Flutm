import 'dart:math' as math;
import 'dart:typed_data' show Float32List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/map_models.dart';
import 'camera.dart';
import 'seeded.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  دنیای در حال رشد 🌱🏡🚗
//  صفحه‌ی سفید با هر دقیقه کاری که کاربر روی همه‌ی شاخه‌ها می‌گذارد کم‌کم به یک
//  سرزمین سرسبز تبدیل می‌شود: چمن، گل، درخت، برکه، جاده، خانه، ماشین، آسیاب…
//  شکلِ نهایی از روی یک «دانه‌ی تصادفیِ» ثابتِ هر کاربر ساخته می‌شود
//  (state.extra['worldSeed']) و قابل پیش‌بینی نیست؛ هر کاربر دنیای خودش را دارد.
//  برای خاموش‌کردن: state.extra['worldOff'] = true
// ═══════════════════════════════════════════════════════════════════════════

double _c01(double x) => x < 0 ? 0.0 : (x > 1 ? 1.0 : x);
double _ease(double x) {
  final t = _c01(x);
  return t * t * (3 - 2 * t);
}

/// سرعتِ رشدِ دنیا: دقیقه‌های واقعیِ کار → «دقیقه‌ی دنیا».
/// دنیا ۱۰۲۰ واحد دارد و با ۱۵۰ ساعتِ کار (۹۰۰۰ دقیقه) به شکلِ کامل می‌رسد؛
/// بعد از آن هم آهسته ادامه می‌دهد و چیزهای دیرتر (بشقاب‌پرنده، خانه‌های بلند…)
/// پس از صدها ساعت پیدا می‌شوند. ابتدا سریع است تا کاربر زود پاداش ببیند.
/// برای کندتر/تندتر کردن فقط [_kFullMinutes] را عوض کن.
const double _kFullMinutes = 9000.0;
const double _kFullWorld = 1020.0;
double _pace(double m) {
  if (m <= 0) return 0.0;
  return _kFullWorld * math.pow(m / _kFullMinutes, 0.62).toDouble();
}

/// شعاعِ زمینِ سرسبز بر حسبِ دقیقه‌های کارِ کل
double _landR(double m) => 150 + 95 * math.sqrt(math.max(0.0, m));

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
class _El {
  _El(this.k, this.x, this.y, this.s, this.at, this.v, this.a);
  final int k;
  final double x, y, s, at, a;
  final int v;
}

class _Lobe {
  _Lobe(this.ang, this.dist, this.size, this.at);
  final double ang, dist, size, at;
}

class _Road {
  _Road(this.pts, this.m0) {
    cum.add(0);
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum.last + (pts[i] - pts[i - 1]).distance);
    }
    length = cum.last;
    final d = <double>[];
    for (var s = 10.0; s + 12 < length; s += 26) {
      final a = pos(s), b = pos(s + 12);
      d.addAll([a.dx, a.dy, b.dx, b.dy]);
    }
    dashes = Float32List.fromList(d);
  }

  final List<Offset> pts;
  final double m0;
  final List<double> cum = [];
  late final double length;
  late final Float32List dashes;

  int get dashCount => dashes.length ~/ 4;

  int _seg(double d) {
    for (var i = 1; i < pts.length; i++) {
      if (d <= cum[i]) return i;
    }
    return pts.length - 1;
  }

  Offset pos(double d) {
    final dd = d.clamp(0.0, cum.last).toDouble();
    final i = _seg(dd);
    final seg = cum[i] - cum[i - 1];
    final f = seg == 0 ? 0.0 : (dd - cum[i - 1]) / seg;
    return Offset.lerp(pts[i - 1], pts[i], f)!;
  }

  double ang(double d) {
    final i = _seg(d.clamp(0.0, cum.last).toDouble());
    final v = pts[i] - pts[i - 1];
    return math.atan2(v.dy, v.dx);
  }

  /// چه مقدار از جاده تا دقیقه‌ی [m] ساخته شده است
  double revealed(double m) {
    if (m <= m0) return 0.0;
    final d = 55.0 * math.pow(m - m0, 0.8);
    return math.min(math.min(d, length), _landR(m));
  }

  /// کمترین دقیقه‌ای که جاده به فاصله‌ی [sd] می‌رسد
  double minuteFor(double sd) {
    for (var m = m0; m < 6000; m += 0.5) {
      if (revealed(m) >= sd) return m;
    }
    return 6000.0;
  }
}

class _Plan {
  final List<_El> flat = []; // برکه، مزرعه، رنگین‌کمان (زیرِ همه)
  final List<_El> tall = []; // بقیه، مرتب بر اساس y
  final List<_Road> roads = [];
  final List<_Lobe> lobes = [];
  int theme = 0; // ۰ روستا ۱ جنگل ۲ مزرعه ۳ دریاچه
  List<Color> houseColors = [], roofColors = [], carColors = [];
}

double _segDist(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (l2 == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / l2)
      .clamp(0.0, 1.0)
      .toDouble();
  return (p - (a + ab * t)).distance;
}

double _roadDist(_Plan pl, Offset p) {
  var best = 1e9;
  for (final r in pl.roads) {
    for (var i = 1; i < r.pts.length; i++) {
      final d = _segDist(p, r.pts[i - 1], r.pts[i]);
      if (d < best) best = d;
    }
  }
  return best;
}

class _Placed {
  _Placed(this.x, this.y, this.r);
  final double x, y, r;
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

int _pickKind(double at, int theme, double Function() R) {
  final w = List<double>.filled(13, 0.0);
  w[0] = at < 15 ? 5 : 2;
  w[1] = at < 30 ? 4 : 2.2;
  w[2] = at > 3 ? 1.5 : 0;
  w[6] = at > 20 ? 0.8 : 0;
  w[7] = at > 20 ? 0.8 : 0;
  w[3] = at > 8 ? (theme == 1 ? 4.0 : 1.6) : 0;
  w[4] = at > 25 ? (theme == 1 ? 3.0 : 1.0) : 0;
  w[5] = at > 40 ? (theme == 3 ? 2.2 : 0.5) : 0;
  w[8] = (at > 60 && theme == 2) ? 1.4 : 0;
  w[9] = at > 50 ? 0.5 : 0;
  w[11] = at > 200 ? (theme == 2 ? 0.5 : 0.12) : 0;
  w[12] = (at > 90 && theme == 2) ? 1.6 : 0;
  var sum = 0.0;
  for (final x in w) {
    sum += x;
  }
  var r = R() * sum;
  for (var i = 0; i < w.length; i++) {
    r -= w[i];
    if (r <= 0 && w[i] > 0) return i;
  }
  return 0;
}

_Plan _buildPlan(int seed) {
  final rnd = seeded('world-v1-$seed');
  double R() => rnd();
  final pl = _Plan();
  pl.theme = (R() * 4).floor().clamp(0, 3).toInt();
  pl.houseColors = (List<Color>.from(_kHouse)..shuffle(math.Random(seed)))
      .take(4)
      .toList();
  pl.roofColors = (List<Color>.from(_kRoof)..shuffle(math.Random(seed + 7)))
      .take(3)
      .toList();
  pl.carColors = (List<Color>.from(_kCar)..shuffle(math.Random(seed + 13)))
      .take(5)
      .toList();

  // لکه‌های زمین
  for (var j = 0; j < 7; j++) {
    pl.lobes.add(_Lobe(R() * math.pi * 2, 0.45 + R() * 0.3, 0.5 + R() * 0.25,
        j == 0 ? 0.0 : 4.0 + j * (6 + R() * 14)));
  }

  // جاده‌ها: از اطراف «من» به بیرون می‌روند و کم‌کم ساخته می‌شوند
  final nRoad = 3 + (R() * 3).floor();
  final base = R() * math.pi * 2;
  for (var k = 0; k < nRoad; k++) {
    var ang = base + k * math.pi * 2 / nRoad + (R() - 0.5) * 0.6;
    var p = Offset(math.cos(ang), math.sin(ang)) * 70;
    final pts = <Offset>[p];
    final total = 1500 + R() * 1800;
    var len = 0.0;
    while (len < total) {
      ang += (R() - 0.5) * 0.55;
      p = p + Offset(math.cos(ang), math.sin(ang)) * 60;
      pts.add(p);
      len += 60;
    }
    final m0 = k == 0 ? 4 + R() * 4 : 8 + k * (15 + R() * 25);
    pl.roads.add(_Road(pts, m0));
  }

  final placed = <_Placed>[];

  // خانه‌ها کنار جاده‌ها
  final houseP = const [0.85, 0.35, 0.55, 0.5][pl.theme];
  var houses = 0;
  for (final r in pl.roads) {
    var sd = 130 + R() * 40;
    while (sd < r.length - 80 && houses < 180) {
      if (R() < houseP) {
        for (final side in const [-1, 1]) {
          if (R() > 0.6) continue;
          final a = r.ang(sd);
          final nrm = Offset(-math.sin(a), math.cos(a));
          final pos = r.pos(sd) + nrm * (side * (50 + R() * 16));
          final at = r.minuteFor(sd) + 1.5 + R() * 9;
          int k = 20;
          if (at > 60 && R() < 0.45) k = 21;
          if (at > 400 && R() < 0.4) k = 22;
          if (pl.theme == 2 && R() < 0.3) k = 23;
          pl.tall.add(_El(k, pos.dx, pos.dy, 0.9 + R() * 0.3, at,
              (R() * 1000).floor(), R() * 6.28));
          placed.add(_Placed(pos.dx, pos.dy, 30));
          houses++;
        }
      }
      sd += 70 + R() * 90;
    }
    // چراغ‌های کنار جاده
    var ld = 150 + R() * 40;
    while (ld < r.length - 40) {
      final a = r.ang(ld);
      final nrm = Offset(-math.sin(a), math.cos(a));
      final side = R() < 0.5 ? -1 : 1;
      final pos = r.pos(ld) + nrm * (side * 24.0);
      pl.tall.add(_El(10, pos.dx, pos.dy, 1.0, r.minuteFor(ld) + 4, 0, R() * 6));
      ld += 170 + R() * 60;
    }
  }

  // پراکنده‌ها: چمن، گل، درخت، برکه…
  const nScatter = 380;
  for (var i = 1; i <= nScatter; i++) {
    final at = 0.3 * math.pow(i, 1.45) * (0.75 + 0.5 * R());
    final k = _pickKind(at, pl.theme, R);
    final rad = _kindRadius(k);
    final rmax = _landR(at) * 0.95;
    final loose = k == 0 || k == 1 || k == 6 || k == 7;
    for (var tr = 0; tr < 25; tr++) {
      final ang = R() * math.pi * 2;
      final rr = math.sqrt(R()) * rmax;
      final p = Offset(math.cos(ang) * rr, math.sin(ang) * rr);
      if (p.distance < 38) continue; // دورِ «من» خالی بماند
      if (_roadDist(pl, p) < (loose ? 22.0 : 26.0 + rad)) continue;
      var ok = true;
      for (final q in placed) {
        final dx = q.x - p.dx, dy = q.y - p.dy;
        final lim = (q.r + rad) * (loose ? 0.45 : 0.8);
        if (dx * dx + dy * dy < lim * lim) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      final s = (k == 5 || k == 12) ? 0.8 + R() * 0.8 : 0.8 + R() * 0.55;
      final el = _El(k, p.dx, p.dy, s, at, (R() * 1000).floor(), R() * 6.28);
      if (k == 5 || k == 12) {
        pl.flat.add(el);
      } else {
        pl.tall.add(el);
      }
      placed.add(_Placed(p.dx, p.dy, rad * (k == 5 || k == 12 ? s : 1.0)));
      break;
    }
  }

  // سورپرایزها: هر کاربر مجموعه‌ی متفاوتی می‌گیرد
  Offset anyPos(double at) {
    final ang = R() * math.pi * 2;
    final rr = math.sqrt(R()) * _landR(at) * 0.6;
    return Offset(math.cos(ang) * rr, math.sin(ang) * rr);
  }

  if (R() < 0.75) {
    final at = 110 + R() * 320;
    final p = anyPos(at);
    pl.tall.add(_El(30, p.dx, p.dy, 1.0, at, 0, R() * 6));
  }
  if (R() < 0.6) {
    final at = 50 + R() * 220;
    final p = anyPos(at);
    pl.flat.add(_El(31, p.dx, p.dy, 0.9 + R() * 0.5, at, 0, R() * 6));
  }
  if (R() < 0.18) {
    final at = 700 + R() * 1000;
    final p = anyPos(at);
    pl.tall.add(_El(32, p.dx, p.dy, 1.0, at, 0, R() * 6));
  }

  pl.tall.sort((a, b) => a.y.compareTo(b.y));
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
  static double _minutes = 0;
  static int _minMs = 0;

  /// کلِ دقیقه‌های کارِ کاربر روی همه‌ی هدف‌ها و حلقه‌ها
  static double totalMinutes(MapState s) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _minMs > 300) {
      var m = 0.0;
      for (final g in s.goals) {
        for (final a in g.actions) {
          m += actionTotalMinutes(a);
        }
      }
      for (final r in s.rings) {
        for (final a in r.actions) {
          m += actionTotalMinutes(a);
        }
      }
      _minutes = m;
      _minMs = now;
    }
    return _minutes;
  }

  static void paint(Canvas canvas, MapState s, CameraController cam,
      Size size, double t, bool isDark) {
    final sc = cam.scale <= 0 ? 1.0 : cam.scale;
    view = Rect.fromLTWH(
        -cam.x / sc, -cam.y / sc, size.width / sc, size.height / sc);
    if (s.extra['worldOff'] == true) return;
    final realMin = totalMinutes(s);
    if (realMin < 0.02) return; // شروع: صفحه‌ی سفید
    final m = _pace(realMin); // دقیقه‌ی دنیا

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
    }
    final pl = _plan!;
    final lod = sc < 0.22;
    final vv = view.inflate(100);

    // ── زمین ──
    final R = _landR(m);
    final g0 = isDark
        ? const Color.fromRGBO(70, 150, 80, 0.34)
        : const Color.fromRGBO(120, 196, 106, 0.50);
    final g1 = isDark
        ? const Color.fromRGBO(70, 150, 80, 0.0)
        : const Color.fromRGBO(120, 196, 106, 0.0);
    final deep = isDark
        ? const Color.fromRGBO(40, 120, 60, 0.30)
        : const Color.fromRGBO(63, 150, 76, 0.34);
    final deep1 = const Color.fromRGBO(63, 150, 76, 0.0);
    void blob(Offset c, double r, Color a, Color b) {
      if (r < 4) return;
      if (!vv.overlaps(Rect.fromCircle(center: c, radius: r))) return;
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = ui.Gradient.radial(c, r, [a, b], const [0.0, 1.0]));
    }

    blob(Offset.zero, R, g0, g1);
    for (final lb in pl.lobes) {
      final k = _ease((m - lb.at) / 25.0);
      if (k <= 0) continue;
      final c = Offset(math.cos(lb.ang), math.sin(lb.ang)) * (R * lb.dist);
      blob(c, R * lb.size * k, g0, g1);
    }
    blob(Offset.zero, R * 0.6 * _c01(m / 30.0), deep, deep1);

    // ── برکه‌ها، مزرعه‌ها، رنگین‌کمان ──
    for (final e in pl.flat) {
      if (m < e.at) continue;
      if (!vv.contains(Offset(e.x, e.y))) continue;
      final p = _ease((m - e.at) / 0.6);
      switch (e.k) {
        case 5:
          _pond(canvas, e, p, t);
          break;
        case 12:
          _field(canvas, e, p);
          break;
        case 31:
          _rainbow(canvas, e, p);
          break;
      }
    }

    // ── جاده‌ها و ماشین‌ها ──
    for (final r in pl.roads) {
      final len = r.revealed(m);
      if (len < 8) continue;
      _path.reset();
      _path.moveTo(r.pts[0].dx, r.pts[0].dy);
      var i = 1;
      while (i < r.pts.length && r.cum[i] <= len) {
        _path.lineTo(r.pts[i].dx, r.pts[i].dy);
        i++;
      }
      final end = r.pos(len);
      _path.lineTo(end.dx, end.dy);
      if (!_path.getBounds().overlaps(vv)) continue;
      canvas.drawPath(
          _path,
          _stroke(isDark ? const Color(0xFF9CA3AF) : const Color(0xFFD5D9DF),
              30));
      canvas.drawPath(_path, _stroke(const Color(0xFF6B7280), 24));
      final cnt = math.min(r.dashCount, math.max(0, ((len - 22) / 26).floor() + 1));
      if (cnt > 0) {
        canvas.drawRawPoints(
            ui.PointMode.lines,
            Float32List.sublistView(r.dashes, 0, cnt * 4),
            _stroke(const Color(0xCCFFFFFF), 2, cap: StrokeCap.butt));
      }
      // نوکِ جاده‌ی در حال ساخت
      if (len < r.length - 1) {
        final pulse = 0.5 + 0.5 * math.sin(t * 5);
        canvas.drawCircle(end, 5 + pulse * 2,
            _fill(Color.fromRGBO(255, 160, 40, 0.55 + 0.35 * pulse)));
      }
      // ماشین‌ها
      final nCar = math.min(7, (len / 300).floor() + (len > 160 ? 1 : 0));
      final idBase = r.m0 * 13.7;
      for (var c = 0; c < nCar; c++) {
        final hsh = ((math.sin(idBase + c * 12.9898) * 43758.5453) % 1.0).abs();
        final speed = 38 + hsh * 40;
        final dir = c.isEven ? 1.0 : -1.0;
        var d = (hsh * 1000 + t * speed * dir) % len;
        if (d < 0) d += len;
        final a = r.ang(d);
        final nrm = Offset(-math.sin(a), math.cos(a));
        final pos = r.pos(d) + nrm * (dir > 0 ? 7.0 : -7.0);
        if (!vv.contains(pos)) continue;
        _car(canvas, pos, dir > 0 ? a : a + math.pi,
            pl.carColors[(c + r.m0.floor()) % pl.carColors.length]);
      }
    }

    // ── بقیه‌ی چیزها (از بالا به پایین) ──
    for (final e in pl.tall) {
      if (m < e.at) continue;
      if (e.x < vv.left || e.x > vv.right || e.y < vv.top - 120 || e.y > vv.bottom + 40) {
        continue;
      }
      if (lod && (e.k == 0 || e.k == 1 || e.k == 6 || e.k == 7)) continue;
      final p = _ease((m - e.at) / 0.6);
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
        case 30:
          _balloon(canvas, e, p, t);
          break;
        case 32:
          _ufo(canvas, e, p, t);
          break;
      }
    }

    // ── پرنده و ابر ──
    if (m > 60) _birds(canvas, m, t, vv);
    if (m > 120) _clouds(canvas, m, t, isDark, vv);
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
  final nf = math.min(26.0, 1.2 * math.pow(minutes, 0.7));
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
