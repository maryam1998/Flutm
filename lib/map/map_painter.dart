import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/constants.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import 'camera.dart';
import 'draw_utils.dart';
import 'foot_shape.dart';
import 'geometry.dart' as geo;
import 'hit_registry.dart';
import 'map_ops.dart';
import 'user_state.dart';

const kLabelRtlAnchor = false;

double _l(double a, double b, double t) => a + (b - a) * t;

/// ease in-out (کند → تند → کند)
double _easeInOut(double t) {
  if (t < 0.5) return 2 * t * t;
  final u = -2 * t + 2;
  return 1 - u * u / 2;
}

/// منحنی عمومی برای قدم‌زن: t بین ۰ و ۱
abstract class _Curve {
  Offset at(double t);
  double tangent(double t);
}

class _CubicCurve implements _Curve {
  _CubicCurve(this.c);
  final geo.Cubic c;
  @override
  Offset at(double t) => c.at(t);
  @override
  double tangent(double t) => c.tangent(t);
}

/// مسیر چندپاره (از ابتدای شاخه، روی شاخه‌های پدر، تا تنه و هدف)
class _RouteCurve implements _Curve {
  _RouteCurve(List<Offset> raw) {
    for (final p in raw) {
      if (pts.isEmpty || (p - pts.last).distance > 0.5) pts.add(p);
    }
    if (pts.length < 2) pts.add(pts.first + const Offset(1, 0));
    cum.add(0);
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum.last + (pts[i] - pts[i - 1]).distance);
    }
    length = cum.last;
  }
  final List<Offset> pts = [];
  final List<double> cum = [];
  late final double length;

  @override
  Offset at(double t) {
    final d = length * t.clamp(0.0, 1.0);
    for (var i = 1; i < pts.length; i++) {
      if (d <= cum[i] || i == pts.length - 1) {
        final seg = (cum[i] - cum[i - 1]);
        final f = seg == 0 ? 0.0 : ((d - cum[i - 1]) / seg).clamp(0.0, 1.0);
        return Offset.lerp(pts[i - 1], pts[i], f)!;
      }
    }
    return pts.first;
  }

  /// جهت به سمت هدف؛ با پنجره‌ی کوچک نرم می‌شود تا در پیچ‌ها ناگهانی نچرخد
  @override
  double tangent(double t) {
    final w = math.min(0.25, 14.0 / math.max(length, 1.0));
    final a = at((t - w).clamp(0.0, 1.0));
    final b = at((t + w).clamp(0.0, 1.0));
    final d = b - a;
    return math.atan2(d.dy, d.dx);
  }
}

class MapPainter extends CustomPainter {
  MapPainter({
    required this.state,
    required this.cam,
    required this.time,
    required this.images,
    required this.boundsBox,
    required this.hits,
    this.isDark = true,
  }) : super(repaint: Listenable.merge([cam, time, images]));

  final MapState state;
  final CameraController cam;
  final ValueNotifier<double> time;
  final NodeImageCache images;
  final MapBoundsBox boundsBox;
  final HitRegistry hits;
  final bool isDark;
  final List<Offset> _pts = [];

  double get _t => time.value;

  /// موقعیت پاهای قدم‌زن‌های رسم‌شده در این فریم (برای دوری از تداخل)
  final List<Offset> _walkerPts = [];

  @override
  bool shouldRepaint(covariant MapPainter old) => true;

  // ───────────────────────── رنگ و اندازه ─────────────────────────

  Color get _textColor {
    final c = state.textColor.toLowerCase().trim();
    final auto = isDark ? Colors.white : Colors.black;
    if (c == '#000000' || c == '#000') return Colors.black;
    if (c.isEmpty || c == '#eef0fa' || c == '#ffffff' || c == '#fff') {
      return auto;
    }
    return hexColor(c, auto);
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

  String _formatStamp(int ts) {
    try {
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      final parts = <String>[];
      if (state.showDateStamps) {
        final j = toJalaali(d.year, d.month, d.day);
        parts.add('${toFa(j.jy)}/${toFa(j.jm)}/${toFa(j.jd)}');
      }
      if (state.showTimeStamps) {
        parts.add(
            '${toFa(d.hour.toString().padLeft(2, '0'))}:${toFa(d.minute.toString().padLeft(2, '0'))}');
      }
      return parts.join(' — ');
    } catch (_) {
      return '';
    }
  }

  void _ringLink(Canvas canvas, Goal g, Ring r) {
    final dx = r.x - g.x;
    final dy = r.y - g.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 1) return;
    final ux = dx / d;
    final uy = dy / d;
    final x1 = g.x + ux * (g.radius + 6);
    final y1 = g.y + uy * (g.radius + 6);
    final x2 = r.x - ux * (r.radius + 6);
    final y2 = r.y - uy * (r.radius + 6);
    final mx = (x1 + x2) / 2 - uy * d * 0.12;
    final my = (y1 + y2) / 2 + ux * d * 0.12;

    final col = hexColor(r.color, hexColor(kRingColor));
    final path = Path()
      ..moveTo(x1, y1)
      ..quadraticBezierTo(mx, my, x2, y2);

    drawDashed(
      canvas,
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = withOp(col, 0.6),
      const [2, 7],
    );
  }

