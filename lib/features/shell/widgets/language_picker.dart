import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/constants/supported_languages.dart';
import '../../../core/providers/language_selection_provider.dart';
import '../../../core/theme/app_theme_colors.dart';

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final sel = ref.watch(languageSelectionProvider);
    final notifier = ref.read(languageSelectionProvider.notifier);

    // زبان مادری
    final nativeOrder = ref.watch(nativeOrderProvider);
    final nativeDefaults = kSupportedLanguages.map((l) => l.code).toList();
    final nativeOrderList = nativeOrder.isEmpty
        ? nativeDefaults
        : [
            ...nativeOrder.where(nativeDefaults.contains),
            ...nativeDefaults.where((cc) => !nativeOrder.contains(cc)),
          ];
    final nativeLanguages = nativeOrderList
        .map((code) => kSupportedLanguages.firstWhere((l) => l.code == code))
        .toList();

    // زبان‌های مقصد
    final targetDisplayOrder = ref.watch(targetDisplayOrderProvider);
    final selected = sel.targets.toList();
    final selectedLangs = selected
        .map((code) => kSupportedLanguages.firstWhere(
              (l) => l.code == code,
              orElse: () => kSupportedLanguages.first,
            ))
        .toList();
    final unselectedCodes = targetDisplayOrder.isEmpty
        ? kSupportedLanguages
            .where((l) => !selected.contains(l.code))
            .map((l) => l.code)
            .toList()
        : [
            ...targetDisplayOrder.where((cc) =>
                !selected.contains(cc) &&
                kSupportedLanguages.any((l) => l.code == cc)),
            ...kSupportedLanguages
                .map((l) => l.code)
                .where((cc) =>
                    !selected.contains(cc) &&
                    !targetDisplayOrder.contains(cc)),
          ];
    final unselectedLangs = unselectedCodes
        .map((code) => kSupportedLanguages.firstWhere((l) => l.code == code))
        .toList();

    return Container(
      color: c.headerFrom,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(text: context.l10n.phrasebook_native_language),
          const SizedBox(height: 3),
          _DragRow(
            key: const ValueKey('native-row'),
            languages: nativeLanguages,
            selectedCodes: {sel.native},
            onTap: (code) => notifier.setNative(code),
            onReorder: (oldIdx, newIdx) {
              ref
                  .read(nativeOrderProvider.notifier)
                  .reorder(nativeOrderList, oldIdx, newIdx);
            },
          ),

          const SizedBox(height: 6),

          _SectionLabel(text: context.l10n.phrasebook_target_languages),
          const SizedBox(height: 3),
          _DragRow(
            key: const ValueKey('target-row'),
            languages: [...selectedLangs, ...unselectedLangs],
            selectedCodes: selected.toSet(),
            onTap: (code) => notifier.toggleTarget(code),
            onReorder: (oldIdx, newIdx) {
              if (oldIdx < selected.length && newIdx <= selected.length) {
                notifier.reorderTargets(oldIdx, newIdx);
              } else {
                final allLangs = [...selectedLangs, ...unselectedLangs]
                    .map((l) => l.code)
                    .toList();
                ref
                    .read(targetDisplayOrderProvider.notifier)
                    .reorder(allLangs, oldIdx, newIdx);
              }
            },
          ),

          if (sel.targets.length > 1) ...[
            const SizedBox(height: 8),
            _SectionLabel(
              text: context.l10n.phrasebook_translation_order,
              small: true,
            ),
            const SizedBox(height: 4),
            _ReorderableChips(
              targets: sel.targets,
              onReorder: notifier.reorderTargets,
              onRemove: notifier.removeTarget,
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  final bool small;
  const _SectionLabel({required this.text, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          style: TextStyle(
            color: c.headerText.withOpacity(small ? 0.55 : 0.75),
            fontSize: small ? 10 : 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
class _DragRow extends StatelessWidget {
  final List<SupportedLanguage> languages;
  final Set<String> selectedCodes;
  final ValueChanged<String> onTap;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _DragRow({
    super.key,
    required this.languages,
    required this.selectedCodes,
    required this.onTap,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return SizedBox(
      height: 52,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        itemCount: languages.length,
        onReorder: onReorder,
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              return Transform.scale(
                scale: 1.0 + (animation.value * 0.12),
                child: Material(
                  color: Colors.transparent,
                  elevation: 8,
                  shape: const CircleBorder(),
                  child: child,
                ),
              );
            },
          );
        },
        itemBuilder: (context, i) {
          final lang = languages[i];
          final active = selectedCodes.contains(lang.code);
          return Padding(
            key: ValueKey('circle-${lang.code}'),
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: _CircleItem(
              index: i,
              abbr: lang.abbr,
              active: active,
              c: c,
              onTap: () => onTap(lang.code),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
class _CircleItem extends StatelessWidget {
  final int index;
  final String abbr;
  final bool active;
  final dynamic c;
  final VoidCallback onTap;

  const _CircleItem({
    required this.index,
    required this.abbr,
    required this.active,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableDelayedDragStartListener(
      index: index,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? c.gold : c.headerText.withOpacity(0.04),
            border: Border.all(
              color: active ? c.gold : c.headerText.withOpacity(0.35),
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
          alignment: Alignment.center,
          child: Text(
            abbr,
            style: TextStyle(
              color: active ? c.headerTo : c.headerText,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
class _ReorderableChips extends StatelessWidget {
  final List<String> targets;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(String code) onRemove;

  const _ReorderableChips({
    required this.targets,
    required this.onReorder,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        itemCount: targets.length,
        onReorder: onReorder,
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          return Material(
            color: Colors.transparent,
            elevation: 4,
            borderRadius: BorderRadius.circular(999),
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final code = targets[index];
          return Padding(
            key: ValueKey('chip-$code'),
            padding: const EdgeInsetsDirectional.only(end: 7),
            child: _OrderChip(
              index: index,
              code: code,
              onRemove: () => onRemove(code),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
class _OrderChip extends StatelessWidget {
  final int index;
  final String code;
  final VoidCallback onRemove;

  const _OrderChip({
    required this.index,
    required this.code,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ReorderableDelayedDragStartListener(
      index: index,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.cardBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.rose.withOpacity(0.15),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.close, size: 11, color: c.rose),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              langDisplayName(context, code),
              style: TextStyle(
                color: c.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.drag_indicator,
              size: 14,
              color: c.inkSoft.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
