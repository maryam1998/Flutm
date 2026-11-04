import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'wind.dart' show windSway;

/// گیاهِ تمرکز 🌱: با گذشتِ دقیقه‌های کارِ امروز روی نوکِ شاخه کم‌کم رشد می‌کند.
///
/// زمان‌بندی (بر پایه‌ی چرخه‌های تمرکز: ۲۵ دقیقه پومودورو، ۹۰ دقیقه چرخه‌ی اولترادین):
///  • ۰–۱ دقیقه   جوانه‌ی بسته و ساقه‌ی کوچک (شروعِ کار؛ همان لحظه پاداشِ دیداری)
///  • ۱–۶         جوانه باز می‌شود، دو برگِ نخستین
///  • ۳–۱۵        ساقه بالا می‌رود (سخت‌ترین بخش: گذر از مقاومتِ شروع)
///  • ۴–۳۰        جفت‌برگ‌های بعدی (ورود به حالتِ جریان)
///  • ۱۳–۳۷        نخستین شاخه‌ی فرعی (پایانِ یک پومودورو ≈ ۲۵ دقیقه)
///  • ۳۰–۹۰        شاخه‌های بعدی، ساقه‌ی کامل در حدود ۹۰ دقیقه
///
/// برای آزمایش سریع‌تر، این ضریب را بزرگ کن (مثلاً ۶۰ = هر ثانیه یک دقیقه).
const double kPlantTimeScale = 1.0;

/// سرعتِ رشدِ بوته/برگ/غنچه روی جاده‌ی شاخه‌ها نسبت به دقیقه‌های واقعی
/// (۰٫۲ = پنج برابر آهسته‌تر)؛ با تایمرِ روشن رشد شروع می‌شود، با توقف می‌ایستد
const double kRoadGrowSlow = 0.2;

/// مدلِ رسم: ۰ = در حال رشد (فقط برگ و شاخه)، ۱ = غنچه‌ها، ۲ = گل‌ها
const int kPlantGrowing = 0;
const int kPlantBuds = 1;
const int kPlantFlowers = 2;

typedef PlantSprig = void Function(Canvas canvas, Offset tip, double dir,
    double r, String id, double p, bool flower);

double _sm(double x) {
  final t = x.clamp(0.0, 1.0).toDouble();
  return t * t * (3 - 2 * t);
}

const List<List<Color>> _greens = [
  [Color(0xFF2E7D32), Color(0xFF81C784)],
  [Color(0xFF388E3C), Color(0xFFA5D66B)],
  [Color(0xFF1B7F4B), Color(0xFF6FCF97)],
];

void _leaf(Canvas canvas, double x, double y, double ang, double len,
    double wid, List<Color> g) {
  if (len < 0.4) return;
  canvas.save();
  canvas.translate(x, y);
  canvas.rotate(ang);
  final lp = Path()
    ..moveTo(0, 0)
    ..cubicTo(wid, -len * 0.25, wid * 0.8, -len * 0.8, 0, -len)
    ..cubicTo(-wid * 0.8, -len * 0.8, -wid, -len * 0.25, 0, 0);
  canvas.drawPath(
      lp,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, -len), g));
  canvas.drawPath(
      lp,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0x33000000));
  canvas.drawLine(
      Offset.zero,
      Offset(0, -len * 0.82),
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..strokeWidth = 0.7);
  canvas.restore();
}

// ───────────────────────── بوته‌ی کنارِ جاده 🌿 ─────────────────────────
// برگِ تنها معنا ندارد: هر برگ روی ساقه‌ی یک بوته می‌روید. بوته از یک نهالِ ریز
// شروع می‌شود و خیلی آهسته بلند و پربرگ می‌شود (جفت‌برگ‌ها، بعد شاخه‌های فرعی).
// کم‌مصرف: بدون سایه‌انداز/گرادیان/saveLayer؛ همه‌ی برگ‌ها در دو Path جمع و با
// دو رنگِ تخت کشیده می‌شوند (به‌جای چند drawPath برای هر برگ)، Path/Paint مشترک.
final Path _bsStem = Path();
final Path _bsA = Path();
final Path _bsB = Path();
final Paint _bsPaint = Paint()..isAntiAlias = true;

