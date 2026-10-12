import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/constants.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';

Future<void> showWeeklySheet(BuildContext context, MapState state) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF14172F),
    builder: (_) => darkSheet(_WeeklySheet(state: state)),
  );
}

class _Routine {
  _Routine(this.node, this.goal, this.host);
  final ActionNode node;
  final Goal goal;
  final MapHost host;
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
            out.add(_Routine(n, g, g));
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

    // امتیاز کل هفته
    var total = 0;
    for (final r in routines) {
      for (final k in days) {
        if (truthy(r.node.logs[k])) total++;
      }
    }
    final maxTotal = routines.length * 7;
    final pct = maxTotal == 0 ? 0 : ((total / maxTotal) * 100).round();

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights, size: 20, color: Color(0xFF5EC8F0)),
                  const SizedBox(width: 8),
                  const Text('نگاه هفته',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('بستن'),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // کارت امتیاز
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF5EC8F0).withAlpha(40),
                      const Color(0xFF8F7BF0).withAlpha(30),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF5EC8F0).withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('پیشرفت این هفته',
                              style: TextStyle(fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(
                            '${toFa(total)} از ${toFa(maxTotal)}',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                          Text('${toFa(routines.length)} روتین فعال',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white54)),
                        ],
                      ),
                    ),
                    // دایره‌ی درصد
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
                              strokeWidth: 6,
                              backgroundColor: Colors.white.withAlpha(30),
                              valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF5EC8F0)),
                            ),
                          ),
                          Text('${toFa(pct)}٪',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // هدر روزهای هفته
              Row(
                children: [
                  const SizedBox(width: 100),
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          dayLabels[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: days[i] == tKey
                                ? const Color(0xFF5EC8F0)
                                : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              if (routines.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'هنوز روتینی نداری.\nتوی ویرایش یه شاخه، گزینه‌ی «تمرین روزانه» رو تیک بزن.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, height: 1.8),
                  ),
                )
              else
                for (final r in routines) _routineRow(r, days, tKey),

              if (routines.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 6),
                const Text('🔥 قوی‌ترین استریک‌ها',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._topStreaks(routines),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _routineRow(_Routine r, List<String> days, String tKey) {
    final color = hexColor(
      r.node.color,
      hexColor(r.goal.color, const Color(0xFF5EC8F0)),
    );
    final streak = routineStreak(r.node);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.node.text.isEmpty ? 'بدون نام' : r.node.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (streak >= 2)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4C542).withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🔥 ${toFa(streak)}',
                          style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFFF4C542),
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  r.goal.name.isEmpty ? 'هدف' : r.goal.name,
                  style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: truthy(r.node.logs[days[i]])
                        ? color
                        : Colors.white.withAlpha(days[i] == tKey ? 20 : 8),
                    border: Border.all(
                      color: days[i] == tKey ? color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: truthy(r.node.logs[days[i]])
                      ? const Icon(Icons.check, size: 12, color: Colors.black87)
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
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('هنوز استریکی نداری — امروز شروع کن 🌱',
              style: TextStyle(fontSize: 12, color: Colors.white54)),
        ),
      ];
    }
    return [
      for (final r in tops)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Text('🥇', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r.node.text.isEmpty ? 'بدون نام' : r.node.text,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text('${toFa(routineStreak(r.node))} روز پیاپی',
                  style: const TextStyle(
                      color: Color(0xFFF4C542),
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
        ),
    ];
  }
}
