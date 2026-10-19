import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../models/review_item.dart';
import '../review_i18n.dart';

/// نمای ۵ جعبه‌ی لایتنر — هر جعبه یک پروگرس‌بار نسبت به کل لغت‌ها.
class BoxVisualization extends StatelessWidget {
  /// تعداد لغت هر جعبه؛ index 0 = جعبه‌ی ۱
  final List<int> counts;

  const BoxVisualization({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final total = counts.fold<int>(0, (a, b) => a + b);

    return Directionality(
      textDirection: uiContentDirection(context),
      child: Column(
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _BoxRow(
              box: i + 1,
              count: i < counts.length ? counts[i] : 0,
              total: total,
              color: Color.lerp(c.rose, c.teal, i / 4) ?? c.gold,
              ink: c.ink,
              inkSoft: c.inkSoft,
              track: c.paperDark,
            ),
          ],
        ],
      ),
    );
  }
}

class _BoxRow extends StatelessWidget {
  final int box;
  final int count;
  final int total;
  final Color color;
  final Color ink;
  final Color inkSoft;
  final Color track;

  const _BoxRow({
    required this.box,
    required this.count,
    required this.total,
    required this.color,
    required this.ink,
    required this.inkSoft,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            context.l10n.review_box_n(context.rvNum(box)),
            style: TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 12,
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 60,
          child: Text(
            context.l10n.rv_box_words_count(context.rvNum(count)),
            textAlign: TextAlign.end,
            style: TextStyle(color: inkSoft, fontSize: 11.5),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 56,
          child: Text(
            context.l10n.rv_box_interval_days(context.rvNum(intervalForBox(box))),
            textAlign: TextAlign.end,
            style: TextStyle(color: inkSoft.withOpacity(0.8), fontSize: 10.5),
          ),
        ),
      ],
    );
  }
}
