import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';

// رنگ‌های شیت زمان (روشن — هم‌رنگ Goals Sheet)
const _kCream = Color(0xFFFBF6EA);
const _kCard = Colors.white;
const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kDanger = Color(0xFFE5484D);
const _kLive = Color(0xFFE5484D);

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
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(100),
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

  Future<void> _openAddDialog() async {
    final res = await askDurationTabbed(
      context,
      title: 'ثبت زمان جدید',
      sub: '${widget.dayLabel} · ${widget.node.text.isEmpty ? 'بدون نام' : widget.node.text}',
      defMin: 60,
    );
    if (res == null) return;
    if (res.mins <= 0) return;
    if (res.range != null) {
      addRange(widget.node, widget.jk, res.range!.start, res.range!.end,
          note: res.note);
    } else {
      addDuration(widget.node, widget.jk, res.mins, note: res.note);
    }
    widget.store.changed();
    if (mounted) setState(() {});
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.node.text.isEmpty
                              ? 'بدون نام'
                              : widget.node.text,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _kInk,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.dayLabel,
                          style: const TextStyle(
                              fontSize: 11.5, color: _kMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        const Text('تمام', style: TextStyle(color: _kMuted)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // کارت مجموع
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('⏱ مجموع امروز',
                              style: TextStyle(
                                  fontSize: 12, color: _kMuted)),
                          const SizedBox(height: 4),
                          Text(
                            fmtDur(total),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _kInk,
                            ),
                          ),
                          if (live) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: _kLive,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'در حال ضبط: ${fmtClock(liveSecs)}',
                                  style: const TextStyle(
                                    color: _kLive,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // دکمه‌های اصلی
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _toggle,
                            icon: Icon(live ? Icons.stop : Icons.play_arrow,
                                size: 18),
                            label: Text(live ? 'توقف' : 'شروع تایمر',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            style: FilledButton.styleFrom(
                              backgroundColor: live ? _kLive : _kGold,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _openAddDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('ثبت زمان',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700)),
                            style: FilledButton.styleFrom(
                              backgroundColor: _kGold.withValues(alpha: 0.15),
                              foregroundColor: _kGold,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // لیست ورودی‌ها
                    if (entries.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kBorder),
                        ),
                        child: const Text(
                          'هنوز زمانی برای این روز ثبت نشده.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _kMuted, fontSize: 12.5),
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Text(
                            'ورودی‌های این روز (${toFa(entries.length)})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _kInk,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text('حذف همه',
                                      style: TextStyle(
                                          fontSize: 14, color: _kInk)),
                                  content: const Text(
                                      'همه‌ی زمان‌های این روز حذف بشه؟',
                                      style: TextStyle(color: _kInk)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('نه',
                                          style:
                                              TextStyle(color: _kMuted)),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                          backgroundColor: _kDanger),
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('حذف'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                clearDayTime(widget.node, widget.jk);
                                widget.store.changed();
                                if (mounted) setState(() {});
                              }
                            },
                            icon: const Icon(Icons.delete_sweep,
                                size: 16, color: _kDanger),
                            label: const Text('همه',
                                style: TextStyle(
                                    fontSize: 12, color: _kDanger)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      for (var i = entries.length - 1; i >= 0; i--)
                        _entryTile(entries[i], i),
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

  Widget _entryTile(Map<String, dynamic> e, int idx) {
    final kind = e['kind'] as String?;
    final mins = (e['mins'] as num?)?.toInt() ?? 0;
    final note = e['note'] as String?;

    final label = kind == 'range'
        ? '🕒 ${fmtHM((e['s'] as num?)?.toInt() ?? 0)} تا ${fmtHM((e['e'] as num?)?.toInt() ?? 0)} — ${fmtDur(mins * 60)}'
        : '⏱ ${fmtDur(mins * 60)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: _kInk,
                        fontWeight: FontWeight.w600)),
                if (note != null && note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('📝 $note',
                        style: const TextStyle(
                            fontSize: 11, color: _kMuted)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: _kDanger),
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

// ============================================================
// دیالوگ یکپارچه‌ی ثبت زمان — دو تب
// ============================================================

class _DurResult {
  _DurResult({required this.mins, required this.note, this.range});
  final int mins;
  final String note;
  final _Range? range;
}

class _Range {
  _Range(this.start, this.end);
  final int start; // دقیقه از نیمه‌شب
  final int end;
}

Future<_DurResult?> askDurationTabbed(
  BuildContext context, {
  required String title,
  String? sub,
  int defMin = 60,
  bool allowZero = false,
}) {
  return showDialog<_DurResult>(
    context: context,
    barrierColor: Colors.black.withAlpha(100),
    builder: (_) => _DurationDialog(
      title: title,
      sub: sub,
      defMin: defMin,
      allowZero: allowZero,
    ),
  );
}

class _DurationDialog extends StatefulWidget {
  const _DurationDialog({
    required this.title,
    this.sub,
    required this.defMin,
    required this.allowZero,
  });
  final String title;
  final String? sub;
  final int defMin;
  final bool allowZero;

  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  late final TextEditingController _h;
  late final TextEditingController _m;
  late final TextEditingController _note;
  late final TextEditingController _from;
  late final TextEditingController _to;
  String _mode = 'dur'; // 'dur' | 'range'

  @override
  void initState() {
    super.initState();
    _h = TextEditingController(text: toFa(widget.defMin ~/ 60));
    _m = TextEditingController(text: toFa(widget.defMin % 60));
    _note = TextEditingController();
    final now = DateTime.now();
    final fromH = now.hour.toString().padLeft(2, '0');
    final toH = ((now.hour + 1) % 24).toString().padLeft(2, '0');
    _from = TextEditingController(text: toFa('$fromH:00'));
    _to = TextEditingController(text: toFa('$toH:00'));
  }

  @override
  void dispose() {
    _h.dispose();
    _m.dispose();
    _note.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  int _total() {
    final hh = _pnum(_h.text) ?? 0;
    final mm = _pnum(_m.text) ?? 0;
    return hh.clamp(0, 24) * 60 + mm.clamp(0, 59);
  }

  _Range? _readRange() {
    final a = _parseHM(_from.text);
    final b = _parseHM(_to.text);
    if (a == null || b == null) return null;
    var e = b;
    if (e <= a) e += 1440;
    return _Range(a, e % 1440);
  }

  void _quick(int mins) {
    setState(() {
      _h.text = toFa(mins ~/ 60);
      _m.text = toFa(mins % 60);
    });
  }

  void _submit() {
    if (_mode == 'dur') {
      final t = _total();
      if (t <= 0 && !widget.allowZero) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ساعت یا دقیقه رو وارد کن')),
        );
        return;
      }
      Navigator.pop(
        context,
        _DurResult(mins: t, note: _note.text.trim()),
      );
    } else {
      final r = _readRange();
      if (r == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ساعت شروع و پایان را درست انتخاب کن')),
        );
        return;
      }
      var end = r.end;
      if (end <= r.start) end += 1440;
      final mins = end - r.start;
      if (mins <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مدت باید بیشتر از صفر باشه')),
        );
        return;
      }
      Navigator.pop(
        context,
        _DurResult(mins: mins, note: _note.text.trim(), range: r),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _readRange();
    var rangeLabel = 'ساعت شروع و پایان را انتخاب کن';
    if (range != null) {
      var end = range.end;
      if (end <= range.start) end += 1440;
      rangeLabel = 'مدت: ${fmtDur((end - range.start) * 60)}';
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            if (widget.sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  widget.sub!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: _kMuted),
                ),
              ),
            const SizedBox(height: 14),

            // تب‌ها
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _kCream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  _tabBtn('مدت زمان', 'dur'),
                  const SizedBox(width: 4),
                  _tabBtn('بازه‌ی ساعت (از … تا …)', 'range'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // بدنه
            if (_mode == 'dur') ...[
              Row(
                children: [
                  Expanded(
                    child: _numField(_h, 'ساعت', max: 24),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':',
                        style: TextStyle(
                            fontSize: 22,
                            color: _kMuted,
                            fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: _numField(_m, 'دقیقه', max: 59),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _quickChip('۱۵ دقیقه', 15),
                  _quickChip('۳۰ دقیقه', 30),
                  _quickChip('۱ ساعت', 60),
                  _quickChip('۲ ساعت', 120),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _timeField(_from, 'از ساعت'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_back,
                        size: 18, color: _kMuted),
                  ),
                  Expanded(
                    child: _timeField(_to, 'تا ساعت'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                rangeLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: range != null ? _kGold : _kMuted,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // یادداشت
            TextField(
              controller: _note,
              maxLines: 2,
              maxLength: 200,
              style: const TextStyle(fontSize: 12.5, color: _kInk),
              decoration: InputDecoration(
                hintText: 'یادداشت (اختیاری) — مثلاً چه کاری انجام دادی؟',
                hintStyle:
                    const TextStyle(color: _kMuted, fontSize: 12),
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kGold, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // دکمه‌ها
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kMuted,
                      side: const BorderSide(color: _kBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('لغو'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _submit,
                    child: const Text('ثبت',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String label, String key) {
    final on = _mode == key;
    return Expanded(
      child: Material(
        color: on ? _kGold : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => setState(() => _mode = key),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? Colors.white : _kMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, {int? max}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: _kInk,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11.5, color: _kMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kGold, width: 1.5),
        ),
      ),
    );
  }

  Widget _timeField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.datetime,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _kInk,
        letterSpacing: 0.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11.5, color: _kMuted),
        hintText: '09:30',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kGold, width: 1.5),
        ),
      ),
    );
  }

  Widget _quickChip(String label, int mins) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _quick(mins),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kBorder),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: _kInk),
          ),
        ),
      ),
    );
  }
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
