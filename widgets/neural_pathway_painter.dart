import 'package:flutter/material.dart';

import '../data/neural_tiers.dart';
import '../models/emotion.dart';
import '../models/neural_container.dart';

/// نقاشِ مسیر عصبی.
///
/// - `colors.webStyle == true`  → دقیقاً مثل renderNeuralPathway وب:
///     رشته‌ی پیش‌فرض: --accent با ضخامت ۱ و شفافیت .۵۵
///     رشته‌ی «حس‌دار»: رنگ ذخیره‌شده‌ی dominant با ضخامت ۲.۲ و شفافیت .۸۸
///       (مثل وب، رشته‌های حس‌دار به ترتیب روی رشته‌های رسم‌شده‌ی اول نگاشت می‌شن)
///     پالس نورون عادت: scale ۱→۱.۰۸ و opacity .۹→۱ (بدون هاله‌ی بلور)
/// - در غیر این صورت ظاهر قبلی حفظ می‌شود.
class NeuralPathwayPainter extends CustomPainter {
  final int fiberCount;
  final NeuralContainer container;
  final Color textColor;
  final double pulseValue;
  final NeuralColors colors;

  NeuralPathwayPainter({
    required this.fiberCount,
    required this.container,
    required this.textColor,
    required this.pulseValue,
    this.colors = NeuralColors.legacy,
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

    final drawCount =
        fiberCount < trueKeys.length ? fiberCount : trueKeys.length;

    final web = colors.webStyle;

    final defaultColor = colors.fiberDefault;
    const defaultOpacity = 0.55;
    const defaultWidth = 1.0;
    final feltOpacity = web ? 0.88 : 0.9;
    final feltWidth = web ? 2.2 : 2.4;
    const spreadCycle = 9;

    // وب: feltKeys = کلیدهای fiberEmotions که logs[k] === true
    // و رشته‌ی i-ام، حسِ i-امین کلیدِ حس‌دار را می‌گیرد.
    final feltKeys = <String>[];
    if (web) {
      for (final k in container.fiberEmotions.keys) {
        if (container.logs[k] == true) feltKeys.add(k);
      }
    }

    for (int i = 0; i < drawCount; i++) {
      final key = trueKeys[i];
      final pairIdx = (i ~/ 2) % spreadCycle;
      final mag = 3.0 + 6.0 * pairIdx;
      final off = (i % 2 == 0 ? -1 : 1) * mag;

      final sY = _nodeY + off * 0.4;
      final mY = _nodeY + off;
      final eY = _nodeY + off * 0.4;

      Color fColor = defaultColor;
      double fWidth = defaultWidth;
      double fOpacity = defaultOpacity;

      if (web) {
        final felt = feltKeys.length > i
            ? container.fiberEmotions[feltKeys[i]]
            : null;
        if (felt != null) {
          fColor = _parseHex(felt.color);
          fWidth = feltWidth;
          fOpacity = feltOpacity;
        }
      } else {
        final felt = container.fiberEmotions[key];
        if (felt != null && felt.ids.isNotEmpty) {
          fColor = blendEmotionColors(felt.ids);
          fWidth = feltWidth;
          fOpacity = feltOpacity;
        }
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
    final style =
        neuralTierStyle(tier, isHabitNode: isHabitNode, colors: colors);
    final web = colors.webStyle;

    double r = _nodeR;
    double opacity = 1.0;

    if (style.glow) {
      if (web) {
        // @keyframes npPulseLock: 0%,100% scale(1) op .9 ؛ 50% scale(1.08) op 1
        r = _nodeR * (1.0 + 0.08 * pulseValue);
        opacity = 0.9 + 0.1 * pulseValue;
      } else {
        final p = 0.9 + pulseValue * 0.15;
        r = _nodeR * p;
        opacity = 0.85 + pulseValue * 0.15;
      }
    }

    if (style.glow && !web) {
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
        ..color = web
            ? style.fill.withValues(alpha: style.fill.a * opacity)
            : style.fill.withValues(alpha: opacity)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(cx, _nodeY),
      r,
      Paint()
        ..color = web
            ? style.stroke.withValues(alpha: style.stroke.a * opacity)
            : style.stroke
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    _drawText(
      canvas,
      text: style.char,
      x: cx,
      // وب: y=94 (baseline) با فونت ۱۰ → مرکزِ خط ≈ ۹۰.۵
      y: web ? _nodeY + 0.5 : _nodeY + 3.5,
      size: web ? 10 : 11,
      color: style.textColor,
      align: TextAlign.center,
      bold: !web,
    );
  }

  // ---------------- labels ----------------

  void _drawLabels(Canvas canvas) {
    // وب: y=128 (baseline) با فونت ۱۲ → مرکزِ خط ≈ ۱۲۴
    final y = colors.webStyle ? 124.0 : 132.0;
    _drawText(canvas,
        text: 'رفتار',
        x: _behX,
        y: y,
        size: 12,
        color: colors.label,
        align: TextAlign.center);
    _drawText(canvas,
        text: 'عادت',
        x: _habX,
        y: y,
        size: 12,
        color: colors.label,
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

  @override
  bool shouldRepaint(covariant NeuralPathwayPainter old) =>
      old.fiberCount != fiberCount ||
      old.pulseValue != pulseValue ||
      old.container.habitFormed != container.habitFormed ||
      old.textColor != textColor ||
      old.colors != colors ||
      old.container.fiberEmotions.length != container.fiberEmotions.length ||
      old.container.logs.length != container.logs.length;
}
