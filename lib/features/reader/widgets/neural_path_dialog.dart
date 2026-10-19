import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_languages.dart';
import '../../../core/constants/supported_languages.dart';
import '../../../core/neural/neural_dates.dart';
import '../../../core/neural/neural_store.dart';
import '../../../core/providers/app_prefs_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/speech_provider.dart';
import '../../../core/tts/tts_config.dart';
import '../../../core/theme/app_theme_colors.dart';

// ═══════════════════════════════════════════════════════════════════
// 🧬 کارتِ «مسیر عصبی این لغت» — پورتِ NeuralPathCard در Hope.
//
// • دو نورون (یادگیری / تثبیت) + دسته‌ای از رشته‌های نازک بینشان؛ هر تکرار
//   (از پلیر یا دستی) یک رشته‌ی تازه می‌سازد.
// • تکرارهایی که کاربر با پلیر گوش می‌دهد خودکار ثبت می‌شود
//   (core/tts/speech_controller → speech_provider → neuralPathProvider).
// • تقویمِ دوره‌ای: هر روز ثبت می‌شود «کدام لغت، به چه زبان‌هایی، چند بار»؛
//   دوره‌ی N روزه (۱ تا ۳۶۵) می‌شود ساخت و دوره‌های قبلی می‌مانند.
//
// مورد = (base, lang): base متنِ نرمال‌شده (همه‌ی زبان‌های یک آیتم یک
// تقویم دارند)، lang زبانِ همین ردیف (هر زبان رشته‌های خودش را دارد).
// ═══════════════════════════════════════════════════════════════════

/// کارت را باز می‌کند. [word] متنی که نمایش داده می‌شود؛ [langCode] زبانِ همین
/// متن؛ [baseText] (اختیاری) متنِ پایه‌ی مشترک بینِ زبان‌ها (برای آیتم‌های
/// برنامه: متنِ انگلیسیِ آیتم). اگر ندهید خودِ [word] پایه است.
Future<void> showNeuralPath(
  BuildContext context, {
  required String word,
  required String langCode,
  String? baseText,
}) {
  return showDialog<void>(
    context: context,
    // طبقِ خواسته: پشتِ کارت تیره نمی‌شود؛ لمسِ بیرون = بستن
    barrierColor: Colors.transparent,
    builder: (_) =>
        NeuralPathDialog(word: word, langCode: langCode, baseText: baseText),
  );
}

