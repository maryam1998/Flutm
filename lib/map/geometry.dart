import 'dart:math' as math;
import 'dart:ui';

import '../models/constants.dart';
import '../models/map_models.dart';
import 'seeded.dart';

class Cubic {
  const Cubic(this.p0, this.p1, this.p2, this.p3);
  final Offset p0, p1, p2, p3;

  Offset at(double t) {
    final mt = 1 - t;
    return p0 * (mt * mt * mt) + p1 * (3 * mt * mt * t) + p2 * (3 * mt * t * t) + p3 * (t * t * t);
  }

  double tangent(double t) {
    final mt = 1 - t;
    final d = (p1 - p0) * (3 * mt * mt) + (p2 - p1) * (6 * mt * t) + (p3 - p2) * (3 * t * t);
    return math.atan2(d.dy, d.dx);
  }
}

/// تنه‌ی هدف (از «من» تا هدف) یا ساقه‌ی حلقه
Cubic trunkControlPoints(MapHost h, MeNode me) {
  if (h.isRing) {
    final rad = h.radius == 0 ? 30.0 : h.radius;
    const ll = 130.0;
    final a = math.atan2(h.y - me.y, h.x - me.x);
    final ux = math.cos(a), uy = math.sin(a), px = -uy, py = ux;
    final q0 = Offset(h.x + ux * rad, h.y + uy * rad);
    final rr = seeded('${h.id}-trunk');
    final k1 = (rr() * 0.5 - 0.25) * ll * 0.3;
    final k2 = (rr() * 0.5 - 0.25) * ll * 0.3;
    return Cubic(
      q0,
      Offset(q0.dx + ux * ll * 0.33 + px * k1, q0.dy + uy * ll * 0.33 + py * k1),
      Offset(q0.dx + ux * ll * 0.66 + px * k2, q0.dy + uy * ll * 0.66 + py * k2),
      Offset(q0.dx + ux * ll, q0.dy + uy * ll),
    );
  }
  final p0 = Offset(me.x, me.y), p3 = Offset(h.x, h.y);
  final dx = p3.dx - p0.dx, dy = p3.dy - p0.dy;
  var len = math.sqrt(dx * dx + dy * dy);
  if (len == 0) len = 1;
  final ux = dx / len, uy = dy / len, px = -uy, py = ux;
  final rnd = seeded('${h.id}-trunk');
  final o1 = (rnd() * 0.5 - 0.25) * len * 0.4;
  final o2 = (rnd() * 0.5 - 0.25) * len * 0.4;
  return Cubic(
    p0,
    Offset(p0.dx + ux * len * 0.33 + px * o1, p0.dy + uy * len * 0.33 + py * o1),
    Offset(p0.dx + ux * len * 0.66 + px * o2, p0.dy + uy * len * 0.66 + py * o2),
    p3,
  );
}

class TwigGeom {
  TwigGeom(this.originPt, this.dir, this.length, this.c1, this.c2, this.end);
  Offset originPt, c1, c2, end;
  double dir, length;
  List<Offset>? poly;
}

/// هندسه‌ی یک شاخه. اگه dir/len هنوز ذخیره نشده، مثل نسخه‌ی وب با seed ساخته و روی خود شاخه ذخیره میشه.
TwigGeom computeTwigGeom(MapHost goal, ActionNode a, Offset originPt, double originDir, int side, double scale) {
  if (a.detached) {
    final origin = Offset(a.originX ?? 0, a.originY ?? 0);
    final dir = a.dir ?? 0, length = a.len ?? 30;
    return _build(origin, dir, length, a.bend1 ?? 0, a.bend2 ?? 0);
  }
  if (a.dir == null || a.len == null) {
    final rnd = seeded('${goal.id}-${a.id}');
    final angleOff = side * (0.8 + rnd() * 0.5);
    final weight = a.weight == 0 ? 5.0 : a.weight;
    a.dir = originDir + angleOff;
    a.len = (18 + weight * 8) * scale;
    a.bend1 = side * (5 + rnd() * 9) * scale;
    a.bend2 = side * (-4 + rnd() * 12) * scale;
  }
  return _build(originPt, a.dir!, a.len!, a.bend1 ?? 0, a.bend2 ?? 0);
}

