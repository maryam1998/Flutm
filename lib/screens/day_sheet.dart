import 'package:flutter/material.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';
import 'time_sheet.dart';

const _kCream = Color(0xFFFBF6EA);
const _kCard = Colors.white;
const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kDanger = Color(0xFFE5484D);

/// شیت جزئیات یک روز از تقویم جلالی
Future<void> showDaySheet(
  BuildContext context, {
  required MapStore store,
  required MapHost host,
  required ActionNode node,
  required DateTime date,
  required Color accent,
}) {
  final jk = jKey(date);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _DaySheet(
      store: store,
      host: host,
      node: node,
      date: date,
      jk: jk,
      accent: accent,
    ),
  );
}

class _DaySheet extends StatefulWidget {
  const _DaySheet({
    required this.store,
    required this.host,
    required this.node,
    required this.date,
    required this.jk,
    required this.accent,
  });
  final MapStore store;
  final MapHost host;
  final ActionNode node;
  final DateTime date;
  final String jk;
  final Color accent;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  String get _jLabel {
    final j = toJalaali(
        widget.date.year, widget.date.month, widget.date.day);
    return '${toFa(j.jd)} ${kJalaliMonths[j.jm - 1]}';
  }

  bool get _done => truthy(widget.node.logs[widget.jk]);

  String? get _dayNote {
    final v = widget.node.logs[widget.jk];
    if (v is String && v != 'انجام شد ✓' && v.isNotEmpty) return v;
    return null;
  }

  Future<void> _toggle() async {
    // همون toggleLog موجود
    if (_done) {
      widget.node.logs.remove(widget.jk);
      // اگه یادداشت خاصی داشت، توی نسخه‌ی جدید حذف نمی‌کنیم — کاربر خودش می‌تونه پاک کنه
    } else {
      widget.node.logs[widget.jk] = 'انجام شد ✓';
      widget.host.lastActivity = DateTime.now().millisecondsSinceEpoch;
    }
    widget.store.changed();
    if (mounted) setState(() {});
  }

