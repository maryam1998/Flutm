import 'package:flutter/material.dart';

import '../../app.dart';
import '../constants/cefr_levels.dart';
import '../constants/level_colors.dart';
import '../theme/app_theme_colors.dart';

/// ردیف مشترک انتخاب سطح (همه سطوح، A1 … C2) — در تمام تب‌ها یکسان.
/// رنگ هر سطح از [levelColor] می‌آید (همان رنگ نشان سطح روی کارت‌ها).
///
/// - [includeAll] : نمایش چیپ «همه سطوح» (مقدار 'all').
/// - [wrap]       : true → چیپ‌ها به‌صورت Wrap (مثل تنظیمات داستان‌ساز)،
///                  false → ردیف افقی اسکرول‌شونده.
class LevelChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final bool includeAll;
  final bool wrap;
  final double height;

  /// متن چیپ «همه» (پیش‌فرض: «همه سطوح»).
  final String? allLabel;

  const LevelChips({
    super.key,
    required this.selected,
    required this.onSelect,
    this.includeAll = true,
    this.wrap = false,
    this.height = 38,
    this.allLabel,
  });

  @override
  Widget build(BuildContext context) {
    final levels = <String>[if (includeAll) 'all', ...kCefrLevels];
    Widget chip(String lvl) => LevelChip(
          level: lvl,
          active: lvl == selected,
          allLabel: allLabel,
          onTap: () => onSelect(lvl),
        );

    if (wrap) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final l in levels) chip(l)],
      );
    }
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: levels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) => Center(child: chip(levels[i])),
      ),
    );
  }
}

class LevelChip extends StatelessWidget {
  final String level; // 'all' یا A1..C2
  final bool active;
  final VoidCallback onTap;
  final String? allLabel;

  const LevelChip({
    super.key,
    required this.level,
    required this.active,
    required this.onTap,
    this.allLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isAll = level == 'all';
    final Color base = isAll ? c.headerFrom : levelColor(level);
    // فعال: دقیقاً مثلِ تبِ فعالِ Story (داخلِ چیپ طلایی + متنِ تیره)
    final Color fill =
        active ? c.gold : (isAll ? Colors.white : levelBgColor(level));
    final Color border = active ? c.gold : (isAll ? c.cardBorder : base);
    final Color text =
        active ? c.headerTo : (isAll ? c.inkSoft : base);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: isAll ? 16 : 14, vertical: 9),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1.1),
        ),
        child: Text(
          isAll ? (allLabel ?? context.l10n.levels_all) : level,
          style: TextStyle(
            color: text,
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
