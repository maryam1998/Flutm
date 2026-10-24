import 'package:flutter/material.dart';

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';
import '../theme/web_palette.dart';

const _kDone = Color(0xFF1E9E6A);
const _kMiss = Color(0xFFD9534F);
const _kToday = Color(0xFFC9962B);

enum _St { done, missed, today, future }

class _Day {
  _Day(this.date, this.j, this.st, this.step);
  final DateTime date;
  final Jalali j;
  final _St st;
  final int step; // شماره‌ی قدم (فقط روزهای انجام‌شده)
}

/// روزهای دوره‌ی هدف برای یک شاخه، با وضعیت هر روز و شماره‌ی قدمش
List<_Day> _periodDays(MapHost host, ActionNode node, MapStore store) {
  final pi = periodInfo(host, store);
  final out = <_Day>[];
  var step = 0;
  for (var i = 0; i < pi.total; i++) {
    final d = DateTime(pi.start.year, pi.start.month, pi.start.day + i);
    final j = toJalaali(d.year, d.month, d.day);
    final jk = '${j.jy}-${j.jm}-${j.jd}';
    final isToday = !pi.finished && i == pi.dayNum - 1;
    final future = !pi.finished && i > pi.dayNum - 1;
    if (future) {
      out.add(_Day(d, j, _St.future, 0));
    } else if (isToday) {
      if (footDoneToday(node, jk)) {
        out.add(_Day(d, j, _St.done, ++step));
      } else {
        out.add(_Day(d, j, _St.today, 0));
      }
    } else if (footDoneOn(node, jk)) {
      out.add(_Day(d, j, _St.done, ++step));
    } else {
      out.add(_Day(d, j, _St.missed, 0));
    }
  }
  return out;
}

Future<void> showFootStatsSheet(
  BuildContext context, {
  required MapStore store,
  required String hostId,
  required String actionId,
  VoidCallback? onPhotos,
}) {
  final host = store.state.findHost(hostId);
  if (host is! MapHost) return Future.value();
  final f = findActionNode(host.actions, actionId);
  if (f == null) return Future.value();
  final days = _periodDays(host, f.node, store);
  final title = f.node.text.isEmpty ? 'قدم' : f.node.text;
  final wp = WebPalette.of(context);

  final done = days.where((d) => d.st == _St.done).length;
  final missed = days.where((d) => d.st == _St.missed).length;
  final future = days.where((d) => d.st == _St.future).length;
  final behind = days.where((d) => d.st == _St.missed || d.st == _St.today).length;

  Widget stat(String label, String value, Color? color) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color ?? wp.textMain)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5, color: wp.textDim)),
          ],
        ),
      );

  // گروه‌بندی ماهانه (جلالی)
  final months = <String, List<_Day>>{};
  for (final d in days) {
    months.putIfAbsent('${d.j.jy}-${d.j.jm}', () => []).add(d);
  }

  Widget cell(_Day? d) {
    if (d == null) return const Expanded(child: SizedBox());
    Color? fill;
    Color txt = wp.textMain;
    Border? border;
    switch (d.st) {
      case _St.done:
        fill = _kDone;
        txt = Colors.white;
        break;
      case _St.missed:
        fill = _kMiss.withValues(alpha: 0.13);
        txt = _kMiss;
        break;
      case _St.today:
        border = Border.all(color: _kToday, width: 2);
        break;
      case _St.future:
        txt = wp.textDim.withValues(alpha: 0.7);
        break;
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(9),
              border: border,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(toFa(d.j.jd),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: txt,
                        height: 1.1)),
                if (d.st == _St.done)
                  Text(toFa(d.step),
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget monthGrid(List<_Day> list) {
    // شنبه = ستون اول (راست)
    int col(DateTime d) => (d.weekday + 1) % 7;
    final cells = <_Day?>[
      for (var i = 0; i < col(list.first.date); i++) null,
      ...list,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final first = list.first.j;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
          child: Text('${kJalaliMonths[first.jm - 1]} ${toFa(first.jy)}',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: wp.textMain)),
        ),
        for (var r = 0; r < cells.length; r += 7)
          Row(children: [for (var c = 0; c < 7; c++) cell(cells[r + c])]),
      ],
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.82),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(
          color: wp.panelBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: wp.panelBorder),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: wp.textMain)),
              const SizedBox(height: 10),
              Row(
                children: [
                  stat('انجام‌شده', toFa(done), _kDone),
                  stat('انجام‌نشده', toFa(missed), missed > 0 ? _kMiss : null),
                  stat('عقب‌مانده', toFa(behind), behind > 0 ? _kMiss : null),
                  stat('باقی‌مانده', toFa(future), null),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final m in months.values) monthGrid(m),
                    ],
                  ),
                ),
              ),
              if (onPhotos != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onPhotos();
                    },
                    child: const Text('عکس‌ها'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