const List<List<Color>> _bushLeaf = [
  [Color(0xFF3F8F45), Color(0xFF6DBE6F)],
  [Color(0xFF4A9A3F), Color(0xFF8FCB62)],
  [Color(0xFF2F8F5B), Color(0xFF5FC08A)],
];

void _bsLeaf(Path p, double x, double y, double a, double len, double wid) {
  if (len < 0.35) return;
  final dx = math.cos(a), dy = math.sin(a);
  final mx = x + dx * len * 0.5, my = y + dy * len * 0.5;
  p
    ..moveTo(x, y)
    ..quadraticBezierTo(mx - dy * wid, my + dx * wid, x + dx * len, y + dy * len)
    ..quadraticBezierTo(mx + dy * wid, my - dx * wid, x, y);
}

/// [base] ریشه روی زمین، [dir] جهتِ رشد (رادیان)، [size] ارتفاعِ بوته‌ی کامل،
/// [g] ۰..۱ پیشرفتِ رشد (۰ = نهالِ ریز، ۱ = بوته‌ی کامل)، [seed] شکلِ ثابت.
void drawRoadBush(Canvas canvas, Offset base, double dir, double size, double g,
    int seed, {double sway = 0.0}) {
  // رشدِ پیوسته: از «هیچ» شروع می‌شود و ارتفاع و برگ‌ها نرم و آهسته زیاد می‌شوند
  // (قبلاً ارتفاعِ اولیه ۳۰٪ بود و جفت‌برگ‌ها ناگهان پدیدار می‌شدند)
  final k = g.clamp(0.0, 1.0).toDouble();
  final hgt = size * (0.04 + 0.96 * k);
  if (hgt < 0.5) return;
  final si = seed.abs();
  final gc = _greens[si % 3];
  final lc = _bushLeaf[si % 3];
  final r1 = ((si >> 3) % 7) / 7.0 - 0.5;
  final dx = math.cos(dir), dy = math.sin(dir);
  final nx = -dy, ny = dx;
  final bend = (r1 * 0.5 + sway) * hgt;
  final p0 = base;
  final c1 = Offset(base.dx + dx * hgt * 0.55 + nx * bend,
      base.dy + dy * hgt * 0.55 + ny * bend);
  final p2 = Offset(base.dx + dx * hgt + nx * bend * 0.5,
      base.dy + dy * hgt + ny * bend * 0.5);
  Offset pt(double u) {
    final v = 1 - u;
    return Offset(v * v * p0.dx + 2 * v * u * c1.dx + u * u * p2.dx,
        v * v * p0.dy + 2 * v * u * c1.dy + u * u * p2.dy);
  }

  double an(double u) {
    final v = 1 - u;
    return math.atan2(2 * v * (c1.dy - p0.dy) + 2 * u * (p2.dy - c1.dy),
        2 * v * (c1.dx - p0.dx) + 2 * u * (p2.dx - c1.dx));
  }

  _bsStem
    ..reset()
    ..moveTo(p0.dx, p0.dy)
    ..quadraticBezierTo(c1.dx, c1.dy, p2.dx, p2.dy);
  _bsA.reset();
  _bsB.reset();

  final lk = 0.55 + 0.45 * k;
  // جفت‌برگ‌های ساقه: ۱ جفت در نهال تا ۴ جفت در بوته‌ی کامل
  // هر جفت‌برگ جداگانه و پیوسته بزرگ می‌شود (نه ناگهانی)
  for (var j = 0; j < 4; j++) {
    final pj = _sm((k - j * 0.2) / 0.3);
    if (pj < 0.02) continue;
    final u = 0.38 + 0.17 * j;
    final q = pt(u);
    final a = an(u);
    final len = hgt * (0.40 - 0.04 * j) * lk * pj;
    final sp = 0.95 - 0.08 * j;
    _bsLeaf(_bsA, q.dx, q.dy, a + sp, len, len * 0.34);
    _bsLeaf(_bsB, q.dx, q.dy, a - sp, len, len * 0.34);
  }
  // دو برگِ نوکِ ساقه
  final aa = an(1.0);
  final al = hgt * 0.38 * lk;
  _bsLeaf(_bsA, p2.dx, p2.dy, aa + 0.3, al, al * 0.34);
  _bsLeaf(_bsB, p2.dx, p2.dy, aa - 0.3, al, al * 0.34);
  // شاخه‌های فرعی: وقتی بوته به‌اندازه‌ی کافی بزرگ شد
  if (k > 0.45) {
    final kt = _sm((k - 0.45) / 0.45);
    final s0 = (si & 1) == 0 ? 1.0 : -1.0;
    final q = pt(0.3);
    final a = an(0.3) + s0 * 0.85;
    final tl = hgt * 0.5 * kt;
    final tx = q.dx + math.cos(a) * tl, ty = q.dy + math.sin(a) * tl;
    _bsStem
      ..moveTo(q.dx, q.dy)
      ..lineTo(tx, ty);
    final l2 = hgt * 0.3 * kt;
    _bsLeaf(_bsA, tx, ty, a + 0.35, l2, l2 * 0.34);
    _bsLeaf(_bsB, tx, ty, a - 0.35, l2, l2 * 0.34);
    if (k > 0.7) {
      final kt2 = _sm((k - 0.7) / 0.3);
      final q2 = pt(0.5);
      final a2 = an(0.5) - s0 * 0.85;
      final tl2 = hgt * 0.42 * kt2;
      final tx2 = q2.dx + math.cos(a2) * tl2, ty2 = q2.dy + math.sin(a2) * tl2;
      _bsStem
        ..moveTo(q2.dx, q2.dy)
        ..lineTo(tx2, ty2);
      final l3 = hgt * 0.27 * kt2;
      _bsLeaf(_bsA, tx2, ty2, a2 + 0.35, l3, l3 * 0.34);
      _bsLeaf(_bsB, tx2, ty2, a2 - 0.35, l3, l3 * 0.34);
    }
  }
  // سایه‌ی کوچکِ پای بوته (یک بیضیِ تخت)
  _bsPaint
    ..style = PaintingStyle.fill
    ..color = const Color(0x22000000);
  canvas.drawOval(
      Rect.fromCenter(
          center: base, width: hgt * 0.75, height: math.max(1.2, hgt * 0.2)),
      _bsPaint);
  _bsPaint
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = math.max(0.7, size * 0.075 * (0.6 + 0.4 * k))
    ..color = gc[0];
  canvas.drawPath(_bsStem, _bsPaint);
  _bsPaint
    ..style = PaintingStyle.fill
    ..color = lc[0];
  canvas.drawPath(_bsA, _bsPaint);
  _bsPaint.color = lc[1];
  canvas.drawPath(_bsB, _bsPaint);
}

