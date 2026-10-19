import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../providers/review_provider.dart';
import '../review_i18n.dart';
import '../providers/review_session_provider.dart';
import 'review_session.dart';

/// خلاصه‌ی پایان جلسه.
class ReviewSummaryScreen extends ConsumerWidget {
  const ReviewSummaryScreen({super.key});

  static String _duration(BuildContext context, Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return context.l10n.rv_seconds(context.rvNum(s));
    return context.l10n.rv_min_sec(context.rvNum(m), context.rvNum(s));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final s = ref.watch(reviewSessionProvider);
    final due = ref.watch(dueReviewProvider);
    final total = s.correct + s.wrong;

    void again() {
      if (due.isEmpty) return;
      ref.read(reviewSessionProvider.notifier).start(due);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ReviewSessionScreen()),
      );
    }

    return Directionality(
      textDirection: uiContentDirection(context),
      child: Scaffold(
        backgroundColor: c.paper,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Text(
                  context.l10n.rv_session_done,
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.rv_words_in_time(
                      context.rvNum(total), _duration(context, s.elapsed)),
                  style: TextStyle(color: c.inkSoft, fontSize: 14),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: context.l10n.rv_correct,
                        value: s.correct,
                        color: const Color(0xFF3F9B72),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stat(
                        label: context.l10n.rv_wrong,
                        value: s.wrong,
                        color: c.rose,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stat(
                        label: context.l10n.rv_learned,
                        value: s.learned,
                        color: c.gold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: due.isEmpty ? null : again,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      due.isEmpty
                          ? context.l10n.rv_none_left
                          : context.l10n.rv_review_again(context.rvNum(due.length)),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.ink,
                      side: BorderSide(color: c.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      context.l10n.rv_back_to_dashboard,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
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

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            context.rvNum(value),
            style: TextStyle(
              color: c.ink,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: c.inkSoft, fontSize: 13)),
        ],
      ),
    );
  }
}
