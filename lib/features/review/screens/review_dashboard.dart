import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_languages.dart';
import '../../../core/constants/level_colors.dart';
import '../../../core/providers/speech_provider.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../tabs/_hope_panel.dart';
import '../models/review_item.dart';
import '../review_i18n.dart';
import '../providers/review_provider.dart';
import '../providers/review_session_provider.dart';
import '../widgets/box_visualization.dart';
import '../widgets/filter_chips.dart';
import '../widgets/streak_widget.dart';
import '../widgets/weekly_chart.dart';
import 'review_session.dart';

/// میانگین زمان تقریبی هر کارت (ثانیه) برای تخمین مدت جلسه
const int _kSecondsPerCard = 10;

/// داشبورد اصلی تب «مرور».
class ReviewDashboard extends ConsumerWidget {
  const ReviewDashboard({super.key});

  void _startSession(
      BuildContext context, WidgetRef ref, List<ReviewItem> items) {
    if (items.isEmpty) return;
    ref.read(reviewSessionProvider.notifier).start(items);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const ReviewSessionScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final all = ref.watch(reviewProvider);
    final due = ref.watch(dueReviewProvider);
    final stats = ref.watch(reviewStatsProvider);
    final filtered = ref.watch(filteredReviewProvider);
    final filter = ref.watch(reviewFilterProvider);
    final chipCounts = ref.watch(reviewChipCountsProvider);
    final boxCounts = ref.watch(boxCountsProvider);
    final info = ref.watch(wordInfoProvider).valueOrNull ?? const {};
    final today = stats.dayStat(DateTime.now());

    final langs = <String>{for (final e in all) e.langCode}.toList()..sort();

    return Directionality(
      textDirection: uiContentDirection(context),
      child: HopePanel(
        title: context.l10n.rv_title,
        intro: context.l10n.rv_intro,
        children: [
          // ── ۱. کارت مرور امروز ──
          _TodayCard(
            dueCount: due.length,
            totalCount: all.length,
            onStart: () => _startSession(context, ref, due),
          ),

          // ── ۲. نمودار هفتگی ──
          _SectionCard(
            title: context.l10n.rv_weekly_progress,
            child: WeeklyChart(
              stats: stats,
              // دعوت‌به‌شروع: اگر مروری موعد دارد → شروع؛ اگر جعبه خالی است → رفتن به لغات
              onEmptyAction: due.isNotEmpty
                  ? () => _startSession(context, ref, due)
                  : (all.isEmpty ? () => context.go('/words') : null),
              emptyActionLabel: due.isNotEmpty
                  ? context.l10n.rv_start_review
                  : context.l10n.rv_go_to_words,
              emptyText: all.isNotEmpty && due.isEmpty
                  ? context.l10n.rv_empty_nothing_today
                  : context.l10n.rv_empty_no_reviews,
            ),
          ),

          // ── ۳. آمار امروز ──
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: context.l10n.rv_correct,
                  value: today.correct,
                  color: const Color(0xFF3F9B72),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: context.l10n.rv_wrong,
                  value: today.wrong,
                  color: c.rose,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: context.l10n.rv_learned,
                  value: today.learned,
                  color: c.gold,
                ),
              ),
            ],
          ),

          // ── ۴. جعبه‌ها ──
          _SectionCard(
            title: context.l10n.rv_leitner_boxes,
            child: BoxVisualization(counts: boxCounts),
          ),

          // ── ۵. زنجیره ──
          _SectionCard(child: StreakWidget(stats: stats)),

