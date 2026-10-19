import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/constants/supported_languages.dart' show langDisplayName;
import '../../core/models/saved_word.dart';
import '../../core/providers/language_selection_provider.dart';
import '../../core/providers/reader_providers.dart';
import '../../core/providers/story_library_provider.dart';
import '../../core/theme/app_theme_colors.dart';
import '_hope_panel.dart';

/// تب «لغات ذخیره‌شده» (زیرتبِ گروه «داستان») — هم‌شکل SavedWordsPanel در Hope.
/// حالتِ خالی: عنوان + توضیح + «هنوز لغتی ذخیره نکردی...»
class SavedTab extends ConsumerStatefulWidget {
  /// true = داخلِ تبِ «داستان» (بین «ساخت داستان» و «کتابخانه») نمایش داده می‌شود؛
  /// بدون اسکرولِ مستقل و بدون هدرِ صفحه.
  final bool embedded;
  const SavedTab({super.key, this.embedded = false});

  @override
  ConsumerState<SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends ConsumerState<SavedTab> {
  final _search = TextEditingController();
  final Set<String> _picked = {}; // '<lang>::<word>'
  String _msg = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _key(SavedWord w) => '${w.langCode}::${w.word}';

  List<SavedWord> _filtered(List<SavedWord> all) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((w) =>
            w.word.toLowerCase().contains(q) ||
            w.meaning.toLowerCase().contains(q))
        .toList();
  }

