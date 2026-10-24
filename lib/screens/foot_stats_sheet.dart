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
  _Day(this.date, this.j, this.st, this.step, this.idx);
  final DateTime date;
  final Jalali j;
  final _St st;
  final int idx; // روزِ چندمِ دوره (از ۱)
  final int step; // انجام‌شده: شماره‌ی قدمِ همین روز؛ بقیه: قدمی که منتظرشه
  int lost = 0; // روز از دست رفته: تعداد روزهای پشت‌سرهم از دست رفته
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
      out.add(_Day(d, j, _St.future, step + 1, i + 1));
    } else if (isToday) {
      if (footDoneToday(node, jk)) {
        out.add(_Day(d, j, _St.done, ++step, i + 1));
      } else {
        out.add(_Day(d, j, _St.today, step + 1, i + 1));
      }
    } else if (footDoneOn(node, jk)) {
      out.add(_Day(d, j, _St.done, ++step, i + 1));
    } else {
      out.add(_Day(d, j, _St.missed, step + 1, i + 1));
    }
  }
  // طولِ هر رشته‌ی پشت‌سرهمِ روزهای از دست رفته
  var i = 0;
  while (i < out.length) {
    if (out[i].st != _St.missed) {
      i++;
      continue;
    }
    var k = i;
    while (k < out.length && out[k].st == _St.missed) {
      k++;
    }
    for (var m = i; m < k; m++) {
      out[m].lost = k - i;
    }
    i = k;
  }
  return out;
}

String _ord(int n) => n >= 1 && n <= kPeriodOrd.length ? periodOrd(n - 1) : toFa(n);

/// متنِ «قدم» برای یک روزِ لمس‌شده
String _stepCaption(_Day d) {
  switch (d.st) {
    case _St.done:
      return 'روز ${_ord(d.idx)}، قدم ${_ord(d.step)}';
    case _St.missed:
      return 'روز ${_ord(d.idx)} · قدم ${_ord(d.step)} '
          '(${toFa(d.lost)} روز را از دست دادی)';
    case _St.today:
      return 'امروز · روز ${_ord(d.idx)}، قدم ${_ord(d.step)}';
    case _St.future:
      return 'روز ${_ord(d.idx)} · قدم ${_ord(d.step)} در راه است';
  }
}

int? _parseDaysIn(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹', ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    var i = fa.indexOf(ch);
    if (i < 0) i = ar.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  final n = int.tryParse(b.toString().trim());
  return (n == null || n < 1 || n > kPcMaxDays) ? null : n;
}

Future<int?> _askPeriodDays(BuildContext context, int def) async {
  final c = TextEditingController(text: toFa(def));
  var err = false;
  final res = await showDialog<int>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('دوره چند روزه باشه؟',
              style: TextStyle(fontSize: 15)),
          content: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              errorText: err ? 'عدد بین ۱ تا ${toFa(kPcMaxDays)} وارد کن' : null,
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
            FilledButton(
              onPressed: () {
                final n = _parseDaysIn(c.text);
                if (n == null) {
                  setS(() => err = true);
                  return;
                }
                Navigator.pop(ctx, n);
              },
              child: const Text('تأیید'),
            ),
          ],
        ),
      ),
    ),
  );
  c.dispose();
  return res;
}

Future<void> showFootStatsSheet(
  BuildContext context, {
  required MapStore store,
  required String hostId,
  required String actionId,
  VoidCallback? onPhotos,
}) {
  final host0 = store.state.findHost(hostId);
  if (host0 is! MapHost) return Future.value();
  if (findActionNode(host0.actions, actionId) == null) return Future.value();
  final wp = WebPalette.of(context);
  var sel = -1; // روزِ انتخاب‌شده (idx)

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: ListenableBuilder(
        listenable: store,
        builder: (ctx, _) {
          final host = store.state.findHost(hostId);
          if (host is! MapHost) return const SizedBox.shrink();
          final f = findActionNode(host.actions, actionId);
          if (f == null) return const SizedBox.shrink();
          final pi = periodInfo(host, store);
          final days = _periodDays(host, f.node, store);
          final title = f.node.text.isEmpty ? 'قدم' : f.node.text;
          final future = days.where((d) => d.st == _St.future).length;

          if (sel < 1 || sel > days.length) {
            final t = days.indexWhere((d) => d.st == _St.today);
            sel = t >= 0 ? t + 1 : (days.isEmpty ? 1 : days.length);
          }

          // گروه‌بندی ماهانه (جلالی)
          final months = <String, List<_Day>>{};
          for (final d in days) {
            months.putIfAbsent('${d.j.jy}-${d.j.jm}', () => []).add(d);
          }

          return StatefulBuilder(
            builder: (ctx, setS) {
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
                if (d.idx == sel && d.st != _St.today) {
                  border =
                      Border.all(color: wp.textMain.withValues(alpha: 0.65), width: 1.6);
                }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setS(() => sel = d.idx),
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
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: txt,
                                      height: 1.1)),
                              if (d.st == _St.done)
                                Text(toFa(d.step),
                                    style: TextStyle(
                                        fontSize: 9,
                                        color:
                                            Colors.white.withValues(alpha: 0.85),
                                        height: 1.1)),
                            ],
                          ),
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
                      padding: const EdgeInsets.fromLTRB(2, 8, 2, 3),
                      child: Text('${kJalaliMonths[first.jm - 1]} ${toFa(first.jy)}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: wp.textMain)),
                    ),
                    for (var r = 0; r < cells.length; r += 7)
                      Row(children: [
                        for (var c = 0; c < 7; c++) cell(cells[r + c])
                      ]),
                  ],
                );
              }

              final selDay = days.isEmpty ? null : days[sel - 1];

              return Container(
                margin: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: wp.textMain)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(toFa(future),
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: wp.textMain)),
                              const SizedBox(height: 2),
                              Text('باقی‌مانده',
                                  style: TextStyle(
                                      fontSize: 10.5, color: wp.textDim)),
                            ],
                          ),
                          const Spacer(),
                          if (!pi.finished)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () async {
                                final n = await _askPeriodDays(ctx, pi.total);
                                if (n != null) store.setPeriodDays(host, n);
                              },
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: Text('دوره‌ی ${toFa(pi.total)} روزه',
                                  style: const TextStyle(fontSize: 12)),
                            )
                          else
                            Text('دوره‌ی ${toFa(pi.total)} روزه',
                                style: TextStyle(
                                    fontSize: 12, color: wp.textDim)),
                        ],
                      ),
                      if (selDay != null)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: wp.textMain.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _stepCaption(selDay),
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                fontWeight: FontWeight.w700,
                                color: selDay.st == _St.missed
                                    ? _kMiss
                                    : wp.textMain),
                          ),
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
              );
            },
          );
        },
      ),
    ),
  );
}
