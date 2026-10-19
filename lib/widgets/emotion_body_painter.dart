import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ── ابعاد بدنه (هم‌ارز BODY_DIMS وب) ──
class BodyDims {
  static const double headR = 12, headCY = -62;
  static const double neckTopY = -50, neckBotY = -42;
  static const double shoulderY = -38, shoulderW = 19;
  static const double waistY = -6, waistW = 12;
  static const double hipY = 10, hipW = 16;
  static const double kneeY = 42, footY = 68;
  static const double armEndY = 4, armHandY = 14;
}

// ── مختصات طراحی (viewBox وب: 260×400) ──
const double kChartW = 260;
const double kChartH = 400;
const double kBodyCX = 185;
const double kBodyCY = 195;

// ── حفره‌ی قلب داخل body.svg (در مختصات محلی بدن) ──
const double kHeartCX = 3, kHeartCY = -32;
const double kHeartRX = 6.5, kHeartRY = 9;

/// سیلوئت بدن (پورت drawBodyShape وب) برای هاله.
Path buildBodyOutlinePath({bool skipHead = false, bool skipNeck = false}) {
  final p = Path();

  if (!skipHead) {
    p.addOval(Rect.fromCircle(
      center: const Offset(0, BodyDims.headCY),
      radius: BodyDims.headR,
    ));
  }
  if (!skipNeck) {
    p.addRect(Rect.fromLTRB(-5, BodyDims.neckTopY, 5, BodyDims.neckBotY));
  }

  // تنه
  p.moveTo(-BodyDims.shoulderW, BodyDims.shoulderY);
  p.quadraticBezierTo(
      0, BodyDims.shoulderY - 5, BodyDims.shoulderW, BodyDims.shoulderY);
  p.lineTo(BodyDims.waistW, BodyDims.waistY);
  p.lineTo(BodyDims.hipW, BodyDims.hipY);
  p.quadraticBezierTo(0, BodyDims.hipY + 3, -BodyDims.hipW, BodyDims.hipY);
  p.lineTo(-BodyDims.waistW, BodyDims.waistY);
  p.close();

  // بازوی چپ
  p.moveTo(-BodyDims.shoulderW, BodyDims.shoulderY);
  p.quadraticBezierTo(-BodyDims.shoulderW - 4, BodyDims.shoulderY + 15,
      -BodyDims.shoulderW - 2, BodyDims.armEndY);
  p.lineTo(-BodyDims.shoulderW + 4, BodyDims.armEndY);
  p.quadraticBezierTo(-BodyDims.shoulderW + 3, BodyDims.shoulderY + 15,
      -BodyDims.waistW - 2, BodyDims.waistY + 3);
  p.close();

  // بازوی راست
  p.moveTo(BodyDims.shoulderW, BodyDims.shoulderY);
  p.quadraticBezierTo(BodyDims.shoulderW + 4, BodyDims.shoulderY + 15,
      BodyDims.shoulderW + 2, BodyDims.armEndY);
  p.lineTo(BodyDims.shoulderW - 4, BodyDims.armEndY);
  p.quadraticBezierTo(BodyDims.shoulderW - 3, BodyDims.shoulderY + 15,
      BodyDims.waistW + 2, BodyDims.waistY + 3);
  p.close();

  // دست‌ها
  p.addOval(Rect.fromCenter(
      center: const Offset(-BodyDims.shoulderW - 2, BodyDims.armHandY),
      width: 7.6,
      height: 11));
  p.addOval(Rect.fromCenter(
      center: const Offset(BodyDims.shoulderW + 2, BodyDims.armHandY),
      width: 7.6,
      height: 11));

  // پای چپ
  p.moveTo(-BodyDims.hipW, BodyDims.hipY);
  p.lineTo(-BodyDims.hipW + 1, BodyDims.kneeY);
  p.lineTo(-BodyDims.hipW + 2, BodyDims.footY);
  p.lineTo(-5, BodyDims.footY);
  p.lineTo(-4, BodyDims.kneeY);
  p.lineTo(-3, BodyDims.hipY);
  p.close();

  // پای راست
  p.moveTo(BodyDims.hipW, BodyDims.hipY);
  p.lineTo(BodyDims.hipW - 1, BodyDims.kneeY);
  p.lineTo(BodyDims.hipW - 2, BodyDims.footY);
  p.lineTo(5, BodyDims.footY);
  p.lineTo(4, BodyDims.kneeY);
  p.lineTo(3, BodyDims.hipY);
  p.close();

  // کف پاها
  p.addOval(Rect.fromCenter(
      center: const Offset(-BodyDims.hipW / 2 - 1, BodyDims.footY + 3),
      width: 14,
      height: 7));
  p.addOval(Rect.fromCenter(
      center: const Offset(BodyDims.hipW / 2 + 1, BodyDims.footY + 3),
      width: 14,
      height: 7));

  return p;
}

