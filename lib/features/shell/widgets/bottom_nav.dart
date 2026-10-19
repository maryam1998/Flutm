import 'package:flutter/material.dart';

import '../../../app.dart';
import '../../../core/models/tab_group.dart';
import '../../../core/theme/app_theme_colors.dart';

class AppBottomNav extends StatelessWidget {
  final String activeGroupKey;
  final void Function(TabGroup) onGroupSelected;

  const AppBottomNav({
    super.key,
    required this.activeGroupKey,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: c.paperDark,
        boxShadow: [
          BoxShadow(
            color: c.ink.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: c.cardBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: kTabGroups.map((group) {
              final active = group.key == activeGroupKey;
              return Expanded(
                child: _BottomNavItem(
                  group: group,
                  active: active,
                  c: c,
                  onTap: () => onGroupSelected(group),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final TabGroup group;
  final bool active;
  final dynamic c;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.group,
    required this.active,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final L = context.l10n;
    final label = _labelFor(L, group.labelKey);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container with animated background
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? c.gold.withOpacity(0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      group.icon,
                      size: 22,
                      color: active ? c.gold : c.inkSoft,
                    ),
                    if (group.isAiPowered)
                      Positioned(
                        top: -3,
                        right: -8,
                        child: _AiDot(active: active),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),

              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  color: active ? c.gold : c.inkSoft,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                ),
                child: Text(label),
              ),
            ],
          ),
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

/// نقطه‌ی کوچک AI گوشه‌ی آیکون.
class _AiDot extends StatelessWidget {
  final bool active;
  const _AiDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: active
              ? [const Color(0xFF8B7CF6), const Color(0xFF6366F1)]
              : [const Color(0xFF9CA3AF), const Color(0xFF6B7280)],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.5),
                  blurRadius: 5,
                  spreadRadius: 0.3,
                ),
              ]
            : null,
      ),
      child: const Text(
        'AI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
