import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';
import '../theme/web_palette.dart';
import 'foot_note_sheet.dart' show FootNoteStyleControls;

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
  int gap = 0; // تعداد روزهای پشت‌سرهمِ از دست رفته درست قبل از این روز
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
    if (k < out.length) out[k].gap = k - i;
    i = k;
  }
  return out;
}

String _ord(int n) => n >= 1 && n <= kPeriodOrd.length ? periodOrd(n - 1) : toFa(n);

/// متنِ «قدم» برای یک روزِ لمس‌شده
String _stepCaption(_Day d) {
  final dateStr =
      '${toFa(d.j.jd)} ${kJalaliMonths[d.j.jm - 1]} ${toFa(d.j.jy)}';
  final gapNote =
      d.gap > 0 ? ' (${toFa(d.gap)} روز را از دست دادی)' : '';
  switch (d.st) {
    case _St.done:
      return '$dateStr · روز ${_ord(d.idx)}، قدم ${_ord(d.step)}$gapNote';
    case _St.missed:
      return '$dateStr · روز ${_ord(d.idx)} · قدم ${_ord(d.step)} '
          '(${toFa(d.lost)} روز را از دست دادی)';
    case _St.today:
      return '$dateStr · امروز · روز ${_ord(d.idx)}، قدم ${_ord(d.step)}$gapNote';
    case _St.future:
      return '$dateStr · روز ${_ord(d.idx)} · قدم ${_ord(d.step)} در راه است';
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

String _jkOf(_Day d) => '${d.j.jy}-${d.j.jm}-${d.j.jd}';

Map<String, dynamic> _notesOf(ActionNode n) {
  final v = n.extra['footNotes'];
  return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
}

/// نوشتن/ویرایش یادداشتِ یک روز؛ خروجی null = لغو، '' = حذف
Future<String?> _askNote(BuildContext context, String initial) async {
  final c = TextEditingController(text: initial);
  final res = await showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('یادداشت این روز', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
        ),
        actions: [
          if (initial.isNotEmpty)
            TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('حذف')),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('ذخیره')),
        ],
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
  String? initialJk,
}) {
  final host0 = store.state.findHost(hostId);
  if (host0 is! MapHost) return Future.value();
  if (findActionNode(host0.actions, actionId) == null) return Future.value();
  final wp = WebPalette.of(context);
  var sel = -1; // روزِ انتخاب‌شده (idx)
  String? hint; // پیام کوتاه زیر دکمه‌ها
  String? jkPending = initialJk; // روزی که باید باز شدن انتخاب بشه
  final selKey = GlobalKey();
  final detailCtl = ScrollController();
  // «تنظیمات یادداشت روی نقشه» پیش‌فرض جمع است (شلوغ نشود)
  var noteStyleOpen = false;

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

          if (jkPending != null) {
            final i = days.indexWhere((d) => _jkOf(d) == jkPending);
            if (i >= 0) {
              sel = i + 1;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final c = selKey.currentContext;
                if (c != null && c.mounted) {
                  Scrollable.ensureVisible(c,
                      alignment: 0.5,
                      duration: const Duration(milliseconds: 250));
                }
              });
            }
            jkPending = null;
          }

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
                    key: d.idx == sel ? selKey : null,
                    padding: const EdgeInsets.all(2),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setS(() {
                        sel = d.idx;
                        hint = null;
                        if (detailCtl.hasClients) detailCtl.jumpTo(0);
                      }),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(9),
                            border: border,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                          Column(
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
                              if (nodeDaySecs(f.node, _jkOf(d)) > 0)
                                Text(
                                    toFa(
                                        '${nodeDaySecs(f.node, _jkOf(d)) ~/ 3600}:${((nodeDaySecs(f.node, _jkOf(d)) % 3600) ~/ 60).toString().padLeft(2, '0')}'),
                                    style: TextStyle(
                                        fontSize: 8,
                                        color: d.st == _St.done
                                            ? Colors.white.withValues(alpha: 0.9)
                                            : wp.textDim,
                                        height: 1.1)),
                            ],
                          ),
                          if (_noteBadge(f.node, _jkOf(d), d.st == _St.done)
                              case final b?)
                            PositionedDirectional(top: 2, end: 3, child: b),
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
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
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
                        flex: 3,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final m in months.values) monthGrid(m),
                            ],
                          ),
                        ),
                      ),
                      // جزئیاتِ روزِ انتخاب‌شده: همیشه زیرِ تقویم دیده می‌شود (اگر بلند بود، خودش اسکرول دارد)
                      Flexible(
                        flex: 2,
                        child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(ctx).height * 0.32),
                        child: SingleChildScrollView(
                          controller: detailCtl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                      if (selDay != null) ...[
                        Builder(builder: (_) {
                          final n = f.node;
                          final jk = _jkOf(selDay);
                          final note = (_notesOf(n)[jk] as String?) ?? '';
                          final isDone = selDay.st == _St.done;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    if (selDay.st != _St.future)
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            foregroundColor:
                                                isDone ? wp.textDim : _kDone,
                                          ),
                                          onPressed: () {
                                            if (isDone) {
                                              if (n.logs[jk] == true) {
                                                n.logs.remove(jk);
                                                hint = null;
                                              } else {
                                                hint =
                                                    'این روز با متن/زمان ثبت شده؛ از خودِ اقدام تغییرش بده';
                                              }
                                            } else {
                                              n.logs[jk] = true;
                                              hint = null;
                                            }
                                            store.changed();
                                            setS(() {});
                                          },
                                          icon: Icon(
                                              isDone
                                                  ? Icons.undo_rounded
                                                  : Icons.check_circle_outline,
                                              size: 17),
                                          label: Text(
                                              isDone
                                                  ? 'برداشتن تیک'
                                                  : 'انجام دادم',
                                              style: const TextStyle(
                                                  fontSize: 12.5)),
                                        ),
                                      ),
                                    if (selDay.st != _St.future)
                                      const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          visualDensity:
                                              VisualDensity.compact,
                                          foregroundColor: _kToday,
                                        ),
                                        onPressed: () async {
                                          final t = await _askNote(ctx, note);
                                          if (t == null) return;
                                          final m = _notesOf(n);
                                          if (t.isEmpty) {
                                            m.remove(jk);
                                            clearFootNoteState(n, jk);
                                          } else {
                                            m[jk] = t;
                                          }
                                          n.extra['footNotes'] = m;
                                          store.changed();
                                          setS(() {});
                                        },
                                        icon: const Icon(Icons.edit_note_rounded,
                                            size: 18),
                                        label: Text(
                                            note.isEmpty
                                                ? 'یادداشت'
                                                : 'ویرایش یادداشت',
                                            style: const TextStyle(
                                                fontSize: 12.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hint != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(hint!,
                                      style: TextStyle(
                                          fontSize: 11, color: _kMiss)),
                                ),
                              if (note.isNotEmpty &&
                                  footNoteStyle(n, jk, create: false)['hidden'] ==
                                      true)
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      footNoteStyle(n, jk).remove('hidden');
                                      store.changed();
                                      setS(() {});
                                    },
                                    icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 16),
                                    label: const Text(
                                        'نمایش دوباره روی نقشه',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              if (nodeEntries(n, jk).isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _kDone.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '⏱ مجموع این روز: ${fmtDur(nodeDaySecs(n, jk))}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: wp.textMain)),
                                      for (final e in nodeEntries(n, jk))
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 3),
                                          child: Text(
                                              e['kind'] == 'range'
                                                  ? '🕒 ${fmtHM((e['s'] as num?)?.toInt() ?? 0)} تا ${fmtHM((e['e'] as num?)?.toInt() ?? 0)} — ${fmtDur(((e['mins'] as num?)?.toInt() ?? 0) * 60)}'
                                                  : '⏱ ${fmtDur(((e['mins'] as num?)?.toInt() ?? 0) * 60)}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  height: 1.4,
                                                  color: wp.textMain)),
                                        ),
                                    ],
                                  ),
                                ),
                              if (note.isNotEmpty)
                                _NoteTodoCard(
                                  key: ValueKey('todo-$jk'),
                                  wp: wp,
                                  node: n,
                                  jk: jk,
                                  note: note,
                                  onChanged: () {
                                    store.changed();
                                    setS(() {});
                                  },
                                ),
                            ],
                          );
                        }),
                      ],
                            ],
                          ),
                        ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text('نمایش یادداشت',
                                style: TextStyle(
                                    fontSize: 12.5, color: wp.textMain)),
                          ),
                          Transform.scale(
                            scale: 0.72,
                            child: Switch(
                              activeColor: _kDone,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              value: f.node.extra['footNotesShow'] == true,
                              onChanged: (v) {
                                f.node.extra['footNotesShow'] = v;
                                store.changed();
                                setS(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      if (selDay != null)
                        Builder(builder: (_) {
                          final jk2 = _jkOf(selDay);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // تنظیماتِ یادداشتِ روی نقشه (فونت، اندازه، رنگ، برگشت، حذف از نقشه)
                              // همیشه همین‌جا، زیرِ «نمایش یادداشت» و بالای «تنظیمات انیمیشن» است
                              Container(
                                margin: const EdgeInsets.only(top: 6, bottom: 4),
                                padding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                decoration: BoxDecoration(
                                  color: wp.textMain.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: wp.panelBorder
                                          .withValues(alpha: 0.7)),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    InkWell(
                                      onTap: () =>
                                          setS(() => noteStyleOpen = !noteStyleOpen),
                                      child: Row(
                                        children: [
                                          Icon(Icons.sticky_note_2_outlined,
                                              size: 16, color: wp.textDim),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                                'تنظیمات یادداشت روی نقشه',
                                                style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: wp.textMain)),
                                          ),
                                          Icon(
                                              noteStyleOpen
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              size: 20,
                                              color: wp.textDim),
                                        ],
                                      ),
                                    ),
                                    if (noteStyleOpen) ...[
                                    const SizedBox(height: 8),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxHeight:
                                              MediaQuery.sizeOf(ctx).height *
                                                  0.2),
                                      child: SingleChildScrollView(
                                        child: FootNoteStyleControls(
                                          key: ValueKey('nstyle-$jk2'),
                                          store: store,
                                          node: f.node,
                                          jk: jk2,
                                          onChanged: () => setS(() {}),
                                        ),
                                      ),
                                    ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      if (onPhotos != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onPhotos();
                            },
                            child: const Text('تنظیمات انیمیشن'),
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
  ).whenComplete(detailCtl.dispose);
}


// ═══════════════ یادداشتِ قدم به شکل to-do ═══════════════

/// نشانِ کوچکِ گوشه‌ی خانه‌ی تقویم: یادداشتِ باز = نقطه، منتظر جواب = ساعت شنی،
/// انجام‌شده = تیک. اگر یادداشتی نباشد null.
Widget? _noteBadge(ActionNode n, String jk, bool cellDone) {
  final all = n.extra['footNotes'];
  if (all is! Map) return null;
  final t = all[jk];
  if (t is! String || t.trim().isEmpty) return null;
  final done = footNoteDone(n, jk);
  final wait = footNoteWaiting(n, jk);
  if (wait) {
    return Icon(Icons.hourglass_bottom_rounded,
        size: 10, color: cellDone ? Colors.white : _kToday);
  }
  if (done) {
    return Icon(Icons.check_rounded,
        size: 11, color: cellDone ? Colors.white : _kDone);
  }
  return Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      color: cellDone ? Colors.white.withValues(alpha: 0.9) : _kToday,
      shape: BoxShape.circle,
    ),
  );
}

