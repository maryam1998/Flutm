import 'dart:async';

import 'package:flutter/material.dart' hide showDialog, showModalBottomSheet;
import '../widgets/dark_dialogs.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart' show nodeFinished;
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';
import '../services/quiet_snack.dart';
import '../services/reminder_notify.dart';

// رنگ‌های شیت زمان (روشن — هم‌رنگ Goals Sheet)
const _kCream = Color(0xFFFFFFFF);
const _kCard = Colors.white;
const _kGold = Color(0xFF1E9E6A); // سبز: دکمه‌ها و رنگِ تاییدِ تایمر/ثبت زمان
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF5B5F77);
const _kBorder = Color(0xFFE4E6EE);
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
  Timer? _noteSave;
  late final TextEditingController _timerNote;

  @override
  void initState() {
    super.initState();
    final tn = widget.node.extra['timerNote'];
    _timerNote = TextEditingController(text: tn is String ? tn : '');
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (timerRunning(widget.node) && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _noteSave?.cancel();
    _storeTimerNote(notify: false);
    _timerNote.dispose();
    super.dispose();
  }

  /// یادداشتِ تایمرِ در حال اجرا (تا لحظه‌ی توقف نگه داشته می‌شود)
  void _storeTimerNote({bool notify = true}) {
    if (!timerRunning(widget.node)) return;
    final t = _timerNote.text.trim();
    final cur = widget.node.extra['timerNote'];
    if (t.isEmpty) {
      if (cur == null) return;
      widget.node.extra.remove('timerNote');
    } else {
      if (cur == t) return;
      widget.node.extra['timerNote'] = t;
    }
    if (notify) {
      widget.store.changed();
    } else {
      Future.microtask(widget.store.changed);
    }
  }

  void _onTimerNoteChanged(String _) {
    _noteSave?.cancel();
    _noteSave = Timer(const Duration(milliseconds: 600), _storeTimerNote);
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
    // ثبت زمان (حتی فقط بازه‌ی ساعت) = آن روز انجام شده
    widget.store.markDoneByTime(widget.host, widget.node, widget.jk);
    if (mounted) setState(() {});
  }

  /// تایمرِ روشن را کم/زیاد می‌کند (اگر فراموش کرده‌ای خاموشش کنی)
  void _shiftTimer(int mins) {
    final n = widget.node;
    if (!timerRunning(n)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    var ns = n.timerStart! - mins * 60000;
    if (ns > now) ns = now; // زمانِ سپری‌شده منفی نمی‌شود
    n.timerStart = ns;
    widget.store.changedNow();
    if (mounted) setState(() {});
  }

  /// تنظیمِ دقیقِ زمانِ سپری‌شده‌ی تایمر (به دقیقه)
  Future<void> _setElapsed() async {
    if (!timerRunning(widget.node)) return;
    final cur = (_elapsedLive() / 60).round();
    final ctl = TextEditingController(text: '$cur');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('زمانِ تایمر (دقیقه)',
            style: TextStyle(fontSize: 14, color: _kInk)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: _kInk),
          decoration: const InputDecoration(hintText: 'مثلاً ۴۵'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('نه', style: TextStyle(color: _kMuted))),
          FilledButton(
            onPressed: () {
              var t = ctl.text.trim();
              const fa = '۰۱۲۳۴۵۶۷۸۹';
              const ar = '٠١٢٣٤٥٦٧٨٩';
              for (var i = 0; i < 10; i++) {
                t = t.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
              }
              Navigator.pop(ctx, int.tryParse(t));
            },
            child: const Text('تنظیم'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (v == null || v < 0 || !timerRunning(widget.node)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    widget.node.timerStart = now - v * 60000;
    widget.store.changedNow();
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (timerRunning(widget.node)) {
      _noteSave?.cancel();
      _storeTimerNote(notify: false);
      final startJk =
          jKey(DateTime.fromMillisecondsSinceEpoch(widget.node.timerStart!));
      final secs = stopTimer(widget.node);
      if (secs > 0) _timerNote.clear();
      if (secs > 0) {
        widget.store.markDoneByTime(widget.host, widget.node, startJk);
      }
      // ذخیره‌ی فوری تا با بستن/رفتن برنامه چیزی گم نشود
      widget.store.changedNow();
      if (mounted) setState(() {});
      // توقف: کار کلاً تمام شد؟ بله = گل‌ها نمایان می‌شوند، نه = غنچه لابه‌لای برگ‌ها
      if (secs > 0 &&
          mounted &&
          !widget.node.isRoutine &&
          !nodeFinished(widget.node)) {
        final done = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('کارت کلاً تموم شد؟'),
            content: const Text(
                'اگه تموم شده، گل‌ها باز می‌شن 🌸\nاگه نه، غنچه‌ها لابه‌لای برگ‌ها می‌مونن 🌱'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('هنوز نه')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('آره، تموم شد')),
            ],
          ),
        );
        if (done == true) {
          widget.store.toggleFinished(widget.host, widget.node);
          if (mounted) setState(() {});
        }
      }
      return;
    }
    startTimer(widget.node);
    // ذخیره‌ی فوری: تایمر بر پایه‌ی ساعتِ واقعی است و با بیرون رفتن از برنامه هم ادامه دارد
    widget.store.changedNow();
    // برای اعلانِ «تایمر در حال اجراست» وقتی برنامه در پس‌زمینه است
    if (notifySupported() && notifyPermission() == 'default') {
      requestNotifyPermission();
    }
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
                            const SizedBox(height: 8),
                            // ویرایشِ تایمرِ در حال اجرا: کم/زیاد کردن یا تنظیمِ دقیق
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final d in const [-10, -5, -1, 1, 5, 10])
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                        '${d > 0 ? '+' : '−'}${toFa(d.abs())}',
                                        style: const TextStyle(fontSize: 12)),
                                    onPressed: () => _shiftTimer(d),
                                  ),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.edit, size: 14),
                                  label: const Text('تنظیم دقیق',
                                      style: TextStyle(fontSize: 12)),
                                  onPressed: _setElapsed,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // یادداشتِ همین تایمر: با توقف به ورودیِ زمان و تقویمِ اهداف وصل می‌شود
                            TextField(
                              controller: _timerNote,
                              onChanged: _onTimerNoteChanged,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              style: const TextStyle(
                                  fontSize: 13, color: _kInk),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'یادداشت: توی این زمان چکار می‌کنی؟',
                                hintStyle: const TextStyle(
                                    fontSize: 12.5, color: _kMuted),
                                prefixIcon: const Icon(
                                    Icons.edit_note_rounded,
                                    size: 20,
                                    color: _kMuted),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: _kBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: _kBorder),
                                ),
                              ),
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
                        const SizedBox(width: 8),
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
                    ..._historySection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// تاریخچه‌ی زمان‌ها و یادداشت‌های روزهای دیگرِ همین شاخه (جدیدترین اول)
  /// تا ببینی هر بار چه کار کرده‌ای؛ فقط خواندنی (ویرایش از خودِ همان روز)
  List<Widget> _historySection() {
    final node = widget.node;
    int keyNum(String k) {
      final p = k.split('-').map((x) => int.tryParse(x) ?? 0).toList();
      return p.length == 3 ? p[0] * 10000 + p[1] * 100 + p[2] : 0;
    }

    final days = node.entries.keys
        .where((k) => k != widget.jk && nodeEntries(node, k).isNotEmpty)
        .toList()
      ..sort((a, b) => keyNum(b).compareTo(keyNum(a)));
    if (days.isEmpty) return const [];
    String dayText(String k) {
      final p = k.split('-');
      return p.length == 3 ? toFa('${p[0]}/${p[1]}/${p[2]}') : k;
    }

    final out = <Widget>[
      const SizedBox(height: 14),
      const Text('📜 تاریخچه‌ی زمان‌ها و یادداشت‌ها',
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13, color: _kInk)),
      const SizedBox(height: 6),
    ];
    for (final k in days.take(40)) {
      final list = nodeEntries(node, k);
      var tot = 0;
      for (final e in list) {
        final s = (e['secs'] as num?)?.toInt();
        tot += (e['kind'] != 'range' && s != null)
            ? s
            : ((e['mins'] as num?)?.toInt() ?? 0) * 60;
      }
      out.add(Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(dayText(k),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _kInk)),
                const Spacer(),
                Text(fmtDur(tot),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kGold)),
              ],
            ),
            for (final e in list) ...[
              const SizedBox(height: 6),
              Text(
                () {
                  final s = (e['secs'] as num?)?.toInt();
                  final m = (e['mins'] as num?)?.toInt() ?? 0;
                  final d = fmtDur(e['kind'] != 'range' && s != null
                      ? s
                      : m * 60);
                  return e['kind'] == 'range'
                      ? '🕒 ${fmtHM((e['s'] as num?)?.toInt() ?? 0)} تا ${fmtHM((e['e'] as num?)?.toInt() ?? 0)} — $d'
                      : '⏱ $d';
                }(),
                style: const TextStyle(
                    fontSize: 12, color: _kInk, fontWeight: FontWeight.w600),
              ),
              if (((e['note'] as String?) ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(((e['note'] as String)).trim(),
                      style: const TextStyle(
                          fontSize: 12, color: _kMuted, height: 1.6)),
                ),
            ],
          ],
        ),
      ));
    }
    return out;
  }

  Widget _entryTile(Map<String, dynamic> e, int idx) {
    final kind = e['kind'] as String?;
    final mins = (e['mins'] as num?)?.toInt() ?? 0;
    final note = e['note'] as String?;

    final secs = (e['secs'] as num?)?.toInt();
    final dur = fmtDur(kind != 'range' && secs != null ? secs : mins * 60);
    final label = kind == 'range'
        ? '🕒 ${fmtHM((e['s'] as num?)?.toInt() ?? 0)} تا ${fmtHM((e['e'] as num?)?.toInt() ?? 0)} — $dur'
        : '⏱ $dur';

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
                // یادداشتِ زیرِ هر ورودی (هم‌زمان در تقویمِ اهداف دیده می‌شود)
                _EntryNoteField(
                  key: ValueKey(e['at'] == null
                      ? '${widget.jk}|i$idx'
                      : '${widget.jk}|${e['at']}|${e['mins']}'),
                  initial: note ?? '',
                  onSave: (t) {
                    setEntryNote(widget.node, widget.jk, idx, t);
                    widget.store.changed();
                  },
                  onSaveQuiet: (t) {
                    setEntryNote(widget.node, widget.jk, idx, t);
                    Future.microtask(widget.store.changed);
                  },
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

/// کادرِ یادداشتِ زیرِ هر ورودیِ زمان (ذخیره‌ی خودکار)
class _EntryNoteField extends StatefulWidget {
  const _EntryNoteField({
    super.key,
    required this.initial,
    required this.onSave,
    required this.onSaveQuiet,
  });

  final String initial;
  final void Function(String text) onSave;
  final void Function(String text) onSaveQuiet;

  @override
  State<_EntryNoteField> createState() => _EntryNoteFieldState();
}

class _EntryNoteFieldState extends State<_EntryNoteField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);
  Timer? _t;
  String _saved = '';

  @override
  void initState() {
    super.initState();
    _saved = widget.initial.trim();
  }

  @override
  void dispose() {
    _t?.cancel();
    final v = _c.text.trim();
    if (v != _saved) widget.onSaveQuiet(v);
    _c.dispose();
    super.dispose();
  }

  void _flush() {
    _t?.cancel();
    final v = _c.text.trim();
    if (v == _saved) return;
    _saved = v;
    widget.onSave(v);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: _c,
        onChanged: (_) {
          _t?.cancel();
          _t = Timer(const Duration(milliseconds: 700), _flush);
        },
        onSubmitted: (_) => _flush(),
        onTapOutside: (_) => _flush(),
        minLines: 1,
        maxLines: 4,
        style: const TextStyle(fontSize: 12, color: _kInk),
        decoration: InputDecoration(
          isDense: true,
          hintText: '📝 یادداشت: توی این زمان چکار کردی؟',
          hintStyle: const TextStyle(fontSize: 11.5, color: _kMuted),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _kBorder),
          ),
        ),
      ),
    );
  }
}

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
        ScaffoldMessenger.of(context).quietSnack(
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
        ScaffoldMessenger.of(context).quietSnack(
          const SnackBar(content: Text('ساعت شروع و پایان را درست انتخاب کن')),
        );
        return;
      }
      var end = r.end;
      if (end <= r.start) end += 1440;
      final mins = end - r.start;
      if (mins <= 0) {
        ScaffoldMessenger.of(context).quietSnack(
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

  /// باز کردنِ ساعتِ انتخاب (۲۴ ساعته) برای فیلدِ «از ساعت / تا ساعت»
  Future<void> _pickTime(TextEditingController c) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final cur = _parseHM(c.text) ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    setState(() => c.text = toFa('$hh:$mm'));
  }

  Widget _timeField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      readOnly: true,
      showCursor: false,
      onTap: () => _pickTime(c),
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
