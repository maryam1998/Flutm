import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/emotion.dart';

/// ارتفاع هر ردیف لیست (ROW_H وب)
const double kListRowH = 21;

/// مرکز عمودیِ ردیف (rowY وب، قبل از translate(6,6)). فرکانس کم پایین، زیاد بالا.
double emotionRowY(int idx) => (kEmotions.length - 1 - idx) * kListRowH + 13;

/// لیست احساسات: ردیف‌ها، چک‌باکس‌ها و متن‌هایی که دورشون هاله‌ی سفید/مشکی دارن
/// (paint-order: stroke fill در وب). فقط وقتی انتخاب یا تم عوض شد دوباره کشیده می‌شه.
class EmotionListPainter extends CustomPainter {
  EmotionListPainter({required this.selected, required this.isDark});

  final Set<String> selected;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final textColor = isDark ? Colors.white : Colors.black;
    final textStroke = isDark ? Colors.black : Colors.white;
    final dimColor = isDark ? const Color(0xFFD8DBE8) : const Color(0xFF2A2D3A);
    final dimStroke = textStroke;

    canvas.save();
    canvas.translate(6, 6);

    for (var idx = 0; idx < kEmotions.length; idx++) {
      final em = kEmotions[idx];
      final col = hexToColor(em.color);
      final on = selected.contains(em.id);
      final rowY = emotionRowY(idx);

      // پس‌زمینه‌ی ردیف + نوار رنگی کنار آن (فقط وقتی انتخاب شده)
      if (on) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(2, rowY - 9.5, 94, 19),
            const Radius.circular(5),
          ),
          Paint()..color = col.withValues(alpha: 0.14),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(2, rowY - 9.5, 2.4, 19),
            const Radius.circular(1.2),
          ),
          Paint()..color = col.withValues(alpha: 0.95),
        );
      }

      // چک‌باکس
      const cbX = 87.0;
      final cbY = rowY + 2.5;
      final c = Offset(cbX, cbY);
      canvas.drawCircle(
        c,
        7.2,
        Paint()..color = textStroke.withValues(alpha: 0.65),
      );
      if (on) {
        canvas.drawCircle(c, 5.4, Paint()..color = col);
      }
      canvas.drawCircle(
        c,
        5.4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = on ? col : textColor,
      );
      if (on) {
        final check = Path()
          ..moveTo(cbX - 2.7, cbY)
          ..relativeLineTo(2, 2)
          ..relativeLineTo(3.8, -4);
        canvas.drawPath(
          check,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        );
      }

      // نام احساس + فرکانس (راست‌چین به x = 74.5)
      const textX = cbX - 12.5;
      _drawText(
        canvas,
        em.fa,
        rightX: textX,
        baselineY: rowY - 1,
        fontSize: 9,
        weight: FontWeight.w800,
        fill: on ? col : textColor,
        stroke: textStroke,
        strokeWidth: 3.2,
        alpha: on ? 1.0 : 0.82,
      );
      _drawText(
        canvas,
        '${em.freq} Hz',
        rightX: textX,
        baselineY: rowY + 7.5,
        fontSize: 6.8,
        weight: FontWeight.w700,
        fill: on ? col : dimColor,
        stroke: dimStroke,
        strokeWidth: 2.6,
        alpha: on ? 1.0 : 0.75,
        tabular: true,
      );
    }

    canvas.restore();
  }

  void _drawText(
    Canvas canvas,
    String text, {
    required double rightX,
    required double baselineY,
    required double fontSize,
    required FontWeight weight,
    required Color fill,
    required Color stroke,
    required double strokeWidth,
    required double alpha,
    bool tabular = false,
  }) {
    final features = tabular ? const [FontFeature.tabularFigures()] : null;

    final strokePainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.vazirmatn(
          fontSize: fontSize,
          fontWeight: weight,
          height: 1.0,
          fontFeatures: features,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = stroke.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final fillPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.vazirmatn(
          fontSize: fontSize,
          fontWeight: weight,
          height: 1.0,
          fontFeatures: features,
          color: fill.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final baseline =
        fillPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final off = Offset(rightX - fillPainter.width, baselineY - baseline);
    strokePainter.paint(canvas, off);
    fillPainter.paint(canvas, off);

    strokePainter.dispose();
    fillPainter.dispose();
  }

  @override
  bool shouldRepaint(EmotionListPainter old) =>
      old.isDark != isDark || !setEquals(old.selected, selected);
}