int _seedOf(String s) => s.codeUnits.fold<int>(0, (a, b) => a + b);

/// **...** = بولد
Widget _richFa(String text, {required Color color, double size = 11.5}) {
  final parts = text.split('**');
  return Text.rich(
    TextSpan(
      style: TextStyle(fontSize: size, height: 1.85, color: color),
      children: [
        for (var i = 0; i < parts.length; i++)
          if (parts[i].isNotEmpty)
            TextSpan(
                text: parts[i],
                style: i.isOdd
                    ? const TextStyle(fontWeight: FontWeight.w800)
                    : null),
      ],
    ),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.right,
  );
}

const _kDoneTitles = [
  'آفرین؛ یک حلقه‌ی باز بسته شد ✅',
  'خط خورد! مغزت این را ثبت کرد 🎯',
  'یک کارِ نیمه‌تمام، تمام شد 🌿',
];

const _kWaitTitles = [
  'سهمِ تو انجام شد؛ حالا نوبتِ جواب است ⏳',
  'توپ حالا در زمینِ بیرون است، نه در ذهنِ تو ⏳',
];

const _kDoneWhy =
    '**چرا مغزت از این خوشش می‌آید؟** کاری که نیمه‌تمام بماند در حافظه‌ی کاری '
    'می‌ماند و مدام مرور می‌شود (اثر زایگارنیک) و **قشر پیش‌پیشانی** (PFC) را '
    'مشغول نگه می‌دارد. وقتی انجامش می‌دهی و خط می‌زنی، این حلقه بسته می‌شود و '
    '**دوپامینِ پیشرفت** ترشح می‌شود؛ یعنی به مغزت می‌گویی «ما داریم به سمتِ '
    'هدف می‌رویم». تکرارِ همین حس، مسیرِ عصبیِ «من آدمِ عمل‌کننده‌ام» را قوی‌تر '
    'می‌کند.';

