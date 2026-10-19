import 'package:flutter/material.dart';

@immutable
class TabMeta {
  final String key;
  final String labelKey;
  final IconData icon;
  final String route;
  final bool isAiPowered;

  const TabMeta({
    required this.key,
    required this.labelKey,
    required this.icon,
    required this.route,
    this.isAiPowered = false,
  });
}

const List<TabMeta> kTabMetaList = [
  TabMeta(
    key: 'conversations',
    labelKey: 'tab_conversations',
    icon: Icons.chat_bubble_outline,
    route: '/conversations',
  ),
  TabMeta(
    key: 'story',
    labelKey: 'tab_story',
    icon: Icons.auto_stories,
    route: '/story',
    isAiPowered: true,
  ),
  TabMeta(
    key: 'saved',
    labelKey: 'tab_saved',
    icon: Icons.bookmark_outline,
    route: '/saved',
  ),
  TabMeta(
    key: 'grammar',
    labelKey: 'tab_grammar',
    icon: Icons.text_format,
    route: '/grammar',
    isAiPowered: true,
  ),
  TabMeta(
    key: 'speaking',
    labelKey: 'tab_speaking',
    icon: Icons.mic_none_outlined,
    route: '/speaking',
    isAiPowered: true,
  ),
  TabMeta(
    key: 'words',
    labelKey: 'tab_words',
    icon: Icons.menu_book_outlined,
    route: '/words',
  ),
  TabMeta(
    key: 'favorites',
    labelKey: 'tab_favorites',
    icon: Icons.favorite_outline,
    route: '/favorites',
  ),
  TabMeta(
    key: 'review',
    labelKey: 'tab_review',
    icon: Icons.task_alt_rounded,
    route: '/review',
  ),
];

final Map<String, TabMeta> kTabMeta = {
  for (final m in kTabMetaList) m.key: m,
};
