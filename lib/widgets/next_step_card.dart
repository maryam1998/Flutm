import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart' show nodeFinished;
import '../map/today_focus.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';
import '../theme/web_palette.dart';

const _kGreen = Color(0xFF178A7C);

class _Sug {
  _Sug(this.goal, this.node);
  final Goal goal;
  final ActionNode node;
}

List<ActionNode> _leaves(List<ActionNode> l, [List<ActionNode>? out]) {
  out ??= [];
  for (final n in l) {
    if (n.children.isEmpty) {
      out.add(n);
    } else {
      _leaves(n.children, out);
    }
  }
  return out;
}

/// قدم‌های انجام‌نشده‌ی امروزِ یک هدف (فقط کوچک‌ترین قدم‌ها، یعنی گره‌های بدون زیرشاخه)
List<ActionNode> _todo(Goal g, String jk) => _leaves(g.actions)
    .where((n) =>
        n.text.trim().isNotEmpty && !truthy(n.logs[jk]) && !nodeFinished(n))
    .toList();

/// کارت «قدم بعدیِ امروز» روی نقشه.
/// - از بین همه‌ی هدف‌ها فقط **یک** قدم کوچک پیشنهاد می‌دهد.
/// - هدفی که دیرتر از همه به آن سر زده‌ای اول می‌آید، پس بین چند هدف خودکار می‌چرخد.
/// - ردیف آیکون هدف‌ها نشان می‌دهد امروز به کدام هدف قدم زده‌ای؛ لمسِ یک آیکون
///   یعنی «امروز می‌خواهم روی همین هدف کار کنم».
class NextStepCard extends StatefulWidget {
  const NextStepCard({super.key});

  @override
  State<NextStepCard> createState() => _NextStepCardState();
}

class _NextStepCardState extends State<NextStepCard> {
  String _day = '';
  int _skip = 0;
  String? _focusId;
  bool _more = false;
  // کارت «قدم بعدی» موقع ورود خودش باز نمی‌شود؛ با لمسِ دکمه‌ی 👣 باز می‌شود
  bool _collapsed = true;
  // آخرین قدمی که همین الان تیک خورد؛ برای پیشنهادِ «کاملاً تمام شد»
  Goal? _jg;
  ActionNode? _jn;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MapStore>();
    final wp = WebPalette.of(context);
    final jk = jKey(DateTime.now());
    if (jk != _day) {
      _day = jk;
      _skip = 0;
      _focusId = null;
      _more = false;
    }

    final goals = store.state.goals.where((g) => !g.reached).toList();
    if (goals.isEmpty) {
      TodayFocus.clear();
      return const SizedBox.shrink();
    }

    final doneBy = <String, int>{for (final g in goals) g.id: todayCount(g, jk)};
    final totalDone = doneBy.values.fold<int>(0, (a, b) => a + b);

    Goal? focus;
    if (_focusId != null) {
      for (final g in goals) {
        if (g.id == _focusId) focus = g;
      }
    }

    final sugg = <_Sug>[];
    if (focus != null) {
      for (final n in _todo(focus, jk)) {
        sugg.add(_Sug(focus, n));
      }
    } else {
      final ordered = [...goals]
        ..sort((a, b) => a.lastActivity.compareTo(b.lastActivity));
      for (final g in ordered) {
        final t = _todo(g, jk);
        if (t.isNotEmpty) sugg.add(_Sug(g, t.first));
      }
    }
    final cur = sugg.isEmpty ? null : sugg[_skip % sugg.length];
    // نقشه در حالت «فقط امروز» همین هدف و قدم را پررنگ نشان می‌دهد
    if (cur == null) {
      TodayFocus.clear();
    } else {
      TodayFocus.update(cur.goal.id, cur.node.id);
    }
    final showDone = totalDone > 0 && !_more && focus == null;

