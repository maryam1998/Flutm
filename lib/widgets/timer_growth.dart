import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// سیستم «رویش» برای تایمر:
///  - در طولِ تایمر گیاه آرام‌آرام رشد می‌کند (جوانه ← سبزه با برگ ← غنچه)
///  - هر تایمر یک نوعِ تصادفی دارد: جوانه/گل‌دار، رز، قارچ، کاج
///  - با توقفِ تایمر گیاه کامل می‌شود و جرقه + پروانه دورش می‌چرخند
/// همه‌چیز با Canvas کشیده می‌شود (بدون عکس و ایموجی).

const int kGrowthKinds = 4;

// مرزهای فازها (ثانیه)
const double _kPhase1 = 5 * 60; // تا ۵ دقیقه: جوانه‌ی کوچک
const double _kPhase2 = 15 * 60; // ۵ تا ۱۵ دقیقه: سبزه با چند برگ
const double _kPhase3 = 30 * 60; // بعد از آن: غنچه‌ی درحال باز شدن

/// پیشرفتِ رشد (۰ تا ۱) بر پایه‌ی ثانیه‌های سپری‌شده؛ تا قبل از توقف سقفش ۰٫۹۲ است.
double growthOfSecs(num secs) {
  final s = secs.toDouble();
  if (s <= 0) return 0;
  if (s < _kPhase1) return 0.30 * (s / _kPhase1);
  if (s < _kPhase2) return 0.30 + 0.50 * ((s - _kPhase1) / (_kPhase2 - _kPhase1));
  if (s < _kPhase3) return 0.80 + 0.12 * ((s - _kPhase2) / (_kPhase3 - _kPhase2));
  return 0.92;
}

String growthLabel(double g, {bool bloom = false}) {
  if (bloom) return 'شکوفا شد!';
  if (g < 0.30) return 'جوانه‌ی کوچک';
  if (g < 0.80) return 'سبزه با چند برگ';
  return 'کم‌کم داره شکوفا می‌شه';
}

class TimerGrowthView extends StatefulWidget {
  const TimerGrowthView({
    super.key,
    required this.kind,
    this.startMs,
    this.endSecs = 0,
    this.bloom = false,
    this.height = 130,
  });

  /// نوعِ گیاه (۰ تا ۳)
  final int kind;

  /// زمانِ شروعِ تایمر (میلی‌ثانیه) — برای حالتِ در‌حال‌رشد
  final int? startMs;

  /// ثانیه‌های سپری‌شده وقتی تایمر متوقف شد — برای حالتِ شکوفایی
  final int endSecs;

  /// true = گیاهِ کامل + جرقه و پروانه
  final bool bloom;
  final double height;

  @override
  State<TimerGrowthView> createState() => _TimerGrowthViewState();
}

class _TimerGrowthViewState extends State<TimerGrowthView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  final Stopwatch _sw = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    if (widget.bloom) HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  double _now() => _sw.elapsedMilliseconds / 1000.0;

  double _growth(double t) {
    if (widget.bloom) {
      final from = growthOfSecs(widget.endSecs);
      final k = Curves.easeOutCubic.transform((t / 1.4).clamp(0.0, 1.0).toDouble());
      return from + (1 - from) * k;
    }
    final ms = widget.startMs;
    if (ms == null) return 0;
    final secs = (DateTime.now().millisecondsSinceEpoch - ms) / 1000.0;
    return growthOfSecs(secs < 0 ? 0 : secs);
  }

  @override
  Widget build(BuildContext context) {
    final label = growthLabel(_growth(_now()), bloom: widget.bloom);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _GrowthPainter(
                repaint: _ctl,
                kind: widget.kind,
                bloom: widget.bloom,
                time: _now,
                growth: _growth,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5B5F77),
          ),
        ),
      ],
    );
  }
}

double _e(double x) => Curves.easeOut.transform(x.clamp(0.0, 1.0).toDouble());

Paint _fill(Color c) => Paint()
  ..color = c
  ..style = PaintingStyle.fill;

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

