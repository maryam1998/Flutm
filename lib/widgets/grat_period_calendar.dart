import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/emotion.dart';
import '../models/jalali.dart' as jal;
import '../state/gratitude_store.dart';
import '../theme/grat_palette.dart';

/// تقویم دوره‌ی شکرگذاری — پورت دقیقِ وب:
///   js/tamrin-tab.js        → periodGridHtml / periodInfoHtml / periodPastHtml /
///                              renderGratitudeMiniCal / setGratitudePeriodDays /
///                              startNewGratitudePeriod
///   css/tamrin-and-beliefs.css (#grat-root .mini-cal-*, .cal-finished, #…-mini-cal)
///   css/base-and-map.css    (.btn / .btn.tiny / .btn.gold)
///   beliefs-patch.js        (.mini-cal-day پایه، .selected، حبابِ تاریخ #cal-date-bubble)
///
/// سه جای وب:
///  • home    → #gratitude-mini-cal      (حاشیه‌ی بیرونی 14/18 را صفحه می‌دهد؛ info هم margin:0 18)
///  • history → #hist-gratitude-mini-cal (margin:14px 0 0، info margin:10px 0 0)
///  • bank    → #bank-cal-period-grid    (مثل history)
enum GratCalVariant { home, history, bank }

// ════════════════════════════════════════════════════════════════
//                          ابزارهای مشترک
// ════════════════════════════════════════════════════════════════
class GratCal {
  GratCal._();

  /// MONTH_ORDINALS_FA
  static const monthOrd = [
    'اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم', 'هفتم',
    'هشتم', 'نهم', 'دهم', 'یازدهم', 'دوازدهم',
  ];

  /// نام ماه‌های Intl('fa-IR-u-ca-persian')
  static const jalaliMonths = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  /// نام روزهای Intl (weekday:'long') — ایندکس = DateTime.weekday - 1
  static const weekdays = [
    'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه',
  ];

  /// periodOrdFa
  static String ord(int i) =>
      i >= 0 && i < monthOrd.length ? monthOrd[i] : faNum(i + 1);

  /// ارقام فارسی بدون جداکننده (مثل Intl سال/روز)
  static String toFa(int n) => n.toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
      );

  /// Number.toLocaleString('fa-IR') — با جداکننده‌ی هزارگان «٬»
  static String faNum(int n) {
    final s = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
      b.write(s[i]);
    }
    return toFa2(b.toString());
  }

  static String toFa2(String s) => s.replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
      );

  /// dayKeyFromDate
  static String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// new Date(key + 'T00:00:00')
  static DateTime parseKey(String k) {
    final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
    if (p.length != 3) {
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day);
    }
    return DateTime(p[0], p[1], p[2]);
  }

  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// fmt در periodGridHtml: {day:'numeric', month:'long'} → «۲۵ مهر»
  static String dayMonth(DateTime d) {
    final j = jal.toJalaali(d.year, d.month, d.day);
    return '${toFa(j.jd)} ${jalaliMonths[j.jm - 1]}';
  }

  /// faDate در حباب: «شنبه ۲۵ مهر ۱۴۰۵»
  static String fullDate(DateTime d) {
    final j = jal.toJalaali(d.year, d.month, d.day);
    return '${weekdays[d.weekday - 1]} ${toFa(j.jd)} ${jalaliMonths[j.jm - 1]} ${toFa(j.jy)}';
  }

  /// normalizeDigits
  static String normDigits(String s) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final c in s.split('')) {
      final i = fa.indexOf(c);
      final j = ar.indexOf(c);
      b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : c));
    }
    return b.toString();
  }

  /// periodParseDays(input, Infinity): parseInt(normalizeDigits(input), 10)
  /// (parseInt فقط رقم‌های ابتدای متن را می‌خواند) و فقط n ≥ 1 معتبره.
  static int parseDays(String input) {
    final m = RegExp(r'^\s*([+-]?\d+)').firstMatch(normDigits(input));
    if (m == null) return 0;
    final n = int.tryParse(m.group(1)!) ?? 0;
    return n >= 1 ? n : 0;
  }
}

// ════════════════════════════════════════════════════════════════
//             انتخابِ روز (کلاس .selected) — سراسری مثل وب
// ════════════════════════════════════════════════════════════════
@immutable
class _CalSel {
  final String owner;
  final String key;
  const _CalSel(this.owner, this.key);
  @override
  bool operator ==(Object o) => o is _CalSel && o.owner == owner && o.key == key;
  @override
  int get hashCode => Object.hash(owner, key);
}

