import 'dart:math' as math;
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

// ── مختصات پنل داخلی (viewBox وب) ──
const double kPanelW = 260;
const double kPanelH = 400;
const double kListW = 100;
const double kListRowH = 21;
const double kListHeaderH = 6;
const double kBodyCX = 185;
const double kBodyCY = 195;

// ── مختصات قلب (اندازه‌گیری‌شده از وب) ──
const double kHeartCX = 3, kHeartCY = -32;
const double kHeartRX = 6.5, kHeartRY = 9;

/// سیلوئت ساده‌ی بدن برای هاله (پورت drawBodyShape).
Path buildBodyOutlinePath({bool skipHead = false, bool skipNeck = false}) {
  final p = Path();
  const d = BodyDims();

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
  p.moveTo(-d.shoulderW, d.shoulderY);
  p.quadraticBezierTo(0, d.shoulderY - 5, d.shoulderW, d.shoulderY);
  p.lineTo(d.waistW, d.waistY);
  p.lineTo(d.hipW, d.hipY);
  p.quadraticBezierTo(0, d.hipY + 3, -d.hipW, d.hipY);
  p.lineTo(-d.waistW, d.waistY);
  p.close();

  // بازوی چپ
  p.moveTo(-d.shoulderW, d.shoulderY);
  p.quadraticBezierTo(-d.shoulderW - 4, d.shoulderY + 15, -d.shoulderW - 2, d.armEndY);
  p.lineTo(-d.shoulderW + 4, d.armEndY);
  p.quadraticBezierTo(-d.shoulderW + 3, d.shoulderY + 15, -d.waistW - 2, d.waistY + 3);
  p.close();

  // بازوی راست
  p.moveTo(d.shoulderW, d.shoulderY);
  p.quadraticBezierTo(d.shoulderW + 4, d.shoulderY + 15, d.shoulderW + 2, d.armEndY);
  p.lineTo(d.shoulderW - 4, d.armEndY);
  p.quadraticBezierTo(d.shoulderW - 3, d.shoulderY + 15, d.waistW + 2, d.waistY + 3);
  p.close();

  // دست‌ها
  p.addOval(Rect.fromCenter(
      center: Offset(-d.shoulderW - 2, d.armHandY), width: 7.6, height: 11));
  p.addOval(Rect.fromCenter(
      center: Offset(d.shoulderW + 2, d.armHandY), width: 7.6, height: 11));

  // پای چپ
  p.moveTo(-d.hipW, d.hipY);
  p.lineTo(-d.hipW + 1, d.kneeY);
  p.lineTo(-d.hipW + 2, d.footY);
  p.lineTo(-5, d.footY);
  p.lineTo(-4, d.kneeY);
  p.lineTo(-3, d.hipY);
  p.close();

  // پای راست
  p.moveTo(d.hipW, d.hipY);
  p.lineTo(d.hipW - 1, d.kneeY);
  p.lineTo(d.hipW - 2, d.footY);
  p.lineTo(5, d.footY);
  p.lineTo(4, d.kneeY);
  p.lineTo(3, d.hipY);
  p.close();

  // پاها
  p.addOval(Rect.fromCenter(
      center: Offset(-d.hipW / 2 - 1, d.footY + 3), width: 14, height: 7));
  p.addOval(Rect.fromCenter(
      center: Offset(d.hipW / 2 + 1, d.footY + 3), width: 14, height: 7));

  return p;
}

// ───────────────────────── Aura ─────────────────────────

class AuraPainter extends CustomPainter {
  final List<Color> colors; // حداکثر ۵ تا
  final double pulse;       // 0..1

  AuraPainter({required this.colors, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / kPanelW;
    final scaleY = size.height / kPanelH;
    canvas.save();
    canvas.translate(kBodyCX * scaleX, kBodyCY * scaleY);
    canvas.scale(scaleX, scaleY);

    final hasSelection = colors.isNotEmpty;
    final layers = hasSelection
        ? colors.take(5).toList()
        : <Color>[const Color(0xFFAAB0C4)];

    final path = buildBodyOutlinePath(skipHead: true, skipNeck: true);

    for (var i = layers.length - 1; i >= 0; i--) {
      final color = layers[i];
      final scaleUp = 1.28 + i * 0.30;
      final layerOp = ((hasSelection ? 0.55 : 0.22) - i * 0.06).clamp(0.0, 1.0);
      final sigma = i >= 3 ? 9.0 : 5.5;
      final pulseScale = 1 + pulse * 0.06 * (i + 1);

      canvas.save();
      canvas.scale(scaleUp * pulseScale);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: layerOp)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 + i * 0.8
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AuraPainter old) => true;
}

// ───────────────────────── Waves ─────────────────────────

Path _eegPath({
  required double cx, required double y, required double halfW,
  required double amp, required double cycles, required double phase,
  required double seed, required double irr,
}) {
  const n = 60;
  final path = Path();
  final h1 = 0.12 + 0.5 * irr;
  final h2 = 0.04 + 0.4 * irr;
  final h3 = irr > 0.32 ? 0.55 * irr : 0.0;

  for (var i = 0; i <= n; i++) {
    final t = i / n;
    final env = math.sin(t * math.pi);
    final x = cx - halfW + t * 2 * halfW;
    final main = math.sin(t * cycles * math.pi * 2 + phase);
    final harm1 = h1 * math.sin(t * cycles * math.pi * 2 * 2.3 + phase * 1.7 + seed);
    final harm2 = h2 * math.sin(t * cycles * math.pi * 2 * 4.1 + phase * 0.6 + seed * 2);
    final harm3 = h3 * math.sin(t * cycles * math.pi * 2 * 7.7 + phase * 2.4 + seed * 3);
    final yy = y - (main + harm1 + harm2 + harm3) * amp * env;
    if (i == 0) {
      path.moveTo(x, yy);
    } else {
      path.lineTo(x, yy);
    }
  }
  return path;
}

class WavesPainter extends CustomPainter {
  final List<Color> colors;
  final List<int> freqs;
  final double phase; // 0..1 چرخه‌ی مداوم

