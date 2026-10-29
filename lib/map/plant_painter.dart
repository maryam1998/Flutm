import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

  // برگ‌های ساقه (جفت‌برگ؛ سمتِ شاخه‌ی فرعی خالی می‌ماند)
  for (var i = 0; i < 6; i++) {
    final hi = nodeH(i);
    final g = _sm((bigH - hi) / (1.3 * R));
    if (g <= 0.01) continue;
    final p = stemPt(hi);
    final len = R * (1.35 - 0.09 * i) * g;
    final ang = (0.95 + 0.06 * i) * (0.35 + 0.65 * g);
    final hasBranch = i >= 1 && _sm((m - starts[i - 1]) / 24) > 0.02;
    final bs = hasBranch ? branchSide(i - 1) : 0.0;
    if (bs != 1.0) _leaf(canvas, p.dx, p.dy, ang, len, len * 0.42, gc);
    if (bs != -1.0) _leaf(canvas, p.dx, p.dy, -ang, len, len * 0.42, gc);
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
      final k2 = _sm((u - tt) / 0.35);
      final sz = R * 0.95 * k2;
      if (sz < 0.3) continue;
      final q = bz(tt);
      final sd = (li % 2 == 0 ? 1.0 : -1.0) * s;
      _leaf(canvas, q.dx, q.dy, tg(tt) + sd * 0.9 * (0.4 + 0.6 * k2), sz,
          sz * 0.42, gc);
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

  if (mode == kPlantGrowing) {
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
  } else {
    final fl = mode == kPlantFlowers;
    place(apex, apexAng, R * (fl ? 1.0 : 0.85), 'top', fl);
    for (final t in tips) {
      place(t.p, t.a, R * (fl ? 0.8 : 0.7), 'b${t.k}', fl);
    }
    for (final i in const [2, 4]) {
      final hi = nodeH(i);
      if (_sm((bigH - hi) / (1.3 * R)) < 0.9) continue;
      place(stemPt(hi), i == 2 ? 0.9 : -0.9, R * (fl ? 0.55 : 0.5), 'a$i', fl);
    }
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
