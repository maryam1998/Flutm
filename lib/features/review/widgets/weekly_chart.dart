import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../models/review_stats.dart';
import '../review_i18n.dart';

/// نمودار ستونی ۷ روز اخیر (تعداد مرورها) — با CustomPainter.
/// قدیمی‌ترین روز سمت راست، امروز سمت چپ (جهت RTL).
class WeeklyChart extends StatelessWidget {
  final ReviewStats stats;

  /// وقتی این هفته هیچ مروری نشده: دکمه‌ی دعوت‌به‌شروع (null = بدونِ دکمه).
  final VoidCallback? onEmptyAction;
  final String? emptyActionLabel;
  final String? emptyText;

  const WeeklyChart({
    super.key,
    required this.stats,
    this.onEmptyAction,
    this.emptyActionLabel,
    this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final dir = uiContentDirection(context);
    final isRtl = dir == TextDirection.rtl;
    // DateTime.weekday: ۱=دوشنبه … ۷=یکشنبه → برچسب‌ها از ARB (rv_weekday_letters)
    final dayLabels = context.rvWeekdayLetters;
    final now = DateTime.now();
    final dates = stats.lastDates(now, n: 7);
    final values = [for (final d in dates) stats.dayStat(d).total];

    // ── حالتِ خالی: به‌جای کادرِ سفیدِ خالی، پیام + دکمه ──
    if (values.every((v) => v == 0)) {
      return Directionality(
        textDirection: dir,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.goldSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.trending_up_rounded, size: 30, color: c.gold),
              ),
              const SizedBox(height: 10),
              Text(
                emptyText ?? context.l10n.rv_empty_no_reviews,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.inkSoft, fontSize: 13, height: 1.7),
              ),
              if (onEmptyAction != null) ...[
                const SizedBox(height: 12),
                Material(
                  color: c.gold,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onEmptyAction,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 10),
                      child: Text(
                        emptyActionLabel ?? context.l10n.rv_start_review,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: dir,
      child: Column(
        children: [
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _BarsPainter(
                values: values,
                barColor: c.teal.withOpacity(0.75),
                todayColor: c.gold,
                gridColor: c.cardBorder,
                textColor: c.inkSoft,
                isRtl: isRtl,
                numText: context.rvNum,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < dates.length; i++)
                Expanded(
                  child: Text(
                    dayLabels[dates[i].weekday - 1],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: i == dates.length - 1 ? c.ink : c.inkSoft,
                      fontSize: 12,
                      fontWeight: i == dates.length - 1
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<int> values; // قدیمی‌ترین اول
  final Color barColor;
  final Color todayColor;
  final Color gridColor;
  final Color textColor;
  final bool isRtl;
  final String Function(Object) numText;

  _BarsPainter({
    required this.values,
    required this.barColor,
    required this.todayColor,
    required this.gridColor,
    required this.textColor,
    required this.isRtl,
    required this.numText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;

    const topPad = 18.0; // جا برای عدد بالای ستون
    final chartH = size.height - topPad;
    final slot = size.width / n;
    final barW = slot * 0.5;
    final maxV = values.fold<int>(1, (a, b) => b > a ? b : a);

    // خط پایه
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      grid,
    );

    for (var i = 0; i < n; i++) {
      final v = values[i];
      // RTL: i=0 (قدیمی‌ترین) سمت راست؛ LTR: سمت چپ
      final cx = isRtl ? size.width - (i + 0.5) * slot : (i + 0.5) * slot;
      final isToday = i == n - 1;
      // حداقل ارتفاعِ ستون (حتی با ۱ مرور) تا حسِ پیشرفت دیده شود
      final h = v == 0 ? 3.0 : ((v / maxV) * chartH).clamp(12.0, chartH);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, size.height - h, barW, h),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = v == 0
              ? gridColor
              : (isToday ? todayColor : barColor),
      );

      if (v > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: numText(v),
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, size.height - h - tp.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values ||
      old.barColor != barColor ||
      old.todayColor != todayColor ||
      old.gridColor != gridColor ||
      old.textColor != textColor ||
      old.isRtl != isRtl;
}