  WavesPainter({required this.colors, required this.freqs, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / kPanelW;
    final scaleY = size.height / kPanelH;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final hasSelection = colors.isNotEmpty;
    const neutral = Color(0xFF9FA5BA);
    final waveColors = hasSelection ? colors.take(2).toList() : <Color>[neutral, neutral];
    final waveFreqs = hasSelection ? freqs.take(2).toList() : <int>[250, 250];
    final waveY0 = kBodyCY + BodyDims.headCY - 20;
    const waveHalfW = 34.0;

    // خط پایه
    canvas.drawLine(
      Offset(kBodyCX - waveHalfW - 4, waveY0),
      Offset(kBodyCX + waveHalfW + 4, waveY0),
      Paint()
        ..color = neutral.withValues(alpha: 0.25)
        ..strokeWidth = 0.6,
    );

    const freqMin = 20, freqMax = 700;

    for (var wi = 0; wi < waveColors.length; wi++) {
      final color = waveColors[wi];
      final freq = waveFreqs[wi].clamp(freqMin, freqMax);
      final reg = (math.log(freq) - math.log(freqMin)) /
          (math.log(freqMax) - math.log(freqMin));
      final irr = 1 - reg;

      final halfW = waveHalfW - wi * 4;
      final amp = 5.2 - wi * 1.1;
      final cycles = 1.5 + reg * 3.6 + wi * 0.35;
      final y = waveY0 - wi * 5.5;
      final seed = wi * 1.3 + (freq % 17) * 0.05;
      final ph = phase * 2 * math.pi;

      final path = _eegPath(
        cx: kBodyCX, y: y, halfW: halfW, amp: amp,
        cycles: cycles, phase: ph, seed: seed, irr: irr,
      );

      final opGlow = ((hasSelection ? 0.28 : 0.16) - wi * 0.06).clamp(0.0, 1.0);
      final opLine = ((hasSelection ? 0.9 : 0.55) - wi * 0.15).clamp(0.0, 1.0);

      // هاله‌ی موج
      canvas.drawPath(path, Paint()
        ..color = color.withValues(alpha: opGlow)
        ..strokeWidth = 3.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3));

      // خط اصلی
      canvas.drawPath(path, Paint()
        ..color = color.withValues(alpha: opLine)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WavesPainter old) => true;
}

// ───────────────────────── Heart ─────────────────────────

class HeartPainter extends CustomPainter {
  final double pulse; // 0..1

  HeartPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / kPanelW;
    final scaleY = size.height / kPanelH;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final s = 1 + pulse * 0.06;
    final rect = Rect.fromCenter(
      center: const Offset(kBodyCX + kHeartCX, kBodyCY + kHeartCY),
      width: kHeartRX * 2 * s,
      height: kHeartRY * 2 * s,
    );

    const grad = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFFB4102A), Color(0xFFEF2440), Color(0xFFFF5468)],
      stops: [0.0, 0.55, 1.0],
    );

    canvas.drawOval(rect, Paint()..shader = grad.createShader(rect));
    canvas.restore();
  }

  @override
  bool shouldRepaint(HeartPainter old) => old.pulse != pulse;
}

// ───────────────────── Heart energy glow ─────────────────────

class HeartEnergyPainter extends CustomPainter {
  final List<Color> colors;
  final double pulse;

  HeartEnergyPainter({required this.colors, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final scaleX = size.width / kPanelW;
    final scaleY = size.height / kPanelH;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final s = 1 + pulse * 0.06;
    final rect = Rect.fromCenter(
      center: const Offset(kBodyCX + kHeartCX, kBodyCY + kHeartCY),
      width: kHeartRX * 2 * 1.35 * s,
      height: kHeartRY * 2 * 1.35 * s,
    );

    final grad = RadialGradient(colors: [
      colors.first.withValues(alpha: 0.85),
      colors.first.withValues(alpha: 0.0),
    ]);

    canvas.saveLayer(rect.inflate(24), Paint());
    canvas.drawOval(
      rect,
      Paint()
        ..shader = grad.createShader(rect)
        ..blendMode = BlendMode.screen
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(HeartEnergyPainter old) => true;
}
