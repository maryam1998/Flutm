import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/web_palette.dart';

/// پس‌زمینه‌ی پیش‌فرض دقیقاً مثل وب:
///   linear-gradient(160deg, bg-1, bg-2 60%, رنگ پایانی)
/// و در تم تاریک ۷ ستاره‌ی ریز روی آن.
class WebBackground extends StatelessWidget {
  const WebBackground({super.key, required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _WebBgPainter(
          isDark ? WebPalette.dark : WebPalette.light,
          isDark,
        ),
      ),
    );
  }
}

class _WebBgPainter extends CustomPainter {
  _WebBgPainter(this.p, this.isDark);
  final WebPalette p;
  final bool isDark;

  // (x%, y%, شعاع، آلفا) — همان radial-gradientهای وب
  static const _stars = <List<num>>[
    [15, 20, 0.5, 0x55],
    [75, 15, 0.5, 0x44],
    [40, 70, 0.75, 0x33],
    [85, 60, 0.5, 0x40],
    [25, 85, 0.5, 0x33],
    [60, 40, 0.75, 0x2E],
    [92, 85, 0.5, 0x33],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // گرادیان CSS با زاویه‌ی ۱۶۰ درجه
    const ang = 160 * math.pi / 180;
    final dx = math.sin(ang), dy = -math.cos(ang);
    final len = (size.width * dx).abs() + (size.height * dy).abs();
    final c = Offset(size.width / 2, size.height / 2);
    final start = Offset(c.dx - dx * len / 2, c.dy - dy * len / 2);
    final end = Offset(c.dx + dx * len / 2, c.dy + dy * len / 2);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          start,
          end,
          [p.bg1, p.bg2, p.bg3],
          const [0.0, 0.6, 1.0],
        ),
    );

    if (isDark) {
      for (final s in _stars) {
        canvas.drawCircle(
          Offset(size.width * s[0] / 100, size.height * s[1] / 100),
          s[2].toDouble(),
          Paint()..color = Colors.white.withAlpha(s[3].toInt()),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WebBgPainter old) => old.isDark != isDark;
}