          // ── ۶ و ۷. فیلترها ──
          _SectionCard(
            title: context.l10n.rv_filter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReviewFilterChips(
                  selected: filter.chip,
                  counts: chipCounts,
                  onChanged: (f) => ref
                      .read(reviewFilterProvider.notifier)
                      .update((s) => s.withChip(f)),
                ),
                const SizedBox(height: 14),
                ReviewSubFilters(
                  filter: filter,
                  langs: langs,
                  onLevel: (v) => ref
                      .read(reviewFilterProvider.notifier)
                      .update((s) => s.withLevel(v)),
                  onLang: (v) => ref
                      .read(reviewFilterProvider.notifier)
                      .update((s) => s.withLang(v)),
                  onSource: (v) => ref
                      .read(reviewFilterProvider.notifier)
                      .update((s) => s.withSource(v)),
                ),
              ],
            ),
          ),

          // ── ۸. لیست لغات ──
          _WordList(
            items: filtered,
            levelOf: (it) => info[it.key]?.level,
            isEmptyBox: all.isEmpty,
            onReviewList: () => _startSession(context, ref, filtered),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// کارت بالایی
// ═══════════════════════════════════════════════════════════════════
class _TodayCard extends StatelessWidget {
  final int dueCount;
  final int totalCount;
  final VoidCallback onStart;

  const _TodayCard({
    required this.dueCount,
    required this.totalCount,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final minutes = (dueCount * _kSecondsPerCard / 60).ceil().clamp(1, 999);
    final has = dueCount > 0;

    final String headline;
    final String sub;
    if (totalCount == 0) {
      headline = context.l10n.rv_box_empty_headline;
      sub = context.l10n.rv_box_empty_sub;
    } else if (!has) {
      headline = context.l10n.rv_nothing_today_headline;
      sub = context.l10n.rv_nothing_today_sub;
    } else {
      headline = context.l10n.rv_due_headline(context.rvNum(dueCount));
      sub = context.l10n.rv_minutes_approx(context.rvNum(minutes));
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.headerFrom, c.headerTo],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: TextStyle(
              color: c.headerText,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (has)
                Icon(Icons.timer_outlined,
                    size: 15, color: c.headerText.withOpacity(0.8)),
              if (has) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  sub,
                  style: TextStyle(
                    color: c.headerText.withOpacity(0.8),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Material(
              color: has ? c.gold : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                // غیرفعال: حاشیه‌ی طلایی (کنتراستِ خوب روی زمینه‌ی تیره)
                side: has
                    ? BorderSide.none
                    : BorderSide(color: c.gold.withOpacity(0.85), width: 1.5),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: has ? onStart : null,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          size: 26,
                          color: has ? Colors.white : c.gold),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.rv_start_review,
                        style: TextStyle(
                          color: has ? Colors.white : c.gold,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// کارت بخش (عنوان اختیاری)
// ═══════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const _SectionCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return HopeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                color: c.ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            context.rvNum(value),
            style: TextStyle(
              color: c.ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: c.inkSoft, fontSize: 12)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// لیست لغات (باکس‌های کوچک)
// ═══════════════════════════════════════════════════════════════════
const int _kListLimit = 40;

class _WordList extends ConsumerWidget {
  final List<ReviewItem> items;
  final String? Function(ReviewItem) levelOf;
  final bool isEmptyBox;
  final VoidCallback onReviewList;

  const _WordList({
    required this.items,
    required this.levelOf,
    required this.isEmptyBox,
    required this.onReviewList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final shown = items.take(_kListLimit).toList();
    final rest = items.length - shown.length;

    return _SectionCard(
      title: context.l10n.rv_words_title(context.rvNum(items.length)),
      child: items.isEmpty
          ? HopeEmptyText(isEmptyBox
              ? context.l10n.rv_no_words_in_box
              : context.l10n.rv_no_words_for_filter)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final it in shown)
                      _WordBox(
                        item: it,
                        level: levelOf(it),
                        onTap: () => unawaited(ref
                            .read(speechControllerProvider.notifier)
                            .toggle(it.word, it.langCode)),
                      ),
                  ],
                ),
                if (rest > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.rv_and_n_more(context.rvNum(rest)),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.inkSoft, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                HopeTextAction(
                  icon: Icons.play_circle_outline_rounded,
                  label: context.l10n.rv_review_this_list(context.rvNum(items.length)),
                  color: c.teal,
                  onTap: onReviewList,
                  fontSize: 13,
                ),
              ],
            ),
    );
  }
}

class _WordBox extends StatelessWidget {
  final ReviewItem item;
  final String? level;
  final VoidCallback onTap;

  const _WordBox({required this.item, required this.level, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final langDir = kAppLanguages[item.langCode]?.dir ?? TextDirection.ltr;
    final accent = level != null ? levelColor(level!) : c.teal;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150, minWidth: 80),
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: langDir,
              style: TextStyle(
                color: c.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              item.meaning.isEmpty ? '—' : item.meaning,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.inkSoft, fontSize: 11),
            ),
            const SizedBox(height: 3),
            Text(
              item.isMastered
                  ? context.l10n.rv_mastered
                  : context.l10n.review_box_n(context.rvNum(item.box)),
              style: TextStyle(color: c.inkSoft, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