// ───────────────────────── کمکی‌ها ─────────────────────────

/// موج مثلثی ۰→۱→۰ (برای animateTransform مقدارهای 1;1.06;1)
double _tri(double p) => p < 0.5 ? p * 2 : (1 - p) * 2;

/// نسبت پیشرفت در یک دوره‌ی تکرارشونده
double _phase(double seconds, double dur) => (seconds % dur) / dur;

/// پورت d3.curveBasis (B-spline یکنواخت) — دقیقاً همان الگوریتم d3
Path basisPath(List<Offset> pts) {
  final path = Path();
  if (pts.isEmpty) return path;
  double x0 = double.nan, y0 = double.nan, x1 = double.nan, y1 = double.nan;
  var state = 0;

  void bez(double x, double y) {
    path.cubicTo(
      (2 * x0 + x1) / 3,
      (2 * y0 + y1) / 3,
      (x0 + 2 * x1) / 3,
      (y0 + 2 * y1) / 3,
      (x0 + 4 * x1 + x) / 6,
      (y0 + 4 * y1 + y) / 6,
    );
  }

  for (final p in pts) {
    final x = p.dx, y = p.dy;
    switch (state) {
      case 0:
        state = 1;
        path.moveTo(x, y);
        break;
      case 1:
        state = 2;
        break;
      case 2:
        state = 3;
        path.lineTo((5 * x0 + x1) / 6, (5 * y0 + y1) / 6);
        bez(x, y);
        break;
      default:
        bez(x, y);
    }
    x0 = x1;
    x1 = x;
    y0 = y1;
    y1 = y;
  }
  if (state == 3) bez(x1, y1);
  if (state == 3 || state == 2) path.lineTo(x1, y1);
  return path;
}

/// keyframeهای echwHeartPulse: scale و opacity (ease-in-out بین هر بازه)
class HeartPulse {
  final double scale;
  final double opacity;
  const HeartPulse(this.scale, this.opacity);

  /// p بین ۰ و ۱
  factory HeartPulse.at(double p) {
    const e = Curves.easeInOut;
    if (p < 0.45) {
      final t = e.transform(p / 0.45);
      return HeartPulse(1 + 0.22 * t, 0.55 + 0.45 * t);
    } else if (p < 0.70) {
      final t = e.transform((p - 0.45) / 0.25);
      return HeartPulse(1.22 - 0.16 * t, 1.0 - 0.15 * t);
    } else {
      final t = e.transform((p - 0.70) / 0.30);
      return HeartPulse(1.06 - 0.06 * t, 0.85 - 0.30 * t);
    }
  }
}

// ───────────────────────── Aura ─────────────────────────

/// هاله دور آدمک: لایه‌های blur شده با mix-blend screen (ایزوله مثل stacking-context وب)
class AuraPainter extends CustomPainter {
  AuraPainter({
    required this.time,
    required this.colors,
    required this.hasSelection,
  }) : super(repaint: time);

  final ValueListenable<double> time;
  final List<Color> colors;
  final bool hasSelection;

  static final Path _body =
      buildBodyOutlinePath(skipHead: true, skipNeck: true);

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final t = time.value;
    final bounds =
        Rect.fromLTWH(-80, -80, size.width + 160, size.height + 160);

