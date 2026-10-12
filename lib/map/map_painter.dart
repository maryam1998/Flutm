import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/constants.dart';
import '../models/map_models.dart';
import 'camera.dart';
import 'draw_utils.dart';
import 'geometry.dart';
import 'user_state.dart';

/// اگه true باشه جای برچسب شاخه‌ها مثل «RTL واقعی» SVG میشه (برچسب روی نوک شاخه می‌افته)
const kLabelRtlAnchor = false;

double _l(double a, double b, double t) => a + (b - a) * t;

class MapPainter extends CustomPainter {
  MapPainter({
    required this.state,
    required this.cam,
    required this.time,
    required this.images,
    required this.boundsBox,
  }) : super(repaint: Listenable.merge([cam, time, images]));

  final MapState state;
  final CameraController cam;
  final ValueNotifier<double> time;
  final NodeImageCache images;
  final MapBoundsBox boundsBox;
  final List<Offset> _pts = [];

  double get _t => time.value;

  @override
  bool shouldRepaint(covariant MapPainter old) => true;

  // ---------- رنگ و اندازه‌ی متن ----------
  Color get _textColor {
    final c = state.textColor.toLowerCase().trim();
    const auto = {'', '#eef0fa', '#ffffff', '#fff', '#000000', '#000'};
    return auto.contains(c) ? Colors.white : hexColor(state.textColor, Colors.white);
  }

  double _fs() => math.max(14, state.fontSize);
  double _labelSize(String type, [double scale = 1]) {
    switch (type) {
      case 'me':
        return _fs() + 3;
      case 'goal':
        return _fs();
      case 'ring':
        return _fs() - 2;
      default:
        return math.max(12, state.fontSize * math.min(1.0, scale + 0.3));
    }
  }

