import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/abundance_models.dart';
import '../models/emotion.dart';
import '../models/gratitude_entry.dart';
import '../models/jalali.dart';
import '../state/abundance_store.dart';
import '../state/beliefs_store.dart';
import '../state/gratitude_store.dart';
import '../utils/money_format.dart';
import 'format_bar.dart';
import 'grat_media.dart' show gratImageFromSrc;

/// نوع تقویم ماهانه (openBankCalendar(kind) وب)
enum BankCalKind { shop, beliefs, tracking }

const _kEmerald700 = Color(0xFF0F5B53);
const _kInkSoft = Color(0xFF3D5551);
const _kAccent = Color(0xFFF4C542);
const _kWeekdays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

/// تقویم ماهانه‌ی مشترک (مودال #bank-cal-modal وب):
/// شبکه‌ی ماهانه + نقطه روی روزهای ثبت‌شده + جزئیات روز با لمس.
/// خوندنِ همه‌ی ثبت‌ها از استورها — شکرگذاری، خرید، متن آینده، ردیابی، تصویرسازی، حس‌ها.
class BankCalendarSheet extends StatefulWidget {
  final BankCalKind kind;
  final GratitudeStore gratitude;
  final BeliefsStore beliefs;
  final AbundanceStore abundance;

  const BankCalendarSheet({
    super.key,
    required this.kind,
    required this.gratitude,
    required this.beliefs,
    required this.abundance,
  });

  /// معادل openBankCalendar(kind)
  static Future<void> show(BuildContext context, BankCalKind kind) {
    final g = context.read<GratitudeStore>();
    final b = context.read<BeliefsStore>();
    final a = context.read<AbundanceStore>();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => BankCalendarSheet(
        kind: kind,
        gratitude: g,
        beliefs: b,
        abundance: a,
      ),
    );
  }

  @override
  State<BankCalendarSheet> createState() => _BankCalendarSheetState();
}

