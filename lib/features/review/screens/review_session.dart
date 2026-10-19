import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/word_entry.dart';
import '../../../core/providers/speech_provider.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../models/review_item.dart';
import '../review_i18n.dart';
import '../providers/review_provider.dart';
import '../providers/review_session_provider.dart';
import '../widgets/rating_buttons.dart';
import '../widgets/review_card.dart';
import 'review_summary.dart';

/// جلسه‌ی مرور با فلش‌کارت (تمام‌صفحه، روی ناوبری ریشه باز می‌شود).
class ReviewSessionScreen extends ConsumerStatefulWidget {
  const ReviewSessionScreen({super.key});

  @override
  ConsumerState<ReviewSessionScreen> createState() =>
      _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends ConsumerState<ReviewSessionScreen>
    with SingleTickerProviderStateMixin {
  /// -1 … 0 … 1 : موقعیت افقی کارت (۰ = وسط). کارت فعلی به +۱ می‌رود (راست،
  /// جهت RTL)، کارت بعدی از -۱ می‌آید.
  late final AnimationController _slide;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      lowerBound: -1.0,
      upperBound: 1.0,
      value: 0.0,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  Future<void> _rate(ReviewRating rating) async {
    if (_busy) return;
    _busy = true;

    await _slide.animateTo(1.0, curve: Curves.easeIn);
    if (!mounted) return;

    ref.read(reviewSessionProvider.notifier).rate(rating);
    _slide.value = -1.0;

    if (ref.read(reviewSessionProvider).finished) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ReviewSummaryScreen()),
      );
      return;
    }

    await _slide.animateTo(0.0, curve: Curves.easeOut);
    _busy = false;
  }

  void _speak(ReviewItem item) {
    unawaited(ref
        .read(speechControllerProvider.notifier)
        .toggle(item.word, item.langCode));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = ref.watch(reviewSessionProvider);
    final item = s.current;

    // جلسه تمام شده و خلاصه در حال باز شدن است
    if (s.finished) return Scaffold(backgroundColor: c.paper);

    if (item == null) {
      return Directionality(
        textDirection: uiContentDirection(context),
        child: Scaffold(
          backgroundColor: c.paper,
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.rv_no_active_session,
                      style: TextStyle(color: c.ink, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.rv_back),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final Map<String, WordEntry> info =
        ref.watch(wordInfoProvider).valueOrNull ?? const {};
    final entry = info[item.key];
    final example = (item.langCode == 'en' &&
            entry != null &&
            entry.examples.isNotEmpty)
        ? entry.examples.first
        : null;
    final progress = s.queue.isEmpty ? 0.0 : s.index / s.queue.length;

    return Directionality(
      textDirection: uiContentDirection(context),
      child: Scaffold(
        backgroundColor: c.paper,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // ── نوار بالا ──
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: c.ink),
                      tooltip: context.l10n.rv_close,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 300),
                          builder: (_, v, __) => LinearProgressIndicator(
                            value: v,
                            minHeight: 8,
                            backgroundColor: c.paperDark,
                            valueColor: AlwaysStoppedAnimation<Color>(c.gold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.rv_progress_of(
                          context.rvNum(s.index + 1), context.rvNum(s.queue.length)),
                      style: TextStyle(
                        color: c.inkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── کارت (با انیمیشن slide بین لغت‌ها) ──
                Expanded(
                  child: AnimatedBuilder(
                    animation: _slide,
                    builder: (context, child) => FractionalTranslation(
                      translation: Offset(_slide.value, 0),
                      child: child,
                    ),
                    child: ReviewCard(
                      key: ValueKey('${item.key}#${s.index}'),
                      item: item,
                      revealed: s.revealed,
                      level: entry?.level,
                      example: example,
                      sourceLabel: item.storyId != null
                          ? context.l10n.rv_source_story
                          : context.l10n.rv_source_saved_words,
                      onSpeak: () => _speak(item),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── پایین: نمایش جواب / سه دکمه‌ی ارزیابی ──
                SizedBox(
                  height: 88,
                  child: s.revealed
                      ? RatingButtons(item: item, onRate: _rate)
                      : _RevealButton(
                          onTap: () => ref
                              .read(reviewSessionProvider.notifier)
                              .reveal(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RevealButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: c.gold,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Text(
              context.l10n.rv_show_answer,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
