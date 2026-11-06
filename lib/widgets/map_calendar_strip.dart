import 'package:flutter/material.dart' hide showDialog, showModalBottomSheet;
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart' show footDoneOn;
import '../models/constants.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/map_store.dart';
import '../theme/web_palette.dart';
import 'dark_dialogs.dart';

/// کلیدِ نمایش در `state.extra`
const kMapCalendarKey = 'showCalendarStrip';

/// ظاهرِ روزِ تقویم: چند کار آن روز انجام شده؟
class _DayEntry {
  const _DayEntry(this.hostId, this.hostName, this.actionId, this.text,
      this.color);
  final String hostId, hostName, actionId, text;
  final Color color;
}

/// تقویمِ نواری سمتِ راستِ نقشه (از «تنظیمات ← نمایش روی نقشه» روشن می‌شود).
/// هر خانه یک روزِ جلالی است؛ نقطه‌ها یعنی آن روز کاری انجام شده.
/// لمسِ روز: فهرستِ کارهای همان روز؛ لمسِ هر کار: تقویمِ همان شاخه.
class MapCalendarStrip extends StatefulWidget {
  const MapCalendarStrip({super.key, required this.onOpenDay});

  /// (hostId, actionId, jk)
  final void Function(String hostId, String actionId, String jk) onOpenDay;

  @override
  State<MapCalendarStrip> createState() => _MapCalendarStripState();
}

class _MapCalendarStripState extends State<MapCalendarStrip> {
  static const double _extent = 54;
  static const int _past = 45, _future = 10;
  static const _wd = ['د', 'س', 'چ', 'پ', 'ج', 'ش', 'ی'];

  final _ctl = ScrollController();
  bool _centered = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Map<String, List<_DayEntry>> _collect(MapState st, Set<String> window) {
    final out = <String, List<_DayEntry>>{};
    void walk(MapHost h, String name, List<ActionNode> list) {
      for (final a in list) {
        final keys = <String>{...a.logs.keys, ...a.time.keys, ...a.entries.keys};
        for (final k in keys) {
          if (!window.contains(k) || !footDoneOn(a, k)) continue;
          final c = (a.color != null && a.color!.isNotEmpty)
              ? hexColor(a.color, const Color(0xFFC9962B))
              : hexColor(h.color, const Color(0xFFC9962B));
          (out[k] ??= []).add(_DayEntry(h.id, name, a.id, a.text.trim(), c));
        }
        walk(h, name, a.children);
      }
    }

    for (final g in st.goals) {
      walk(g, g.name, g.actions);
    }
    for (final r in st.rings) {
      walk(r, r.label, r.actions);
    }
    return out;
  }

  void _openDay(BuildContext context, DateTime d, String jk,
      List<_DayEntry> items) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                  child: Text(
                    '${faWeekdayName(d)} ${faDateLong(d)}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF000000)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Text(
                    items.isEmpty
                        ? 'برای این روز کاری ثبت نشده.'
                        : '${toFa(items.length)} کار انجام شده',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF5B5F77)),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    children: [
                      for (final e in items)
                        ListTile(
                          dense: true,
                          leading: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: e.color, shape: BoxShape.circle),
                          ),
                          title: Text(
                            e.text.isEmpty ? '(بدون نام)' : e.text,
                            style: const TextStyle(
                                fontSize: 13.5, color: Color(0xFF000000)),
                          ),
                          subtitle: Text(e.hostName,
                              style: const TextStyle(
                                  fontSize: 11.5, color: Color(0xFF5B5F77))),
                          onTap: () {
                            Navigator.pop(ctx);
                            widget.onOpenDay(e.hostId, e.actionId, jk);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MapStore>();
    final wp = WebPalette.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <DateTime>[
      for (var i = -_past; i <= _future; i++)
        DateTime(today.year, today.month, today.day + i),
    ];
    final keys = [for (final d in days) jKey(d)];
    final done = _collect(store.state, keys.toSet());
    final todayKey = jKey(today);

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.noScaling),
      child: Container(
      width: 44,
      decoration: BoxDecoration(
        color: wp.panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: wp.panelBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, box) {
        if (!_centered) {
          _centered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_ctl.hasClients) return;
            final want = _past * _extent - box.maxHeight / 2 + _extent / 2;
            _ctl.jumpTo(want.clamp(0.0, _ctl.position.maxScrollExtent));
          });
        }
        return ListView.builder(
          controller: _ctl,
          padding: EdgeInsets.zero,
          itemExtent: _extent,
          itemCount: days.length,
          itemBuilder: (context, i) {
            final d = days[i];
            final k = keys[i];
            final j = toJalaali(d.year, d.month, d.day);
            final items = done[k] ?? const <_DayEntry>[];
            final isToday = k == todayKey;
            final future = d.isAfter(today);
            final first = j.jd == 1;
            final fg = isToday ? Colors.white : wp.textMain;
            final dim = isToday
                ? Colors.white70
                : wp.textDim.withValues(alpha: future ? 0.55 : 0.95);
            final n = items.length;
            return InkWell(
              onTap: () => _openDay(context, d, k, items),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                decoration: BoxDecoration(
                  color: isToday ? wp.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      first ? kJalaliMonths[j.jm - 1] : _wd[d.weekday - 1],
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: TextStyle(
                          fontSize: first ? 8.5 : 10,
                          fontWeight: first ? FontWeight.w800 : FontWeight.w500,
                          color: first && !isToday ? wp.accent : dim),
                    ),
                    Text(
                      toFa(j.jd),
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: fg.withValues(alpha: future ? 0.6 : 1.0)),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 6,
                      child: n == 0
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var q = 0; q < (n > 3 ? 3 : n); q++)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 0.8),
                                    decoration: BoxDecoration(
                                      color: isToday
                                          ? Colors.white
                                          : items[q].color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    ));
  }
}