const _kWaitWhy =
    '**چرا «منتظر جواب» مهم است؟** کاری که نتیجه‌اش دستِ دیگران است، اگر '
    'برچسب نخورد، برای مغز «ناتمام» می‌ماند و **آمیگدال** مدام نگرانِ نتیجه '
    'است. با ثبتِ «سهمِ من تمام شد» به مغزت می‌گویی الان کاری جز صبر لازم '
    'نیست؛ پژوهش‌ها نشان می‌دهد وقتی برای یک کارِ باز، برنامه‌ی روشن داریم '
    '(اینجا: صبر)، فکرهای مزاحمش کم می‌شود. صبر هم یک قدم است. اگر جواب دیر '
    'شد، یادداشتِ تازه‌ی «پیگیری» بنویس.';

/// یادداشتِ یک روز شبیه کارهای to-do: با تیک خط می‌خورد، «منتظر جواب» می‌گیرد
/// و مغز پاداشِ علمیِ کوتاه می‌گیرد.
class _NoteTodoCard extends StatelessWidget {
  const _NoteTodoCard({
    super.key,
    required this.wp,
    required this.node,
    required this.jk,
    required this.note,
    required this.onChanged,
  });

  final WebPalette wp;
  final ActionNode node;
  final String jk;
  final String note;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final done = footNoteDone(node, jk);
    final wait = footNoteWaiting(node, jk);
    final accent = done ? _kDone : _kToday;
    final seed = _seedOf(jk);

