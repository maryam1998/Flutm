import 'package:flutter/material.dart';

@immutable
class TabGroup {
  final String key;
  final String labelKey;
  final IconData icon;
  final List<String> tabs;
  final bool isAiPowered;

  const TabGroup({
    required this.key,
    required this.labelKey,
    required this.icon,
    required this.tabs,
    this.isAiPowered = false,
  });
}

// ✅ ترتیب جدید: Talk → Words → Story → Practice
const List<TabGroup> kTabGroups = [
  TabGroup(
    key: 'talk',
    labelKey: 'group_talk',
    icon: Icons.chat_bubble_outline,
    tabs: ['conversations'],
  ),
  TabGroup(
    key: 'words',
    labelKey: 'group_words',
    icon: Icons.menu_book_outlined,
    tabs: ['words'],
  ),
  TabGroup(
    key: 'story',
    labelKey: 'group_story',
    icon: Icons.auto_stories,
    tabs: ['story', 'grammar', 'speaking'],
    isAiPowered: true,
  ),
  TabGroup(
    key: 'practice',
    labelKey: 'group_practice',
    icon: Icons.task_alt_rounded,
    tabs: ['favorites', 'review'],
  ),
];

TabGroup groupOfTab(String tabKey) {
  return kTabGroups.firstWhere(
    (g) => g.tabs.contains(tabKey),
    orElse: () => kTabGroups.first,
  );
}
