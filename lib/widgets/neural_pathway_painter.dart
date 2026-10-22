import 'package:flutter/material.dart';

import '../data/neural_tiers.dart';
import '../models/emotion.dart';
import '../models/neural_container.dart';

/// نقاشِ مسیر عصبی — همه‌ی رشته‌های `true` رنگ احساسِ خودشان را دارند.
/// ضخامت رشته‌های رنگی ثابت است (مستقل از تعداد احساسات).
class NeuralPathwayPainter extends CustomPainter {
  final int fiberCount;
  final NeuralContainer container;
  final Color textColor;
  final double pulseValue;

  /// ضخامت رشته‌ی دارای حس
  final double feltWidth;

  NeuralPathwayPainter({
    required this.fiberCount,
    required this.container,
    required this.textColor,
    required this.pulseValue,
    this.feltWidth = 1.3,
  });

  static const double _vbW = 380;
  static const double _vbH = 175;

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

    final trueKeys = <String>[];
    for (final k in container.logs.keys) {
      if (container.logs[k] == true) trueKeys.add(k);
    }
    if (trueKeys.isEmpty) return;

    // فقط جدیدترین رشته‌ها کشیده می‌شن (به اندازه‌ی fiberCount)
    // برای خوانایی حداکثر ۲۴ رشته‌ی آخر کشیده می‌شه (عدد کل بالای ویجت می‌مونه)
    var drawCount =
        fiberCount < trueKeys.length ? fiberCount : trueKeys.length;
    if (drawCount > 24) drawCount = 24;
    final drawKeys = trueKeys.sublist(trueKeys.length - drawCount);

    // رشته‌ی بدون حس: فیروزه‌ای و نازک. رشته‌ی با حس: به رنگ همون حس و کمی
    // ضخیم‌تر (اثر ثبت حس) — ولی نه اونقدر که زشت بشه.
    const defaultColor = kEmerald500;
    const defaultOpacity = 0.55;
    const defaultWidth = 0.8;
    const feltOpacity = 0.9;
    const spreadCycle = 9;

    for (int i = 0; i < drawCount; i++) {
      final pairIdx = (i ~/ 2) % spreadCycle;
      final mag = 3.0 + 6.0 * pairIdx;
      final off = (i % 2 == 0 ? -1 : 1) * mag;

      final sY = _nodeY + off * 0.4;
      final mY = _nodeY + off;
      final eY = _nodeY + off * 0.4;

      Color fColor = defaultColor;
      double fWidth = defaultWidth;
      double fOpacity = defaultOpacity;

      // رنگ از خودِ همین رشته خونده می‌شه (نه از روی ایندکس)
      final felt = container.fiberEmotions[drawKeys[i]];
      if (felt != null) {
        fColor = _parseHex(felt.color);
        fWidth = feltWidth;
        fOpacity = feltOpacity;
      }

      final path = Path()
        ..moveTo(_behX + _nodeR + 1, sY)
        ..quadraticBezierTo(190, mY, _habX - _nodeR - 1, eY);

      canvas.drawPath(
        path,
        Paint()
          ..color = fColor.withValues(alpha: fOpacity)
          ..strokeWidth = fWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  /// ترکیبِ رنگ همه‌ی احساسات یک لیست (میانگین RGB).
  static Color blendEmotionColors(List<String> ids) {
    final list = ids.map(emotionById).whereType<Emotion>().toList();
    if (list.isEmpty) return kEmerald500;
    if (list.length == 1) return _parseHex(list.first.color);

    double r = 0, g = 0, b = 0;
    for (final e in list) {
      final c = _parseHex(e.color);
      r += c.r;
      g += c.g;
      b += c.b;
    }
    final n = list.length;
    return Color.fromARGB(
      255,
      (r / n * 255).round().clamp(0, 255),
      (g / n * 255).round().clamp(0, 255),
      (b / n * 255).round().clamp(0, 255),
    );
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

    if (style.glow) {
      final p = 0.9 + pulseValue * 0.15;
      r = _nodeR * p;
      opacity = 0.85 + pulseValue * 0.15;
    }

    if (style.glow) {
      canvas.drawCircle(
        Offset(cx, _nodeY),
        r + 6,
        Paint()
          ..color = style.stroke.withValues(alpha: 0.15 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    canvas.drawCircle(
      Offset(cx, _nodeY),
      r,
      Paint()
        ..color = style.fill.withValues(alpha: opacity)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(cx, _nodeY),
      r,
      Paint()
        ..color = style.stroke
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

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

  // رنگ رشته‌ها داخل container تغییر می‌کنه (بدون تغییر تعداد) پس همیشه بازکشی
  @override
  bool shouldRepaint(covariant NeuralPathwayPainter old) => true;
}