class _BankCalendarSheetState extends State<BankCalendarSheet> {
  late DateTime _cursor;
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _cursor = DateTime(n.year, n.month, 1);
  }

  String get _title {
    switch (widget.kind) {
      case BankCalKind.shop:
        return '📅 تقویم بازی فراوانی';
      case BankCalKind.beliefs:
        return '📅 تقویم خواندن متن آینده';
      case BankCalKind.tracking:
        return '📅 تقویم ردیابی';
    }
  }

  void _nav(int delta) {
    setState(() {
      _cursor = DateTime(_cursor.year, _cursor.month + delta, 1);
      _selectedKey = null; // مثل وب: با عوض‌شدن ماه جزئیات پاک می‌شه
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: kBeliefsCard,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: ListenableBuilder(
            listenable: Listenable.merge(
                [widget.gratitude, widget.beliefs, widget.abundance]),
            builder: (context, _) => _content(),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final idx = _Index.build(widget.gratitude, widget.beliefs, widget.abundance);
    final y = _cursor.year, m = _cursor.month;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    // ستون اول = شنبه (هم‌راستا با هدر ش ی د س چ پ ج)
    final startCol = (DateTime(y, m, 1).weekday + 1) % 7;
    final todayKey = _norm(DateTime.now());

    final jc = toJalaali(y, m, 1);
    final monthLabel = '${kJalaliMonths[jc.jm - 1]} ${toFaDigits('${jc.jy}')}';

    final cells = <Widget>[];
    for (var i = 0; i < startCol; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(y, m, d);
      final key = _norm(date);
      final has = idx.hasAny(key, widget.beliefs, widget.gratitude);
      final j = toJalaali(y, m, d);
      cells.add(_cell(
        label: toFaDigits('${j.jd}'),
        has: has,
        isToday: key == todayKey,
        onTap: () => setState(() => _selectedKey = key),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kBeliefsInk)),
              ),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: Center(
                    child: Text('✕',
                        style: TextStyle(fontSize: 16, color: kBeliefsMuted)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navBtn('‹', () => _nav(-1)),
              Text(monthLabel,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kBeliefsInk)),
              _navBtn('›', () => _nav(1)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final w in _kWeekdays)
                Expanded(
                  child: Center(
                    child: Text(w,
                        style: const TextStyle(
                            fontSize: 10.5, color: kBeliefsMuted)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: cells,
          ),
          if (_selectedKey != null) _dayDetail(_selectedKey!, idx),
        ],
      ),
    );
  }

  Widget _navBtn(String t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kBeliefsCream,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBeliefsBorder),
        ),
        child: Text(t,
            style: const TextStyle(fontSize: 15, color: kBeliefsInk)),
      ),
    );
  }

  Widget _cell({
    required String label,
    required bool has,
    required bool isToday,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: has ? _kAccent.withValues(alpha: 0.14) : kBeliefsCream,
          border: Border.all(color: has ? _kAccent : kBeliefsBorder),
          boxShadow: isToday
              ? const [BoxShadow(color: _kAccent, spreadRadius: 1.5)]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: kBeliefsInk)),
            if (has)
              Positioned(
                bottom: 3,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                      color: _kAccent, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ جزئیات روز (showBankCalDay) ═══════════════
  Widget _dayDetail(String key, _Index idx) {
    final groups = <Widget>[];

    // 💗 حس‌ها
    final emoRows = idx.emotionRows(key, widget.beliefs, widget.gratitude);
    if (emoRows.isNotEmpty) {
      groups.add(_group('💗 حس‌های قبل و بعد از تمرین', [
        for (final r in emoRows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBeliefsBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💗 ${r.label}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: kBeliefsInk)),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('بعد: ',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: kBeliefsInk)),
                    for (final id in r.ids) _emoChip(id),
                  ],
                ),
              ],
            ),
          ),
      ]));
    }

    // 🙏 شکرگذاری
    final grats = idx.gratitudeByDay[key] ?? const <GratitudeEntry>[];
    if (grats.isNotEmpty) {
      groups.add(_group('🙏 شکرگذاری', [
        for (final g in grats)
          _row([
            if (g.time.isNotEmpty)
              Text(g.time,
                  style:
                      const TextStyle(fontSize: 11, color: kBeliefsMuted)),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${g.icon.isNotEmpty ? '${g.icon} ' : ''}${g.text}',
                style: const TextStyle(fontSize: 12.5, color: kBeliefsInk),
              ),
            ),
            if (g.amount != null && g.amount! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(formatMoney(g.amount!),
                    style: const TextStyle(
                        fontSize: 11, color: _kEmerald700)),
              ),
            if (g.shared)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('🌍 با دوستان هم‌فرکانسی به اشتراک گذاشته شد',
                    style: TextStyle(fontSize: 10.5, color: _kEmerald700)),
              ),
          ]),
      ]));
    }

    // 🛍️ خرید
    final buys = idx.shopByDay[key] ?? const [];
    if (buys.isNotEmpty) {
      groups.add(_group('🛍️ خریدهای فراوانی', [
        for (final h in buys)
          _row([
            if (h.time.isNotEmpty)
              Text(h.time,
                  style:
                      const TextStyle(fontSize: 11, color: kBeliefsMuted)),
            for (final it in h.items)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text:
                          '${it.icon.isNotEmpty ? it.icon : '🛍️'} ${it.name} ',
                      style: const TextStyle(
                          fontSize: 12.5, color: kBeliefsInk)),
                  TextSpan(
                      text: '— ${formatMoney(it.qty * it.price)}',
                      style: const TextStyle(
                          fontSize: 12.5, color: _kEmerald700)),
                ])),
              ),
          ]),
      ]));
    }

    // 📖 متن آینده
    if (idx.readDays.contains(key)) {
      groups.add(_group('📖 متن آینده', [
        const Text('✅ این روز متن آینده‌ات را خواندی',
            style: TextStyle(fontSize: 12, color: _kInkSoft)),
      ]));
    }

    // 📡 نشانه‌ها
    final signs = idx.signalsByDay[key] ?? const <RasSignal>[];
    if (signs.isNotEmpty) {
      groups.add(_group('📡 نشانه‌هایی که دیدی', [
        for (final t in signs)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBeliefsBorder)),
            ),
            child: Text('🌀 ${t.text}',
                style: const TextStyle(fontSize: 12.5, color: kBeliefsInk)),
          ),
      ]));
    }

    // ✨ تصویرسازی
    final imgs = idx.visualByDay[key] ?? const <GratitudeImage>[];
    if (imgs.isNotEmpty) {
      groups.add(_group('✨ عکس‌های تصویرسازی', [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in imgs)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: kBeliefsBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: gratImageFromSrc(v.src),
                ),
              ),
          ],
        ),
      ]));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: groups.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('چیزی برای این روز ثبت نشده.',
                  style: TextStyle(fontSize: 12, color: kBeliefsMuted)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: groups,
            ),
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kBeliefsInk)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBeliefsBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _emoChip(String id) {
    final e = emotionById(id);
    if (e == null) return const SizedBox.shrink();
    final c = hexToColor(e.color);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 2, 2, 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.33)),
      ),
      child: Text(e.fa, style: TextStyle(fontSize: 10.5, color: c)),
    );
  }
}

