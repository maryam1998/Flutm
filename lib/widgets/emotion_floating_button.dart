import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const double kEmotionBtnSize = 32;

/// دایره‌ی شناور (دقیقاً مثل .echw-btn وب): گرادیان ۱۵۰ درجه، هایلایت، سایه، آیکون ECG،
/// تنفس (echwBtnBreathe)، بزرگ شدن هنگام درگ، و حالت بازِ تیره با ضربدر.
class EmotionFloatingButton extends StatefulWidget {
  const EmotionFloatingButton({
    super.key,
    required this.open,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
    required this.onTap,
  });

  final bool open;
  final VoidCallback onDragStart;
  final void Function(Offset delta) onDrag;

  /// moved = true یعنی کاربر دکمه را کشیده (نه تپ)
  final void Function(bool moved) onDragEnd;
  final VoidCallback onTap;

  @override
  State<EmotionFloatingButton> createState() => _EmotionFloatingButtonState();
}

class _EmotionFloatingButtonState extends State<EmotionFloatingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  Offset _start = Offset.zero;
  bool _moved = false;
  bool _down = false;
  int? _pointer;

  @override
  void initState() {
    super.initState();
    // 2.8s برای یک دور کامل: 1.4s بالا + 1.4s پایین
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        _start = e.position;
        _moved = false;
        setState(() => _down = true);
        widget.onDragStart();
      },
      onPointerMove: (e) {
        if (e.pointer != _pointer) return;
        final d = e.position - _start;
        if (!_moved && (d.dx.abs() > 3 || d.dy.abs() > 3)) _moved = true;
        if (_moved) widget.onDrag(d);
      },
      onPointerUp: (e) {
        if (e.pointer != _pointer) return;
        final wasMoved = _moved;
        _pointer = null;
        _moved = false;
        setState(() => _down = false);
        widget.onDragEnd(wasMoved);
        if (!wasMoved) widget.onTap();
      },
      onPointerCancel: (e) {
        if (e.pointer != _pointer) return;
        final wasMoved = _moved;
        _pointer = null;
        _moved = false;
        setState(() => _down = false);
        widget.onDragEnd(wasMoved);
      },
      child: AnimatedScale(
        scale: _down ? 1.14 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.ease,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (context, _) {
            final breathe = (widget.open || _down)
                ? 1.0
                : 1.0 + 0.06 * Curves.easeInOut.transform(_breath.value);
            return Transform.scale(
              scale: breathe,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: widget.open ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.ease,
                builder: (context, t, _) => CustomPaint(
                  size: const Size(kEmotionBtnSize, kEmotionBtnSize),
                  painter: _ButtonPainter(t: t, open: widget.open),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ButtonPainter extends CustomPainter {
  _ButtonPainter({required this.t, required this.open});

  /// ۰ = حالت بسته (آبی/فیروزه‌ای)، ۱ = حالت باز (تیره)
  final double t;
  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final circle = Rect.fromCircle(center: c, radius: r);

    // سایه‌ی بیرونی: 0 3px 12px
    final shadow = Color.lerp(
      const Color(0x663C5AD2), // rgba(60,90,210,.4)
      const Color(0x800A0E1A), // rgba(10,14,26,.5)
      t,
    )!;
    canvas.drawCircle(
      c + const Offset(0, 3),
      r,
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // گرادیان ۱۵۰ درجه‌ی CSS
    const angle = 150 * math.pi / 180;
    final dir = Offset(math.sin(angle), -math.cos(angle));
    final half = (size.width * math.sin(angle).abs() +
            size.height * math.cos(angle).abs()) /
        2;
    final start = c - dir * half;
    final end = c + dir * half;

    const openA = Color(0xFF3A4256);
    const openB = Color(0xFF1C2233);
    final c0 = Color.lerp(const Color(0xFF38E0D8), openA, t)!;
    final c1 = Color.lerp(
        const Color(0xFF4F7CF0), Color.lerp(openA, openB, 0.55)!, t)!;
    final c2 = Color.lerp(const Color(0xFF5B4FD6), openB, t)!;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          start,
          end,
          [c0, c1, c2],
          const [0.0, 0.55, 1.0],
        ),
    );

    // نور داخلی بالا: inset 0 1px 3px rgba(255,255,255,.4)
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    final inner = Path.combine(
      PathOperation.difference,
      Path()..addRect(circle.inflate(20)),
      Path()..addOval(circle.shift(const Offset(0, 1))),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4 - 0.2 * t)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.restore();

    // حاشیه: 1px rgba(255,255,255,.45)
    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.45),
    );

    // هایلایت بالا-چپ (::after): left 16%، top 12%، w 32%، h 22%
    final hi = Rect.fromLTWH(
      size.width * 0.16,
      size.height * 0.12,
      size.width * 0.32,
      size.height * 0.22,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(hi));
    canvas.drawRect(
      hi,
      Paint()
        ..shader = ui.Gradient.radial(
          hi.center,
          math.sqrt(hi.width * hi.width / 4 + hi.height * hi.height / 4),
          [
            Colors.white.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.0),
          ],
          const [0.0, 0.7],
        ),
    );
    canvas.restore();

    // آیکون ۱۵px داخل viewBox ۱۶
    final s = 15 / 16;
    canvas.save();
    canvas.translate((size.width - 15) / 2, (size.height - 15) / 2);
    canvas.scale(s);
    final icon = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (open) {
      icon.strokeWidth = 1.7;
      canvas.drawLine(const Offset(4, 4), const Offset(12, 12), icon);
      canvas.drawLine(const Offset(12, 4), const Offset(4, 12), icon);
    } else {
      icon.strokeWidth = 1.4;
      final ecg = Path()
        ..moveTo(1.8, 8)
        ..lineTo(4.6, 8)
        ..lineTo(6, 4)
        ..lineTo(8.2, 12)
        ..lineTo(9.7, 8)
        ..lineTo(14.2, 8);
      canvas.drawPath(ecg, icon);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ButtonPainter old) => old.t != t || old.open != open;
}