    final title = wait
        ? _kWaitTitles[seed % _kWaitTitles.length]
        : _kDoneTitles[seed % _kDoneTitles.length];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: done ? 0.09 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final next = !done;
                  setFootNoteDone(node, jk, next);
                  if (next) HapticFeedback.mediumImpact();
                  onChanged();
                },
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? _kDone : Colors.transparent,
                      border: Border.all(color: accent, width: 2),
                      boxShadow: done
                          ? [
                              BoxShadow(
                                  color: _kDone.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1),
                            ]
                          : null,
                    ),
                    child: AnimatedScale(
                      scale: done ? 1 : 0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 260),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: done ? wp.textDim : wp.textMain,
                    decoration:
                        done ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: _kDone,
                    decorationThickness: 2.2,
                  ),
                  child: Text(note),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                _TodoChip(
                  wp: wp,
                  icon: Icons.hourglass_bottom_rounded,
                  text: 'منتظر جواب',
                  color: _kToday,
                  on: wait,
                  onTap: () {
                    final next = !wait;
                    setFootNoteWaiting(node, jk, next);
                    if (next) HapticFeedback.selectionClick();
                    onChanged();
                  },
                ),
                const SizedBox(width: 8),
                if (!done)
                  Expanded(
                    child: Text('انجامش دادی؟ تیک بزن تا خط بخورد',
                        style: TextStyle(fontSize: 10.5, color: wp.textDim)),
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SizeTransition(sizeFactor: a, child: c),
              ),
              child: !done
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : Container(
                      key: ValueKey(wait ? 'wait' : 'done'),
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: BoxDecoration(
                        color: (wait ? _kToday : _kDone)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: (wait ? _kToday : _kDone)
                                .withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.6,
                                  fontWeight: FontWeight.w800,
                                  color: wp.textMain)),
                          const SizedBox(height: 4),
                          _richFa(wait ? _kWaitWhy : _kDoneWhy,
                              color: wp.textMain.withValues(alpha: 0.85)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoChip extends StatelessWidget {
  const _TodoChip({
    required this.wp,
    required this.icon,
    required this.text,
    required this.color,
    required this.on,
    required this.onTap,
  });

  final WebPalette wp;
  final IconData icon;
  final String text;
  final Color color;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? color.withValues(alpha: 0.16) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: on ? color : wp.textDim.withValues(alpha: 0.35),
              width: on ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: on ? color : wp.textDim),
            const SizedBox(width: 5),
            Text(text,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: on ? color : wp.textMain)),
          ],
        ),
      ),
    );
  }
}