  // ───────────────────────── paint ─────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    textCache.setOutline(
        isDark ? const Color(0xFF0A0C18) : const Color(0xFFF4F6FB));
    _pts.clear();
    _walkerPts.clear();
    hits.clear();
    canvas.save();
    canvas.translate(cam.x, cam.y);
    canvas.scale(cam.scale);
    final tc = _textColor;

    for (final g in state.goals) {
      _branches(canvas, g, tc, trunkOnly: g.collapsed && g.actions.isNotEmpty);
    }
    if (!state.ringsCollapsed) {
      for (final r in state.rings) {
        if (r.actions.isNotEmpty) {
          final lg = _goalOf(r);
          _branches(canvas, r, tc,
              trunkOnly: r.collapsed || (lg?.collapsed ?? false));
        }
      }
    }
    if (state.showRingLinks && !state.ringsCollapsed) {
      for (final r in state.rings) {
        if (r.goalId.isEmpty) continue;
        Goal? lg;
        for (final gg in state.goals) {
          if (gg.id == r.goalId) {
            lg = gg;
            break;
          }
        }
        if (lg == null) continue;
        _ringLink(canvas, lg, r);
      }
    }
    _drawMe(canvas, tc);
    for (final g in state.goals) {
      _drawGoal(canvas, g, tc);
    }
    if (!state.ringsCollapsed) {
      for (final r in state.rings) {
        _drawRing(canvas, r, tc);
      }
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

  // ───────────────────────── هاله ─────────────────────────

  void _halo(Canvas canvas, Offset c, Color color, double r, double pf,
      String? freqKey) {
    final f = kFreqBands[freqKey] ?? kFreqBands['alpha']!;
    final base = f.speed;
    double tri(double dur) {
      final p = (_t / dur) % 1.0;
      return p < 0.5 ? p * 2 : (1 - p) * 2;
    }

    final blur =
        cam.scale < 0.3 ? null : const MaskFilter.blur(BlurStyle.normal, 4);
    final to = tri(base * 1.35);
    canvas.drawCircle(c, _l(r * 1.7 * pf, r * 2.2 * pf, to),
        Paint()
          ..color = withOp(color, _l(0.07, 0.16, to))
          ..maskFilter = blur);
    final tm = tri(base);
    canvas.drawCircle(c, _l(r * 1.25 * pf, r * 1.55 * pf, tm),
        Paint()
          ..color = withOp(color, _l(0.13, 0.24, tm))
          ..maskFilter = blur);
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
    canvas.drawCircle(c, glowR * 0.6,
        Paint()..color = withOp(Colors.white, glowOp * 0.55));
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

  void _circleImage(Canvas canvas, Offset c, double r, ui.Image im) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(center: c, radius: r),
        image: im,
        fit: BoxFit.cover);
    canvas.restore();
  }

  // ───────────────────────── من ─────────────────────────

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
    hits.add(HitEntry(
        type: 'me', id: '', kind: HitKind.node, center: c, radius: r));

    if (me.images.isEmpty) {
      canvas.drawCircle(c, r, Paint()..color = meColor);
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..color = meColor);
      final s = r * 0.42, cy2 = c.dy - r * 0.12;
      final pp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = withOp(tc, 0.85);
      drawDashed(
          canvas,
          Path()..addOval(Rect.fromCircle(center: Offset(c.dx, cy2), radius: s)),
          pp,
          [4, 3]);
      final lp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = withOp(tc, 0.85);
      canvas.drawLine(
          Offset(c.dx - s * 0.5, cy2), Offset(c.dx + s * 0.5, cy2), lp);
      canvas.drawLine(
          Offset(c.dx, cy2 - s * 0.5), Offset(c.dx, cy2 + s * 0.5), lp);
      drawText(canvas, me.name, c.dx, c.dy + r * 0.62,
          size: math.max(9, state.fontSize - 4),
          color: tc,
          weight: FontWeight.w700);
    } else {
      final im = images.get(me.images.first.src);
      if (im != null) {
        _circleImage(canvas, c, r, im);
      } else {
        canvas.drawCircle(c, r, Paint()..color = withOp(meColor, 0.4));
      }
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..color = meColor);
      final lr = drawText(canvas, me.name, c.dx + me.labelDX,
          c.dy + 6 + me.labelDY,
          size: me.labelSize ?? _labelSize('me'),
          color: tc,
          weight: FontWeight.w700,
          outline: 3);
      if (me.name.isNotEmpty) {
        hits.add(
            HitEntry(type: 'me', id: '', kind: HitKind.label, rect: lr));
      }
    }
  }

  void _nodeIcon(Canvas canvas, Offset c, double r0, List<ImageItem> imgs,
      String icon, Color color, double iconScale, Color tc) {
    final r = r0 * iconScale;
    if (imgs.isNotEmpty && imgs.first.src.isNotEmpty) {
      final im = images.get(imgs.first.src);
      if (im != null) {
        _circleImage(canvas, c, r, im);
        canvas.drawCircle(
            c,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = withOp(color, 0.55));
      } else {
        canvas.drawCircle(c, r, Paint()..color = withOp(color, 0.4));
      }
    } else if (icon.trim().isNotEmpty) {
      drawText(canvas, icon, c.dx, c.dy,
          size: r * 1.7, color: tc, vCenter: true);
    } else {
      canvas.drawCircle(c, r, Paint()..color = withOp(color, 0.85));
    }
  }

  // ───────────────────────── هدف ─────────────────────────

  void _drawGoal(Canvas canvas, Goal g, Color tc) {
    final r0 = g.radius;
    final c = Offset(g.x, g.y);
    final col = hexColor(g.color, hexColor(kPalette[0]));
    _halo(canvas, c, col, r0 * math.max(1.0, g.iconScale), 1, g.freq);
    _nodeIcon(canvas, c, r0, g.images, g.icon, col, g.iconScale, tc);
    final r = r0 * g.iconScale;
    _addCircleBounds(c, r);
    hits.add(HitEntry(
        type: 'goal',
        id: g.id,
        kind: HitKind.node,
        center: c,
        radius: math.max(r, r0) + 8));

    var off = -(r0 + 22);
    if (r > r0) off += (off < 0 ? -1 : 1) * (r - r0);
    final lr = drawText(
        canvas, g.name, c.dx + g.labelDX, c.dy + off + g.labelDY,
        size: g.labelSize ?? _labelSize('goal'),
        color: tc,
        weight: FontWeight.w600,
        outline: 3);
    if (g.name.isNotEmpty) {
      hits.add(HitEntry(
          type: 'goal', id: g.id, kind: HitKind.label, rect: lr));
    }

    if ((state.showDateStamps || state.showTimeStamps) &&
        g.createdAt != null &&
        g.createdAt! > 0) {
      final stamp = _formatStamp(g.createdAt!);
      if (stamp.isNotEmpty) {
        drawText(
            canvas,
            stamp,
            c.dx + g.labelDX,
            c.dy + off + g.labelDY + (g.labelSize ?? _labelSize('goal')) * 1.15,
            size: math.max(9, (g.labelSize ?? _labelSize('goal')) * 0.62),
            color: withOp(tc, 0.6),
            weight: FontWeight.w400,
            outline: 2);
      }
    }

    final freq = kFreqBands[g.freq] ?? kFreqBands['alpha']!;
    double sumW(List<ActionNode> l) =>
        l.fold(0.0, (s, a) => s + a.weight + sumW(a.children));
    final power = math.min(100, (sumW(g.actions) * 3).round());
    final has = g.actions.isNotEmpty;
    final hud = (g.collapsed && has)
        ? 'رشد $power٪'
        : '${freq.label} — ${freq.desc} · رشد $power٪';
    drawText(canvas, hud, c.dx, c.dy + r0 + (has ? 46 : 42),
        size: 11, color: withOp(tc, 0.6), weight: FontWeight.w400);
    _goalShutter(canvas, g, col, tc);
  }

  void _goalShutter(Canvas canvas, Goal g, Color col, Color tc) {
    final n = goalBranchCount(state, g);
    if (n == 0) return;
    final cx = g.x, cy = g.y + g.radius + 15;
    final open = !g.collapsed;
    hits.add(HitEntry(
        type: 'goalToggle',
        id: g.id,
        kind: HitKind.handle,
        rect: Rect.fromLTWH(cx - 34, cy - 19, 68, 38)));
    final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 27, cy - 11, 54, 22), const Radius.circular(11));
    final ink = open ? tc : const Color(0xFF1B1400);
    if (!open) canvas.drawRRect(pill, Paint()..color = withOp(col, 0.92));
    canvas.drawRRect(
        pill,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = withOp(col, open ? 0.75 : 1.0));
    final chev = Path();
    if (open) {
      chev
        ..moveTo(-4, 1.8)
        ..lineTo(0, -2.2)
        ..lineTo(4, 1.8);
    } else {
      chev
        ..moveTo(-4, -1.8)
        ..lineTo(0, 2.2)
        ..lineTo(4, -1.8);
    }
    canvas.drawPath(
        chev.shift(Offset(cx - 14, cy)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = withOp(ink, open ? 0.75 : 0.95));
    drawText(canvas, toFa(n), cx + 7, cy + 4.3,
        size: 12,
        color: withOp(ink, open ? 0.8 : 1.0),
        weight: FontWeight.w700);
  }

  void _drawRing(Canvas canvas, Ring r, Color tc) {
    final c = Offset(r.x, r.y);
    final rad = r.radius;
    final col = hexColor(r.color, hexColor(kRingColor));
    final big = rad * math.max(1.0, r.iconScale);
    _halo(canvas, c, col, big, 1.2, null);
    _nodeIcon(canvas, c, rad, r.images, r.icon, col, r.iconScale, tc);
    _addCircleBounds(c, rad * r.iconScale);
    hits.add(HitEntry(
        type: 'ring',
        id: r.id,
        kind: HitKind.node,
        center: c,
        radius: math.max(big, rad) + 8));

    if (r.label.isNotEmpty) {
      final lines = wrapText(r.label, 16);
      final lx = c.dx + r.labelDX;
      final ly = c.dy - (big + 20) + r.labelDY;
      Rect? lr;
      for (var i = 0; i < lines.length; i++) {
        final b = drawText(canvas, lines[i], lx, ly + i * 16,
            size: r.labelSize ?? _labelSize('ring'),
            color: col,
            weight: FontWeight.w700,
            outline: 3);
        lr = lr == null ? b : lr.expandToInclude(b);
      }
      if (lr != null) {
        hits.add(HitEntry(
            type: 'ring', id: r.id, kind: HitKind.label, rect: lr));
      }
    }
    if (r.note.isNotEmpty) {
      final lines = wrapText(r.note, 22);
      final ly = c.dy + big + 18;
      for (var i = 0; i < lines.length; i++) {
        drawText(canvas, lines[i], c.dx, ly + i * 16,
            size: _fs() - 3,
            color: tc,
            weight: FontWeight.w400,
            outline: 2.5);
      }
    }
  }

  // ───────────────────────── تنه ─────────────────────────

  void _branches(Canvas canvas, MapHost h, Color tc,
      {required bool trunkOnly}) {
    final cp = geo.trunkControlPoints(h, state.me);
    final col =
        hexColor(h.color, hexColor(h.isRing ? kRingColor : kPalette[0]));
    if (h.isRing) {
      _taperedBezier(canvas, cp, col, 3.2, 1.6, 0.6);
    } else {
      final ts = (h is Goal && h.trunkStyle.isNotEmpty)
          ? h.trunkStyle
          : state.trunkStyle;
      _trunk(canvas, cp, col, kTrunkStyles.containsKey(ts) ? ts : 'dashed');
    }
    _pts..add(cp.p0)..add(cp.p3);

    if (h is Goal) {
      if (!h.collapsed) {
        _walker(canvas, h, cp, col);
      }
      _goalTrophy(canvas, h, col);
    }

    if (trunkOnly) return;
    final acts = _visibleActs(h.actions);
    for (var i = 0; i < acts.length; i++) {
      final t = math.min(0.9, 0.15 + i * 0.09);
      _twig(canvas, h, col, cp.at(t), cp.tangent(t), acts[i],
          i.isEven ? 1 : -1, 1.0, tc,
          route: [
            for (var k = 0; k <= 16; k++) cp.at(t + (0.94 - t) * k / 16)
          ],
          trunkLane: (i % 3) - 1);
    }
  }

  Paint _stroke(Color col, double w, double op,
          {StrokeCap cap = StrokeCap.round}) =>
      Paint()
        ..style = PaintingStyle.stroke
        ..color = withOp(col, op)
        ..strokeWidth = w
        ..strokeCap = cap
        ..strokeJoin = StrokeJoin.round;

  Path _pathOf(geo.Cubic k) => Path()
    ..moveTo(k.p0.dx, k.p0.dy)
    ..cubicTo(k.p1.dx, k.p1.dy, k.p2.dx, k.p2.dy, k.p3.dx, k.p3.dy);

  void _trunk(Canvas c, geo.Cubic cp, Color col, String style) {
    switch (style) {
      case 'solid':
        c.drawPath(_pathOf(cp), _stroke(col, 3, 0.9));
      case 'dotted':
        drawDashed(c, _pathOf(cp), _stroke(col, 3.6, 0.9), [0.1, 8]);
      case 'dashdot':
        drawDashed(c, _pathOf(cp),
            _stroke(col, 3, 0.9, cap: StrokeCap.butt), [14, 7, 2, 7]);
      case 'long':
        drawDashed(c, _pathOf(cp),
            _stroke(col, 3, 0.9, cap: StrokeCap.butt), [26, 13]);
      case 'double':
        {
          final d = cp.p3 - cp.p0;
          final len = d.distance == 0 ? 1.0 : d.distance;
          final n = Offset(-d.dy / len * 2.6, d.dx / len * 2.6);
          for (final k in [1.0, -1.0]) {
            final o = n * k;
            c.drawPath(
                _pathOf(geo.Cubic(cp.p0 + o, cp.p1 + o, cp.p2 + o, cp.p3 + o)),
                _stroke(col, 1.6, 0.9));
          }
        }
      case 'glow':
        c.drawPath(_pathOf(cp), _stroke(col, 9, 0.16));
        c.drawPath(_pathOf(cp), _stroke(col, 2.8, 0.95));
      case 'taper':
        _taperedBezier(c, cp, col, 5.2, 1.6, 0.9);
      default:
        drawDashed(c, _pathOf(cp),
            _stroke(col, 3, 0.9, cap: StrokeCap.butt), [9, 9]);
    }
  }

  void _taperedBezier(
      Canvas c, geo.Cubic cp, Color col, double w0, double w1, double op) {
    const seg = 7;
    final p = _stroke(col, w0, op);
    for (var s = 0; s < seg; s++) {
      p.strokeWidth = w0 + (w1 - w0) * ((s + 0.5) / seg);
      c.drawLine(cp.at(s / seg), cp.at((s + 1) / seg), p);
    }
  }

  void _taperedPoly(
      Canvas c, List<Offset> pts, Color col, double w0, double w1, double op) {
    final cum = geo.polyCum(pts);
    final tot = cum.last == 0 ? 1.0 : cum.last;
    final p = _stroke(col, w0, op);
    for (var i = 1; i < pts.length; i++) {
      final f = ((cum[i - 1] + cum[i]) / 2) / tot;
      p.strokeWidth = w0 + (w1 - w0) * f;
      c.drawLine(pts[i - 1], pts[i], p);
    }
  }

  // ───────────────────────── شمارش لاگ ─────────────────────────

  static int _jalaliDayNum(String jk) {
    final p = jk.split('-').map((e) => int.tryParse(e) ?? 0).toList();
    if (p.length != 3) return 0;
    const cum = [0, 31, 62, 93, 124, 155, 186, 216, 246, 276, 306, 336];
    final jy = p[0];
    final jm = p[1].clamp(1, 12);
    final jd = p[2];
    return jy * 365 + cum[jm - 1] + jd;
  }

  static bool _isDoneLog(dynamic v) =>
      v == true ||
      v == 'انجام شد ✓' ||
      (v is String && v.isNotEmpty);

  int _logCount(ActionNode a) {
    var n = 0;
    for (final v in a.logs.values) {
      if (_isDoneLog(v)) n++;
    }
    return n;
  }

  int _goalTotalLogs(Goal g) {
    var n = 0;
    void walk(List<ActionNode> list) {
      for (final a in list) {
        n += _logCount(a);
        walk(a.children);
      }
    }
    walk(g.actions);
    return n;
  }

  // ───────────────────────── شکل قدم ─────────────────────────

  Path _footPath(double size, {bool left = false}) {
    final k = size / 16.0 * 20.0;
    final m = Matrix4.identity()..scale(left ? -k : k, k);
    return footBasePath().transform(m.storage);
  }

  void _drawFoot(
    Canvas canvas,
    Offset pos,
    double angle,
    double size,
    Color color, {
    bool outline = false,
    double strokeW = 1.4,
    bool left = false,
  }) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    final path = _footPath(size, left: left);
    if (outline) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    } else {
      canvas.drawPath(path, Paint()..color = color);
    }
    canvas.restore();
  }

  // ───────────────────────── قدم‌زن روی تنه ─────────────────────────

  /// قدم‌زن هدف (آبی): کل تنه، رفت و برگشتی.
  void _walker(Canvas canvas, Goal g, geo.Cubic cp, Color col) {
    final playing = g.extra['walkerPlaying'] as bool? ?? true;
    final speed =
        ((g.extra['walkerSpeed'] as num?)?.toDouble() ?? 1.5).clamp(0.3, 4.0);
    final manualT = (g.extra['walkerPos'] as num?)?.toDouble();
    _walkerCore(
      canvas,
      _CubicCurve(cp),
      col,
      tMin: 0.06,
      tMax: 0.94,
      stepLen: 1.0 / 20,
      totalSteps: 20,
      playing: playing,
      speed: speed.toDouble(),
      manualT: manualT,
      baseSize: 20.0 * state.footScale.clamp(0.4, 3.0),
      trailCount: 5,
      hitType: 'walker',
      hitId: g.id,
      hostId: g.id,
    );
  }

  /// قدم‌زن شاخه/زیرشاخه: از نقطه‌ی ساخته شدن شاخه، روی شاخه‌های پدر تا تنه،
  /// و بعد روی تنه تا هدف اصلی؛ رفت و برگشتی.
  void _branchWalker(Canvas canvas, List<Offset> routePts, int lane,
      ActionNode a, Color color, double baseSize, String hostId) {
    if (routePts.length < 2) return;
    final n = _logCount(a);
    final route = _RouteCurve(routePts);
    final sizeMul = state.footScale.clamp(0.4, 3.0);
    final footMul = (a.footSize ?? 1.0).clamp(0.4, 2.5);
    final size = baseSize * 1.2 * sizeMul * footMul;
    final len = math.max(route.length, 1.0);

    // ─── بدون ثبت: فقط علامت کم‌رنگ پا کنار شاخه (شروع مسیر) ───
    if (n == 0) {
      const u0 = 0.03;
      _drawWalkerFoot(canvas, route, u0, -1.0, size, withOp(color, 0.32));
      _drawWalkerFoot(canvas, route, u0, 1.0, size, withOp(color, 0.32));
      hits.add(HitEntry(
        type: 'foot',
        id: a.id,
        hostId: hostId,
        kind: HitKind.handle,
        center: route.at(u0),
        radius: size * 1.4,
      ));
      return;
    }

    // ─── روزهای قبل: قدم‌های ثابت و کم‌رنگ، پشت سر هم از شروع مسیر ───
    final fixed = n - 1;
    if (fixed > 0) {
      final stride =
          math.min(size * 1.5 / len, 0.85 / math.max(1, fixed)).toDouble();
      for (var k = 0; k < fixed; k++) {
        final u = (0.03 + k * stride).clamp(0.0, 0.95).toDouble();
        // هر روز یک جفت پا، کمی جلوتر از روز قبل
        _drawWalkerFoot(canvas, route, u, -1.0, size * 0.9,
            withOp(color, 0.30));
        _drawWalkerFoot(canvas, route, u, 1.0, size * 0.9,
            withOp(color, 0.30));
      }
    }

    // ─── امروز: پاها در مسیر هدف قدم می‌زنند (رفت و برگشت) ───
    final stepLen = (size * 1.4 / len).clamp(0.01, 0.12);
    final totalSteps = math.max(4, (1.0 / stepLen).round());
    final speed = 1.5 * (a.footSpeed ?? 1.0).clamp(0.2, 3.0);
    final stagger = (a.id.hashCode & 0xFF) / 255.0 * 10.0;
    _walkerCore(
      canvas,
      route,
      color,
      tMin: 0.0,
      tMax: 1.0,
      stepLen: stepLen.toDouble(),
      totalSteps: totalSteps,
      playing: a.footPlaying,
      speed: speed.toDouble(),
      manualT: a.footPos?.clamp(0.0, 1.0).toDouble(),
      baseSize: size,
      trailCount: 0,
      timeOffset: stagger,
      pref: (a.id.hashCode & 1) == 0 ? 1.0 : -1.0,
      hitType: 'foot',
      hitId: a.id,
      hostId: hostId,
      withBody: false,
    );
  }

  void _walkerCore(
    Canvas canvas,
    _Curve cp,
    Color col, {
    required double tMin,
    required double tMax,
    required double stepLen,
    required int totalSteps,
    required bool playing,
    required double speed,
    double? manualT,
    required double baseSize,
    required int trailCount,
    double timeOffset = 0,
    double laneOff = 0,
    double pref = 1.0,
    required String hitType,
    required String hitId,
    required String hostId,
    bool withBody = true,
  }) {
    final range = tMax - tMin;
    final tt = _t + timeOffset;
    final mine = <Offset>[];

    // ─── موقعیت بدنه + جهت (رفت / برگشت) ───
    double bodyT;
    bool returning = false;
    if (playing) {
      final tSteps = tt * speed;
      final cycleLen = totalSteps * 2.0;
      final cycle = tSteps % cycleLen;
      double stepNum;
      if (cycle < totalSteps) {
        stepNum = cycle;
      } else {
        stepNum = cycleLen - cycle;
        returning = true;
      }
      bodyT = tMin + (stepNum / totalSteps).clamp(0.0, 1.0) * range;
    } else {
      bodyT = (manualT ?? (tMin + range / 2)).clamp(tMin, tMax);
    }
    final dir = returning ? -1.0 : 1.0;

    // ─── فاز قدم ───
    final stepPhase = playing ? (tt * speed) % 1.0 : 0.0;
    final leftSwinging = stepPhase < 0.5;
    final swingPhase = leftSwinging ? stepPhase * 2 : (stepPhase - 0.5) * 2;
    final swingEase = _easeInOut(swingPhase);

    // ─── موقعیت پاها (نسبت به جهت حرکت) ───
    final footGap = stepLen * 0.45;
    final plantedT = (bodyT - dir * footGap).clamp(0.02, 0.98);
    final swingStart = plantedT;
    final swingEnd = (bodyT + dir * footGap).clamp(0.02, 0.98);
    final swingingT = swingStart + (swingEnd - swingStart) * swingEase;

    final leftT = leftSwinging ? swingingT : plantedT;
    final rightT = leftSwinging ? plantedT : swingingT;

    const maxLift = 5.0;
    final leftLift =
        leftSwinging ? math.sin(swingPhase * math.pi) * maxLift : 0.0;
    final rightLift =
        leftSwinging ? 0.0 : math.sin(swingPhase * math.pi) * maxLift;

    // ─── دنباله (پشت سر، نسبت به جهت حرکت) ───
    for (var i = 1; i <= trailCount; i++) {
      final trailT = (bodyT - dir * i * stepLen).clamp(0.02, 0.98);
      if (trailT < tMin - 0.001 || trailT > tMax + 0.001) continue;
      final trailSize = baseSize * math.max(0.2, 0.5 - i * 0.06);
      final trailOpacity = (1.0 - i / (trailCount + 1)) * 0.42;
      final trailIsLeft = (i + (leftSwinging ? 0 : 1)) % 2 == 0;
      _drawWalkerFoot(canvas, cp, trailT, trailIsLeft ? -1.0 : 1.0, trailSize,
          withOp(col, trailOpacity),
          lift: 0,
          outline: true,
          returning: returning,
          laneOff: laneOff,
          others: _walkerPts,
          pref: pref);
    }

    // ─── دو پا ───
    _drawWalkerFoot(canvas, cp, leftT, -1.0, baseSize, withOp(col, 0.92),
        lift: leftLift,
        returning: returning,
        laneOff: laneOff,
        others: _walkerPts,
        mine: mine,
        pref: pref);
    _drawWalkerFoot(canvas, cp, rightT, 1.0, baseSize, withOp(col, 0.92),
        lift: rightLift,
        returning: returning,
        laneOff: laneOff,
        others: _walkerPts,
        mine: mine,
        pref: pref);
    _walkerPts.addAll(mine);

    // ─── بدنه ───
    final bodyPt = cp.at(bodyT);
    final bodyAng = cp.tangent(bodyT);
    final nx = -math.sin(bodyAng);
    final ny = math.cos(bodyAng);

    final bobFreq = speed * 2;
    final bobPhase = (tt * bobFreq * math.pi * 2) % (math.pi * 2);
    final bob = playing ? math.sin(bobPhase) * 1.5 : 0.0;
    final bodyPos = Offset(bodyPt.dx + nx * (bob + laneOff),
        bodyPt.dy + ny * (bob + laneOff));

    if (withBody) {
      final pulseRate = playing ? (1.0 + speed * 0.5) : 0.4;
      final pulse = 0.9 + math.sin(tt * pulseRate * 2 * math.pi) * 0.1;
      final bodyR = 8.0 * pulse;

      canvas.drawCircle(
          bodyPos,
          bodyR * 2.6,
          Paint()
            ..color = withOp(col, 0.20)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      canvas.drawCircle(
          bodyPos,
          bodyR * 1.35,
          Paint()
            ..color = withOp(col, 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(
          bodyPos,
          bodyR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = withOp(col, 0.92));
      canvas.drawCircle(
          bodyPos, bodyR * 0.42, Paint()..color = withOp(col, 0.92));

      if (!playing) {
        final r = bodyR * 0.32;
        canvas.drawRect(
          Rect.fromCenter(center: bodyPos, width: r, height: r),
          Paint()..color = withOp(col, 0.92),
        );
      }
    } else {
      canvas.drawCircle(
          bodyPos,
          baseSize * 1.3,
          Paint()
            ..color = withOp(col, playing ? 0.16 : 0.10)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    hits.add(HitEntry(
      type: hitType,
      id: hitId,
      hostId: hostId,
      kind: HitKind.handle,
      center: bodyPos,
      radius: baseSize * 1.4,
    ));
  }

  void _drawWalkerFoot(
    Canvas canvas,
    _Curve cp,
    double t,
    double side,
    double size,
    Color color, {
    double lift = 0,
    bool outline = false,
    bool returning = false,
    double laneOff = 0,
    List<Offset>? others,
    List<Offset>? mine,
    double pref = 1.0,
  }) {
    final pt = cp.at(t);
    final tang = cp.tangent(t);
    // جهت پا: در برگشت ۱۸۰ درجه می‌چرخد تا پنجه رو به جهت حرکت باشد
    final heading = returning ? tang + math.pi : tang;
    final nx = -math.sin(heading);
    final ny = math.cos(heading);
    final sideOffset = size * 0.32 * side;
    final total = sideOffset + lift;
    final lnx = -math.sin(tang);
    final lny = math.cos(tang);
    var pos = Offset(pt.dx + nx * total + lnx * laneOff,
        pt.dy + ny * total + lny * laneOff);

    // فقط وقتی به پای دیگری نزدیک شد، کمی از خط هدف کنار می‌رود
    // و بعد از دور شدن دوباره روی خط برمی‌گردد.
    if (others != null && others.isNotEmpty) {
      final r = size * 1.7;
      var dev = 0.0;
      for (final q in others) {
        final dd = pos - q;
        final d = dd.distance;
        if (d >= r) continue;
        var w = 1 - d / r;
        w = w * w * (3 - 2 * w);
        final proj = dd.dx * lnx + dd.dy * lny;
        final sgn = proj.abs() < size * 0.2 ? pref : (proj > 0 ? 1.0 : -1.0);
        dev += sgn * w * r * 0.8;
      }
      dev = dev.clamp(-size * 1.6, size * 1.6).toDouble();
      pos = Offset(pos.dx + lnx * dev, pos.dy + lny * dev);
    }
    mine?.add(pos);
    _drawFoot(canvas, pos, heading + math.pi / 2, size, color,
        outline: outline, strokeW: outline ? 1.2 : 1.4, left: side < 0);
  }

  // ───────────────────────── جام ─────────────────────────

  void _goalTrophy(Canvas canvas, Goal g, Color col) {
    if (g.extra['trophyVisible'] == false) return;

    final totalLogs = _goalTotalLogs(g);
    if (totalLogs == 0) return;

    final progress = (totalLogs / 30.0).clamp(0.0, 1.0);

    final cx = g.x + g.radius + 34;
    final cy = g.y - g.radius - 34;

    final pulse = 0.9 + math.sin(_t * 2.2) * 0.1;
    final size = 26.0 * pulse;

    canvas.drawCircle(
      Offset(cx, cy),
      size * 1.7,
      Paint()
        ..color = withOp(col, 0.15 + 0.35 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      size * 0.95,
      Paint()
        ..color = withOp(col, 0.35 + 0.5 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final rayPaint = Paint()
      ..color = withOp(col, 0.7)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = (i / 8) * math.pi * 2 + _t * 0.5;
      final r1 = size * 1.1;
      final r2 = size * (1.3 + math.sin(_t * 3 + i) * 0.15);
      canvas.drawLine(
        Offset(cx + math.cos(a) * r1, cy + math.sin(a) * r1),
        Offset(cx + math.cos(a) * r2, cy + math.sin(a) * r2),
        rayPaint,
      );
    }

    _drawEmoji(canvas, Offset(cx, cy), 0, size, col, '🏆');

    drawText(
      canvas,
      '${(progress * 100).round()}٪',
      cx,
      cy + size * 0.95,
      size: 11,
      color: withOp(col, 0.85),
      weight: FontWeight.w700,
      outline: 2,
    );

    hits.add(HitEntry(
      type: 'trophy',
      id: g.id,
      hostId: g.id,
      kind: HitKind.handle,
      center: Offset(cx, cy),
      radius: size * 1.2,
    ));
  }

  // ───────────────────────── کمکی ─────────────────────────

  void _drawEmoji(Canvas canvas, Offset at, double angle, double size,
      Color color, String emoji) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: size, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  List<ActionNode> _visibleActs(List<ActionNode> list) {
    final out = <ActionNode>[];
    for (final n in list) {
      if (n.extra['achieved'] == true) {
        out.addAll(_visibleActs(n.children));
      } else {
        out.add(n);
      }
    }
    return out;
  }

  void _routineRing(Canvas canvas, Offset center, double tipR, Color color,
      double scale, ActionNode a) {
    final R = tipR + 5.5 * math.max(0.8, scale);
    final sw = 2.2 * math.max(0.8, scale);
    final days = jalaaliCurrentWeekDates();
    final tKey = todayJK();
    final rect = Rect.fromCircle(center: center, radius: R);

    const step = 2 * math.pi / 7;
    const gap = 0.34;

    for (var i = 0; i < 7; i++) {
      final k = days[i];
      final has = truthy(a.logs[k]);
      final isToday = k == tKey;
      final a0 = -math.pi / 2 + i * step + gap / 2;
      final a1 = -math.pi / 2 + (i + 1) * step - gap / 2;
      final op = has ? 0.95 : (isToday ? 0.55 : 0.20);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = isToday ? sw * 1.45 : sw
        ..color = withOp(color, op);
      canvas.drawArc(rect, a0, a1 - a0, false, paint);
    }

    if (!truthy(a.logs[tKey])) {
      canvas.drawCircle(center, tipR * 0.55,
          Paint()..color = const Color(0xFF0A0C18).withAlpha(140));
    }

    final streak = routineStreak(a);
    if (streak >= 2) {
      final fs = 8.5 * math.max(0.9, scale);
      drawText(canvas, toFa(streak), center.dx, center.dy - R - 3.5,
          size: fs, color: color, weight: FontWeight.w700, outline: 2);
    }
  }

  void _twig(Canvas canvas, MapHost h, Color hostColor, Offset originPt,
      double originDir, ActionNode a, int side, double scale, Color tc,
      {List<Offset>? route, int trunkLane = 0}) {
    final weight = a.weight == 0 ? 5.0 : a.weight;
    final color = (a.color != null && a.color!.isNotEmpty)
        ? hexColor(a.color, hostColor)
        : hostColor;
    final isRoutine = a.isRoutine;
    final geom = geo.computeTwigGeom(h, a, originPt, originDir, side, scale);
    geo.applyBranchStyle(geom, geo.effBranchStyle(h, a), side);
    final end = geom.end;
    _pts.add(end);
    hits.geom[a.id] = ActionGeomEntry(h.id, geom.originPt, end, scale);
    hits.add(HitEntry(
        type: 'action',
        id: a.id,
        hostId: h.id,
        kind: HitKind.handle,
        center: end,
        radius: math.max(15.0, 18 * scale)));

    final baseW = math.max(1.0, (1.9 + weight * 1.05) * scale);
    final tipW = math.max(0.7, baseW * 0.38);
    final cub = geo.Cubic(geom.originPt, geom.c1, geom.c2, end);
    if (geom.poly != null) {
      _taperedPoly(canvas, geom.poly!, color, baseW, tipW, 0.92);
    } else {
      _taperedBezier(canvas, cub, color, baseW, tipW, 0.92);
    }

    if (route != null) {
      // مسیر قدم‌ها: از نوک شاخه → ابتدای شاخه (برگشت روی خود شاخه) →
      // شاخه‌های پدر → تنه → هدف اصلی؛ و دوباره برعکس.
      final own = <Offset>[];
      if (geom.poly != null) {
        own.addAll(geom.poly!.reversed);
      } else {
        for (var k = 0; k <= 16; k++) {
          own.add(cub.at(1.0 - k / 16));
        }
      }
      own.addAll(route);
      _branchWalker(canvas, own, trunkLane, a, color, 15.0 * scale, h.id);
    }

    final kids = _visibleActs(a.children);
    if (kids.isNotEmpty) {
      canvas.drawCircle(end, math.max(2.0, 2.6 * scale),
          _stroke(color, 1.2, 0.55));
      for (var i = 0; i < kids.length; i++) {
        final tt = 0.5 + ((i + 1) / (kids.length + 1)) * 0.45;
        Offset co;
        double cd;
        if (geom.poly != null) {
          final q = geo.polyPointAt(geom.poly!, tt);
          co = q.pt;
          cd = q.angle;
        } else {
          co = cub.at(tt);
          cd = cub.tangent(tt);
        }
        // مسیر بچه: از نقطه‌ی اتصال، برگشت روی همین شاخه تا ابتدایش، بعد مسیر خود شاخه
        final childRoute = <Offset>[];
        if (route != null) {
          for (var k = 0; k <= 12; k++) {
            final u = tt * (1 - k / 12);
            childRoute.add(geom.poly != null
                ? geo.polyPointAt(geom.poly!, u).pt
                : cub.at(u));
          }
          childRoute.addAll(route);
        }
        _twig(canvas, h, hostColor, co, cd, kids[i], i.isEven ? 1 : -1,
            scale * 0.72, tc,
            route: route == null ? null : childRoute, trunkLane: trunkLane);
      }
    } else if (a.images.isNotEmpty) {
      final radius = math.max(1.8, 2 + weight * 0.28 * scale);
      final cnt = math.min(a.images.length, 3);
      for (var i = 0; i < cnt; i++) {
        final e = a.images[i];
        final ang = (i / cnt) * math.pi * 2 - math.pi / 2;
        final off = Offset(math.cos(ang) * radius * 0.7 + e.dx,
            math.sin(ang) * radius * 0.7 + e.dy);
        final rect = Rect.fromCenter(
            center: end + off, width: e.size, height: e.size);
        final im = images.get(e.src);
        if (im != null) {
          paintImage(
              canvas: canvas, rect: rect, image: im, fit: BoxFit.contain);
        }
        hits.add(HitEntry(
            type: 'action',
            id: a.id,
            hostId: h.id,
            kind: HitKind.image,
            imgIdx: i,
            rect: rect));
      }
      if (a.images.length > 3) {
        drawText(canvas, '+${a.images.length - 3}', end.dx + radius * 0.7,
            end.dy + radius * 0.7 + 4,
            size: 10, color: tc, outline: 2);
      }
    } else {
      canvas.drawCircle(end, math.max(1.8, 2 + weight * 0.28 * scale),
          Paint()..color = color);
    }

    if (isRoutine) {
      final tipR = math.max(1.8, 2 + weight * 0.28 * scale);
      _routineRing(canvas, end, tipR, color, scale, a);
    }

    if (a.text.isNotEmpty) {
      final lines = wrapText(a.text,
          math.max(10, (18 * math.min(1.0, scale + 0.35)).round()));
      final right = kLabelRtlAnchor ? side > 0 : side < 0;
      final lx = end.dx + (side > 0 ? 8 : -8) + a.labelDX;
      final ly = end.dy + 4 + a.labelDY;
      final fs = a.labelSize ?? _labelSize('action', scale);
      Rect? lr;
      for (var i = 0; i < lines.length; i++) {
        final b = drawText(canvas, lines[i], lx, ly + i * 16,
            size: fs,
            color: tc,
            weight: FontWeight.w400,
            align: right ? LabelAlign.right : LabelAlign.left,
            outline: 2.5);
        lr = lr == null ? b : lr.expandToInclude(b);
      }
      if (lr != null) {
        hits.add(HitEntry(
            type: 'action',
            id: a.id,
            hostId: h.id,
            kind: HitKind.label,
            rect: lr));
      }

      final cAt = a.extra['createdAt'];
      if ((state.showDateStamps || state.showTimeStamps) &&
          cAt is num &&
          cAt > 0) {
        final stamp = _formatStamp(cAt.toInt());
        if (stamp.isNotEmpty) {
          drawText(canvas, stamp, lx, ly + lines.length * 16,
              size: math.max(9, fs * 0.62),
              color: withOp(tc, 0.6),
              weight: FontWeight.w400,
              align: right ? LabelAlign.right : LabelAlign.left,
              outline: 2);
        }
      }
    }
  }
}