/// کلیک روی هر خانه: از همه‌ی خانه‌ها .selected برداشته می‌شه و به همین یکی داده می‌شه
final ValueNotifier<_CalSel?> _calSelection = ValueNotifier<_CalSel?>(null);

// ════════════════════════════════════════════════════════════════
//        حبابِ تاریخ — #cal-date-bubble در beliefs-patch.js
// ════════════════════════════════════════════════════════════════
@immutable
class _BubbleData {
  final bool show;
  final double left, top, width, height, arrowX;
  final bool above;
  final String title, status;
  const _BubbleData({
    required this.show,
    this.left = 0,
    this.top = 0,
    this.width = 0,
    this.height = 0,
    this.arrowX = 0,
    this.above = true,
    this.title = '',
    this.status = '',
  });
  _BubbleData hidden() => _BubbleData(
        show: false,
        left: left,
        top: top,
        width: width,
        height: height,
        arrowX: arrowX,
        above: above,
        title: title,
        status: status,
      );
}

class _CalBubble {
  _CalBubble._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static final ValueNotifier<_BubbleData> _data =
      ValueNotifier<_BubbleData>(const _BubbleData(show: false));

  static const _bg = Color(0xFF12303A); // #12303a

  /// styles مطابق وب: بدنه 12px/700، small 10.5px/600 با opacity .8، line-height 1.7
  static TextStyle _titleStyle(TextStyle base) => base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.7,
        color: Colors.white,
        leadingDistribution: TextLeadingDistribution.even,
        fontFamilyFallback: _withCheck(base),
      );
  static TextStyle _smallStyle(TextStyle base) => base.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        height: 1.7,
        color: Colors.white.withValues(alpha: 0.8),
        leadingDistribution: TextLeadingDistribution.even,
        fontFamilyFallback: _withCheck(base),
      );

  static List<String> _withCheck(TextStyle base) =>
      ['GratCheck', ...?base.fontFamilyFallback];

  static double _textWidth(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout();
    return tp.width;
  }

  static void show(
    BuildContext context, {
    required Rect cell,
    required String title,
    required String status,
  }) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final ts = _titleStyle(base), ss = _smallStyle(base);
    // padding: 7px 11px — width = بلندترین خط + ۲۲ ، height = 12*1.7 + 10.5*1.7 + ۱۴
    final bw =
        (math.max(_textWidth(title, ts), _textWidth(status, ss)) + 22).ceilToDouble();
    final bh = 12 * 1.7 + 10.5 * 1.7 + 14;
    final vw = MediaQuery.of(context).size.width;

    final cx = cell.left + cell.width / 2;
    final left = math.max(8.0, math.min(vw - bw - 8, cx - bw / 2));
    final above = cell.top - bh - 10 >= 8;
    final top = above ? cell.top - bh - 10 : cell.bottom + 10;
    final arrowX = math.max(12.0, math.min(bw - 12, cx - left));

    final data = _BubbleData(
      show: true,
      left: left,
      top: top,
      width: bw,
      height: bh,
      arrowX: arrowX,
      above: above,
      title: title,
      status: status,
    );
    if (_entry == null || !_entry!.mounted) {
      // اولین بار: اول مخفی درج می‌شه تا transition ‎.15s‎ (opacity/translateY) اجرا بشه
      _data.value = data.hidden();
      _ensureEntry(context, base);
      WidgetsBinding.instance.addPostFrameCallback((_) => _data.value = data);
    } else {
      _data.value = data;
    }
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2600), hide);
  }

  static void hide() {
    _timer?.cancel();
    if (_data.value.show) _data.value = _data.value.hidden();
  }

  static void _ensureEntry(BuildContext context, TextStyle base) {
    if (_entry != null && _entry!.mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<_BubbleData>(
        valueListenable: _data,
        builder: (ctx, d, _) {
          final ts = _titleStyle(base), ss = _smallStyle(base);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // کلیک بیرون از خانه‌ها → hideBubble (رویداد از زیرش هم رد می‌شه)
              if (d.show)
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) => hide(),
                  ),
                ),
              Positioned(
                left: d.left,
                top: d.top,
                width: d.width,
                height: d.height,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: d.show ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.ease,
                    child: AnimatedSlide(
                      offset: Offset(0, d.show ? 0 : 4 / math.max(d.height, 1)),
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.ease,
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color.fromRGBO(0, 0, 0, .28),
                                      offset: Offset(0, 6),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 7),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(d.title,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        textAlign: TextAlign.center,
                                        style: ts),
                                    Text(d.status,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        textAlign: TextAlign.center,
                                        style: ss),
                                  ],
                                ),
                              ),
                            ),
                            // :after — مربع ۸×۸ چرخیده ۴۵°
                            Positioned(
                              left: d.arrowX - 4,
                              top: d.above ? null : -4,
                              bottom: d.above ? -4 : null,
                              width: 8,
                              height: 8,
                              child: Transform.rotate(
                                angle: math.pi / 4,
                                child: const ColoredBox(color: _bg),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    overlay.insert(_entry!);
  }
}