// ───────────────────────── متن‌های رابط ─────────────────────────
const Map<String, Map<String, String>> _kN = {
  'fa': {
    'title': 'مسیر عصبی این {label}',
    'wordLabel': 'لغت',
    'sentenceLabel': 'جمله',
    'learn': 'یادگیری',
    'stable': 'تثبیت',
    'built': 'مرورهای ثبت‌شده',
    'repsLast': '{n} تکرار · آخرین تمرین: {rel}',
    'today': 'امروز',
    'yesterday': 'دیروز',
    'st0': 'هنوز شروع نکردی.',
    'st1': 'اولین قدم رو برداشتی! ادامه بده.',
    'st2': 'داری کم‌کم این {label} رو یاد می‌گیری.',
    'st3': 'این {label} رو {n} بار مرور کردی. اگه رفت توی حافظه‌ی بلندمدتت، می‌تونی یادگرفتنش رو تأیید کنی.',
    'stHabit': 'این {label} رو یاد گرفتی 🎉',
    'doToday': '✨ امروز مرور کردم',
    'missed': 'دیروز وقت نکردم',
    'lock': '✅ این {label} رو یاد گرفتم',
    'unlock': '↩️ هنوز کافی نیست، ادامه بده',
    'showCal': 'نمایش تقویم این مسیر',
    'hideCal': 'بستن تقویم',
        'dayOf': 'روز {a} / {b}',
    'month': 'ماه {ord}',
    'to': 'تا',
    'none': 'در این روز تمرینی ثبت نشده.',
    'times': '{n} بار',
    'reps': '{n} تکرار',
    'notDone': 'ثبت نشده',
    'changeDays': '⚙️ روزهای دوره (الان {n} روزه)',
    'finished': '🎉🥳 دوره‌ی {ord} رو تموم کردی! {a} روز از {b} روز تمرین کردی.\nبرای ادامه دوره‌ی بعدی رو شروع کن — دوره‌های قبلی همین‌جا می‌مونن.',
    'startNext': '▶️ شروع دوره‌ی {ord}',
    'askDays': 'دوره‌ی {ord} چند روزه باشه؟ (۱ تا ۳۶۵)',
    'badNum': 'یه عدد بین ۱ تا ۳۶۵ وارد کن',
    'ok': 'تأیید',
    'cancel': 'لغو',
    'close': 'بستن',
    'pastTitle': '✅ دوره‌ی {ord} — {n} روزه',
  },
  'en': {
    'title': 'Neural path of this {label}',
    'wordLabel': 'word',
    'sentenceLabel': 'sentence',
    'learn': 'Learning',
    'stable': 'Settled',
    'built': 'Recorded reviews',
    'repsLast': '{n} repeats · last practice: {rel}',
    'today': 'today',
    'yesterday': 'yesterday',
    'st0': 'You haven’t started yet.',
    'st1': 'You took the first step! Keep going.',
    'st2': 'You’re gradually learning this {label}.',
    'st3': 'You reviewed this {label} {n} times. If it’s in your long-term memory, you can confirm you’ve learned it.',
    'stHabit': 'You’ve learned this {label} 🎉',
    'doToday': '✨ I reviewed it today',
    'missed': 'I didn’t have time yesterday',
    'lock': '✅ I’ve learned this {label}',
    'unlock': '↩️ Not enough yet, keep going',
    'showCal': 'Show this path’s calendar',
    'hideCal': 'Hide calendar',
    'dayOf': 'Day {a} / {b}',
    'month': 'Month {ord}',
    'to': 'to',
    'none': 'No practice recorded on this day.',
    'times': '{n}×',
    'reps': '{n} repeats',
    'notDone': 'none',
    'changeDays': '⚙️ Period days (now {n})',
    'finished': '🎉🥳 You finished period {ord}! You practiced {a} of {b} days.\nStart the next one to continue — past periods stay here.',
    'startNext': '▶️ Start period {ord}',
    'askDays': 'How many days should period {ord} be? (1 to 365)',
    'badNum': 'Enter a number between 1 and 365',
    'ok': 'OK',
    'cancel': 'Cancel',
    'close': 'Close',
    'pastTitle': '✅ Period {ord} — {n} days',
  },
};

const List<String> _kOrdFa = [
  'اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم', 'هفتم', 'هشتم', 'نهم', 'دهم',
  'یازدهم', 'دوازدهم', 'سیزدهم',
];

String _t(String ui, String key, [Map<String, String> args = const {}]) {
  var s = _kN[ui]?[key] ?? _kN['en']![key]!;
  args.forEach((k, v) => s = s.replaceAll('{$k}', v));
  return s;
}

String _num(String ui, int n) => ui == 'fa' ? faDigits(n) : '$n';

/// «اول»، «دوم»، … (فارسی) یا شماره (بقیه). در متنِ دوره، بعدش فاصله می‌آید.
String _ord(String ui, int i) =>
    ui == 'fa' ? (i < _kOrdFa.length ? _kOrdFa[i] : faDigits(i + 1)) : '${i + 1}';

String _abbr(String code) {
  for (final l in kSupportedLanguages) {
    if (l.code == code) return l.abbr;
  }
  return code.toUpperCase();
}

// ───────────────────────── دیالوگ ─────────────────────────
class NeuralPathDialog extends ConsumerStatefulWidget {
  final String word;
  final String langCode;
  final String? baseText;

  const NeuralPathDialog({
    super.key,
    required this.word,
    required this.langCode,
    this.baseText,
  });

  @override
  ConsumerState<NeuralPathDialog> createState() => _NeuralPathDialogState();
}

class _NeuralPathDialogState extends ConsumerState<NeuralPathDialog> {
  bool _showCalendar = false;
  Offset _drag = Offset.zero;

