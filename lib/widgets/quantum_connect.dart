import 'dart:math' as math;
import 'package:flutter/material.dart';

const _kEmerald700 = Color(0xFF0F5B53);
const _kGold500 = Color(0xFFC9972B);
const _kMuted = Color(0xFF7A6B57);
const _kInk = Color(0xFF2A2218);

class QuantumConnect extends StatefulWidget {
  const QuantumConnect({super.key});
  @override
  State<QuantumConnect> createState() => _QuantumConnectState();
}

class _QuantumConnectState extends State<QuantumConnect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            const Color(0xFF8F7BF0).withValues(alpha: 0.10),
            const Color(0xFF5EC8F0).withValues(alpha: 0.03),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8F7BF0).withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.5,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: _QuantumPainter(t: _ctrl.value),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Caption
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('🕳️ آگاهی خالص',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kInk)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2BBFAB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('هم‌فرکانسی',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _kEmerald700)),
                    ),
                    const Spacer(),
                    const Text('🌌 قلمرو ممکن‌ها',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kInk)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'وقتی آگاهیت با فرکانس قلمرو ممکن‌ها یکی می‌شه، سیگنالت به میدان می‌رسه — و واقعیت دلخواهت شروع می‌کنه به شکل گرفتن.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: _kMuted, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantumPainter extends CustomPainter {
  final double t;
  _QuantumPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width / 300.0;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(s);

    final phase = t * 2 * math.pi;

    // ═══ کره‌ی چپ (آگاهی خالص) ═══
    _drawField(
      canvas,
      const Offset(-80, 0),
      55,
      const Color(0xFF8F7BF0),
      0.15 + 0.20 * (0.5 + 0.5 * math.sin(phase)),
    );

    // ═══ کره‌ی وسط (هسته) ═══
    // هاله
    canvas.drawCircle(
      Offset.zero,
      26 + 2 * math.sin(phase),
      Paint()
        ..shader = RadialGradient(
          colors: [
            _kGold500.withValues(alpha: 0.95),
            const Color(0xFF2BBFAB).withValues(alpha: 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 26)),
    );
    // حلقه‌ها
    for (final r in [14.0, 9.0]) {
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r == 14 ? 1.5 : 1.2
          ..color = _kGold500.withValues(alpha: 0.6 + 0.4 * math.sin(phase + r)),
      );
    }
    // نقطه‌ی مرکزی
    canvas.drawCircle(
      Offset.zero,
      4 + 1.5 * math.sin(phase),
      Paint()..color = _kGold500,
    );

    // ═══ کره‌ی راست (قلمرو ممکن‌ها) ═══
    _drawField(
      canvas,
      const Offset(80, 0),
      55,
      _kGold500,
      0.15 + 0.20 * (0.5 + 0.5 * math.cos(phase)),
    );

    // ═══ موجِ اتصال (بین دو کره) ═══
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8F7BF0).withValues(alpha: 0.85);
    final wavePath = Path();
    wavePath.moveTo(-40, 0);
    for (var i = 1; i <= 20; i++) {
      final p = i / 20;
      final x = -40 + 80 * p;
      final y = math.sin(p * math.pi * 3 + phase * 2) * 8;
      wavePath.lineTo(x, y);
    }
    canvas.drawPath(wavePath, wavePaint);

    // ═══ لینکِ منحنی (خط‌چین) ═══
    final linkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF8F7BF0).withValues(alpha: 0.55);
    final linkPath = Path();
    linkPath.moveTo(-80, 0);
    linkPath.quadraticBezierTo(-20, -30, 0, 0);
    linkPath.quadraticBezierTo(20, 30, 80, 0);
    canvas.drawPath(linkPath, linkPaint);

    canvas.restore();
  }

  void _drawField(Canvas canvas, Offset center, double radius, Color color, double glowOpacity) {
    // هاله‌ی رنگی
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: glowOpacity * 0.6),
            color.withValues(alpha: glowOpacity),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    // حلقه‌های متحدالمرکز
    for (final r in [radius * 0.7, radius * 0.5, radius * 0.33]) {
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = color.withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QuantumPainter old) => old.t != t;
}