TwigGeom _build(Offset o, double dir, double length, double bend1, double bend2) {
  final dvx = math.cos(dir), dvy = math.sin(dir), px = -dvy, py = dvx;
  return TwigGeom(
    o, dir, length,
    Offset(o.dx + dvx * length * 0.33 + px * bend1, o.dy + dvy * length * 0.33 + py * bend1),
    Offset(o.dx + dvx * length * 0.72 + px * bend2, o.dy + dvy * length * 0.72 + py * bend2),
    Offset(o.dx + dvx * length, o.dy + dvy * length),
  );
}

String effBranchStyle(MapHost host, ActionNode a) {
  final s = a.style.isNotEmpty ? a.style : host.branchStyle;
  return kBranchStyles.containsKey(s) ? s : 'organic';
}

void applyBranchStyle(TwigGeom g, String style, int side) {
  if (style.isEmpty || style == 'organic') return;
  final o = g.originPt, e = g.end;
  final len = g.length == 0 ? 1.0 : g.length;
  final dvx = math.cos(g.dir), dvy = math.sin(g.dir), px = -dvy, py = dvx;
  final sd = side.toDouble();
  Offset at(double a, double b) =>
      Offset(o.dx + dvx * len * a + px * len * b, o.dy + dvy * len * a + py * len * b);
  switch (style) {
    case 'straight':
      g.c1 = at(0.33, 0);
      g.c2 = at(0.72, 0);
    case 'curve':
      g.c1 = at(0.22, 0.40 * sd);
      g.c2 = at(0.78, 0.40 * sd);
    case 'wave':
      g.c1 = at(0.25, 0.45 * sd);
      g.c2 = at(0.75, -0.45 * sd);
    case 'elbow':
      {
        final horiz = (e.dx - o.dx).abs() >= (e.dy - o.dy).abs();
        g.poly = [o, horiz ? Offset(e.dx, o.dy) : Offset(o.dx, e.dy), e];
      }
    case 'step':
      {
        final horiz = (e.dx - o.dx).abs() >= (e.dy - o.dy).abs();
        g.poly = horiz
            ? [o, Offset((o.dx + e.dx) / 2, o.dy), Offset((o.dx + e.dx) / 2, e.dy), e]
            : [o, Offset(o.dx, (o.dy + e.dy) / 2), Offset(e.dx, (o.dy + e.dy) / 2), e];
      }
    case 'zigzag':
      {
        const n = 6;
        final amp = math.min(0.13 * len, 13.0);
        final pts = <Offset>[o];
        for (var i = 1; i < n; i++) {
          final k = (i % 2 == 1 ? 1 : -1) * sd * amp;
          final b = at(i / n, 0);
          pts.add(Offset(b.dx + px * k, b.dy + py * k));
        }
        pts.add(e);
        g.poly = pts;
      }
  }
}

class PolyPoint {
  PolyPoint(this.pt, this.angle);
  final Offset pt;
  final double angle;
}

List<double> polyCum(List<Offset> pts) {
  final c = <double>[0];
  for (var i = 1; i < pts.length; i++) {
    c.add(c[i - 1] + (pts[i] - pts[i - 1]).distance);
  }
  return c;
}

PolyPoint polyPointAt(List<Offset> pts, double t) {
  final c = polyCum(pts);
  final tt = c.last * t.clamp(0.0, 1.0);
  for (var i = 1; i < pts.length; i++) {
    if (tt <= c[i] || i == pts.length - 1) {
      final seg = (c[i] - c[i - 1]) == 0 ? 1.0 : (c[i] - c[i - 1]);
      final f = ((tt - c[i - 1]) / seg).clamp(0.0, 1.0);
      final d = pts[i] - pts[i - 1];
      return PolyPoint(Offset.lerp(pts[i - 1], pts[i], f)!, math.atan2(d.dy, d.dx));
    }
  }
  return PolyPoint(pts.first, 0);
}
