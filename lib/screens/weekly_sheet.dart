import 'package:flutter/material.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/constants.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';

// رنگ‌های تم روشن (کرم/طلایی مثل بقیه‌ی شیت‌ها)
const _kCream = Color(0xFFFBF6EA);
const _kCard = Colors.white;
const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kTeal = Color(0xFF2DD4BF);
const _kPurple = Color(0xFF8F7BF0);

Future<void> showWeeklySheet(BuildContext context, MapState state) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(100),
    builder: (_) => _WeeklySheet(state: state),
  );
}

class _Routine {
  _Routine(this.node, this.goal);
  final ActionNode node;
  final Goal goal;
}

class _WeeklySheet extends StatelessWidget {
  const _WeeklySheet({required this.state});
  final MapState state;

  List<_Routine> _collect() {
    final out = <_Routine>[];
    for (final g in state.goals) {
      void walk(List<ActionNode> list) {
        for (final n in list) {
          if (n.isRoutine && n.extra['achieved'] != true) {
            out.add(_Routine(n, g));
          }
          walk(n.children);
        }
      }

      walk(g.actions);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final routines = _collect();
    final days = jalaaliCurrentWeekDates();
    const dayLabels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final tKey = todayJK();

    var total = 0;
    for (final r in routines) {
      for (final k in days) {
        if (truthy(r.node.logs[k])) total++;
      }
    }
    final maxTotal = routines.length * 7;
    final pct = maxTotal == 0 ? 0 : ((total / maxTotal) * 100).round();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),

            // هدر
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.insights, size: 18, color: _kGold),
                  const SizedBox(width: 8),
                  const Text(
                    'نگاه هفته',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('بستن',
                        style: TextStyle(color: _kMuted)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorder),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // کارت امتیاز
                    _scoreCard(total, maxTotal, routines.length, pct),
                    const SizedBox(height: 16),

                    if (routines.isEmpty)
                      _emptyCard()
                    else
                      _weekTable(routines, days, tKey, dayLabels),

                    if (routines.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        '🔥 قوی‌ترین استریک‌ها',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._topStreaks(routines),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard(int total, int max, int count, int pct) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('پیشرفت این هفته',
                    style: TextStyle(fontSize: 12, color: _kMuted)),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _kInk),
                    children: [
                      TextSpan(text: toFa(total)),
                      const TextSpan(
                          text: ' از ',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kMuted)),
                      TextSpan(text: toFa(max)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('${toFa(count)} روتین فعال',
                    style: const TextStyle(
                        fontSize: 11, color: _kMuted)),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: pct / 100,
                    strokeWidth: 5,
                    backgroundColor: _kBorder,
                    valueColor: const AlwaysStoppedAnimation(_kGold),
                  ),
                ),
                Text(
                  '${toFa(pct)}٪',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() => Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: const Text(
          'هنوز روتینی نداری.\nتوی ویرایش یه شاخه، گزینه‌ی «این یه کار روتینه» رو تیک بزن.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _kMuted, height: 1.9, fontSize: 13),
        ),
      );

  Widget _weekTable(
      List<_Routine> routines, List<String> days, String tKey, List<String> labels) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          // سرستون روزهای هفته
          Row(
            children: [
              const SizedBox(width: 110),
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: days[i] == tKey ? _kGold : _kMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 12, color: _kBorder),
          for (final r in routines) _routineRow(r, days, tKey),
        ],
      ),
    );
  }

  Widget _routineRow(_Routine r, List<String> days, String tKey) {
    final color = hexColor(
      r.node.color,
      hexColor(r.goal.color, _kGold),
    );
    final streak = routineStreak(r.node);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.node.text.isEmpty ? 'بدون نام' : r.node.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  r.goal.name.isEmpty ? 'هدف' : r.goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _kMuted),
                ),
                if (streak >= 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '🔥 ${toFa(streak)} روز',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: _kGold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: truthy(r.node.logs[days[i]])
                        ? color
                        : const Color(0xFFF2EDE2),
                    border: days[i] == tKey
                        ? Border.all(color: _kGold, width: 2)
                        : null,
                  ),
                  child: truthy(r.node.logs[days[i]])
                      ? const Icon(Icons.check,
                          size: 13, color: Colors.white)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _topStreaks(List<_Routine> routines) {
    final sorted = [...routines]
      ..sort((a, b) =>
          routineStreak(b.node).compareTo(routineStreak(a.node)));
    final tops = sorted.take(3).where((r) => routineStreak(r.node) >= 2);
    if (tops.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: const Text(
            'هنوز استریکی نداری — امروز شروع کن 🌱',
            style: TextStyle(fontSize: 12, color: _kMuted),
          ),
        ),
      ];
    }
    return [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          children: [
            for (final r in tops)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Text('🥇', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.node.text.isEmpty ? 'بدون نام' : r.node.text,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _kInk,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${toFa(routineStreak(r.node))} روز پیاپی',
                        style: const TextStyle(
                          color: _kGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }
}