    // گروه ایزوله: screen فقط بین خود لایه‌های هاله اتفاق می‌افته
    canvas.saveLayer(bounds, Paint());
    for (var i = colors.length - 1; i >= 0; i--) {
      final scaleUp = 1.28 + i * 0.30;
      final layerOp = ((hasSelection ? 0.55 : 0.22) - i * 0.06).clamp(0.0, 1.0);
      final dur = 1.4 + i * 0.3;
      final sigma = i >= 3 ? 9.0 : 5.5;
      final pulse = 1 + 0.06 * _tri(_phase(t, dur));

      canvas.saveLayer(
        bounds,
        Paint()
          ..blendMode = BlendMode.screen
          ..color = Color.fromRGBO(0, 0, 0, layerOp),
      );
      canvas.save();
      canvas.translate(kBodyCX, kBodyCY);
      canvas.scale(scaleUp * pulse);
      canvas.drawPath(
        _body,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 + i * 0.8
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
      canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AuraPainter old) =>
      old.hasSelection != hasSelection || !listEquals(old.colors, colors);
}

// ───────────────────────── Waves (EEG) ─────────────────────────

class _WaveSpec {
  final Color color;
  final double dur;
  final List<List<Offset>> frames;
  final double glowOp;
  final double lineOp;
  const _WaveSpec(this.color, this.dur, this.frames, this.glowOp, this.lineOp);
}

List<Offset> _eegPoints({
  required double cx,
  required double y,
  required double halfW,
  required double amp,
  required double cycles,
  required double phase,
  required double seed,
  required double irr,
}) {
  const n = 60;
  final h1 = 0.12 + 0.5 * irr;
  final h2 = 0.04 + 0.4 * irr;
  final h3 = irr > 0.32 ? 0.55 * irr : 0.0;
  final pts = <Offset>[];
  for (var i = 0; i <= n; i++) {
    final t = i / n;
    final env = math.sin(t * math.pi);
    final x = cx - halfW + t * 2 * halfW;
    final main = math.sin(t * cycles * math.pi * 2 + phase);
    final harm1 =
        h1 * math.sin(t * cycles * math.pi * 2 * 2.3 + phase * 1.7 + seed);
    final harm2 =
        h2 * math.sin(t * cycles * math.pi * 2 * 4.1 + phase * 0.6 + seed * 2);
    final harm3 =
        h3 * math.sin(t * cycles * math.pi * 2 * 7.7 + phase * 2.4 + seed * 3);
    final yy = y - (main + harm1 + harm2 + harm3) * amp * env;
    pts.add(Offset(x, yy));
  }
  return pts;
}

class WavesPainter extends CustomPainter {
  WavesPainter({
    required this.time,
    required List<Color> colors,
    required List<int> freqs,
    required this.hasSelection,
    required this.neutral,
  })  : _specs = _buildSpecs(colors, freqs, hasSelection, neutral),
        super(repaint: time);

  final ValueListenable<double> time;
  final bool hasSelection;
  final Color neutral;
  final List<_WaveSpec> _specs;

  static const double _halfW = 34;
  static final double _y0 = kBodyCY + BodyDims.headCY - 20;

  static List<_WaveSpec> _buildSpecs(
    List<Color> colors,
    List<int> freqs,
    bool hasSel,
    Color neutral,
  ) {
    final waveColors =
        hasSel ? colors.take(2).toList() : <Color>[neutral, neutral];
    final waveFreqs = hasSel ? freqs.take(2).toList() : <int>[250, 250];
    final specs = <_WaveSpec>[];
    for (var wi = 0; wi < waveColors.length; wi++) {
      final freq = waveFreqs[wi];
      final f = math.max(20, math.min(700, freq)).toDouble();
      final reg = ((math.log(f) - math.log(20)) /
              (math.log(700) - math.log(20)))
          .clamp(0.0, 1.0);
      final irr = 1 - reg;

      final halfW = _halfW - wi * 4;
      final amp = 5.2 - wi * 1.1;
      final cycles = 1.5 + reg * 3.6 + wi * 0.35;
      final y = _y0 - wi * 5.5;
      final seed = wi * 1.3 + (freq % 17) * 0.05;

      final phases = irr > 0.45
          ? <double>[
              0,
              math.pi * 0.55,
              math.pi * 1.35,
              math.pi * 1.8,
              math.pi * 2,
            ]
          : <double>[0, math.pi, math.pi * 2];

      final frames = [
        for (final ph in phases)
          _eegPoints(
            cx: kBodyCX,
            y: y,
            halfW: halfW,
            amp: amp,
            cycles: cycles,
            phase: ph,
            seed: seed,
            irr: irr,
          ),
      ];

      specs.add(_WaveSpec(
        waveColors[wi],
        1.15 + reg * 1.7 + wi * 0.35,
        frames,
        ((hasSel ? 0.28 : 0.16) - wi * 0.06).clamp(0.0, 1.0),
        ((hasSel ? 0.9 : 0.55) - wi * 0.15).clamp(0.0, 1.0),
      ));
    }
    return specs;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;

    // خط پایه‌ی خط‌چین (dasharray 1.5,2)
    final base = Paint()
      ..color = neutral.withValues(alpha: 0.25)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    final xEnd = kBodyCX + _halfW + 4;
    for (var x = kBodyCX - _halfW - 4; x < xEnd; x += 3.5) {
      canvas.drawLine(
          Offset(x, _y0), Offset(math.min(x + 1.5, xEnd), _y0), base);
    }

    for (final s in _specs) {
      final p = _phase(t, s.dur);
      final segs = s.frames.length - 1;
      final pos = p * segs;
      var k = pos.floor();
      if (k >= segs) k = segs - 1;
      final a = pos - k;
      final f0 = s.frames[k], f1 = s.frames[k + 1];
      final pts = <Offset>[
        for (var i = 0; i < f0.length; i++) Offset.lerp(f0[i], f1[i], a)!,
      ];
      final path = basisPath(pts);

      canvas.drawPath(
        path,
        Paint()
          ..color = s.color.withValues(alpha: s.glowOp)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color.withValues(alpha: s.lineOp)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(WavesPainter old) =>
      old.hasSelection != hasSelection ||
      old.neutral != neutral ||
      !identical(old._specs, _specs) && !_sameSpecs(old._specs, _specs);

  static bool _sameSpecs(List<_WaveSpec> a, List<_WaveSpec> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].color != b[i].color || a[i].dur != b[i].dur) return false;
    }
    return true;
  }
}

// ───────────────────────── Heart ─────────────────────────

/// قلب تپنده — پشت تصویر body.svg کشیده می‌شه تا از حفره‌ی قلب دیده بشه.
class HeartPainter extends CustomPainter {
  HeartPainter({required this.time, required this.hasSelection})
      : super(repaint: time);