/// [tip] = جای رشد (پایه‌ی گیاه)، [dir] = جهتِ رشد (رادیان، مثل ادامه‌ی شاخه)،
/// [r] = اندازه‌ی واحد، [minutes] = دقیقه‌های کارِ امروز، [bloom] = ۰..۱ برای
/// انیمیشنِ شکفتنِ غنچه/گل.
void drawFocusPlant(
  Canvas canvas, {
  required Offset tip,
  required double dir,
  required double r,
  required String id,
  required double minutes,
  required int mode,
  required double bloom,
  required PlantSprig sprig,
  // زمانِ باد (ثانیه)؛ null = بدونِ تکان
  double? windT,
}) {
  final m = math.max(0.0, minutes * kPlantTimeScale);
  var h = 7;
  for (final u in id.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  final gc = _greens[h % 3];
  final R = r;
  final sx = (((h >> 3) & 1) == 1 ? 1.0 : -1.0) * R * (0.5 + ((h >> 4) % 5) * 0.12);
  final hf = 7 * R;
  Offset stemPt(double hh) => Offset(sx * (hh / hf) * (hh / hf), -hh);

  canvas.save();
  canvas.translate(tip.dx, tip.dy);
  canvas.rotate(dir + math.pi / 2);
  // نسیم: کلِ گیاه کمی حولِ ریشه‌اش خم می‌شود
  if (windT != null) {
    canvas.rotate(windSway(windT, tip.dx, (h % 628) / 100.0) * 0.07);
  }

  final bigH = R *
      (0.35 +
          0.9 * _sm(m / 3) +
          1.6 * _sm((m - 3) / 12) +
          2.2 * _sm((m - 15) / 40) +
          1.5 * _sm((m - 55) / 45));
  final w0 = math.max(1.1, R * 0.2) * (0.8 + 0.5 * _sm(m / 40));

  // ساقه
  final step = R * 0.4;
  final stemPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..color = gc[0];
  for (var a = 0.0; a < bigH; a += step) {
    final b = math.min(bigH, a + step);
    stemPaint.strokeWidth = w0 * (1 - 0.45 * a / math.max(bigH, 1.0));
    canvas.drawLine(stemPt(a), stemPt(b), stemPaint);
  }

  // دو برگِ نخستین
  final cs = 0.55 * R * _sm(m / 3);
  if (cs > 0.3) {
    _leaf(canvas, 0, -R * 0.12, -1.35, cs, cs * 0.5, gc);
    _leaf(canvas, 0, -R * 0.12, 1.35, cs, cs * 0.5, gc);
  }

  double nodeH(int i) => R * (0.9 + 0.85 * i);
  const starts = [13.0, 21.0, 31.0, 44.0, 68.0];
  double branchSide(int k) => k % 2 == 0 ? 1.0 : -1.0;

  // جوانه‌ی سبزِ کوچک (برای جوانه‌ی برگ و جوانه‌ی شاخه): قبل از باز شدن دیده می‌شود
  void greenBud(Offset p, double ang, double size) {
    if (size < 0.3) return;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(ang);
    final bp = Path()
      ..moveTo(0, 0)
      ..cubicTo(size * 0.45, -size * 0.2, size * 0.4, -size * 0.8, 0, -size * 1.25)
      ..cubicTo(-size * 0.4, -size * 0.8, -size * 0.45, -size * 0.2, 0, 0);
    canvas.drawPath(bp, Paint()..color = gc[1]);
    canvas.drawPath(
        bp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = const Color(0x33000000));
    canvas.restore();
  }

  // برگ‌های ساقه (جفت‌برگ؛ سمتِ شاخه‌ی فرعی خالی می‌ماند).
  // هر جفت‌برگ اول یک جوانه‌ی ریز است، بعد کم‌کم باز و بزرگ می‌شود.
  for (var i = 0; i < 6; i++) {
    final hi = nodeH(i);
    final g = _sm((bigH - hi) / (1.8 * R));
    final pre = _sm((bigH - hi + 0.7 * R) / (0.7 * R));
    if (pre <= 0.01) continue;
    final p = stemPt(hi);
    final full = R * (1.35 - 0.09 * i);
    final len = full * g + 0.3 * R * pre * (1 - g);
    final ang = (0.95 + 0.06 * i) * (0.2 + 0.8 * g);
    final wid = len * (0.5 - 0.08 * g);
    final hasBranch = i >= 1 && _sm((m - starts[i - 1]) / 24) > 0.02;
    final bs = hasBranch ? branchSide(i - 1) : 0.0;
    if (bs != 1.0) _leaf(canvas, p.dx, p.dy, ang, len, wid, gc);
    if (bs != -1.0) _leaf(canvas, p.dx, p.dy, -ang, len, wid, gc);
  }

  // جوانه‌ی شاخه‌ی فرعی: چند دقیقه قبل از رشدش در گرهِ ساقه پدیدار می‌شود
  for (var k = 0; k < 5; k++) {
    final pre = _sm((m - (starts[k] - 7)) / 7);
    if (pre <= 0.02 || _sm((m - starts[k]) / 24) > 0.02) continue;
    final hn = nodeH(k + 1);
    if (hn > bigH) continue;
    greenBud(stemPt(hn), branchSide(k) * 0.8, 0.55 * R * pre);
  }

  // شاخه‌های فرعی
  final tips = <_Tip>[];
  for (var k = 0; k < 5; k++) {
    final u = _sm((m - starts[k]) / 24);
    if (u <= 0.02) continue;
    final s = branchSide(k);
    final L = R * (3.0 - 0.2 * k);
    final p0 = stemPt(math.min(nodeH(k + 1), bigH - 0.2 * R));
    final e = Offset(L * s * 0.8, -L * 0.6);
    final c = Offset(L * s * 0.65, -L * 0.1);
    Offset bz(double t) => Offset(
          p0.dx + 2 * (1 - t) * t * c.dx + t * t * e.dx,
          p0.dy + 2 * (1 - t) * t * c.dy + t * t * e.dy,
        );
    double tg(double t) {
      final dx = 2 * (1 - t) * c.dx + 2 * t * (e.dx - c.dx);
      final dy = 2 * (1 - t) * c.dy + 2 * t * (e.dy - c.dy);
      return math.atan2(dx, -dy);
    }

    var prev = bz(0);
    for (var j = 1; j <= 14; j++) {
      final t = u * j / 14;
      final q = bz(t);
      stemPaint.strokeWidth = w0 * 0.7 * (1 - 0.5 * t);
      canvas.drawLine(prev, q, stemPaint);
      prev = q;
    }
    const lt = [0.35, 0.6, 0.85];
    for (var li = 0; li < 3; li++) {
      final tt = lt[li];
      final k2 = _sm((u - tt) / 0.4);
      final pre = _sm((u - tt + 0.12) / 0.12);
      final sz = R * 0.95 * k2 + 0.28 * R * pre * (1 - k2);
      if (sz < 0.3) continue;
      final q = bz(tt);
      final sd = (li % 2 == 0 ? 1.0 : -1.0) * s;
      _leaf(canvas, q.dx, q.dy, tg(tt) + sd * 0.9 * (0.2 + 0.8 * k2), sz,
          sz * (0.5 - 0.08 * k2), gc);
    }
    tips.add(_Tip(bz(u), tg(u), k, u));
  }

  // نوکِ ساقه و شاخه‌ها
  final apex = stemPt(bigH);
  final apexAng = math.atan2(2 * sx * bigH / (hf * hf), 1.0);
  var bi = 0;
  void place(Offset p, double a, double rr, String id2, bool flower) {
    final pp = (bloom * 1.4 - bi * 0.15).clamp(0.0, 1.0).toDouble();
    bi++;
    sprig(canvas, p, a - math.pi / 2, rr, '$id|$id2', pp, flower);
  }

  // برگ‌ها در همه‌ی حالت‌ها یکسان‌اند (توقف هیچ برگ و شاخه‌ای را حذف نمی‌کند)؛
  // فقط جوانه‌ی بسته‌ی نوک تا وقتی باز نشده دیده می‌شود.
  final open = _sm((m - 1) / 6);
  final bs = 0.3 * R * (1 - open) + 0.05 * R;
  if (open < 0.98) {
    canvas.save();
    canvas.translate(apex.dx, apex.dy);
    canvas.rotate(apexAng);
    final bp = Path()
      ..moveTo(0, 0)
      ..cubicTo(bs * 0.8, -bs * 0.5, bs * 0.6, -bs * 2.0, 0, -bs * 2.8)
      ..cubicTo(-bs * 0.6, -bs * 2.0, -bs * 0.8, -bs * 0.5, 0, 0);
    canvas.drawPath(bp, Paint()..color = gc[1]);
    canvas.drawPath(
        bp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = const Color(0x33000000));
    canvas.restore();
  }
  if (open > 0.02) {
    final l2 = R * open * (1 + 0.3 * _sm(m / 60));
    _leaf(canvas, apex.dx, apex.dy, apexAng + (0.15 + 0.7 * open), l2,
        l2 * 0.42, gc);
    _leaf(canvas, apex.dx, apex.dy, apexAng - (0.15 + 0.7 * open), l2,
        l2 * 0.42, gc);
  }
  for (final t in tips) {
    final l2 = R * 0.8 * t.u;
    _leaf(canvas, t.p.dx, t.p.dy, t.a + 0.5, l2, l2 * 0.42, gc);
    _leaf(canvas, t.p.dx, t.p.dy, t.a - 0.5, l2, l2 * 0.42, gc);
  }

  // بعد از توقف: غنچه (کار ناتمام) یا گل (کار تمام) لابه‌لای همان برگ‌ها و شاخه‌ها.
  // هرچه گیاه بزرگ‌تر باشد، تعدادشان بیشتر است. همه کم‌کم می‌شکفند.
  if (mode != kPlantGrowing) {
    final fl = mode == kPlantFlowers;
    // زمان (تایمر/بازه) فقط برگ می‌دهد؛ غنچه = «امروز کار کردم» (یک غنچه برای هر روز)
    // و گل = کارِ تمام‌شده. پس روی نوکِ ساقه فقط یک غنچه (یا گل) می‌نشیند.
    place(apex, apexAng, R * (fl ? 0.8 : 0.62), 'top', fl);
  }
  canvas.restore();
}

class _Tip {
  _Tip(this.p, this.a, this.k, this.u);
  final Offset p;
  final double a;
  final int k;
  final double u;
}

/// برگ، غنچه و گل روی «تنه»ی خودِ شاخه/زیرشاخه 🌿
///
/// همان منطقِ زمانیِ گیاهِ تمرکز، ولی به‌جای نوکِ شاخه روی خودِ تنه می‌نشیند:
///  • همین که شاخه ثبت شد، دو جوانه‌ی ریزِ برگ روی تنه‌اش پدیدار می‌شود
///  • با جمع‌شدنِ دقیقه‌های کار، جوانه‌ها باز می‌شوند و جفت‌برگ‌های بعدی می‌آیند
///  • کارِ شروع‌شده (زمان/روزِ ثبت‌شده) = غنچه لابه‌لای برگ‌ها
///  • هر ۳ روزِ ثبت‌شده یک غنچه گل می‌شود؛ کارِ «کاملاً تمام شد» = همه گل
///
/// [pointAt]/[angleAt] نقطه و جهتِ تنه را در t=۰..۱ می‌دهند. [minutes] مجموعِ
/// همه‌ی دقیقه‌های ثبت‌شده‌ی همین شاخه است (نه فقط امروز).
void drawTrunkFlora(
  Canvas canvas, {
  required Offset Function(double t) pointAt,
  required double Function(double t) angleAt,
  required double r,
  required String id,
  required double minutes,
  required int doneDays,
  required bool finished,
  required bool running,
  required double bloom,
  required PlantSprig sprig,
  int slots = 6,
  // نیمه‌ی پهنای جاده: اگر بیشتر از صفر باشد، برگ و غنچه و گل از لبه‌ی جاده
  // (دو طرفِ جاده، دور تا دورِ آن) می‌رویند و روی آسفالت نمی‌افتند
  double edge = 0.0,
  // هر غنچه/گل = یک روزِ ثبت‌شده: seed همان شناسه‌ی تقویم است (شکلِ یکسان)؛
  // اگر داده شود جای [doneDays] را می‌گیرد و محدودیتِ تعداد ندارد
  List<({String seed, bool flower, double grow})>? marks,
  // طولِ جاده (برای چیدنِ غنچه‌ها در ردیف‌های بعدی وقتی کنارِ جاده جا نباشد)
  double pathLen = 0.0,
  // محلِ اتصالِ زیرشاخه‌ها (t=۰..۱): غنچه/گل‌ها از این نقطه‌ها دور می‌مانند
  List<double> avoidT = const [],
  // زمانِ باد (ثانیه)؛ null = بدونِ تکان
  double? windT,
}) {
  if (r < 1.2 || slots < 2) return;
  final m = math.max(0.0, minutes * kPlantTimeScale);
  var h = 11;
  for (final u in id.codeUnits) {
    h = (h * 33 + u) & 0x7fffffff;
  }
  final gc = _greens[h % 3];
  final dayBoost = doneDays * 12.0; // هر روزِ ثبت‌شده مثلِ چند دقیقه کار رشد می‌دهد
  final mm = m + dayBoost;
  // شاخه‌ای که هیچ کاری (دقیقه، روزِ ثبت‌شده یا تمام‌شدن) برایش ثبت نشده: نه بوته، نه علف، نه غنچه
  if (mm <= 0 && !finished && (marks == null || marks.isEmpty)) return;

  // آستانه‌ی بازشدنِ هر جفت‌برگ (دقیقه)
  const th = [0.0, 3.0, 10.0, 25.0, 50.0, 90.0, 150.0, 240.0, 340.0, 470.0,
    630.0, 820.0];
  // کنارِ جاده: جای برگ‌ها در طولِ جاده پخش می‌شود (هر تعداد که باشد یک‌جا جمع نمی‌شوند)
  double t0(int i) => edge > 0
      ? 0.9 - 0.78 * ((i * 0.6180339887 + 0.3) % 1.0)
      : 0.14 + i * (0.74 / (slots - 1));
  Offset nrm(double a) => Offset(-math.sin(a), math.cos(a));

  for (var i = 0; i < slots; i++) {
    final base = th[math.min(i, th.length - 1)];
    // دو جوانه‌ی اول از لحظه‌ی ثبت هستند؛ بقیه کمی قبل از باز شدن پدیدار می‌شوند
    final pre = i < 2 ? 1.0 : _sm((mm - base + 6) / 6);
    if (pre <= 0.02) continue;
    final k = i == 0
        ? math.max(0.3, _sm(mm / 4))
        : _sm((mm - base) / (8.0 + 4.0 * i));
    final full = r * math.max(0.72, 1.25 - 0.07 * i);
    final len = full * k + 0.28 * r * pre * (1 - k);
    if (len < 0.4) continue;
    final t = t0(i);
    // بوته روی جاده‌ی زیرشاخه نیفتد
    if (edge > 0 &&
        avoidT.any((jt) => (jt - t).abs() * math.max(pathLen, 44.0) < 18.0)) {
      continue;
    }
    final pc = pointAt(t);
    final a = angleAt(t);
    final jit = (((h >> (i + 2)) & 3) - 1.5) * 0.06;
    final spread = (edge > 0 ? 1.12 : 0.95) * (0.35 + 0.65 * k) + jit;
    final side = i.isEven ? 1.0 : -1.0;
    if (edge > 0) {
      // کنارِ جاده: به‌جای برگِ تنها، یک بوته که خیلی آهسته رشد می‌کند
      final gk =
          mm <= base ? 0.0 : 1.0 - math.exp(-(mm - base) / (12.0 + 6.0 * i));
      if (gk <= 0.0) continue;
      final bushDir = a + side * 1.25 + jit * 3;
      final bushBase = pc + nrm(a) * (side * (edge + r * 0.2));
      // نسیم: همه‌ی بوته‌ها در یک جهتِ دنیا خم می‌شوند (نه نسبت به جهتِ رشدشان)
      final bushSway = windT == null
          ? 0.0
          : windSway(windT, bushBase.dx, (h % 628) / 100.0 + i * 1.7) *
              0.2 *
              (math.sin(bushDir) <= 0 ? 1.0 : -1.0);
      drawRoadBush(canvas, bushBase, bushDir, r * 2.1, gk, h + i * 7919,
          sway: bushSway);
      continue;
    }
    // پایه‌ی برگ: روی خط‌وسطِ تنه (قبل)؛ کنارِ جاده: لبه‌ی همان سمت
    final p = edge > 0 ? pc + nrm(a) * (side * edge) : pc;
    final lw = windT == null
        ? 0.0
        : windSway(windT, pc.dx, (h % 628) / 100.0 + i * 1.3) * 0.12;
    _leaf(canvas, p.dx, p.dy, a + side * spread + math.pi / 2 + lw, len,
        len * (0.5 - 0.08 * k), gc);
    // از جفت‌برگِ سوم به بعد، برگِ سمتِ دیگر هم می‌آید (برگ‌های رویِ تنه پرتر می‌شوند)
    // کنارِ جاده از جفت‌برگِ دوم؛ برگِ سمتِ دیگر روی لبه‌ی آن سمت می‌نشیند
    if (i >= (edge > 0 ? 1 : 2) && k > 0.15) {
      final l2 = len * 0.82;
      final p2 = edge > 0 ? pc - nrm(a) * (side * edge) : pc;
      _leaf(canvas, p2.dx, p2.dy, a - side * spread + math.pi / 2 + lw, l2,
          l2 * (0.5 - 0.08 * k), gc);
    }
  }

  // غنچه و گل
  if (running && marks == null) return; // وقتی تایمر روشن است فقط رشدِ برگ دیده می‌شود
  final started = marks != null
      ? marks.isNotEmpty
      : (m > 0 || doneDays > 0 || finished);
  if (!started) return;
  if (marks != null) {
    // از سرِ شاخه (t≈۱) شروع می‌شود و به سمتِ ابتدا می‌آید؛ هر ۲۲ پیکسل یک جا،
    // دور از محلِ اتصالِ زیرشاخه‌ها. وقتی پر شد، ردیفِ بعدی کمی دورتر از جاده
    final plen = math.max(pathLen, 44.0);
    final step = (22.0 / plen).clamp(0.02, 0.25).toDouble();
    final cand = <double>[];
    for (var tt = 0.93; tt >= 0.1; tt -= step) {
      var ok = true;
      for (final jt in avoidT) {
        if ((jt - tt).abs() * plen < 18.0) {
          ok = false;
          break;
        }
      }
      if (ok) cand.add(tt);
    }
    if (cand.isEmpty) cand.add(0.6);
    final perRow = cand.length;
    for (var j = 0; j < marks.length; j++) {
      final mk = marks[j];
      final row = j ~/ perRow;
      final col = j % perRow;
      final t = (cand[col] - (row.isOdd ? step * 0.5 : 0.0))
          .clamp(0.05, 0.95)
          .toDouble();
      final pc = pointAt(t);
      final a = angleAt(t);
      final side = (col + row).isEven ? -1.0 : 1.0;
      final dirA = a + side * 1.15;
      final rr = r * (mk.flower ? 0.62 : 0.5);
      final dist = (edge > 0 ? edge : 0.0) + r * 0.5 + row * r * 1.7;
      final pos = pc + nrm(a) * (side * dist);
      final pp = math.min(
          (bloom * 1.4 - math.min(j, 6) * 0.12).clamp(0.0, 1.0).toDouble(),
          mk.grow);
      sprig(canvas, pos, dirA, rr, mk.seed, pp, mk.flower);
    }
    return;
  }
  // هر روزِ ثبت‌شده یک غنچه؛ وقتی کار تمام شد آخرین غنچه گل می‌شود.
  // (زمانِ تایمر/بازه فقط برگ می‌دهد، نه غنچه)
  // فقط برای کارِ واقعاً ثبت‌شده (تایمر، ساعتِ ثبت‌شده یا تیکِ تقویم): هر غنچه = یک روزِ ثبت‌شده
  final n = math.min(14, doneDays);
  for (var j = 0; j < n; j++) {
    final fl = finished && j == n - 1;
    final t = n == 1 ? 0.5 : 0.2 + j * (0.68 / (n - 1));
    final p = pointAt(math.min(t, 0.92));
    final a = angleAt(math.min(t, 0.92));
    final side = j.isEven ? -1.0 : 1.0; // سمتِ مخالفِ برگِ همان گره
    final dirA = a + side * (edge > 0 ? 1.15 : 1.05);
    // کنارِ جاده: غنچه/گل بیرونِ لبه‌ی جاده می‌نشیند
    final out = edge > 0
        ? nrm(a) * (side * (edge + r * 0.35))
        : Offset(math.cos(dirA), math.sin(dirA)) * (r * 0.3);
    final pp = (bloom * 1.4 - j * 0.12).clamp(0.0, 1.0).toDouble();
    sprig(canvas, p + out, dirA, r * (fl ? 0.62 : 0.5), '$id|t$j', pp, fl);
  }
}
