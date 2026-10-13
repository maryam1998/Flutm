import 'package:flutter/material.dart';

import '../data/neural_tiers.dart';
import '../models/neural_container.dart';

/// نقاشِ مسیر عصبی — دو نورون (رفتار/عادت) + رشته‌های نازک بینشون
class NeuralPathwayPainter extends CustomPainter {
  final int fiberCount;
  final NeuralContainer container;
  final Color textColor;
  final double pulseValue; // ۰..۱ — برای پالسِ نورون عادت

  NeuralPathwayPainter({
    required this.fiberCount,
    required this.container,
    required this.textColor,
    required this.pulseValue,
  });

  static const double _vbW = 380;
  static const double _vbH = 175;

  // موقعیت دو نورون (در مختصات viewBox)
  static const double _behX = 55;
  static const double _habX = 325;
  static const double _nodeY = 90;
  static const double _nodeR = 15;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vbW;
    final sy = size.height / _vbH;
    canvas.save();
    canvas.scale(sx, sy);

    _drawFibers(canvas);
    _drawNeuron(
      canvas,
      cx: _behX,
      tier: neuralTier(fiberCount, false),
      isHabitNode: false,
    );
    _drawNeuron(
      canvas,
      cx: _habX,
      tier: neuralTier(fiberCount, container.habitFormed),
      isHabitNode: true,
    );
    _drawLabels(canvas);

    canvas.restore();
  }

  // ---------------- fibers ----------------

  void _drawFibers(Canvas canvas) {
    if (fiberCount <= 0) return;

    // آخرین احساس ثبت‌شده — بر اساس timestamp کلید رشته.
    // همه‌ی رشته‌ها با همین رنگ کشیده می‌شوند.
    // اگر هیچ حسی ثبت نشده باشد، رنگ پیش‌فرض سبز-فیروزه‌ای است.
    String? latestKey;
    int latestTs = 0;
    for (final k in container.fiberEmotions.keys) {
      if (container.logs[k] != true) continue;
      final ts = _keyTs(k);
      if (ts >= latestTs) {
        latestTs = ts;
        latestKey = k;
      }
    }

    const defaultColor = kEmerald500;
    const defaultOpacity = 0.55;
    const defaultWidth = 1.0;
    const feltOpacity = 0.88;
    const feltWidth = 2.2;
    const spreadCycle = 9;

    // تعیین رنگ نهایی
    Color fColor = defaultColor;
    double fWidth = defaultWidth;
    double fOpacity = defaultOpacity;

    if (latestKey != null) {
      final felt = container.fiberEmotions[latestKey];
      if (felt != null) {
        fColor = _parseHex(felt.color);
        fWidth = feltWidth;
        fOpacity = feltOpacity;
      }
    }

    for (int i = 0; i < fiberCount; i++) {
      final pairIdx = (i ~/ 2) % spreadCycle;
      final mag = 3.0 + 6.0 * pairIdx;
      final off = (i % 2 == 0 ? -1 : 1) * mag;

      final sY = _nodeY + off * 0.4;
      final mY = _nodeY + off;
      final eY = _nodeY + off * 0.4;

      final path = Path()
        ..moveTo(_behX + _nodeR + 1, sY)
        ..quadraticBezierTo(190, mY, _habX - _nodeR - 1, eY);

      final paint = Paint()
        ..color = fColor.withValues(alpha: fOpacity)
        ..strokeWidth = fWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, paint);
    }
  }

  /// استخراج timestamp از کلید رشته (`f<ts>-xxx`)
  static int _keyTs(String key) {
    final m = RegExp(r'^f(\d{10,})-').firstMatch(key);
    if (m == null) return 0;
    return int.tryParse(m.group(1) ?? '0') ?? 0;
  }

  // ---------------- neuron ----------------

  void _drawNeuron(
    Canvas canvas, {
    required double cx,
    required int tier,
    required bool isHabitNode,
  }) {
    final style = neuralTierStyle(tier, isHabitNode: isHabitNode);

    double r = _nodeR;
    double opacity = 1.0;

    // پالسِ آرام برای نورونِ عادتِ بالغ
    if (style.glow) {
      final p = 0.9 + pulseValue * 0.15;
      r = _nodeR * p;
      opacity = 0.85 + pulseValue * 0.15;
    }

    // هاله‌ی نورانیِ اطراف
    if (style.glow) {
      canvas.drawCircle(
        Offset(cx, _nodeY),
        r + 6,
        Paint()
          ..color = style.stroke.withValues(alpha: 0.15 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // دایره‌ی اصلی
    canvas.drawCircle(
      Offset(cx, _nodeY),
      r,
      Paint()
        ..color = style.fill.withValues(alpha: opacity)
        ..style = PaintingStyle.fill,
    );

    // حلقه
    canvas.drawCircle(
      Offset(cx, _nodeY),
      r,
      Paint()
        ..color = style.stroke
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // کاراکتر
    _drawText(
      canvas,
      text: style.char,
      x: cx,
      y: _nodeY + 3.5,
      size: 11,
      color: style.textColor,
      align: TextAlign.center,
      bold: true,
    );
  }

  // ---------------- labels ----------------

  void _drawLabels(Canvas canvas) {
    _drawText(canvas,
        text: 'رفتار',
        x: _behX,
        y: 132,
        size: 12,
        color: kNeuralMuted,
        align: TextAlign.center);
    _drawText(canvas,
        text: 'عادت',
        x: _habX,
        y: 132,
        size: 12,
        color: kNeuralMuted,
        align: TextAlign.center);
  }

  // ---------------- text helper ----------------

  void _drawText(
    Canvas canvas, {
    required String text,
    required double x,
    required double y,
    required double size,
    required Color color,
    TextAlign align = TextAlign.center,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: align,
    )..layout();
    final dx = align == TextAlign.center ? x - tp.width / 2 : x;
    tp.paint(canvas, Offset(dx, y - tp.height / 2));
  }

  static Color _parseHex(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return kEmerald500;
    }
  }

  @override
  bool shouldRepaint(covariant NeuralPathwayPainter old) =>
      old.fiberCount != fiberCount ||
      old.pulseValue != pulseValue ||
      old.container.habitFormed != container.habitFormed ||
      old.textColor != textColor;
}
