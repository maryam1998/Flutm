import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app.dart';

import '../../../core/models/filter_state.dart';
import '../../../core/providers/words_filter_provider.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/widgets/level_chips.dart';

class FilterBar extends ConsumerStatefulWidget {
  final String searchHint;
  final bool showLevels;
  final bool showSort;

  const FilterBar({
    super.key,
    this.searchHint = 'جستجو...',
    this.showLevels = true,
    this.showSort = true,
  });

  @override
  ConsumerState<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<FilterBar> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
      text: ref.read(wordsFilterProvider).query,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final filter = ref.watch(wordsFilterProvider);
    final notifier = ref.read(wordsFilterProvider.notifier);

    return Container(
      color: c.paper,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showLevels) ...[
            LevelChips(
              selected: filter.level,
              onSelect: notifier.setLevel,
            ),
            const SizedBox(height: 10),
          ],
          if (widget.showSort) ...[
            _SortRow(
              current: filter.sort,
              c: c,
              onSelect: notifier.setSort,
            ),
            const SizedBox(height: 10),
          ],
          _SearchField(
            controller: _searchCtrl,
            hint: widget.searchHint,
            c: c,
            onChanged: notifier.setQuery,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
class _SortRow extends StatelessWidget {
  final SortMode current;
  final dynamic c;
  final ValueChanged<SortMode> onSelect;

  const _SortRow({
    required this.current,
    required this.c,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight, // همیشه سمتِ راست (فیزیکی)
      child: PopupMenuButton<SortMode>(
        initialValue: current,
        onSelected: onSelect,
        color: c.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        itemBuilder: (_) => SortMode.values.map((mode) {
          return PopupMenuItem<SortMode>(
            value: mode,
            height: 40,
            child: Row(
              children: [
                if (mode == current)
                  Icon(Icons.check, size: 16, color: c.gold)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(mode.label(context.l10n),
                    style: TextStyle(color: c.ink, fontSize: 13.5)),
              ],
            ),
          );
        }).toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: c.paperDark.withOpacity(0.5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sort, size: 15, color: c.inkSoft),
              const SizedBox(width: 6),
              Text(
                '${context.l10n.sort_label}: ${current.label(context.l10n)}',
                style: TextStyle(
                  color: c.ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down, size: 15, color: c.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final dynamic c;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: c.ink.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: TextAlign.right,
        style: TextStyle(color: c.ink, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: c.inkSoft.withOpacity(0.6), fontSize: 14),
          prefixIcon: Icon(Icons.search, color: c.inkSoft, size: 20),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
