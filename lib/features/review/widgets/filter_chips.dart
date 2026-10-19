import 'package:flutter/material.dart';

import '../../../app.dart';
import '../../../core/constants/app_languages.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/widgets/level_chips.dart';
import '../../tabs/_hope_panel.dart';
import '../providers/review_provider.dart';
import '../review_i18n.dart';

/// چیپ‌های اصلی: امروز / این هفته / یاد گرفته / همه / سخت‌ها / جدیدها
class ReviewFilterChips extends StatelessWidget {
  final ReviewFilter selected;
  final Map<ReviewFilter, int> counts;
  final ValueChanged<ReviewFilter> onChanged;

  const ReviewFilterChips({
    super.key,
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Directionality(
      textDirection: uiContentDirection(context),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in ReviewFilter.values)
            HopeChoiceChip(
              label: '${context.rvFilterLabel(f)} ${context.rvNum(counts[f] ?? 0)}',
              active: f == selected,
              activeBorder: c.gold,
              activeFill: c.gold.withOpacity(0.18),
              activeText: c.ink,
              fontSize: 12.5,
              onTap: () => onChanged(f),
            ),
        ],
      ),
    );
  }
}

/// فیلتر سطح (A1–C2)، زبان و منبع (داستان / لغات) — هر کدام یک ردیف افقی.
class ReviewSubFilters extends StatelessWidget {
  final ReviewFilterState filter;

  /// زبان‌هایی که در جعبه لغت دارند
  final List<String> langs;
  final ValueChanged<String?> onLevel;
  final ValueChanged<String?> onLang;
  final ValueChanged<ReviewSource> onSource;

  const ReviewSubFilters({
    super.key,
    required this.filter,
    required this.langs,
    required this.onLevel,
    required this.onLang,
    required this.onSource,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    Widget chip(String label, bool active, VoidCallback onTap,
        {Color? color}) {
      final col = color ?? c.teal;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: HopeChoiceChip(
          label: label,
          active: active,
          activeBorder: col,
          activeFill: col.withOpacity(0.16),
          activeText: c.ink,
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          onTap: onTap,
        ),
      );
    }

    Widget row(String title, List<Widget> chips, {Widget? custom}) {
      return Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              title,
              style: TextStyle(
                color: c.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: custom ??
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: chips),
                ),
          ),
        ],
      );
    }

    return Directionality(
      textDirection: uiContentDirection(context),
      child: Column(
        children: [
          // کارت مشترک سطح‌ها — همان LevelChips بقیه‌ی تب‌ها (رنگی)
          row(
            context.l10n.rv_level,
            const [],
            custom: LevelChips(
              selected: filter.level ?? 'all',
              allLabel: context.l10n.review_filter_all,
              height: 34,
              onSelect: (l) => onLevel(l == 'all' ? null : l),
            ),
          ),
          const SizedBox(height: 8),
          row(context.l10n.rv_language, [
            chip(context.l10n.review_filter_all, filter.lang == null, () => onLang(null)),
            for (final code in langs)
              chip(kAppLanguages[code]?.label ?? code, filter.lang == code,
                  () => onLang(code)),
          ]),
          const SizedBox(height: 8),
          row(context.l10n.rv_source, [
            chip(context.l10n.review_filter_all, filter.source == ReviewSource.any,
                () => onSource(ReviewSource.any)),
            chip(context.l10n.rv_source_story, filter.source == ReviewSource.story,
                () => onSource(ReviewSource.story)),
            chip(context.l10n.rv_source_words, filter.source == ReviewSource.words,
                () => onSource(ReviewSource.words)),
          ]),
        ],
      ),
    );
  }
}