  Future<void> _editDayNote() async {
    final c = TextEditingController(text: _dayNote ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('یادداشت این روز',
            style: TextStyle(fontSize: 15, color: _kInk)),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          style: const TextStyle(color: _kInk),
          decoration: InputDecoration(
            hintText: 'مثلاً: امروز عالی بود، ۲ ساعت پادکست گوش دادم',
            hintStyle: const TextStyle(color: _kMuted, fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لغو', style: TextStyle(color: _kMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    c.dispose();
    if (res == null) return;
    if (res.isEmpty) {
      widget.node.logs[widget.jk] = 'انجام شد ✓';
    } else {
      widget.node.logs[widget.jk] = res;
    }
    widget.store.changed();
    if (mounted) setState(() {});
  }

  Future<void> _addTime() async {
    final res = await askDurationTabbed(
      context,
      title: 'ثبت زمان جدید',
      sub: '$_jLabel · ${widget.node.text.isEmpty ? 'بدون نام' : widget.node.text}',
      defMin: 60,
    );
    if (res == null || res.mins <= 0) return;
    if (res.range != null) {
      addRange(widget.node, widget.jk, res.range!.start, res.range!.end,
          note: res.note);
    } else {
      addDuration(widget.node, widget.jk, res.mins, note: res.note);
    }
    // اگه قبلاً تیک نخورده بود، تیک بخوره
    if (!_done) widget.node.logs[widget.jk] = 'انجام شد ✓';
    widget.store.changed();
    if (mounted) setState(() {});
  }

  Future<void> _editEntryNote(int idx, Map<String, dynamic> e) async {
    final c = TextEditingController(text: (e['note'] as String?) ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('یادداشت ورودی',
            style: TextStyle(fontSize: 15, color: _kInk)),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          style: const TextStyle(color: _kInk),
          decoration: InputDecoration(
            hintText: 'مثلاً: چه کاری انجام دادی؟',
            hintStyle: const TextStyle(color: _kMuted, fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لغو', style: TextStyle(color: _kMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    c.dispose();
    if (res == null) return;
    final raw = widget.node.entries[widget.jk];
    if (raw is List && idx < raw.length) {
      final entry = raw[idx];
      if (entry is Map) {
        if (res.isEmpty) {
          entry.remove('note');
        } else {
          entry['note'] = res;
        }
      }
    }
    widget.store.changed();
    if (mounted) setState(() {});
  }

  void _deleteEntry(int idx) {
    deleteEntry(widget.node, widget.jk, idx);
    // اگه هیچ ورودی یا تیکی نموند، تیک رو نگه می‌داریم ولی اگه کاربر بخواد خودش حذف می‌کنه
    widget.store.changed();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entries = nodeEntries(widget.node, widget.jk);
    final total = nodeDaySecs(widget.node, widget.jk);
    final isToday = _isToday();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
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
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _jLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _kInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.node.text.isEmpty
                              ? 'بدون نام'
                              : widget.node.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: _kMuted),
                        ),
                      ],
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'امروز',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _kGold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        const Text('بستن', style: TextStyle(color: _kMuted)),
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
                    // ---------- تیک روز ----------
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _toggle,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _done
                              ? widget.accent.withValues(alpha: 0.10)
                              : _kCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _done ? widget.accent : _kBorder,
                            width: _done ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _done
                                    ? widget.accent
                                    : Colors.transparent,
                                border: Border.all(
                                    color: widget.accent, width: 2),
                              ),
                              child: _done
                                  ? const Icon(Icons.check,
                                      size: 18, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _done
                                        ? 'این روز انجام شد'
                                        : 'این روز انجام نشد',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: _kInk,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'برای تغییر تیک، این کارت را بزن',
                                    style: TextStyle(
                                        fontSize: 11, color: _kMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ---------- یادداشت روز ----------
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _editDayNote,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes,
                                size: 18, color: _kMuted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('یادداشت روز',
                                      style: TextStyle(
                                          fontSize: 12, color: _kMuted)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _dayNote ?? 'برای نوشتن یادداشت اینجا بزن...',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: _dayNote != null
                                          ? _kInk
                                          : _kMuted,
                                      height: 1.6,
                                      fontStyle: _dayNote != null
                                          ? FontStyle.normal
                                          : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_outlined,
                                size: 14, color: _kMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ---------- زمان‌ها ----------
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 16, color: _kInk),
                        const SizedBox(width: 6),
                        const Text(
                          'زمان‌های این روز',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _kInk),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${fmtDur(total)}',
                          style: const TextStyle(
                              fontSize: 11.5, color: _kMuted),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addTime,
                          icon: const Icon(Icons.add,
                              size: 16, color: _kGold),
                          label: const Text('افزودن زمان',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _kGold,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (entries.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
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
                    else
                      for (var i = entries.length - 1; i >= 0; i--)
                        _entryTile(entries[i], i),

                    const SizedBox(height: 12),
                    // ---------- ورودی‌های دوره (اگه بخوای) ----------
                    if (total > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'مجموع این روز: ${fmtDur(total)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _kInk,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday() {
    final n = DateTime.now();
    return widget.date.year == n.year &&
        widget.date.month == n.month &&
        widget.date.day == n.day;
  }

  Widget _entryTile(Map<String, dynamic> e, int idx) {
    final kind = e['kind'] as String?;
    final mins = (e['mins'] as num?)?.toInt() ?? 0;
    final note = (e['note'] as String? ?? '').trim();

    final label = kind == 'range'
        ? '🕒 ${fmtHM((e['s'] as num?)?.toInt() ?? 0)} تا ${fmtHM((e['e'] as num?)?.toInt() ?? 0)} — ${fmtDur(mins * 60)}'
        : '⏱ ${fmtDur(mins * 60)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
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
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: _kInk,
                      fontWeight: FontWeight.w600),
                ),
                if (note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('📝 $note',
                        style: const TextStyle(
                            fontSize: 11, color: _kMuted, height: 1.5)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 16, color: _kMuted),
            tooltip: 'ویرایش یادداشت',
            onPressed: () => _editEntryNote(idx, e),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: _kDanger),
            tooltip: 'حذف',
            onPressed: () => _deleteEntry(idx),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
        ],
      ),
    );
  }
}