  late final String _base = neuralBase(widget.baseText ?? widget.word);
  String get _lang => widget.langCode;

  void _speak() {
    final key = '${TtsConfig.locale[_lang] ?? 'en-US'}::${widget.word}';
    ref.read(neuralPathProvider.notifier).hint(key, _base);
    ref.read(speechControllerProvider.notifier).toggle(widget.word, _lang);
  }

  String _label(String ui) => _t(
      ui,
      RegExp(r'\s').hasMatch(widget.word.trim())
          ? 'sentenceLabel'
          : 'wordLabel');

  String _rel(String ui, int? ts) {
    if (ts == null) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final diff = daysBetween(d, DateTime.now());
    if (diff == 0) return _t(ui, 'today');
    if (diff == 1) return _t(ui, 'yesterday');
    final g = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if (ui == 'fa') {
      final j = gregorianToJalali(d.year, d.month, d.day);
      return faDigits('${j[0]}/${j[1].toString().padLeft(2, '0')}/${j[2].toString().padLeft(2, '0')}');
    }
    return g;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final ui = ref.watch(localeProvider).languageCode;
    final dir = kAppLanguages[ui]?.dir ?? TextDirection.rtl;
    // با هر تغییرِ همین مورد (مثلاً یک تکرار از پلیر) بازسازی می‌شود
    ref.watch(neuralPathProvider.select((s) => s.versionOf(_base)));
    final store = ref.read(neuralPathProvider.notifier);
    final rec = store.recordOf(_base);

    final fibers = rec?.fibers(_lang) ?? 0;
    final habit = rec?.isHabit(_lang) ?? false;
    final total = rec?.total(_lang) ?? 0;
    final lastTs = rec?.last[_lang];
    final nodeMid = habit || fibers >= (kNeuralFiberCap / 3).ceil();
    final nodeStrong = habit || fibers >= kNeuralFiberCap;
    final label = _label(ui);

    final args = {'label': label, 'n': _num(ui, fibers)};
    String status;
    if (habit) {
      status = _t(ui, 'stHabit', args);
    } else if (fibers <= 0) {
      status = _t(ui, 'st0', args);
    } else if (fibers < 4) {
      status = _t(ui, 'st1', args);
    } else if (fibers < 10) {
      status = _t(ui, 'st2', args);
    } else {
      status = _t(ui, 'st3', args);
    }

    const circle = 34.0;

    return Directionality(
      textDirection: dir,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Transform.translate(
          offset: _drag,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 292,
                maxHeight: MediaQuery.of(context).size.height * 0.86,
              ),
              child: Material(
                color: c.paper,
                elevation: 10,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.cardBorder),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ═══ دستگیره + عنوان (قابلِ کشیدن) ═══
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (d) => setState(() => _drag += d.delta),
                          child: Column(
                            children: [
                              Container(
                                width: 34,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: c.cardBorder,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Row(
                                  children: [
                                    InkResponse(
                                      onTap: () => Navigator.of(context).pop(),
                                      radius: 18,
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(Icons.close,
                                            size: 19, color: c.inkSoft),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    _LangChip(code: _lang, c: c),
                                    const Spacer(),
                                    // از راست به چپ: 🔊 ← 🧬
                                    const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Text('🧬',
                                          style: TextStyle(
                                              fontSize: 18, height: 1.1)),
                                    ),
                                    InkResponse(
                                      onTap: _speak,
                                      radius: 18,
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Text('🔊',
                                            style: TextStyle(
                                                fontSize: 18, height: 1.1)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Directionality(
                            textDirection: dirFor(_lang),
                            child: Text(
                              widget.word,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: c.gold,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ═══ دو نورون + رشته‌ها ═══
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: SizedBox(
                          height: 54,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _FibersPainter(
                                    count: fibers,
                                    color: (nodeStrong) ? c.gold : c.teal,
                                    circle: circle,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _Neuron(
                                      size: circle,
                                      fill: c.paperDark,
                                      border: c.cardBorder,
                                    ),
                                    _Neuron(
                                      size: circle,
                                      fill: nodeStrong
                                          ? c.goldSoft
                                          : c.paperDark,
                                      border: nodeMid ? c.gold : c.cardBorder,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                        const SizedBox(height: 3),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(
                              width: 56,
                              child: Text(_t(ui, 'learn'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: c.inkSoft,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                            SizedBox(
                              width: 56,
                              child: Text(_t(ui, 'stable'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: nodeMid ? c.ink : c.inkSoft,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        ),
                        const SizedBox(height: 8),

                        // ═══ مرورهای ثبت‌شده ═══
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: c.paperDark,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Column(
                            children: [
                              Text(_t(ui, 'built'),
                                  style: TextStyle(
                                      color: c.inkSoft, fontSize: 11.5)),
                              const SizedBox(height: 4),
                              Text(_num(ui, fibers),
                                  style: TextStyle(
                                      color: c.ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              if (total > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _t(ui, 'repsLast', {
                                    'n': _num(ui, total),
                                    'rel': _rel(ui, lastTs),
                                  }),
                                  style: TextStyle(
                                      color: c.inkSoft, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          status,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: c.inkSoft, fontSize: 12, height: 1.8),
                        ),
                        const SizedBox(height: 10),

                        // ═══ دکمه‌ها ═══
                        _PathButton(
                          label: _t(ui, 'doToday'),
                          fill: c.teal,
                          fg: Colors.white,
                          onTap: () => store.addRepeat(_base, _lang,
                              manual: true),
                        ),
                        const SizedBox(height: 7),
                        _PathButton(
                          label: _t(ui, 'missed'),
                          border: c.cardBorder,
                          fg: fibers == 0 ? c.cardBorder : c.inkSoft,
                          onTap: fibers == 0
                              ? null
                              : () => store.removeFiber(_base, _lang),
                        ),
                        if (fibers > 0 || habit) ...[
                          const SizedBox(height: 7),
                          _PathButton(
                            label: habit ? _t(ui, 'unlock') : _t(ui, 'lock', {'label': label}),
                            fill: habit ? c.paperDark : null,
                            border: habit
                                ? c.cardBorder
                                : const Color(0xFF3F9B72),
                            fg: habit ? c.inkSoft : const Color(0xFF2E7D5B),
                            onTap: () => store.toggleHabit(_base, _lang),
                          ),
                        ],
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            if (!_showCalendar) store.ensurePeriod(_base);
                            setState(() => _showCalendar = !_showCalendar);
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(30),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            _t(ui, _showCalendar ? 'hideCal' : 'showCal'),
                            style: TextStyle(
                              color: c.inkSoft,
                              fontSize: 11.5,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        if (_showCalendar)
                          _NeuralCalendar(base: _base, ui: ui),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── اجزای کوچک ─────────────────────────

class _LangChip extends StatelessWidget {
  final String code;
  final AppThemeColorsExt c;
  const _LangChip({required this.code, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.paperDark,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.cardBorder, width: 0.7),
      ),
      child: Text(
        _abbr(code),
        style: TextStyle(
            color: c.gold,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4),
      ),
    );
  }
}

class _Neuron extends StatelessWidget {
  final double size;
  final Color fill;
  final Color border;
  const _Neuron({required this.size, required this.fill, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 2),
      ),
    );
  }
}

class _PathButton extends StatelessWidget {
  final String label;
  final Color? fill;
  final Color? border;
  final Color fg;
  final VoidCallback? onTap;

  const _PathButton({
    required this.label,
    required this.fg,
    this.fill,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// رشته‌های نازکِ بینِ دو نورون — هر رشته یک خطِ جدا؛ شکلِ عدسی‌مانند با
/// هر رشته‌ی تازه کمی بازتر می‌شود (مثلِ SVG در Hope).
class _FibersPainter extends CustomPainter {
  final int count;
  final Color color;
  final double circle;
  _FibersPainter(
      {required this.count, required this.color, required this.circle});

  static double _jitter(int seed) {
    final x = math.sin(seed * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (count <= 0) return;
    final n = math.min(count, 500);
    final spread = math.min(34.0, 8 + math.sqrt(n) * 1.2) * (size.height / 40);
    final endSpread = math.min(9.0, 2 + math.sqrt(n) * 0.35) * (size.height / 40);
    final baseOpacity = math.max(0.15, 0.6 - n * 0.0008);
    final baseWidth = n > 200 ? 0.5 : (n > 80 ? 0.7 : 1.0);
    final cy = size.height / 2;
    final x0 = circle / 2;
    final x1 = size.width - circle / 2;
    final cx = size.width / 2;

    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 0.5 : i / (n - 1);
      final bow = -spread / 2 + t * spread;
      final sj = (_jitter(i * 2 + 1) - 0.5) * endSpread;
      final ej = (_jitter(i * 2 + 2) - 0.5) * endSpread;
      final newest = i == n - 1;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = newest ? baseWidth + 0.5 : baseWidth
        ..color = color.withOpacity(newest ? 0.95 : baseOpacity);
      final path = Path()
        ..moveTo(x0, cy + sj)
        ..quadraticBezierTo(cx, cy + bow * 2, x1, cy + ej);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _FibersPainter old) =>
      old.count != count || old.color != color || old.circle != circle;
}

// ───────────────────────── تقویمِ دوره‌ای ─────────────────────────

class _NeuralCalendar extends ConsumerStatefulWidget {
  final String base;
  final String ui;
  const _NeuralCalendar({required this.base, required this.ui});

  @override
  ConsumerState<_NeuralCalendar> createState() => _NeuralCalendarState();
}

class _NeuralCalendarState extends ConsumerState<_NeuralCalendar> {
  String? _selected;
  final Set<int> _openPast = {};

  String get ui => widget.ui;

  String _fmtDate(DateTime d, CalendarSystem cs) {
    if (cs == CalendarSystem.gregorian) {
      return '${d.day} ${kEnMonthsShort[d.month - 1]}';
    }
    final j = gregorianToJalali(d.year, d.month, d.day);
    return ui == 'fa'
        ? '${faDigits(j[2])} ${kPersianMonths[j[1] - 1]}'
        : '${j[2]} ${kPersianMonths[j[1] - 1]}';
  }

  String _dayHeader(String key, CalendarSystem cs) {
    final d = parseDayKey(key);
    final g = '${d.day} ${kEnMonthsShort[d.month - 1]} ${d.year}';
    final j = gregorianToJalali(d.year, d.month, d.day);
    final js = '${ui == 'fa' ? faDigits(j[2]) : j[2]} ${kPersianMonths[j[1] - 1]} ${ui == 'fa' ? faDigits(j[0]) : j[0]}';
    if (cs == CalendarSystem.gregorian) return g;
    if (cs == CalendarSystem.both) return '$js ($g)';
    return js;
  }

  Future<int?> _askDays(int current, int ordIdx) async {
    final ctrl = TextEditingController(text: '$current');
    final c = context.appColors;
    final res = await showDialog<int>(
      context: context,
      builder: (dctx) {
        String? err;
        return StatefulBuilder(builder: (dctx, setS) {
          return Directionality(
            textDirection: kAppLanguages[ui]?.dir ?? TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _t(ui, 'askDays', {'ord': _ord(ui, ordIdx)}),
                    style: TextStyle(color: c.ink, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: c.ink),
                    decoration: InputDecoration(
                      errorText: err,
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: c.inkSoft)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: c.teal, width: 2)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: Text(_t(ui, 'cancel'),
                      style: TextStyle(color: c.teal)),
                ),
                TextButton(
                  onPressed: () {
                    final n = int.tryParse(enDigits(ctrl.text.trim()));
                    if (n == null || n < 1 || n > kPeriodMaxDays) {
                      setS(() => err = _t(ui, 'badNum'));
                      return;
                    }
                    Navigator.pop(dctx, n);
                  },
                  child:
                      Text(_t(ui, 'ok'), style: TextStyle(color: c.teal)),
                ),
              ],
            ),
          );
        });
      },
    );
    ctrl.dispose();
    return res;
  }

  /// شبکه‌ی «ماه اول، ماه دوم، …» برای یک دوره (جاری یا قبلی)
  ({List<Widget> widgets, int done}) _grid(
    NeuralRecord? rec,
    String startKey,
    int days,
    CalendarSystem cs,
    AppThemeColorsExt c,
  ) {
    final start = parseDayKey(startKey);
    final today = dateOnly(DateTime.now());
    final out = <Widget>[];
    var done = 0;

    for (var blockStart = 0; blockStart < days; blockStart += kPeriodBlockDays) {
      final blockEnd = math.min(blockStart + kPeriodBlockDays, days);
      final d0 = DateTime(start.year, start.month, start.day + blockStart);
      final d1 = DateTime(start.year, start.month, start.day + blockEnd - 1);
      out.add(Padding(
        padding: EdgeInsets.fromLTRB(2, blockStart == 0 ? 0 : 8, 2, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _t(ui, 'month',
                  {'ord': _ord(ui, blockStart ~/ kPeriodBlockDays)}),
              style: TextStyle(
                  color: c.ink, fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
            Text(
              '${_fmtDate(d0, cs)} ${_t(ui, 'to')} ${_fmtDate(d1, cs)}',
              style: TextStyle(color: c.inkSoft, fontSize: 10.5),
            ),
          ],
        ),
      ));

      final cells = <Widget>[];
      for (var d = blockStart; d < blockEnd; d++) {
        final date = DateTime(start.year, start.month, start.day + d);
        final key = dayKeyOf(date);
        final n = rec?.dayTotal(key) ?? 0;
        final isDone = n > 0;
        if (isDone) done++;
        final isToday = date == today;
        final isFuture = date.isAfter(today);
        final isSel = key == _selected;
        final monthEnd =
            d % kPeriodBlockDays == kPeriodBlockDays - 1 || d == days - 1;
        cells.add(GestureDetector(
          onTap: isFuture
              ? null
              : () => setState(() => _selected = isSel ? null : key),
          child: Opacity(
            opacity: isFuture ? 0.3 : 1,
            child: Container(
              decoration: BoxDecoration(
                color: isDone ? c.gold : c.paperDark,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: isDone ? c.gold : c.cardBorder, width: 0.8),
                boxShadow: isSel
                    ? [BoxShadow(color: c.ink, spreadRadius: 1.5)]
                    : (isToday
                        ? [BoxShadow(color: c.teal, spreadRadius: 1.2)]
                        : null),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isDone)
                    const Text('✓',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 1)),
                  // نوارِ پایانِ هر «ماه»
                  if (monthEnd)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 3,
                      child: ColoredBox(color: c.teal),
                    ),
                ],
              ),
            ),
          ),
        ));
      }
      out.add(GridView.count(
        crossAxisCount: 15,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 2),
        children: cells,
      ));
    }
    return (widgets: out, done: done);
  }

  Widget _dayDetails(NeuralRecord? rec, CalendarSystem cs, AppThemeColorsExt c) {
    final key = _selected;
    if (key == null) return const SizedBox.shrink();
    final byLang = <MapEntry<String, int>>[
      ...?rec?.days[key]?.entries,
    ]..sort((a, b) {
        final k = b.value.compareTo(a.value);
        return k != 0 ? k : a.key.compareTo(b.key);
      });
    final total = rec?.dayTotal(key) ?? 0;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: _dayHeader(key, cs)),
              if (total > 0)
                TextSpan(
                  text: ' · ${_t(ui, 'reps', {'n': _num(ui, total)})}',
                  style: TextStyle(color: c.gold),
                ),
            ]),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c.ink, fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (byLang.isEmpty)
            Text(_t(ui, 'none'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.inkSoft,
                    fontSize: 11,
                    fontStyle: FontStyle.italic))
          else
            for (final e in byLang)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: c.paperDark,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_abbr(e.key),
                        style: TextStyle(
                            color: c.ink,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800)),
                    Text(_t(ui, 'times', {'n': _num(ui, e.value)}),
                        style: TextStyle(color: c.inkSoft, fontSize: 11.5)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final cs = ref.watch(appPrefsProvider.select((p) => p.calendarSystem));
    ref.watch(neuralPathProvider.select((s) => s.versionOf(widget.base)));
    final store = ref.read(neuralPathProvider.notifier);
    final rec = store.recordOf(widget.base);
    final period = rec?.period ??
        NeuralPeriod(days: kPeriodDefaultDays, startDate: dayKeyOf(DateTime.now()));

    final total = period.days;
    final past = period.past;
    final today = dateOnly(DateTime.now());
    final start = parseDayKey(period.startDate);
    final passed = daysBetween(start, today) + 1;
    final dayNum = passed.clamp(1, total).toInt();
    final endOfPeriod = DateTime(start.year, start.month, start.day + total);
    final finished = !today.isBefore(endOfPeriod);

    final cur = _grid(rec, period.startDate, total, cs, c);
    final pastOrd = _ord(ui, past.length);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _periodHeader(past.length, total),
                  style: TextStyle(
                      color: c.ink, fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                _t(ui, 'dayOf',
                    {'a': _num(ui, dayNum), 'b': _num(ui, total)}),
                style: TextStyle(
                    color: c.inkSoft, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...cur.widgets,
          if (_selected != null && _inPeriod(_selected!, start, total))
            _dayDetails(rec, cs, c),
          const SizedBox(height: 8),
          if (finished) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: c.paperDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.goldSoft),
              ),
              child: Text(
                _t(ui, 'finished', {
                  'ord': pastOrd,
                  'a': _num(ui, math.min(cur.done, total)),
                  'b': _num(ui, total),
                }),
                style: TextStyle(
                    color: c.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.8),
              ),
            ),
            const SizedBox(height: 8),
            _PathButton(
              label: _t(ui, 'startNext', {'ord': _ord(ui, past.length + 1)}),
              fill: c.goldSoft,
              border: c.gold,
              fg: c.ink,
              onTap: () async {
                final n = await _askDays(total, past.length + 1);
                if (n == null) return;
                store.startNextPeriod(widget.base, n);
                if (mounted) setState(() => _selected = null);
              },
            ),
          ] else
            _PathButton(
              label: _t(ui, 'changeDays', {'n': _num(ui, total)}),
              fill: c.paperDark,
              border: c.cardBorder,
              fg: c.ink,
              onTap: () async {
                final n = await _askDays(total, past.length);
                if (n == null) return;
                store.ensurePeriod(widget.base);
                store.setPeriodDays(widget.base, n);
              },
            ),
          if (past.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var i = past.length - 1; i >= 0; i--)
              _pastBlock(rec, past[i], i, cs, c),
          ],
        ],
      ),
    );
  }

  String _periodHeader(int pastCount, int total) {
    final ord = pastCount == 0 ? '' : '${_ord(ui, pastCount)} — ';
    if (ui == 'fa') {
      return '🧭 دوره‌ی $ord${faDigits(total)} روزه';
    }
    return '🧭 ${pastCount == 0 ? '' : 'Period $pastCount — '}$total-day period';
  }

  bool _inPeriod(String key, DateTime start, int total) {
    final d = parseDayKey(key);
    final off = daysBetween(start, d);
    return off >= 0 && off < total;
  }

  Widget _pastBlock(NeuralRecord? rec, PastPeriod p, int i, CalendarSystem cs,
      AppThemeColorsExt c) {
    final g = _grid(rec, p.startDate, p.days, cs, c);
    final open = _openPast.contains(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.paperDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (!_openPast.add(i)) _openPast.remove(i);
            }),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _t(ui, 'pastTitle',
                        {'ord': _ord(ui, i), 'n': _num(ui, p.days)}),
                    style: TextStyle(
                        color: c.ink,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${_num(ui, g.done)} / ${_num(ui, p.days)} ${open ? '▲' : '▼'}',
                  style: TextStyle(color: c.inkSoft, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (open) ...[
            const SizedBox(height: 8),
            ...g.widgets,
            if (_selected != null &&
                _inPeriod(_selected!, parseDayKey(p.startDate), p.days))
              _dayDetails(rec, cs, c),
          ],
        ],
      ),
    );
  }
}
