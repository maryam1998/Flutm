import 'package:flutter/material.dart';

import '../../../app.dart';
import '../../../core/models/tab_group.dart';
import '../../../core/models/tab_meta.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/screen_scale.dart';

class SubTabsRow extends StatelessWidget {
  final TabGroup group;
  final String activeTabKey;
  final void Function(String tabKey) onTabSelected;

  const SubTabsRow({
    super.key,
    required this.group,
    required this.activeTabKey,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final L = context.l10n;
    final c = context.appColors;

    return Container(
      color: c.paperDark,
      height: context.px(140),
      // فونتِ زیرتب‌ها ثابت و هم‌اندازه‌ی تب‌های بالاست؛ اگر جا کم بود اسکرولِ افقی.
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.px(20),
          vertical: context.px(26),
        ),
        child: LayoutBuilder(builder: (ctx, box) {
          final gap = context.px(10);
          final n = group.tabs.length;
          final base = DefaultTextStyle.of(ctx).style;

          // فونت/آیکون دقیقاً هم‌اندازه‌ی تب‌های بالا (Practice/Story/Words/Talk):
          // متن ۱۳، آیکون ۱۶. اگر مجموعِ پهنای طبیعیِ تب‌ها از صفحه بیشتر شد،
          // ردیف به‌جای کوچک شدنِ فونت، افقی اسکرول می‌شود.
          final naturalW = <double>[];
          for (final key in group.tabs) {
            final meta = kTabMeta[key]!;
            final tp = TextPainter(
              text: TextSpan(
                text: _labelFor(L, meta.labelKey),
                style: base.copyWith(
                  fontSize: _kFont,
                  fontWeight: FontWeight.w800,
                ),
              ),
              textDirection: Directionality.of(ctx),
              maxLines: 1,
            )..layout();
            var w = _kIcon + 6 + tp.width + _kPadH * 2 + 4;
            if (meta.isAiPowered) w += 6 + 24;
            naturalW.add(w);
          }
          final total =
              naturalW.fold<double>(0, (a, b) => a + b) + gap * (n - 1);
          final fits = total <= box.maxWidth;

          Widget chipAt(int i) {
            final key = group.tabs[i];
            final meta = kTabMeta[key]!;
            return _SubChip(
              icon: meta.icon,
              label: _labelFor(L, meta.labelKey),
              active: key == activeTabKey,
              isAi: meta.isAiPowered,
              c: c,
              onTap: () => onTabSelected(key),
            );
          }

          if (fits) {
            return Row(
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(child: chipAt(i)),
                ],
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  SizedBox(width: naturalW[i], child: chipAt(i)),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  // هم‌اندازه با header_tabs.dart
  static const double _kFont = 13;
  static const double _kIcon = 16;
  static const double _kPadH = 8;

  static String _labelFor(AppLocalizations L, String key) {
    switch (key) {
      case 'tab_conversations': return L.tab_conversations;
      case 'tab_story':         return L.tab_story;
      case 'tab_saved':         return L.tab_saved;
      case 'tab_grammar':       return L.tab_grammar;
      case 'tab_speaking':      return L.tab_speaking;
      case 'tab_words':         return L.tab_words;
      case 'tab_favorites':     return L.tab_favorites;
      case 'tab_review':        return L.tab_review;
      default:                  return key;
    }
  }
}

class _SubChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool isAi;
  final dynamic c;
  final VoidCallback onTap;

  const _SubChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.isAi,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // مثل اسکرین‌شات: نوار کرم (paperDark)؛ تبِ غیرفعال تخت و بدون پس‌زمینه،
    // تبِ فعال یک پیلِ کرمِ روشن‌تر با حاشیهٔ طلایی و آیکونِ طلایی.
    final Color ink = c.ink as Color;
    final Color soft = c.inkSoft as Color;
    final Color gold = c.gold as Color;
    final Color fg = active ? ink : soft;
    final Color iconColor = active ? gold : soft;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: active ? c.paper as Color : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? gold : Colors.transparent,
          width: context.px(2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: SubTabsRow._kPadH, vertical: 8),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: SubTabsRow._kIcon, color: iconColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SubTabsRow._kFont,
                        color: fg,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isAi) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B7CF6), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