// ════════════════════════════════════════════════════════════════
//                  خودِ تقویم (grid + info + دوره‌های قبلی)
// ════════════════════════════════════════════════════════════════
class GratMiniCalendar extends StatefulWidget {
  final GratitudeStore store;
  final GratPalette pal;
  final GratCalVariant variant;
  const GratMiniCalendar({
    super.key,
    required this.store,
    required this.pal,
    this.variant = GratCalVariant.history,
  });

  static String ord(int i) => GratCal.ord(i);

  @override
  State<GratMiniCalendar> createState() => _GratMiniCalendarState();
}

class _GratMiniCalendarState extends State<GratMiniCalendar> {
  late final String _id = 'cal${identityHashCode(this)}';
  ScrollPosition? _pos;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
  }

  @override
  void didUpdateWidget(covariant GratMiniCalendar old) {
    super.didUpdateWidget(old);
    if (old.store != widget.store) {
      old.store.removeListener(_onStore);
      widget.store.addListener(_onStore);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // window.addEventListener('scroll', hideBubble, {capture:true})
    final p = Scrollable.maybeOf(context)?.position;
    if (p != _pos) {
      _pos?.removeListener(_CalBubble.hide);
      _pos = p;
      _pos?.addListener(_CalBubble.hide);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _pos?.removeListener(_CalBubble.hide);
    super.dispose();
  }

  /// با هر رندرِ دوباره‌ی وب (innerHTML) کلاس .selected از بین می‌رفت
  void _onStore() {
    final s = _calSelection.value;
    if (s != null && s.owner.startsWith(_id)) _calSelection.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final pal = widget.pal;
    final home = widget.variant == GratCalVariant.home;

    final start = GratCal.parseKey(store.journeyStart);
    final total = store.journeyDays;
    final today = GratCal.today();
    final doneSet = store.doneDayKeys;

    var doneCount = 0;
    for (var d = 0; d < total; d++) {
      if (doneSet.contains(
          GratCal.key(DateTime(start.year, start.month, start.day + d)))) {
        doneCount++;
      }
    }
    // finished = today >= startDate + totalDays
    final end = DateTime(start.year, start.month, start.day + total);
    final finished = !today.isBefore(end);

    final pastCount = store.pastPeriods.length;

    // فاصله‌ی بالای بلوک info (margin-collapse وب):
    //  home:    info margin 0  → .cal-finished(8)=8  ، دکمه(inline-block 8)=8
    //  history: info margin 10 → .cal-finished(8)=10 ، دکمه = 10 + 8 = 18
    final gapFinished = home ? 8.0 : 10.0;
    final gapButton = home ? 8.0 : 18.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // کارت تقویم: سفید با کادر و سایه‌ی ملایم، سرتیتر پیشرفت، شبکه، راهنما
          Container(
            padding: const EdgeInsets.all(14),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: pal.isDark ? pal.surface : Colors.white,
              border: Border.all(color: pal.panelBorder),
              borderRadius: BorderRadius.circular(18),
              boxShadow: pal.isDark
                  ? null
                  : const [
                      BoxShadow(
                          color: Color(0x0F141832),
                          blurRadius: 12,
                          offset: Offset(0, 3)),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CalHeader(
                  pal: pal,
                  done: math.min(doneCount, total),
                  total: total,
                ),
                const SizedBox(height: 14),
                GratPeriodGrid(
                  pal: pal,
                  store: store,
                  owner: '$_id:main',
                  start: start,
                  total: total,
                  doneSet: doneSet,
                  withEmotions: true,
                ),
                const SizedBox(height: 12),
                _CalLegend(pal: pal),
              ],
            ),
          ),
          if (finished) ...[
            SizedBox(height: gapFinished),
            // .cal-finished
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(230, 205, 142, .25),
                border: Border.all(color: pal.gold300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🎉🥳 دوره‌ی ${GratCal.ord(pastCount)} رو تموم کردی! '
                '${GratCal.faNum(math.min(doneCount, total))} روز از ${GratCal.faNum(total)} روز شکرگذاری کردی.\n'
                'برای ادامه دوره‌ی بعدی رو شروع کن — دوره‌های قبلی همین‌جا می‌مونن.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.8,
                  leadingDistribution: TextLeadingDistribution.even,
                  color: pal.ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _CalBtn(
              pal: pal,
              gold: true,
              label: '▶️ شروع دوره‌ی ${GratCal.ord(pastCount + 1)}',
              onTap: () => _askDays(
                context,
                title: 'دوره‌ی ${GratCal.ord(pastCount + 1)} چند روزه باشه؟',
                initial: total,
                onOk: (n) async {
                  // startNewGratitudePeriod → periodStartNext
                  await store.startNewJourney(days: n);
                  if (context.mounted) {
                    _snack(context,
                        'دوره‌ی ${GratCal.ord(store.pastPeriods.length)} شروع شد 🌱');
                  }
                },
              ),
            ),
          ] else ...[
            SizedBox(height: gapButton),
            _CalBtn(
              pal: pal,
              label: '⚙️ روزهای دوره (الان ${GratCal.faNum(total)} روزه)',
              onTap: () => _askDays(
                context,
                title: 'دوره‌ی ${GratCal.ord(pastCount)} چند روزه باشه؟',
                initial: total,
                onOk: (n) async {
                  // setGratitudePeriodDays: فقط days عوض می‌شه، startDate همون می‌مونه
                  await store.setJourneyDays(n);
                  if (context.mounted) {
                    _snack(context,
                        'دوره روی ${GratCal.faNum(n)} روز تنظیم شد 🌱');
                  }
                },
              ),
            ),
          ],
          // periodPastHtml — از آخرین دوره به اولین
          if (pastCount > 0) ...[
            const SizedBox(height: 10), // .mini-cal-past-list margin-top
            for (var i = pastCount - 1; i >= 0; i--) ...[
              _PastPeriod(
                pal: pal,
                store: store,
                index: i,
                doneSet: doneSet,
                owner: '$_id:past$i',
              ),
              if (i > 0) const SizedBox(height: 6), // gap:6px
            ],
          ],
        ],
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1600),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// window.prompt وب. لغو → هیچ؛ ورودیِ نامعتبر → toast
  static Future<void> _askDays(
    BuildContext context, {
    required String title,
    required int initial,
    required Future<void> Function(int n) onOk,
  }) async {
    final ctrl = TextEditingController(text: '$initial');
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (raw == null) return;
    final n = GratCal.parseDays(raw);
    if (n < 1) {
      if (context.mounted) {
        _snack(context, 'یه عدد معتبر بزرگ‌تر از صفر وارد کن');
      }
      return;
    }
    await onOk(n);
  }
}

