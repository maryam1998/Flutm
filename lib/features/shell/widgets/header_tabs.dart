import 'package:flutter/material.dart';

import '../../../app.dart';
import '../../../core/models/tab_group.dart';
import '../../../core/theme/app_theme_colors.dart';

class HeaderTabs extends StatelessWidget {
  final String activeGroupKey;
  final void Function(TabGroup) onGroupSelected;
  final VoidCallback onSettingsTap;

  const HeaderTabs({
    super.key,
    required this.activeGroupKey,
    required this.onGroupSelected,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final L = context.l10n;
    final c = context.appColors;

    return Container(
      color: c.headerFrom,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: kTabGroups.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final group = kTabGroups[i];
            final active = group.key == activeGroupKey;
            return _HeaderChip(
              icon: group.icon,
              label: _labelFor(L, group.labelKey),
              active: active,
              isAi: group.isAiPowered,
              c: c,
              onTap: () => onGroupSelected(group),
            );
          },
        ),
      ),
    );
  }

  static String _labelFor(AppLocalizations L, String key) {
    switch (key) {
      case 'group_talk':     return L.group_talk;
      case 'group_story':    return L.group_story;
      case 'group_words':    return L.group_words;
      case 'group_practice': return L.group_practice;
      default:               return key;
    }
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool isAi;
  final dynamic c;
  final VoidCallback onTap;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.isAi,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          // ✅ تب فعال = همون طلایی دایره‌های زبان
          color: active ? c.gold : c.headerText.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? c.gold : c.headerText.withOpacity(0.20),
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: c.gold.withOpacity(0.45),
                    blurRadius: 9,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              // آیکون و متن روی طلایی → رنگ تیره‌ی هدر
              color: active ? c.headerTo : c.headerText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? c.headerTo : c.headerText,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (isAi) ...[
              const SizedBox(width: 6),
              _AiDot(active: active, c: c),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiDot extends StatelessWidget {
  final bool active;
  final dynamic c;
  const _AiDot({required this.active, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: active
              ? [const Color(0xFF6D4BD1), const Color(0xFF4A2FA8)]
              : [const Color(0xFFA78BFA), const Color(0xFF818CF8)],
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
    );
  }
}