// ═══════════════ ایندکس ثبت‌ها بر اساس روز (bankCalEntriesByDay) ═══════════════

String _norm(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _normKey(String k) {
  final p = k.split('-').map((e) => int.tryParse(e) ?? 0).toList();
  if (p.length != 3 || p[0] == 0) return k;
  return '${p[0]}-${p[1].toString().padLeft(2, '0')}-${p[2].toString().padLeft(2, '0')}';
}

class _EmoRow {
  final String label;
  final List<String> ids;
  const _EmoRow(this.label, this.ids);
}

class _Index {
  final Map<String, List<GratitudeEntry>> gratitudeByDay = {};
  final Map<String, List<Purchase>> shopByDay = {};
  final Set<String> readDays = {};
  final Map<String, List<RasSignal>> signalsByDay = {};
  final Map<String, List<GratitudeImage>> visualByDay = {};

  /// ساعتِ ساخت از روی id (۸ کاراکتر اول = میلی‌ثانیه به مبنای ۳۶ + ۵ کاراکتر تصادفی)
  static DateTime? _tsFromId(String id) {
    if (id.length <= 5) return null;
    final ms = int.tryParse(id.substring(0, id.length - 5), radix: 36);
    if (ms == null) return null;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    if (d.year < 2000 || d.year > 2200) return null;
    return d;
  }

  static _Index build(
      GratitudeStore g, BeliefsStore b, AbundanceStore a) {
    final idx = _Index();
    for (final e in g.entries) {
      if (e.source == 'purchase' || e.iso.isEmpty) continue;
      final k = GratitudeStore.isoToKey(e.iso);
      if (k.isEmpty) continue;
      (idx.gratitudeByDay[k] ??= []).add(e);
    }
    for (final h in a.history) {
      if (h.iso.isEmpty) continue;
      final k = GratitudeStore.isoToKey(h.iso);
      if (k.isEmpty) continue;
      (idx.shopByDay[k] ??= []).add(h);
    }
    final v = b.activeVersion;
    if (v != null) {
      for (final k in v.readDays) {
        idx.readDays.add(_normKey(k));
      }
    }
    for (final s in b.rasSignals) {
      (idx.signalsByDay[_norm(s.ts)] ??= []).add(s);
    }
    for (final im in b.visualImages) {
      final d = _tsFromId(im.id);
      if (d == null) continue;
      (idx.visualByDay[_norm(d)] ??= []).add(im);
    }
    return idx;
  }

  List<_EmoRow> emotionRows(String key, BeliefsStore b, GratitudeStore g) {
    final rows = <_EmoRow>[];
    final gIds = g.dayAfter[key];
    if (gIds != null && gIds.isNotEmpty) {
      rows.add(_EmoRow('شکرگذاری', gIds));
    }
    final bIds = b.neural.emotionIdsForDay(key);
    if (bIds.isNotEmpty) rows.add(_EmoRow('تمرین باب پراکتور', bIds.toList()));
    final tIds = b.missionNeural.emotionIdsForDay(key);
    if (tIds.isNotEmpty) rows.add(_EmoRow('ردیابی RAS', tIds.toList()));
    return rows;
  }

  bool hasAny(String key, BeliefsStore b, GratitudeStore g) =>
      (gratitudeByDay[key]?.isNotEmpty ?? false) ||
      (shopByDay[key]?.isNotEmpty ?? false) ||
      readDays.contains(key) ||
      (signalsByDay[key]?.isNotEmpty ?? false) ||
      (visualByDay[key]?.isNotEmpty ?? false) ||
      emotionRows(key, b, g).isNotEmpty;
}