// ════════════════════════════════════════════════════════════════
//                 سرتیتر پیشرفت و راهنمای رنگ‌ها
// ════════════════════════════════════════════════════════════════
class _CalHeader extends StatelessWidget {
  final GratPalette pal;
  final int done, total;
  const _CalHeader(
      {required this.pal, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final frac = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final pct = (frac * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: pal.emerald500.withAlpha(36),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.calendar_month_rounded,
                  size: 17, color: pal.emerald500),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text('مسیر شکرگذاری',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: pal.ink)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: pal.emerald500.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${GratCal.faNum(done)} از ${GratCal.faNum(total)} روز',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: pal.isDark ? pal.emerald300 : pal.emerald700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Container(
                      height: 7,
                      color: pal.isDark
                          ? const Color(0xFF333750)
                          : const Color(0xFFE3E6F0),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerRight,
                      widthFactor: frac,
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [pal.emerald500, pal.emerald700]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${GratCal.faNum(pct)}٪',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: pal.textDim)),
          ],
        ),
      ],
    );
  }
}

class _CalLegend extends StatelessWidget {
  final GratPalette pal;
  const _CalLegend({required this.pal});

  Widget _item(Widget swatch, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          swatch,
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 10.5, color: pal.textDim)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final e = _DayPainter.emptyColors(pal);
    Widget box(Color fill, Color border, {double bw = 1.2, Widget? child}) =>
        Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border, width: bw),
          ),
          child: child,
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        _item(
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient:
                  LinearGradient(colors: [pal.emerald700, pal.emerald500]),
            ),
          ),
          'انجام شده',
        ),
        _item(box(e.$1, e.$2), 'ثبت نشده'),
        _item(box(e.$1, pal.accent, bw: 2), 'امروز'),
        _item(
            Opacity(opacity: 0.55, child: box(Colors.transparent, e.$2)),
            'پیش‌رو'),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//                 دکمه‌ی .btn.tiny / .btn.tiny.gold