  // ---------- paint ----------
  @override
  void paint(Canvas canvas, Size size) {
    _pts.clear();
    canvas.save();
    canvas.translate(cam.x, cam.y);
    canvas.scale(cam.scale);
    final tc = _textColor;

    for (final g in state.goals) {
      _branches(canvas, g, tc, trunkOnly: g.collapsed && g.actions.isNotEmpty);
    }
    for (final r in state.rings) {
      if (r.actions.isNotEmpty) {
        final lg = _goalOf(r);
        _branches(canvas, r, tc, trunkOnly: r.collapsed || (lg?.collapsed ?? false));
      }
    }
    _drawMe(canvas, tc);
    for (final g in state.goals) {
      _drawGoal(canvas, g, tc);
    }
    for (final r in state.rings) {
      _drawRing(canvas, r, tc);
    }
    canvas.restore();

    if (_pts.isNotEmpty) {
      var minX = _pts.first.dx, maxX = minX, minY = _pts.first.dy, maxY = minY;
      for (final p in _pts) {
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
      boundsBox.rect = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(30);
    }
  }

  Goal? _goalOf(Ring r) {
    for (final g in state.goals) {
      if (g.id == r.goalId) return g;
    }
    return null;
  }

  void _addCircleBounds(Offset c, double r) {
    _pts..add(c.translate(-r, -r))..add(c.translate(r, r));
  }

  // ---------- هاله و آئورا ----------
  void _halo(Canvas canvas, Offset c, Color color, double r, double pf, String? freqKey) {
    final f = kFreqBands[freqKey] ?? kFreqBands['alpha']!;
    final base = f.speed;
    double tri(double dur) {
      final p = (_t / dur) % 1.0;
      return p < 0.5 ? p * 2 : (1 - p) * 2;
    }

    final blur = cam.scale < 0.3 ? null : const MaskFilter.blur(BlurStyle.normal, 4);
    final to = tri(base * 1.35);
    canvas.drawCircle(c, _l(r * 1.7 * pf, r * 2.2 * pf, to),
        Paint()..color = withOp(color, _l(0.07, 0.16, to))..maskFilter = blur);
    final tm = tri(base);
    canvas.drawCircle(c, _l(r * 1.25 * pf, r * 1.55 * pf, tm),
        Paint()..color = withOp(color, _l(0.13, 0.24, tm))..maskFilter = blur);
    final ti = tri(base * 0.8);
    canvas.drawCircle(
        c,
        _l(r * 0.88 * pf, r * 1.08 * pf, ti),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = withOp(color, _l(0.45, 0.75, ti)));
  }

  void _aura(Canvas canvas, Offset c, double r, UserFreq u) {
    final band = kFreqBands[u.band]!;
    final col = hexColor(band.color);
    final glowR = r * (1.6 + u.progress * 0.9);
    final glowOp = 0.15 + u.progress * 0.25;
    canvas.drawCircle(c, glowR, Paint()..color = withOp(col, glowOp));
    canvas.drawCircle(c, glowR * 0.6, Paint()..color = withOp(Colors.white, glowOp * 0.55));
    final dur = band.speed * 1.4;
    final op = 0.35 + u.progress * 0.45;
    for (var i = 0; i < 3; i++) {
      final local = _t - i * band.speed / 3;
      if (local < 0) continue;
      final p = (local % dur) / dur;
      canvas.drawCircle(
          c,
          _l(r * 1.15, r * 3.2, p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 + u.progress * 1.6
            ..color = withOp(col, op * (1 - p)));
    }
  }

  // ---------- تصویر ----------
  void _circleImage(Canvas canvas, Offset c, double r, ui.Image im) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    paintImage(canvas: canvas, rect: Rect.fromCircle(center: c, radius: r), image: im, fit: BoxFit.cover);
    canvas.restore();
  }

  // ---------- گره «من» ----------
  void _drawMe(Canvas canvas, Color tc) {
    final me = state.me;
    final c = Offset(me.x, me.y);
    final r = me.radius;
    final u = userFrequencyState(state);
    final band = kFreqBands[u.band]!;
    _aura(canvas, c, r, u);
    _halo(canvas, c, hexColor(band.color), r, 1, u.band);
    final meColor = hexColor(me.color.isEmpty ? band.color : me.color);
    _addCircleBounds(c, r);

    if (me.images.isEmpty) {
      canvas.drawCircle(c, r, Paint()..color = meColor);
      canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5..color = meColor);
      final s = r * 0.42, cy2 = c.dy - r * 0.12;
      final pp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = withOp(tc, 0.85);
      drawDashed(canvas, Path()..addOval(Rect.fromCircle(center: Offset(c.dx, cy2), radius: s)), pp, [4, 3]);
      final lp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = withOp(tc, 0.85);
      canvas.drawLine(Offset(c.dx - s * 0.5, cy2), Offset(c.dx + s * 0.5, cy2), lp);
      canvas.drawLine(Offset(c.dx, cy2 - s * 0.5), Offset(c.dx, cy2 + s * 0.5), lp);
      drawText(canvas, me.name, c.dx, c.dy + r * 0.62,
          size: math.max(9, state.fontSize - 4), color: tc, weight: FontWeight.w700);
    } else {
      final im = images.get(me.images.first.src);
      if (im != null) {
        _circleImage(canvas, c, r, im);
      } else {
        canvas.drawCircle(c, r, Paint()..color = withOp(meColor, 0.4));
      }
      canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5..color = meColor);
      drawText(canvas, me.name, c.dx + me.labelDX, c.dy + 6 + me.labelDY,
          size: me.labelSize ?? _labelSize('me'), color: tc, weight: FontWeight.w700, outline: 3);
    }
  }

  // ---------- آیکون گره (هدف/حلقه) ----------
  void _nodeIcon(Canvas canvas, Offset c, double r0, List<ImageItem> imgs, String icon, Color color, double iconScale, Color tc) {
    final r = r0 * iconScale;
    if (imgs.isNotEmpty && imgs.first.src.isNotEmpty) {
      final im = images.get(imgs.first.src);
      if (im != null) {
        _circleImage(canvas, c, r, im);
        canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = withOp(color, 0.55));
      } else {
        canvas.drawCircle(c, r, Paint()..color = withOp(color, 0.4));
      }
    } else if (icon.trim().isNotEmpty) {
      drawText(canvas, icon, c.dx, c.dy, size: r * 1.7, color: tc, vCenter: true);
    } else {
      canvas.drawCircle(c, r, Paint()..color = withOp(color, 0.85));
    }
  }

  // ---------- هدف ----------
  void _drawGoal(Canvas canvas, Goal g, Color tc) {
    final r0 = g.radius;
    final c = Offset(g.x, g.y);
    final col = hexColor(g.color, hexColor(kPalette[0]));
    _halo(canvas, c, col, r0 * math.max(1.0, g.iconScale), 1, g.freq);
    _nodeIcon(canvas, c, r0, g.images, g.icon, col, g.iconScale, tc);
    final r = r0 * g.iconScale;
    _addCircleBounds(c, r);

    var off = -(r0 + 22);
    if (r > r0) off += (off < 0 ? -1 : 1) * (r - r0);
    drawText(canvas, g.name, c.dx + g.labelDX, c.dy + off + g.labelDY,
        size: g.labelSize ?? _labelSize('goal'), color: tc, weight: FontWeight.w600, outline: 3);

    final freq = kFreqBands[g.freq] ?? kFreqBands['alpha']!;
    double sumW(List<ActionNode> l) => l.fold(0.0, (s, a) => s + a.weight + sumW(a.children));
    final power = math.min(100, (sumW(g.actions) * 3).round());
    final has = g.actions.isNotEmpty;
    final hud = (g.collapsed && has) ? 'رشد $power٪' : '${freq.label} — ${freq.desc} · رشد $power٪';
    drawText(canvas, hud, c.dx, c.dy + r0 + (has ? 46 : 42), size: 11, color: withOp(tc, 0.6), weight: FontWeight.w400);
  }

  // ---------- حلقه ----------
  void _drawRing(Canvas canvas, Ring r, Color tc) {
    final c = Offset(r.x, r.y);
    final rad = r.radius;
    final col = hexColor(r.color, hexColor(kRingColor));
    final big = rad * math.max(1.0, r.iconScale);
    _halo(canvas, c, col, big, 1.2, null);
    _nodeIcon(canvas, c, rad, r.images, r.icon, col, r.iconScale, tc);
    _addCircleBounds(c, rad * r.iconScale);

    if (r.label.isNotEmpty) {
      final lines = wrapText(r.label, 16);
      final lx = c.dx + r.labelDX;
      final ly = c.dy - (big + 20) + r.labelDY;
      for (var i = 0; i < lines.length; i++) {
        drawText(canvas, lines[i], lx, ly + i * 16,
            size: r.labelSize ?? _labelSize('ring'), color: col, weight: FontWeight.w700, outline: 3);
      }
    }
    if (r.note.isNotEmpty) {
      final lines = wrapText(r.note, 22);
      final ly = c.dy + big + 18;
      for (var i = 0; i < lines.length; i++) {
        drawText(canvas, lines[i], c.dx, ly + i * 16, size: _fs() - 3, color: tc, weight: FontWeight.w400, outline: 2.5);
      }
    }
  }

  // ---------- تنه و شاخه‌ها ----------
  void _branches(Canvas canvas, MapHost h, Color tc, {required bool trunkOnly}) {
    final cp = trunkControlPoints(h, state.me);
    final col = hexColor(h.color, hexColor(h.isRing ? kRingColor : kPalette[0]));
    if (h.isRing) {
      _taperedBezier(canvas, cp, col, 3.2, 1.6, 0.6);
    } else {
      final ts = (h is Goal && h.trunkStyle.isNotEmpty) ? h.trunkStyle : state.trunkStyle;
      _trunk(canvas, cp, col, kTrunkStyles.containsKey(ts) ? ts : 'dashed');
    }
    _pts..add(cp.p0)..add(cp.p3);
    if (trunkOnly) return;
    for (var i = 0; i < h.actions.length; i++) {
      final t = math.min(0.9, 0.15 + i * 0.09);
      _twig(canvas, h, col, cp.at(t), cp.tangent(t), h.actions[i], i.isEven ? 1 : -1, 1.0, tc);
    }
  }

  Paint _stroke(Color col, double w, double op, {StrokeCap cap = StrokeCap.round}) => Paint()
    ..style = PaintingStyle.stroke
    ..color = withOp(col, op)
    ..strokeWidth = w
    ..strokeCap = cap
    ..strokeJoin = StrokeJoin.round;

  Path _pathOf(Cubic k) => Path()
    ..moveTo(k.p0.dx, k.p0.dy)
    ..cubicTo(k.p1.dx, k.p1.dy, k.p2.dx, k.p2.dy, k.p3.dx, k.p3.dy);

  void _trunk(Canvas c, Cubic cp, Color col, String style) {
    switch (style) {
      case 'solid':
        c.drawPath(_pathOf(cp), _stroke(col, 3, 0.9));
      case 'dotted':
        drawDashed(c, _pathOf(cp), _stroke(col, 3.6, 0.9), [0.1, 8]);
      case 'dashdot':
        drawDashed(c, _pathOf(cp), _stroke(col, 3, 0.9, cap: StrokeCap.butt), [14, 7, 2, 7]);
      case 'long':
        drawDashed(c, _pathOf(cp), _stroke(col, 3, 0.9, cap: StrokeCap.butt), [26, 13]);
      case 'double':
        {
          final d = cp.p3 - cp.p0;
          final len = d.distance == 0 ? 1.0 : d.distance;
          final n = Offset(-d.dy / len * 2.6, d.dx / len * 2.6);
          for (final k in [1.0, -1.0]) {
            final o = n * k;
            c.drawPath(_pathOf(Cubic(cp.p0 + o, cp.p1 + o, cp.p2 + o, cp.p3 + o)), _stroke(col, 1.6, 0.9));
          }
        }
      case 'glow':
        c.drawPath(_pathOf(cp), _stroke(col, 9, 0.16));
        c.drawPath(_pathOf(cp), _stroke(col, 2.8, 0.95));
      case 'taper':
        _taperedBezier(c, cp, col, 5.2, 1.6, 0.9);
      default:
        drawDashed(c, _pathOf(cp), _stroke(col, 3, 0.9, cap: StrokeCap.butt), [9, 9]);
    }
  }

  void _taperedBezier(Canvas c, Cubic cp, Color col, double w0, double w1, double op) {
    const seg = 7;
    final p = _stroke(col, w0, op);
    for (var s = 0; s < seg; s++) {
      p.strokeWidth = w0 + (w1 - w0) * ((s + 0.5) / seg);
      c.drawLine(cp.at(s / seg), cp.at((s + 1) / seg), p);
    }
  }

  void _taperedPoly(Canvas c, List<Offset> pts, Color col, double w0, double w1, double op) {
    final cum = polyCum(pts);
    final tot = cum.last == 0 ? 1.0 : cum.last;
    final p = _stroke(col, w0, op);
    for (var i = 1; i < pts.length; i++) {
      final f = ((cum[i - 1] + cum[i]) / 2) / tot;
      p.strokeWidth = w0 + (w1 - w0) * f;
      c.drawLine(pts[i - 1], pts[i], p);
    }
  }

  void _twig(Canvas canvas, MapHost h, Color hostColor, Offset originPt, double originDir, ActionNode a, int side, double scale, Color tc) {
    final weight = a.weight == 0 ? 5.0 : a.weight;
    final color = (a.color != null && a.color!.isNotEmpty) ? hexColor(a.color, hostColor) : hostColor;
    final geom = computeTwigGeom(h, a, originPt, originDir, side, scale);
    applyBranchStyle(geom, effBranchStyle(h, a), side);
    final end = geom.end;
    _pts.add(end);

    final baseW = math.max(1.0, (1.9 + weight * 1.05) * scale);
    final tipW = math.max(0.7, baseW * 0.38);
    final cub = Cubic(geom.originPt, geom.c1, geom.c2, end);
    if (geom.poly != null) {
      _taperedPoly(canvas, geom.poly!, color, baseW, tipW, 0.92);
    } else {
      _taperedBezier(canvas, cub, color, baseW, tipW, 0.92);
    }

    final kids = a.children;
    if (kids.isNotEmpty) {
      canvas.drawCircle(end, math.max(2.0, 2.6 * scale), _stroke(color, 1.2, 0.55));
      for (var i = 0; i < kids.length; i++) {
        final tt = 0.5 + ((i + 1) / (kids.length + 1)) * 0.45;
        Offset co;
        double cd;
        if (geom.poly != null) {
          final q = polyPointAt(geom.poly!, tt);
          co = q.pt;
          cd = q.angle;
        } else {
          co = cub.at(tt);
          cd = cub.tangent(tt);
        }
        _twig(canvas, h, hostColor, co, cd, kids[i], i.isEven ? 1 : -1, scale * 0.72, tc);
      }
    } else if (a.images.isNotEmpty) {
      final radius = math.max(1.8, 2 + weight * 0.28 * scale);
      final cnt = math.min(a.images.length, 3);
      for (var i = 0; i < cnt; i++) {
        final e = a.images[i];
        final ang = (i / cnt) * math.pi * 2 - math.pi / 2;
        final off = Offset(math.cos(ang) * radius * 0.7 + e.dx, math.sin(ang) * radius * 0.7 + e.dy);
        final rect = Rect.fromCenter(center: end + off, width: e.size, height: e.size);
        final im = images.get(e.src);
        if (im != null) paintImage(canvas: canvas, rect: rect, image: im, fit: BoxFit.contain);
      }
      if (a.images.length > 3) {
        drawText(canvas, '+${a.images.length - 3}', end.dx + radius * 0.7, end.dy + radius * 0.7 + 4,
            size: 10, color: tc, outline: 2);
      }
    } else {
      canvas.drawCircle(end, math.max(1.8, 2 + weight * 0.28 * scale), Paint()..color = color);
    }

    if (a.text.isNotEmpty) {
      final lines = wrapText(a.text, math.max(10, (18 * math.min(1.0, scale + 0.35)).round()));
      final right = kLabelRtlAnchor ? side > 0 : side < 0;
      final lx = end.dx + (side > 0 ? 8 : -8) + a.labelDX;
      final ly = end.dy + 4 + a.labelDY;
      final fs = a.labelSize ?? _labelSize('action', scale);
      for (var i = 0; i < lines.length; i++) {
        drawText(canvas, lines[i], lx, ly + i * 16,
            size: fs, color: tc, weight: FontWeight.w400,
            align: right ? LabelAlign.right : LabelAlign.left, outline: 2.5);
      }
    }
  }
}