  final ValueListenable<double> time;
  final bool hasSelection;

  @override
  void paint(Canvas canvas, Size size) {
    final dur = hasSelection ? 0.95 : 1.35;
    final pulse = HeartPulse.at(_phase(time.value, dur));

    final rect = Rect.fromCenter(
      center: const Offset(kBodyCX + kHeartCX, kBodyCY + kHeartCY),
      width: kHeartRX * 2 * pulse.scale,
      height: kHeartRY * 2 * pulse.scale,
    );

    final o = pulse.opacity;
    final shader = ui.Gradient.linear(
      Offset(rect.center.dx, rect.bottom),
      Offset(rect.center.dx, rect.top),
      [
        const Color(0xFFB4102A).withValues(alpha: o),
        const Color(0xFFEF2440).withValues(alpha: o),
        const Color(0xFFFF5468).withValues(alpha: o),
      ],
      const [0.0, 0.55, 1.0],
    );
    canvas.drawOval(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(HeartPainter old) => old.hasSelection != hasSelection;
}

// ───────────────────── Heart energy glow ─────────────────────

/// درخششِ رنگی احساس‌های انتخاب‌شده دور حفره‌ی قلب (روی سیلوئت، حالت screen)
class HeartEnergyPainter extends CustomPainter {
  HeartEnergyPainter({required this.time, required this.colors})
      : super(repaint: time);

  final ValueListenable<double> time;

  /// همه‌ی احساس‌های انتخاب‌شده به ترتیب فرکانس
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final pulse = HeartPulse.at(_phase(time.value, 0.95));
    final o = pulse.opacity;

    final cs = <Color>[];
    final st = <double>[];
    if (colors.length == 1) {
      final c = colors[0];
      cs.addAll([
        c.withValues(alpha: 0.95 * o),
        c.withValues(alpha: 0.5 * o),
        c.withValues(alpha: 0.0),
      ]);
      st.addAll([0.0, 0.65, 1.0]);
    } else {
      final m = math.max(colors.length, 2) - 1;
      final cnt = math.min(5, colors.length);
      for (var i = 0; i < cnt; i++) {
        st.add(i / m * 0.65);
        cs.add(colors[i].withValues(alpha: 0.85 * o));
      }
      st.add(1.0);
      cs.add(colors[0].withValues(alpha: 0.0));
    }

    final center = const Offset(kBodyCX + kHeartCX, kBodyCY + kHeartCY);
    final rx = kHeartRX * 1.35 * pulse.scale;
    final ry = kHeartRY * 1.35 * pulse.scale;
    final rect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);

    // گرادیان بیضوی (objectBoundingBox): دایره‌ی شعاع rx که در راستای y کشیده می‌شه
    final m4 = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(1.0, ry / rx)
      ..translate(-center.dx, -center.dy);
    final Float64List matrix = Float64List.fromList(m4.storage);

    final shader = ui.Gradient.radial(
      center,
      rx,
      cs,
      st,
      TileMode.clamp,
      matrix,
    );

    canvas.drawOval(
      rect,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.screen
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(HeartEnergyPainter old) => !listEquals(old.colors, colors);
}