// ════════════════════════════════════════════════════════════════
class _CalBtn extends StatelessWidget {
  final GratPalette pal;
  final String label;
  final bool gold;
  final VoidCallback onTap;
  const _CalBtn({
    required this.pal,
    required this.label,
    required this.onTap,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    // .btn: bg rgba(255,255,255,.05)، border panel-border، رنگ text-main
    // .btn.gold: bg accent، رنگ #221800، border accent، وزن ۶۰۰
    // .btn.tiny: radius 7 — inline: width:100%; font-size:11.5px; padding:9px
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: gold ? pal.accent : const Color.fromRGBO(255, 255, 255, .05),
          border: Border.all(color: gold ? pal.accent : pal.panelBorder),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: gold ? FontWeight.w600 : FontWeight.w400,
            color: gold ? const Color(0xFF221800) : pal.ink,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//             شبکه‌ی ۱۵ ستونه — periodGridHtml
// ════════════════════════════════════════════════════════════════
class GratPeriodGrid extends StatelessWidget {
  final GratPalette pal;

  /// فقط برای حلقه‌ی رنگ حس (emoPk='gratitude' وب). دوره‌های قبلی null می‌دن.
  final GratitudeStore? store;
  final String owner;
  final DateTime start;
  final int total;
  final Set<String> doneSet;
  final bool withEmotions;

  /// داخل .mini-cal-inner (دوره‌ی قبلی) padding سرتیتر 6/2 است نه 8/3
  final bool inner;

  const GratPeriodGrid({
    super.key,
    required this.pal,
    required this.owner,
    required this.start,
    required this.total,
    required this.doneSet,
    this.store,
    this.withEmotions = false,
    this.inner = false,
  });

  static const cols = 15;
  static const gap = 3.0;
  static const blockSize = 30;

  /// state.practiceEmotions[key].gratitude → قوی‌ترین حس (اولین با freq بیشتر)
  Color? _ringFor(String key, bool done) {
    final st = store;
    if (!withEmotions || st == null) return null;
    Iterable<String> ids = st.dayAfter[key] ?? const <String>[];
    if (ids.isEmpty && done) ids = st.emotionIdsForDay(key);
    final dom = dominantEmotion(ids);
    return dom == null ? null : hexToColor(dom.color);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // grid-template-columns: repeat(15, minmax(0,1fr)); gap:3px
      final cell = (box.maxWidth - gap * (cols - 1)) / cols;
      final today = GratCal.today();
      final todayKey = GratCal.key(today);

      return ValueListenableBuilder<_CalSel?>(
        valueListenable: _calSelection,
        builder: (context, sel, _) {
          final rows = <Widget>[];
          void addRow(Widget w) {
            if (rows.isNotEmpty) rows.add(const SizedBox(height: gap)); // row-gap
            rows.add(w);
          }

          var cur = <Widget>[];
          void flush() {
            if (cur.isEmpty) return;
            final r = cur;
            cur = <Widget>[];
            addRow(Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                for (var i = 0; i < r.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  r[i],
                ],
              ],
            ));
          }

          for (var d = 0; d < total; d++) {
            final date = DateTime(start.year, start.month, start.day + d);
            final key = GratCal.key(date);

            if (d % blockSize == 0) {
              flush();
              final endIdx = math.min(d + blockSize, total) - 1;
              final endDate =
                  DateTime(start.year, start.month, start.day + endIdx);
              // .mini-cal-month: padding 8/2/3 (اولین: top 0) — داخل دوره‌ی قبلی 6/2/2
              final padTop = d == 0 ? 0.0 : (inner ? 6.0 : 8.0);
              final padBottom = inner ? 2.0 : 3.0;
              addRow(Padding(
                padding: EdgeInsets.fromLTRB(2, padTop, 2, padBottom),
                child: Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          width: 3,
                          height: 12,
                          decoration: BoxDecoration(
                            color: pal.gold500,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('ماه ${GratCal.ord(d ~/ blockSize)}',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: pal.ink)),
                      ],
                    ),
                    Text(
                      '${GratCal.dayMonth(date)} تا ${GratCal.dayMonth(endDate)}',
                      style: TextStyle(fontSize: 10.5, color: pal.muted),
                    ),
                  ],
                ),
              ));
            }

            final done = doneSet.contains(key);
            final isToday = key == todayKey;
            final isFuture = date.isAfter(today);
            final monthEnd =
                (d % blockSize) == blockSize - 1 || d == total - 1;
            final selected = sel != null && sel.owner == owner && sel.key == key;

            cur.add(_DayCell(
              index: d + 1,
              pal: pal,
              size: cell,
              date: date,
              dayKey: key,
              done: done,
              today: isToday,
              future: isFuture,
              monthEnd: monthEnd,
              ring: _ringFor(key, done),
              selected: selected,
              owner: owner,
            ));
            if (cur.length == cols) flush();
          }
          flush();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          );
        },
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════
//                     یک روز — .mini-cal-day
// ════════════════════════════════════════════════════════════════
class _DayCell extends StatelessWidget {
  final GratPalette pal;
  final double size;
  final DateTime date;
  final String dayKey;
  final String owner;
  final bool done, today, future, monthEnd, selected;
  final Color? ring;