    if (_collapsed) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Material(
            color: wp.panelBg,
            shape: CircleBorder(side: BorderSide(color: wp.panelBorder)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _collapsed = false),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Center(child: Text('👣', style: TextStyle(fontSize: 17))),
              ),
            ),
          ),
        ),
      );
    }

    Widget main;
    if (showDone) {
      main = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✓ امروز ${toFa(totalDone)} قدم برداشتی 🎉',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: wp.textMain)),
                const SizedBox(height: 2),
                Text('همین کافیه؛ اگه حال داری یکی دیگه:',
                    style: TextStyle(fontSize: 11, color: wp.textDim)),
                // کارِ یک‌باره (نه تکراری) که همین الان تیک خورد: دکمه‌ی «کاملاً تمام شد»
                if (_jg != null &&
                    _jn != null &&
                    !_jn!.isRoutine &&
                    !nodeFinished(_jn!))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E9E6A),
                        side: const BorderSide(color: Color(0xFF1E9E6A)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () {
                        final g = _jg!, n = _jn!;
                        setState(() {
                          _jg = null;
                          _jn = null;
                        });
                        store.toggleFinished(g, n);
                      },
                      icon: const Icon(Icons.task_alt_rounded, size: 17),
                      label: Text('«${_jn!.text}» کاملاً تمام شد',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
          if (cur != null)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => setState(() {
                _more = true;
                _skip = 0;
              }),
              child: const Text('یه قدم دیگه',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      );
    } else if (cur == null) {
      main = Text(
        totalDone > 0
            ? 'همه‌ی قدم‌های امروز تموم شد 🎉'
            : 'هنوز قدمی نداری؛ از «اهداف» یه اقدام کوچک اضافه کن تا اینجا پیشنهاد بدم.',
        style: TextStyle(fontSize: 12, height: 1.6, color: wp.textDim),
      );
    } else {
      final g = cur.goal;
      main = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '👣 قدم بعدی · ${g.icon.isEmpty ? '🎯' : g.icon} ${g.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: wp.textDim),
                ),
                const SizedBox(height: 2),
                Text(
                  cur.node.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      fontWeight: FontWeight.w800,
                      color: wp.textMain),
                ),
              ],
            ),
          ),
          if (sugg.length > 1)
            IconButton(
              tooltip: 'یه قدم دیگه پیشنهاد بده',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.autorenew, size: 20, color: wp.textDim),
              onPressed: () => setState(() => _skip++),
            ),
          const SizedBox(width: 2),
          Material(
            color: _kGreen,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                // پاداش (صدا/انیمیشن) از hook موجود در MapStore.toggleLog می‌آید
                store.toggleLog(cur.goal, cur.node, jk);
                setState(() {
                  _jg = cur.goal;
                  _jn = cur.node;
                  _skip = 0;
                  _more = false;
                });
              },
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.check_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      );
    }

    final withStep = doneBy.values.where((v) => v > 0).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: wp.panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: wp.panelBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          main,
          if (goals.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _collapseBtn(wp),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final g in goals) _goalDot(g, doneBy[g.id] ?? 0, wp),
                      ],
                    ),
                  ),
                ),
                Text('${toFa(withStep)} از ${toFa(goals.length)} هدف',
                    style: TextStyle(fontSize: 10.5, color: wp.textDim)),
              ],
            ),
          ] else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _collapseBtn(wp),
            ),
        ],
      ),
    );
  }

  /// دکمه‌ی جمع‌کردنِ کارت: سمت راست (دست‌رس) و با ناحیه‌ی لمسِ بزرگ
  Widget _collapseBtn(WebPalette wp) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _collapsed = true),
      child: SizedBox(
        width: 44,
        height: 36,
        child: Icon(Icons.keyboard_arrow_up_rounded,
            size: 26, color: wp.textDim),
      ),
    );
  }

  Widget _goalDot(Goal g, int done, WebPalette wp) {
    final focused = _focusId == g.id;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _focusId = focused ? null : g.id;
          _more = true;
          _skip = 0;
        }),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: focused
                    ? _kGreen.withValues(alpha: 0.18)
                    : Colors.transparent,
                border: Border.all(
                  color: focused
                      ? _kGreen
                      : (done > 0 ? _kGreen.withValues(alpha: 0.55) : wp.panelBorder),
                  width: focused ? 2 : 1.4,
                ),
              ),
              child: Text(g.icon.isEmpty ? '🎯' : g.icon,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(fontSize: 16, height: 1)),
            ),
            if (done > 0)
              const Positioned(
                right: -2,
                top: -2,
                child: CircleAvatar(
                  radius: 7,
                  backgroundColor: _kGreen,
                  child: Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
