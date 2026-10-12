import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';

/// پنل پایین‌روی ثبت زمان برای یک شاخه در یک روز مشخص
Future<void> showTimeSheet(
  BuildContext context, {
  required MapStore store,
  required MapHost host,
  required ActionNode node,
  required String jk,
  required String dayLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF14172F),
    builder: (_) => _TimeSheet(
      store: store,
      host: host,
      node: node,
      jk: jk,
      dayLabel: dayLabel,
    ),
  );
}

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({
    required this.store,
    required this.host,
    required this.node,
    required this.jk,
    required this.dayLabel,
  });

  final MapStore store;
  final MapHost host;
  final ActionNode node;
  final String jk;
  final String dayLabel;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // هر ثانیه رفرش، برای وقتی تایمر فعاله
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (timerRunning(widget.node) && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int _elapsedLive() {
    if (!timerRunning(widget.node)) return 0;
    final start =
        DateTime.fromMillisecondsSinceEpoch(widget.node.timerStart!);
    return DateTime.now().difference(start).inSeconds;
  }

  Future<void> _addManual() async {
    final res = await _askDuration(context, def: 60);
    if (res == null || res.mins <= 0) return;
    addDuration(widget.node, widget.jk, res.mins, note: res.note);
    widget.store.changed();
    setState(() {});
  }

  Future<void> _addRange() async {
    final res = await _askRange(context);
    if (res == null) return;
    addRange(widget.node, widget.jk, res.start, res.end, note: res.note);
    widget.store.changed();
    setState(() {});
  }

  void _toggle() {
    if (timerRunning(widget.node)) {
      stopTimer(widget.node);
    } else {
      startTimer(widget.node);
    }
    widget.store.changed();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final total = nodeDaySecs(widget.node, widget.jk);
    final entries = nodeEntries(widget.node, widget.jk);
    final live = timerRunning(widget.node);
    final liveSecs = _elapsedLive();

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.node.text.isEmpty
                          ? 'بدون نام'
                          : widget.node.text,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('تمام'),
                  ),
                ],
              ),
              Text(widget.dayLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 14),

              // نمایش مجموع
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⏱ مجموع امروز',
                        style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(fmtDur(total),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    if (live) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.fiber_manual_record,
                              size: 12, color: Color(0xFFE5484D)),
                          const SizedBox(width: 6),
                          Text('در حال ضبط: ${fmtClock(liveSecs)}',
                              style: const TextStyle(
                                  color: Color(0xFFE5484D),
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // دکمه‌ها
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _toggle,
                      icon: Icon(live ? Icons.stop : Icons.play_arrow),
                      label: Text(live ? 'توقف' : 'شروع تایمر'),
                      style: FilledButton.styleFrom(
                        backgroundColor: live
                            ? const Color(0xFFE5484D)
                            : const Color(0xFF5EC8F0),
                        foregroundColor:
                            live ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _addManual,
                      icon: const Icon(Icons.timer_outlined),
                      label: const Text('مدت دستی'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addRange,
                  icon: const Icon(Icons.schedule),
                  label: const Text('ثبت بازه‌ی ساعت (از … تا …)'),
                ),
              ),
              const SizedBox(height: 16),

              // لیست ورودی‌ها
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('هنوز زمانی برای این روز ثبت نشده.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54)),
                )
              else ...[
                Row(
                  children: [
                    const Text('ورودی‌های این روز',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('حذف همه'),
                            content: const Text(
                                'همه‌ی زمان‌های این روز حذف بشه؟'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('نه')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('حذف')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          clearDayTime(widget.node, widget.jk);
                          widget.store.changed();
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: const Text('همه'),
                    ),
                  ],
                ),
                for (var i = entries.length - 1; i >= 0; i--)
                  _entryTile(entries[i], i),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _entryTile(Map<String, dynamic> e, int idx) {
    final kind = e['kind'] as String?;
    final mins = (e['mins'] as num?)?.toInt() ?? 0;
    final note = e['note'] as String?;

    final label = kind == 'range'
        ? '🕒 ${fmtHM((e['s'] as num?)?.toInt() ?? 0)} تا ${fmtHM((e['e'] as num?)?.toInt() ?? 0)}'
        : '⏱ ${fmtDur(mins * 60)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (note != null && note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('📝 $note',
                        style: const TextStyle(
                            fontSize: 11.5, color: Colors.white60)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              deleteEntry(widget.node, widget.jk, idx);
              widget.store.changed();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ دیالوگ‌ها

class _DurRes {
  _DurRes(this.mins, this.note);
  final int mins;
  final String note;
}

class _RangeRes {
  _RangeRes(this.start, this.end, this.note);
  final int start; // دقیقه از نیمه‌شب
  final int end;
  final String note;
}

Future<_DurRes?> _askDuration(BuildContext context, {required int def}) async {
  final h = TextEditingController(text: toFa(def ~/ 60));
  final m = TextEditingController(text: toFa(def % 60));
  final note = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ثبت مدت زمان'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: h,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'ساعت',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(':', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: m,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'دقیقه',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: note,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'یادداشت (اختیاری)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لغو')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ثبت')),
      ],
    ),
  );
  final hh = _pnum(h.text) ?? 0;
  final mm = _pnum(m.text) ?? 0;
  final out = _DurRes(hh * 60 + mm, note.text.trim());
  h.dispose();
  m.dispose();
  note.dispose();
  return ok == true ? out : null;
}

Future<_RangeRes?> _askRange(BuildContext context) async {
  final now = DateTime.now();
  final f = TextEditingController(
      text: toFa('${now.hour.toString().padLeft(2, '0')}:00'));
  final t = TextEditingController(
      text: toFa('${((now.hour + 1) % 24).toString().padLeft(2, '0')}:00'));
  final note = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ثبت بازه‌ی ساعت'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: f,
            autofocus: true,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'از ساعت (مثلاً 09:30)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: t,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'تا ساعت (مثلاً 11:15)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: note,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'یادداشت (اختیاری)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لغو')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ثبت')),
      ],
    ),
  );
  final s = _parseHM(f.text);
  final e = _parseHM(t.text);
  final r = _RangeRes(s ?? 0, e ?? 0, note.text.trim());
  f.dispose();
  t.dispose();
  note.dispose();
  if (ok != true || s == null || e == null) return null;
  if (s == e) return null;
  return r;
}

int? _pnum(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹', ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    var i = fa.indexOf(ch);
    if (i < 0) i = ar.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return int.tryParse(b.toString().trim());
}

int? _parseHM(String s) {
  final m = RegExp(r'^\s*(\d{1,2})\s*:\s*(\d{1,2})\s*$').firstMatch(s);
  if (m == null) return null;
  final h = _pnum(m.group(1)!) ?? 0;
  final mi = _pnum(m.group(2)!) ?? 0;
  if (h < 0 || h > 23 || mi < 0 || mi > 59) return null;
  return h * 60 + mi;
}