  Future<bool> _confirm(String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel_button),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.saved_delete_permanently),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _clearVisible(List<SavedWord> all, List<SavedWord> visible) async {
    if (visible.isEmpty) return;
    final isAll = visible.length == all.length;
    final ok = await _confirm(isAll
        ? context.l10n.saved_confirm_clear_all('${visible.length}')
        : context.l10n.saved_confirm_clear_filtered('${visible.length}'));
    if (!ok) return;
    ref.read(savedWordsProvider.notifier).removeWords(visible);
    setState(() {
      _picked.removeAll(visible.map(_key));
      _msg = context.l10n.saved_words_cleared('${visible.length}');
    });
  }

  Future<void> _deleteSelected(List<SavedWord> all) async {
    final chosen = all.where((w) => _picked.contains(_key(w))).toList();
    if (chosen.isEmpty) return;
    final ok = await _confirm(context.l10n.saved_confirm_delete_selected('${chosen.length}'));
    if (!ok) return;
    ref.read(savedWordsProvider.notifier).removeWords(chosen);
    setState(() {
      _picked.removeAll(chosen.map(_key));
      _msg = context.l10n.saved_words_deleted('${chosen.length}');
    });
  }

  void _sendToStory(String lang, List<SavedWord> group) {
    final chosen = group.where((w) => _picked.contains(_key(w))).toList();
    if (chosen.isEmpty) return;
    ref.read(storyDraftProvider.notifier).state =
        StoryDraft(lang, chosen.map((w) => w.word).toList());
    setState(() => _picked.removeAll(chosen.map(_key)));
    if (!widget.embedded) context.go('/story');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final all = ref.watch(savedWordsProvider);
    final visible = _filtered(all);

    // گروه‌بندی بر اساس زبان (جدیدترین اول)
    final byLang = <String, List<SavedWord>>{};
    for (final w in visible.reversed) {
      byLang.putIfAbsent(w.langCode, () => []).add(w);
    }
    final allVisiblePicked =
        visible.isNotEmpty && visible.every((w) => _picked.contains(_key(w)));
    final totalPicked = all.where((w) => _picked.contains(_key(w))).length;

    final kids = <Widget>[
        if (all.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // جستجو
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: c.cardBorder),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 15, color: c.inkSoft),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() => _msg = ''),
                        style: TextStyle(color: c.ink, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: context.l10n.saved_search_placeholder,
                          hintStyle: TextStyle(
                              color: c.inkSoft.withOpacity(0.6), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_search.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(_search.clear),
                        child: Icon(Icons.close, size: 15, color: c.inkSoft),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // نوارِ ابزار
              Wrap(
                spacing: 8,
                runSpacing: 8,
                // دکمه‌ها همیشه سمت راست (در رابط راست‌به‌چپ، start = راست)
                alignment: uiContentDirection(context) == TextDirection.rtl
                    ? WrapAlignment.start
                    : WrapAlignment.end,
                children: [
                  _toolButton(
                    c,
                    icon: Icons.check_box_outlined,
                    label: allVisiblePicked
                        ? context.l10n.saved_deselect_all
                        : context.l10n.select_all,
                    color: c.ink,
                    enabled: visible.isNotEmpty,
                    onTap: () => setState(() {
                      if (allVisiblePicked) {
                        _picked.removeAll(visible.map(_key));
                      } else {
                        _picked.addAll(visible.map(_key));
                      }
                    }),
                  ),
                  _toolButton(
                    c,
                    icon: Icons.delete_outline,
                    label: context.l10n.clear_all_words,
                    color: c.rose,
                    enabled: visible.isNotEmpty,
                    onTap: () => _clearVisible(all, visible),
                  ),
                  if (totalPicked > 0)
                    _toolButton(
                      c,
                      icon: Icons.close,
                      label: context.l10n.saved_delete_n_selected('$totalPicked'),
                      color: c.rose,
                      enabled: true,
                      onTap: () => _deleteSelected(all),
                    ),
                ],
              ),
              if (_msg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_msg,
                      style: TextStyle(color: c.teal, fontSize: 12)),
                ),
            ],
          ),

        if (byLang.isEmpty)
          HopeEmptyText(
            all.isEmpty
                ? context.l10n.saved_none_yet
                : context.l10n.saved_none_for_search,
          )
        else
          for (final entry in byLang.entries)
            _langCard(c, entry.key, entry.value),
    ];

    if (widget.embedded) {
      return Directionality(
        textDirection: uiContentDirection(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.saved_words_hint,
              style: TextStyle(color: c.inkSoft, fontSize: 13, height: 1.7),
            ),
            for (final w in kids) ...[const SizedBox(height: 16), w],
          ],
        ),
      );
    }

    return HopePanel(
      contentDirection: uiContentDirection(context),
      title: context.l10n.saved_words_title,
      intro: context.l10n.saved_words_hint,
      children: kids,
    );
  }

  Widget _toolButton(
    AppThemeColorsExt c, {
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langCard(AppThemeColorsExt c, String lang, List<SavedWord> group) {
    final pickedHere = group.where((w) => _picked.contains(_key(w))).length;
    return HopeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${langDisplayName(context, lang)} (${group.length})',
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: pickedHere == 0 ? null : () => _sendToStory(lang, group),
                child: Opacity(
                  opacity: pickedHere == 0 ? 0.5 : 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 13,
                          color: pickedHere == 0 ? c.inkSoft : c.teal),
                      const SizedBox(width: 4),
                      Text(
                        pickedHere == 0
                            ? context.l10n.saved_add_to_story_builder
                            : context.l10n.saved_add_n_words('$pickedHere'),
                        style: TextStyle(
                          color: pickedHere == 0 ? c.inkSoft : c.teal,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in group) _wordChip(c, w),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wordChip(AppThemeColorsExt c, SavedWord w) {
    final picked = _picked.contains(_key(w));
    return GestureDetector(
      onTap: () => setState(() {
        if (!_picked.add(_key(w))) _picked.remove(_key(w));
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: picked ? c.goldSoft : c.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: picked ? c.gold : c.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              w.word,
              textDirection: autoDir(w.word),
              style: TextStyle(
                color: c.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (w.meaning.trim().isNotEmpty)
              Text(
                w.meaning,
                textDirection: autoDir(w.meaning),
                style: TextStyle(color: c.inkSoft, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}