  /// شماره‌ی روز در دوره (۱ تا total)
  final int index;

  const _DayCell({
    required this.index,
    required this.pal,
    required this.size,
    required this.date,
    required this.dayKey,
    required this.owner,
    required this.done,
    required this.today,
    required this.future,
    required this.monthEnd,
    required this.selected,
    this.ring,
  });

  void _tap(BuildContext context) {
    // کلیک روی .mini-cal-day[data-cal-key]: .selected + حبابِ تاریخ
    _calSelection.value = _CalSel(owner, dayKey);
    var status = future ? 'هنوز نرسیده' : (done ? '✓ ثبت شده' : 'ثبت نشده');
    if (today) status = 'امروز — $status';
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final tl = box.localToGlobal(Offset.zero);
    _CalBubble.show(
      context,
      cell: Rect.fromLTWH(tl.dx, tl.dy, box.size.width, box.size.height),
      title: GratCal.fullDate(date),
      status: status,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(context),
        child: Opacity(
          opacity: future ? 0.6 : 1,
          child: CustomPaint(
            painter: _DayPainter(
              pal: pal,
              done: done,
              today: today,
              monthEnd: monthEnd,
              selected: selected,
              ring: ring,
            ),
            child: Center(
              child: done
                  ? const _CheckGlyph()
                  : Text(
                      GratCal.faNum(index),
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: (size * 0.36).clamp(7.0, 10.0),
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: pal.textDim,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «✓» — font-size:10px; font-weight:800; line-height:1; color:#fff
class _CheckGlyph extends StatelessWidget {
  const _CheckGlyph();
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return Text(
      '✓',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        height: 1,
        color: Colors.white,
        leadingDistribution: TextLeadingDistribution.even,
        fontFamilyFallback: ['GratCheck', ...?base.fontFamilyFallback],
      ),
    );
  }
}

/// رنگ‌آمیزی عین CSS:
///  • پس‌زمینه: surface-2  |  done → gradient(135deg, emerald-700, emerald-500)
///  • box-shadow (فقط یکی برنده است):
///      حلقه‌ی حس (inline) `0 0 0 2px color` ← همه‌ی بقیه را کنار می‌زند
///      month-end         `inset 0 -3px 0 gold-500`
///      done              none
///      پیش‌فرض           `inset 0 0 0 1px line`
///  • outline: today → 1.5px emerald-500 (offset 0) ؛ وگرنه selected → 2px ink (offset 1)
class _DayPainter extends CustomPainter {
  final GratPalette pal;
  final bool done, today, monthEnd, selected;
  final Color? ring;

  _DayPainter({
    required this.pal,
    required this.done,
    required this.today,
    required this.monthEnd,
    required this.selected,
    required this.ring,
  });

  /// (پرکردن, کادر) روزِ ثبت‌نشده — با کنتراست واضح روی کارت سفید/تیره
  static (Color, Color) emptyColors(GratPalette pal) => pal.isDark
      ? (const Color(0xFF282C3B), const Color(0xFF4A5070))
      : (const Color(0xFFEEF0F7), const Color(0xFFC3C8DA));

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    // حلقه‌ی رنگ حس — زیر پس‌زمینه کشیده می‌شود
    if (ring != null) {
      canvas.drawRRect(r.inflate(2), Paint()..color = ring!);
    }

    final (emptyFill, emptyBorder) = emptyColors(pal);

    // سایه‌ی ملایم زیر روزهای انجام‌شده
    if (done) {
      canvas.drawRRect(
        r.shift(const Offset(0, 1.2)),
        Paint()
          ..color = pal.emerald700.withAlpha(70)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
    }

    // پس‌زمینه
    final bg = Paint();
    if (done) {
      bg.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [pal.emerald700, pal.emerald500],
      ).createShader(rect);
    } else {
      bg.color = emptyFill;
    }
    canvas.drawRRect(r, bg);

    // کادر روزِ ثبت‌نشده (پررنگ و واضح)
    if (!done && ring == null) {
      canvas.drawDRRect(r, r.deflate(1.2), Paint()..color = emptyBorder);
    }

    // نوار طلایی آخرِ هر ماه
    if (monthEnd && ring == null) {
      canvas.save();
      canvas.clipRRect(r);
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - 3, size.width, 3),
        Paint()..color = pal.gold500,
      );
      canvas.restore();
    }

    // امروز: حلقه‌ی طلاییِ ضخیم با فاصله‌ی کوچک
    if (today) {
      canvas.drawDRRect(
          r.inflate(2.6), r.inflate(0.8), Paint()..color = pal.accent);
    } else if (selected) {
      canvas.drawDRRect(
          r.inflate(3), r.inflate(1), Paint()..color = pal.ink);
    }
  }

  @override
  bool shouldRepaint(covariant _DayPainter o) =>
      o.pal != pal ||
      o.done != done ||
      o.today != today ||
      o.monthEnd != monthEnd ||
      o.selected != selected ||
      o.ring != ring;
}

// ════════════════════════════════════════════════════════════════
//         دوره‌ی تمام‌شده‌ی قبلی — details.mini-cal-past
// ════════════════════════════════════════════════════════════════
class _PastPeriod extends StatefulWidget {
  final GratPalette pal;
  final GratitudeStore store;
  final int index;
  final Set<String> doneSet;
  final String owner;
  const _PastPeriod({
    required this.pal,
    required this.store,
    required this.index,
    required this.doneSet,
    required this.owner,
  });

  @override
  State<_PastPeriod> createState() => _PastPeriodState();
}

class _PastPeriodState extends State<_PastPeriod> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final pd = widget.store.pastPeriods[widget.index];
    final days = (pd['days'] as int?) ?? 28;
    final start = GratCal.parseKey(pd['startDate']?.toString() ?? '');
    var done = 0;
    for (var d = 0; d < days; d++) {
      if (widget.doneSet.contains(
          GratCal.key(DateTime(start.year, start.month, start.day + d)))) {
        done++;
      }
    }
    final head = TextStyle(
        fontSize: 11.5, fontWeight: FontWeight.w800, color: pal.ink);

    // .mini-cal-past: surface، کادر line، گوشه‌ی ۱۲، padding 9/12
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: pal.isDark ? pal.surface : Colors.white,
        border: Border.all(color: pal.panelBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '✅ دوره‌ی ${GratCal.ord(widget.index)} — ${GratCal.faNum(days)} روزه',
                    style: head,
                  ),
                ),
                const SizedBox(width: 8), // gap:8px
                Text('${GratCal.faNum(done)} / ${GratCal.faNum(days)}',
                    style: head),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 10), // .mini-cal-inner margin-top
            GratPeriodGrid(
              pal: pal,
              owner: widget.owner,
              start: start,
              total: days,
              doneSet: widget.doneSet,
              inner: true,
            ),
          ],
        ],
      ),
    );
  }
}