Offset _q(Offset a, Offset b, Offset c, double u) {
  final v = 1 - u;
  return Offset(
    v * v * a.dx + 2 * v * u * b.dx + u * u * c.dx,
    v * v * a.dy + 2 * v * u * b.dy + u * u * c.dy,
  );
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter({
    required Listenable repaint,
    required this.kind,
    required this.bloom,
    required this.time,
    required this.growth,
  }) : super(repaint: repaint);

  final int kind;
  final bool bloom;
  final double Function() time;
  final double Function(double) growth;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time();
    final g = growth(t).clamp(0.0, 1.0).toDouble();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final gy = h - 10.0;
    final s = math.min(h - 14.0, w * 0.7);
    final sway = math.sin(t * 1.7) * 0.045 * (0.35 + g);

    _ground(canvas, cx, gy, s, g);
    switch (kind % kGrowthKinds) {
      case 0:
        _drawStemPlant(canvas, cx, gy, s, g, sway, rose: false);
        break;
      case 1:
        _drawStemPlant(canvas, cx, gy, s, g, sway, rose: true);
        break;
      case 2:
        _drawMushroom(canvas, cx, gy, s, g, sway);
        break;
      default:
        _drawPine(canvas, cx, gy, s, g, sway);
    }

    if (bloom) {
      _drawButterflies(canvas, cx, gy, w, s, t);
      _drawSparkles(canvas, Offset(cx, gy - s * 0.55), s, t);
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthPainter old) => true;

  // ───────────── زمین ─────────────
  void _ground(Canvas c, double cx, double gy, double s, double g) {
    final w = s * 0.9;
    c.drawOval(
      Rect.fromCenter(center: Offset(cx, gy + 1), width: w, height: 12),
      _fill(const Color(0xFF8D6E4F).withValues(alpha: 0.35)),
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(cx, gy), width: w * 0.62, height: 8),
      _fill(const Color(0xFF7B5A3B)),
    );
    if (g < 0.04) {
      c.drawCircle(Offset(cx, gy - 1), 3, _fill(const Color(0xFF4E342E)));
    }
  }

  // ───────────── برگ ─────────────
  void _leaf(Canvas c, Offset base, double angle, double len, Color col) {
    if (len < 1) return;
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(angle);
    final p = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.5, -len * 0.45, len, 0)
      ..quadraticBezierTo(len * 0.5, len * 0.45, 0, 0);
    c.drawPath(p, _fill(col));
    c.drawLine(
      Offset.zero,
      Offset(len * 0.85, 0),
      _stroke(Colors.white.withValues(alpha: 0.35), 0.8),
    );
    c.restore();
  }

  // ───────────── جوانه‌ی گل‌دار و رز ─────────────
  void _drawStemPlant(Canvas c, double cx, double gy, double s, double g,
      double sway,
      {required bool rose}) {
    final hh = s * 0.82 * _e(g * 1.15);
    final p0 = Offset(cx, gy);
    final tip = Offset(cx + sway * hh * 1.6, gy - hh);
    final p1 = Offset(cx - sway * hh * 0.3 + hh * 0.06, gy - hh * 0.55);
    final stem = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(p1.dx, p1.dy, tip.dx, tip.dy);
    c.drawPath(stem, _stroke(const Color(0xFF3E9B4F), 2.2 + 2.2 * g));

    final th = rose ? const [0.04, 0.24, 0.44] : const [0.0, 0.2, 0.38, 0.56];
    final us = rose ? const [0.3, 0.5, 0.7] : const [0.28, 0.48, 0.66, 0.84];
    for (var i = 0; i < th.length; i++) {
      final ls = _e((g - th[i]) / 0.2);
      if (ls <= 0) continue;
      final pos = _q(p0, p1, tip, us[i]);
      final len = s * (rose ? 0.2 : 0.24) * ls * (1 - 0.1 * i);
      final col = i.isEven ? const Color(0xFF4CAF50) : const Color(0xFF66BB6A);
      final lift = 0.55 + 0.12 * i;
      _leaf(c, pos, -lift + sway * 2, len, col);
      _leaf(c, pos, -math.pi + lift - sway * 2, len, col);
    }

    if (rose) {
      final rs = _e((g - 0.35) / 0.65);
      if (rs > 0) {
        _rose(c, Offset(tip.dx, tip.dy - s * 0.04 * rs), s * 0.18 * rs);
      }
    } else {
      if (g > 0.6) {
        final br = s * 0.05 * ((g - 0.6) / 0.18).clamp(0.0, 1.0);
        c.drawCircle(tip, br, _fill(const Color(0xFF43A047)));
      }
      if (g > 0.78) {
        _daisy(c, tip, s * 0.2 * _e((g - 0.78) / 0.22));
      }
    }
  }

  void _daisy(Canvas c, Offset ctr, double r) {
    if (r < 1) return;
    for (var k = 0; k < 8; k++) {
      c.save();
      c.translate(ctr.dx, ctr.dy);
      c.rotate(k * math.pi / 4);
      c.drawOval(
        Rect.fromCenter(
            center: Offset(r * 0.62, 0), width: r * 0.8, height: r * 0.42),
        _fill(const Color(0xFFFFCA28)),
      );
      c.restore();
    }
    c.drawCircle(ctr, r * 0.36, _fill(const Color(0xFF8D5524)));
  }

  void _rose(Canvas c, Offset ctr, double r) {
    if (r < 1) return;
    const cols = [
      Color(0xFFD81B60),
      Color(0xFFE91E63),
      Color(0xFFF06292),
      Color(0xFFF48FB1),
    ];
    const rs = [1.0, 0.78, 0.56, 0.34];
    for (var i = 0; i < cols.length; i++) {
      c.drawCircle(ctr, r * rs[i], _fill(cols[i]));
      c.drawArc(
        Rect.fromCircle(center: ctr, radius: r * rs[i] * 0.78),
        0.6 + i * 1.3,
        3.2,
        false,
        _stroke(const Color(0xFFAD1457).withValues(alpha: 0.55), 1.1),
      );
    }
  }

  // ───────────── قارچ ─────────────
  void _drawMushroom(
      Canvas c, double cx, double gy, double s, double g, double sway) {
    c.save();
    c.translate(cx, gy);
    c.rotate(sway * 0.6);
    c.translate(-cx, -gy);

    final sh = s * 0.5 * _e(g * 1.3);
    final sw = s * 0.2 * (0.5 + 0.5 * _e(g * 2));
    if (sh > 0.5) {
      final stem = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - sw / 2, gy - sh, sw, sh),
        Radius.circular(sw * 0.35),
      );
      c.drawRRect(stem, _fill(const Color(0xFFF3E6D0)));
    }
    final cs = _e((g - 0.12) / 0.88);
    if (cs > 0) {
      final capW = s * 0.66 * cs;
      final capH = s * 0.34 * cs;
      final r = Rect.fromLTWH(cx - capW / 2, gy - sh - capH, capW, capH * 2);
      final cap = Path()
        ..arcTo(r, math.pi, math.pi, false)
        ..close();
      c.drawPath(cap, _fill(const Color(0xFFE5484D)));
      if (cs > 0.35) {
        final k = ((cs - 0.35) / 0.65).clamp(0.0, 1.0);
        const spots = [
          [-0.22, -0.45, 0.07],
          [0.12, -0.62, 0.08],
          [0.26, -0.3, 0.055],
          [-0.02, -0.25, 0.05],
        ];
        for (final sp in spots) {
          c.drawCircle(
            Offset(cx + capW * sp[0], gy - sh + capH * sp[1]),
            capW * sp[2] * k,
            _fill(Colors.white.withValues(alpha: 0.92)),
          );
        }
      }
    }
    c.restore();
  }

  // ───────────── کاج ─────────────
  void _drawPine(
      Canvas c, double cx, double gy, double s, double g, double sway) {
    c.save();
    c.translate(cx, gy);
    c.rotate(sway * 0.5);
    c.translate(-cx, -gy);

    final th = s * 0.18 * _e(g * 10);
    if (th > 0.5) {
      c.drawRect(
        Rect.fromLTWH(cx - s * 0.04, gy - th, s * 0.08, th),
        _fill(const Color(0xFF6D4C41)),
      );
    }
    const ths = [0.1, 0.3, 0.52];
    const cols = [Color(0xFF2E7D4F), Color(0xFF3A9462), Color(0xFF48A873)];
    for (var i = 0; i < 3; i++) {
      final ls = _e((g - ths[i]) / 0.3);
      if (ls <= 0) continue;
      final bw = s * (0.56 - 0.14 * i) * ls;
      final bh = s * 0.34 * ls;
      final by = gy - s * 0.18 - i * s * 0.2;
      final p = Path()
        ..moveTo(cx - bw / 2, by)
        ..lineTo(cx, by - bh)
        ..lineTo(cx + bw / 2, by)
        ..close();
      c.drawPath(p, _fill(cols[i]));
    }
    if (g > 0.95) {
      _star(c, Offset(cx, gy - s * 0.92), s * 0.07, const Color(0xFFFFC107));
    }
    c.restore();
  }

  void _star(Canvas c, Offset ctr, double r, Color col,
      {double rot = 0, double inner = 0.4, int pts = 5}) {
    final p = Path();
    for (var i = 0; i < pts * 2; i++) {
      final rr = i.isEven ? r : r * inner;
      final a = rot - math.pi / 2 + i * math.pi / pts;
      final o = Offset(ctr.dx + math.cos(a) * rr, ctr.dy + math.sin(a) * rr);
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    p.close();
    c.drawPath(p, _fill(col));
  }

  // ───────────── جرقه‌ها ─────────────
  void _drawSparkles(Canvas c, Offset ctr, double s, double t) {
    final fade = ((t - 0.4) / 0.6).clamp(0.0, 1.0).toDouble();
    if (fade <= 0) return;
    const cols = [
      Color(0xFFFFC107),
      Color(0xFFFF8A65),
      Color(0xFFBA68C8),
      Color(0xFF4FC3F7),
    ];
    for (var i = 0; i < 16; i++) {
      final phase = (i * 0.37) % 1.0;
      final life = (t * 0.55 + phase) % 1.0;
      final a = i * 2.399;
      final r = s * (0.25 + 0.55 * life);
      final pos = Offset(
        ctr.dx + math.cos(a) * r * 1.2,
        ctr.dy + math.sin(a) * r * 0.8,
      );
      final alpha = math.sin(life * math.pi) * fade;
      final size = 3.0 + 4.0 * ((i % 3) / 2);
      _star(
        c,
        pos,
        size,
        cols[i % cols.length].withValues(alpha: alpha.clamp(0.0, 1.0).toDouble()),
        rot: t * 2 + i,
        inner: 0.3,
        pts: 4,
      );
    }
  }

  // ───────────── پروانه‌ها ─────────────
  void _drawButterflies(
      Canvas c, double cx, double gy, double w, double s, double t) {
    final fade = ((t - 0.6) / 0.8).clamp(0.0, 1.0).toDouble();
    if (fade <= 0) return;
    const cols = [Color(0xFFFF9800), Color(0xFF42A5F5), Color(0xFFEC407A)];
    for (var i = 0; i < 3; i++) {
      final x = cx + w * 0.3 * math.sin(t * 0.9 + i * 2.1);
      final y = gy - s * (0.5 + 0.2 * math.sin(t * 1.3 + i * 1.7));
      final flap = math.sin(t * 9 + i).abs();
      final ww = 7.0 * flap + 1.5;
      final col = cols[i].withValues(alpha: fade);
      c.save();
      c.translate(x, y);
      c.drawOval(
        Rect.fromCenter(center: Offset(-(ww / 2 + 0.8), -2), width: ww, height: 9),
        _fill(col),
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(ww / 2 + 0.8, -2), width: ww, height: 9),
        _fill(col),
      );
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 2.4, height: 9),
        _fill(const Color(0xFF37474F).withValues(alpha: fade)),
      );
      c.restore();
    }
  }
}
