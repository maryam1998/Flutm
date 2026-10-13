import 'package:flutter/material.dart';

const double kEmotionBtnSize = 32;

class EmotionFloatingButton extends StatefulWidget {
  final bool open;
  final void Function(Offset delta) onDrag;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final VoidCallback onTap;

  const EmotionFloatingButton({
    super.key,
    required this.open,
    required this.onDrag,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onTap,
  });

  @override
  State<EmotionFloatingButton> createState() => _EmotionFloatingButtonState();
}

class _EmotionFloatingButtonState extends State<EmotionFloatingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  Offset _start = Offset.zero;
  bool _dragged = false;
  int? _pointer;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opened = widget.open;
    return Listener(
      onPointerDown: (e) {
        _pointer = e.pointer;
        _start = e.position;
        _dragged = false;
        widget.onDragStart();
      },
      onPointerMove: (e) {
        if (e.pointer != _pointer) return;
        final d = e.position - _start;
        if (!_dragged && d.distance > 3) _dragged = true;
        if (_dragged) widget.onDrag(d);
      },
      onPointerUp: (e) {
        if (e.pointer != _pointer) return;
        final wasDrag = _dragged;
        _pointer = null;
        _dragged = false;
        widget.onDragEnd();
        if (!wasDrag) widget.onTap();
      },
      onPointerCancel: (e) {
        if (e.pointer != _pointer) return;
        _pointer = null;
        _dragged = false;
        widget.onDragEnd();
      },
      child: AnimatedBuilder(
        animation: _breath,
        builder: (_, __) {
          final s = opened ? 1.0 : 1.0 + _breath.value * 0.06;
          return Transform.scale(
            scale: s,
            child: SizedBox(
              width: kEmotionBtnSize,
              height: kEmotionBtnSize,
              child: CustomPaint(painter: _ButtonPainter(opened: opened)),
            ),
          );
        },
      ),
    );
  }
}

class _ButtonPainter extends CustomPainter {
  final bool opened;
  _ButtonPainter({required this.opened});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final r = size.width / 2;

    final grad = LinearGradient(
      begin: const Alignment(-0.5, -1),
      end: const Alignment(0.5, 1),
      colors: opened
          ? const [Color(0xFF3A4256), Color(0xFF1C2233)]
          : const [Color(0xFF38E0D8), Color(0xFF4F7CF0), Color(0xFF5B4FD6)],
      stops: opened ? null : const [0.0, 0.55, 1.0],
    );

    canvas.drawCircle(center, r, Paint()..shader = grad.createShader(rect));

    canvas.drawCircle(
      center, r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.45),
    );

    if (!opened) {
      final hi = Rect.fromCircle(
        center: Offset(center.dx - r * 0.35, center.dy - r * 0.55),
        radius: r * 0.35,
      );
      canvas.drawOval(
        hi,
        Paint()
          ..shader = const RadialGradient(colors: [
            Color(0xCCFFFFFF),
            Color(0x00FFFFFF),
          ]).createShader(hi),
      );
    }

    final iconPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = opened ? 1.7 : 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (opened) {
      final d = r * 0.4;
      canvas.drawLine(
          center + Offset(-d, -d), center + Offset(d, d), iconPaint);
      canvas.drawLine(
          center + Offset(d, -d), center + Offset(-d, d), iconPaint);
    } else {
      final path = Path()
        ..moveTo(center.dx - r * 0.62, center.dy)
        ..lineTo(center.dx - r * 0.36, center.dy)
        ..lineTo(center.dx - r * 0.22, center.dy - r * 0.45)
        ..lineTo(center.dx - r * 0.02, center.dy + r * 0.45)
        ..lineTo(center.dx + r * 0.14, center.dy)
        ..lineTo(center.dx + r * 0.62, center.dy);
      canvas.drawPath(path, iconPaint);
    }
  }

  @override
  bool shouldRepaint(_ButtonPainter old) => old.opened != opened;
}
