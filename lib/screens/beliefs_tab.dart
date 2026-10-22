import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/future_text_format.dart';
import '../models/future_version.dart';
import '../state/beliefs_store.dart';
import '../utils/edit_mark.dart';
import '../widgets/belief_visual_section.dart';
import '../widgets/breath_circle.dart';
import '../widgets/format_bar.dart';
import '../widgets/grat_period_calendar.dart';
import '../theme/grat_palette.dart';
import '../widgets/neural_pathway.dart';
import '../widgets/nothing_scene.dart';
import '../widgets/quantum_connect.dart';
import '../widgets/ras_mission.dart';
import '../services/quiet_snack.dart';

const Color _kEmerald = Color(0xFF178A7C);
const Color _kEmerald300 = Color(0xFF54B3A4);
const Color _kEmerald700 = Color(0xFF0F5B53);
const Color _kSky = Color(0xFF5EC8F0);
const Color _kInkSoft = Color(0xFF3D5551);
const Color _kYellow = Color(0xFFF4C542);

/// مدت تایمر تمرین (۱۵ دقیقه)
const int _kTimerTotal = 15 * 60;

/// کلیدِ مرحله‌های قابل‌تیک (به ترتیب) و عنوان کوتاهِ هر مرحله (۶ تا: آخری مأموریت ذهن)
const List<String> _kTracked = [
  'breath',
  'nothing',
  'connection',
  'seed',
  'images',
];
const List<String> _kStepTitles = [
  'رهاسازی',
  'هیچ شدن',
  'اتصال',
  'متن خواسته',
  'تصاویر',
  'مأموریت',
];

class BeliefsTab extends StatefulWidget {
  const BeliefsTab({super.key});
  @override
  State<BeliefsTab> createState() => _BeliefsTabState();
}

class _BeliefsTabState extends State<BeliefsTab> {
  bool _showReminder = false;
  bool _showNotes = false;
  bool _showScience = false;
  bool _showArchive = false;
  String? _selectedDay;

  // آکاردئونِ مراحل: هر مرحله یک کارت جمع‌شونده؛ محتوای هر مرحله اولین بار که
  // باز شد ساخته می‌شود و بعد زنده می‌ماند (تایمر/یادداشت/صدا گم نمی‌شود).
  int _openStep = 0;
  final Set<int> _visited = <int>{0};
  final List<GlobalKey> _stepKeys =
      List<GlobalKey>.generate(6, (_) => GlobalKey());

  // هایلایت بخش ویرایش‌شده‌ی متن خواسته (مثل EditMark وب)
  final GlobalKey _futureKey = GlobalKey();
  EditRange? _futureMark;
  int _futureMarkToken = 0;

  // تایمر تمرین
  Timer? _timer;
  int _timerSeconds = _kTimerTotal;
  bool _timerRunning = false;
  String _timerLabel = 'شروع';

  // یادداشت‌ها
  final Map<String, TextEditingController> _noteCtrls = {};
  final Map<String, Timer> _noteTimers = {};

  @override
  void dispose() {
    _timer?.cancel();
    for (final t in _noteTimers.values) {
      t.cancel();
    }
    for (final c in _noteCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BeliefsStore>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _header(store),
            if (_showReminder) _reminderPanel(store),
            const SizedBox(height: 14),

            // ═══ پیشرفت امروز ═══
            _progressCard(store),
            const SizedBox(height: 12),

            // ═══ آماده‌سازی: موسیقی + تایمر ═══
            _prepCard(),
            const SizedBox(height: 18),

            // ═══ مراحل تمرین (آکاردئون) ═══
            _sectionLabel('مراحل تمرین'),
            const SizedBox(height: 8),
            _practiceSteps(store),
            const SizedBox(height: 8),

            // ═══ پشتوانه‌ی علمی (جمع‌شده) ═══
            _scienceSection(),
          ],
        ),
      ),
    );
  }

  // ═══════════════ هدر + یادآوری ═══════════════
  Widget _header(BeliefsStore store) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('بازنویسی باورها',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsInk,
                  )),
              SizedBox(height: 4),
              Text(
                'سیم‌کشی مغز بر پایه‌ی RAS، نوروپلاستیسیتی و روش دکتر جو دیسپنزا',
                style: TextStyle(
                    fontSize: 11.5, color: kBeliefsMuted, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'یادآوری روزانه',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _showReminder = !_showReminder),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: store.alarmEnabled
                    ? _kEmerald.withValues(alpha: 0.10)
                    : kBeliefsCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: store.alarmEnabled ? _kEmerald : kBeliefsBorder),
              ),
              child: Icon(
                store.alarmEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_none_outlined,
                size: 22,
                color: store.alarmEnabled ? _kEmerald700 : kBeliefsMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: kBeliefsInk)),
      );

  // ═══════════════ پیشرفت امروز ═══════════════
  Widget _progressCard(BeliefsStore store) {
    final steps = store.todaySteps;
    final done = _kTracked.where(steps.contains).length;
    final total = _kTracked.length;
    final all = done == total;
    String? next;
    for (var i = 0; i < total; i++) {
      if (!steps.contains(_kTracked[i])) {
        next = _kStepTitles[i];
        break;
      }
    }
    final v = store.activeVersion;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _kEmerald.withValues(alpha: 0.10),
            _kSky.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kEmerald.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 62,
                height: 62,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: done / total,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.85),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            all ? _kEmerald700 : _kEmerald),
                      ),
                    ),
                    Text('${_toFa(done)}/${_toFa(total)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: kBeliefsInk)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(all ? 'تمرین امروز کامل شد 🎉' : 'تمرین امروز',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kBeliefsInk)),
                    const SizedBox(height: 3),
                    Text(
                      all
                          ? 'آفرین! فردا دوباره مسیر عصبی تازه را تقویت کن.'
                          : 'قدم بعدی: ${next ?? ''}',
                      style: const TextStyle(
                          fontSize: 11.5, color: _kInkSoft, height: 1.6),
                    ),
                    if (v != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'روز ${_toFa(store.currentDay)} از ${_toFa(store.cycleDays)}'
                        ' · ${_toFa(store.readDayCount * 2)} جلسه',
                        style: const TextStyle(
                            fontSize: 10.5, color: kBeliefsMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _kStepTitles.length; i++)
                Expanded(child: _stepDot(i, steps)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepDot(int i, Set<String> steps) {
    final tracked = i < _kTracked.length;
    final done = tracked && steps.contains(_kTracked[i]);
    final open = _openStep == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setOpen(i, toggle: false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? _kEmerald : Colors.white,
              border: Border.all(
                color: done
                    ? _kEmerald
                    : (open ? kBeliefsGold : kBeliefsBorder),
                width: open ? 2 : 1.5,
              ),
            ),
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    tracked ? _toFa(i + 1) : '🎯',
                    style: TextStyle(
                      fontSize: tracked ? 12 : 13,
                      fontWeight: FontWeight.w800,
                      color: open ? kBeliefsGold : kBeliefsMuted,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _kStepTitles[i],
              maxLines: 1,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: open ? FontWeight.w800 : FontWeight.w600,
                color: open ? kBeliefsInk : kBeliefsMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════ آماده‌سازی: موسیقی + تایمر ═══════════════
  Widget _prepCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Text('🎧', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text('آماده‌سازی',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kBeliefsInk)),
              ),
              Text('موسیقی و زمان‌سنج ۱۵ دقیقه‌ای',
                  style: TextStyle(fontSize: 10.5, color: kBeliefsMuted)),
            ],
          ),
          const SizedBox(height: 12),
          const BeliefMeditationMusic(),
          const SizedBox(height: 10),
          _timerBlock(),
        ],
      ),
    );
  }

  Widget _reminderPanel(BeliefsStore store) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('آلارم تمرین روزانه فعال باشد',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kBeliefsInk)),
              ),
              Switch(
                value: store.alarmEnabled,
                onChanged: (val) {
                  store.setAlarm(enabled: val);
                },
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(
                child: Text('ساعت یادآوری',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kBeliefsInk)),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kBeliefsInk,
                  side: const BorderSide(color: kBeliefsBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _pickAlarmTime(store),
                child: Text(_faStr(store.alarmTime),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ساعت و وضعیت آلارم ذخیره می‌شود.',
            style: TextStyle(fontSize: 11, color: kBeliefsMuted, height: 1.7),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAlarmTime(BeliefsStore store) async {
    final parts = store.alarmTime.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 20;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: h.clamp(0, 23).toInt(),
        minute: m.clamp(0, 59).toInt(),
      ),
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    await store.setAlarm(time: '$hh:$mm');
  }

  // ═══════════════ کارت قلمرو ممکن‌ها ═══════════════
  Widget _quantumFieldCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _kEmerald.withValues(alpha: 0.08),
            _kSky.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kEmerald.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🌌 قلمرو ممکن‌ها',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: kBeliefsInk,
            ),
          ),
          const SizedBox(height: 8),
          _rich(
              'تصور کن در **ذهنِ** تو فضایی شبیه به یک «میدان احتمالات» وجود دارد. **علم اعصاب** به ما می‌گوید مغز ثابت نیست — از خاصیت **نوروپلاستیسیتی** (انعطاف‌پذیری عصبی) برخوردار است؛ مثل زمینی که آماده‌ی کشت است. هر **قصد** و **حسِ** متمرکزی، اتصالات عصبی‌ات را از نظر فیزیکی بازسازی می‌کند.'),
          const SizedBox(height: 8),
          _rich(
              'واقعیت امروز تو، فقط عادت‌ترین مسیرِ عصبیِ فعلی توست. **استعاره‌ی «موج احتمالات»** — که از فیزیک کوانتوم وام گرفته‌ایم — یادآوری می‌کند: تا وقتی آن احتمال را با **باور و احساس** واقعی «انتخاب» نکرده‌ای، سایر مسیرها در ذهنت به‌صورت بالقوه باقی می‌مانند.'),
          const SizedBox(height: 8),
          _accentBox(
            bg: _kEmerald.withValues(alpha: 0.10),
            accent: _kEmerald,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            radius: 10,
            child: _rich(
                '**یه نکته:** تو این تمرین‌ها چیز جدیدی از بیرون «نمی‌سازی» — فقط مسیرهای عصبیِ تازه‌ای را در ذهن خودت تقویت می‌کنی که تا حالا فعال نبودند.'),
          ),
        ],
      ),
    );
  }

  // ═══════════════ کارت چرا باید هیچ شوی؟ ═══════════════
  Widget _whyNothingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🕳 چرا باید «هیچ» شوی؟',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: kBeliefsInk,
            ),
          ),
          const SizedBox(height: 8),
          _rich(
              'اگر از «منِ قدیمی» شروع کنی، مغزت همون الگوهای عصبیِ قدیمی رو دوباره اجرا می‌کنه. باید اول «هیچ» شی — یعنی موقتاً از هویت قدیمی، از ترس‌ها و از داستان‌های تکرارشونده فاصله بگیری. در اون سکوت و خالی بودن، **شبکه‌ی حالت پیش‌فرض مغز (DMN)** — همون بخشی که مدام با خودش حرف می‌زنه — آروم می‌شه.'),
          const SizedBox(height: 8),
          _rich(
              'وقتی «هیچ» می‌شی، **RAS** (سیستم فعال‌ساز شبکه‌ای مغزت) دوباره تنظیم می‌شه و می‌تونه اون نشانه‌ها و فرصت‌هایی رو ببینه که قبلاً از فیلتر توجهت رد می‌شدن. این یعنی گفت‌وگو با **انعطاف‌پذیری مغزت** — نه با کائنات.'),
        ],
      ),
    );
  }
  // ═══════════════ آکاردئونِ مراحل ═══════════════
  Widget _practiceSteps(BeliefsStore store) {
    final steps = store.todaySteps;
    final v = store.activeVersion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _accordion(
          index: 0,
          title: 'رهاسازی',
          subtitle: 'تنفس و آرام‌سازی بدن',
          isDone: steps.contains('breath'),
          body: () => _breathBody(store),
        ),
        _accordion(
          index: 1,
          title: 'هیچ شدن',
          subtitle: 'رها کردن پنج لایه‌ی هویت',
          isDone: steps.contains('nothing'),
          body: () => _nothingBody(store),
        ),
        _accordion(
          index: 2,
          title: 'اتصال به قلمرو ممکن‌ها',
          subtitle: 'باز کردن کانال توجه',
          isDone: steps.contains('connection'),
          body: () => _connectionBody(store),
        ),
        _accordion(
          index: 3,
          title: 'متن خواسته و تقویم',
          subtitle: store.hasReadToday
              ? 'امروز ثبت شد ✓'
              : (v == null
                  ? 'متن خواسته‌ات را بنویس'
                  : 'بخوان و برای امروز ثبت کن'),
          isDone: steps.contains('seed'),
          body: () => _seedStep(store, steps),
        ),
        _accordion(
          index: 4,
          title: 'تصاویر',
          subtitle: 'تجسم و حسِ واقعیت دلخواه',
          isDone: steps.contains('images'),
          body: () => _imagesStep(store, steps),
        ),
        _accordion(
          index: 5,
          emoji: '🎯',
          title: 'مأموریت ذهن',
          subtitle: store.rasMission != null && store.rasMission!.label.isNotEmpty
              ? store.rasMission!.label
              : 'آموزش RAS برای دیدن نشانه‌ها',
          body: () => _missionStep(store),
        ),
      ],
    );
  }

  void _setOpen(int i, {bool toggle = true}) {
    setState(() {
      _openStep = (toggle && _openStep == i) ? -1 : i;
      if (_openStep >= 0) _visited.add(_openStep);
    });
    if (_openStep == i) _scrollToStep(i);
  }

  void _advanceFrom(int i) {
    final n = i + 1;
    if (n >= _stepKeys.length) {
      setState(() => _openStep = -1);
      return;
    }
    _setOpen(n, toggle: false);
  }

  void _scrollToStep(int i) {
    // کمی صبر تا کارتِ قبلی جمع شود و بعد روی کارت تازه برویم
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      final ctx = _stepKeys[i].currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.03,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _accordion({
    required int index,
    required String title,
    required String subtitle,
    required Widget Function() body,
    bool? isDone,
    String? emoji,
  }) {
    final open = _openStep == index;
    final done = isDone ?? false;
    final visited = _visited.contains(index);

    return Container(
      key: _stepKeys[index],
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: open
              ? _kEmerald.withValues(alpha: 0.55)
              : (done ? _kEmerald300.withValues(alpha: 0.6) : kBeliefsBorder),
          width: open ? 1.5 : 1,
        ),
        boxShadow: open
            ? [
                BoxShadow(
                  color: _kEmerald.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _setOpen(index),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  _stepBadge(index, done, emoji),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: kBeliefsInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: done ? _kEmerald700 : kBeliefsMuted,
                            fontWeight:
                                done ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (done)
                    Container(
                      margin: const EdgeInsetsDirectional.only(end: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kEmerald.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text('انجام شد',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _kEmerald700)),
                    ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more,
                        size: 24,
                        color: open ? _kEmerald700 : kBeliefsMuted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: visited
                ? Offstage(
                    offstage: !open,
                    child: TickerMode(
                      enabled: open,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                        child: body(),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _stepBadge(int index, bool done, String? emoji) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? _kEmerald : kBeliefsCream,
        border: Border.all(color: done ? _kEmerald : kBeliefsBorder),
      ),
      child: done
          ? const Icon(Icons.check, size: 19, color: Colors.white)
          : (emoji != null
              ? Text(emoji, style: const TextStyle(fontSize: 16))
              : Text(
                  _toFa(index + 1),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsMuted,
                  ),
                )),
    );
  }

  /// دکمه‌ی پایانِ هر مرحله: تیک می‌زند و کارت بعدی را باز می‌کند
  Widget _doneButton(BeliefsStore store, String key, int index) {
    final done = store.todaySteps.contains(key);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    if (done) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _kEmerald700,
          side: const BorderSide(color: _kEmerald, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: shape,
        ),
        onPressed: () => store.toggleStep(key),
        icon: const Icon(Icons.check_circle, size: 18),
        label: const Text('انجام شد — برای برداشتن تیک بزن',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      );
    }
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: _kEmerald700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: shape,
      ),
      onPressed: () {
        store.toggleStep(key);
        _advanceFrom(index);
      },
      icon: const Icon(Icons.check, size: 18),
      label: const Text('این مرحله را انجام دادم',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
    );
  }

  // ─── محتوای مرحله‌ها ───
  Widget _breathBody(BeliefsStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _whyBox([
          _defChip('رهاسازی (Relaxation):',
              'بدنت رو عمیقاً آروم کن تا از حالت آماده‌باش و تنش فاصله بگیری.'),
          _bodyText(
              'وقتی بدن آروم می‌شه، توجهت از فشارها و فکرهای روزمره جدا می‌شه. ذهنت آماده می‌شه برای تمرکز، تجسم و تجربه‌ی درونی.'),
        ]),
        const SizedBox(height: 14),
        const BreathCircle(),
        const SizedBox(height: 16),
        _doneButton(store, 'breath', 0),
      ],
    );
  }

  Widget _nothingBody(BeliefsStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _whyBox([
          _defChip('هیچ شدن (Becoming Nothing):',
              'توجهت رو از بدن، محیط و هویت «من» برمی‌داری و به آگاهی محض اجازه می‌دی گسترش پیدا کنه.'),
          _bodyText(
              'وقتی خودت رو با اسم، شغل، بدن، خاطرات گذشته و نگرانی‌های آینده تعریف می‌کنی، داری سیگنالی از «گذشته» به میدان می‌فرستی. «هیچ شدن» یعنی رها کردن این هویت‌های شرطی‌شده.'),
        ]),
        const SizedBox(height: 14),
        const Text(
          'پنج لایه رو یکی‌یکی رها کن — با هر تیک، غبار کمتر و آگاهی روشن‌تر:',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: kBeliefsInk),
        ),
        const SizedBox(height: 10),
        NothingScene(
          doneLayers: store.todayNothingLayers,
          onToggle: (key) {
            store.toggleNothingLayer(key);
          },
        ),
        const SizedBox(height: 12),
        _accentBox(
          bg: _kYellow.withValues(alpha: 0.08),
          accent: kBeliefsGold,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          radius: 8,
          child: const Text(
            'این «هیچ» منفی نیست — مثل صفحه‌ی سفیده که همه‌چیز رو توی خودش جا می‌ده.',
            style: TextStyle(fontSize: 11, color: _kInkSoft, height: 1.75),
          ),
        ),
        const SizedBox(height: 16),
        _doneButton(store, 'nothing', 1),
      ],
    );
  }

  Widget _connectionBody(BeliefsStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _whyBox([
          _defChip('اتصال (Connection):',
              'در این حالت خالی و آروم، RAS مغزت دوباره تنظیم می‌شه و می‌تونه فرصت‌ها و نشانه‌هایی رو ببینه که قبلاً از فیلتر توجهت رد می‌شدن.'),
          _bodyText(
              'این یه تمرین ذهن‌آگاهی برای بازکردن کانال توجهه — نه ارسال سیگنال به یک میدان بیرونی.'),
        ]),
        const SizedBox(height: 10),
        const QuantumConnect(),
        const SizedBox(height: 16),
        _doneButton(store, 'connection', 2),
      ],
    );
  }

  // ═══════════════ پشتوانه‌ی علمی ═══════════════
  Widget _scienceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _showScience = !_showScience),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kBeliefsCream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBeliefsBorder),
            ),
            child: Row(
              children: [
                const Text('📖', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('چرا این تمرین کار می‌کند؟',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: kBeliefsInk)),
                      SizedBox(height: 2),
                      Text('نوروپلاستیسیتی، RAS و معنای «هیچ شدن»',
                          style: TextStyle(
                              fontSize: 11, color: kBeliefsMuted)),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _showScience ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more,
                      size: 24, color: kBeliefsMuted),
                ),
              ],
            ),
          ),
        ),
        if (_showScience) ...[
          const SizedBox(height: 10),
          _quantumFieldCard(),
          const SizedBox(height: 10),
          _whyNothingCard(),
        ],
      ],
    );
  }

// ═══════════════ تایمر ═══════════════
Widget _timerBlock() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: kBeliefsCream,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Text('⏱ زمان تمرین',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: kBeliefsInk)),
        const Spacer(),
        Text(_fmtTimer(_timerSeconds),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: kBeliefsInk,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(width: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: kBeliefsInk,
            side: const BorderSide(color: kBeliefsBorder),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _toggleTimer,
          child: Text(_timerLabel, style: const TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );
}

void _toggleTimer() {
  if (_timerRunning) {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _timerLabel = 'ادامه';
    });
    return;
  }
  if (_timerSeconds <= 0) {
    _timerSeconds = _kTimerTotal;
  }
  setState(() {
    _timerRunning = true;
    _timerLabel = 'توقف';
  });
  _timer?.cancel();
  _timer = Timer.periodic(const Duration(seconds: 1), (t) {
    if (!mounted) {
      t.cancel();
      return;
    }
    if (_timerSeconds <= 1) {
      t.cancel();
      HapticFeedback.heavyImpact();
      setState(() {
        _timerSeconds = 0;
        _timerRunning = false;
        _timerLabel = 'پایان';
      });
      return;
    }
    setState(() => _timerSeconds--);
  });
}

// ═══════════════ مرحله‌ی متن خواسته + تقویم ═══════════════
Widget _seedStep(BeliefsStore store, Set<String> steps) {
  final v = store.activeVersion;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _whyBox([
        _bodyText(
            'متن خواسته‌ات رو یک بار با حس بخون (بلند یا توی ذهن) و بعد «امروز خوندم» رو بزن تا تقویم و رشته‌ی عصبی‌ات جلو بره.'),
      ]),
      const SizedBox(height: 12),
      _futureBox(store),
      const SizedBox(height: 10),
      _actionsRow(store),
      const SizedBox(height: 10),
      _registerButton(store, v),
      const SizedBox(height: 12),
      if (_showArchive) ...[
        _archiveBox(store),
        const SizedBox(height: 10),
      ],
      _calendarSection(store, v),
      if (_showNotes) ...[
        const SizedBox(height: 12),
        _notesBox(store),
      ],
      const SizedBox(height: 16),
      _doneButton(store, 'seed', 3),
    ],
  );
}

Widget _futureBox(BeliefsStore store) {
  final text = (store.activeVersion?.text ?? '').trim();

  return GestureDetector(
    key: _futureKey,
    onTap: () => _openEditor(store),
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: text.isNotEmpty
          ? SizedBox(
              width: double.infinity,
              child: EditMarkedText(
                text: text,
                range: _futureMark,
                prefix: '«',
                suffix: '»',
                style: store.format.buildStyle(color: kBeliefsInk),
                textAlign: store.format.textAlign,
              ),
            )
          : const Column(
              children: [
                SizedBox(height: 6),
                Text(
                  'هنوز چیزی ثبت نکردی.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: kBeliefsMuted),
                ),
                SizedBox(height: 4),
                Text(
                  'روی همین کادر بزن و بنویس.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: kBeliefsMuted),
                ),
                SizedBox(height: 6),
              ],
            ),
    ),
  );
}

/// دکمه‌های «ویرایش» و «آرشیو»
Widget _actionsRow(BeliefsStore store) {
  return Row(
    children: [
      Expanded(
        child: _tinyBtn('ویرایش', () => _openEditor(store)),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: _tinyBtn(
          '📚 آرشیو (${_toFa(store.versions.length)})',
          () => setState(() => _showArchive = !_showArchive),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: _tinyBtn(
          _showNotes ? '📝 بستن یادداشت' : '📝 یادداشت',
          () => setState(() => _showNotes = !_showNotes),
          gold: _showNotes,
        ),
      ),
    ],
  );
}

Widget _registerButton(BeliefsStore store, FutureVersion? v) {
  final read = store.hasReadToday;
  var label = '✅ امروز خوندم — ثبت کن';
  if (read && v != null) {
    final ms = v.readTimes[_dayKey(DateTime.now())];
    label = ms == null
        ? '✓ امروز ثبت شد'
        : '✓ امروز ثبت شد — ساعت ${_fmtTime(ms)}';
  }
  final shape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  const labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w800);

  if (read) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _kEmerald700,
        side: const BorderSide(color: _kEmerald, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: shape,
      ),
      onPressed: () => _registerToday(store),
      child: Text(label, style: labelStyle),
    );
  }
  return FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: _kEmerald700,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: shape,
    ),
    onPressed: () => _registerToday(store),
    child: Text(label, style: labelStyle),
  );
}

Future<void> _registerToday(BeliefsStore store) async {
  final v = store.activeVersion;
  if (v == null || v.text.trim().isEmpty) {
    _toast('اول متن خواسته‌ات را بنویس');
    return;
  }
  final already = store.hasReadToday;
  await store.markReadToday();
  if (!mounted) return;
  final tk = _dayKey(DateTime.now());
  setState(() => _selectedDay = tk);
  if (!already) {
    final ms = v.readTimes[tk];
    final timeTxt = ms == null ? '' : ' — ساعت ${_fmtTime(ms)}';
    _toast('✓ امروز ثبت شد$timeTxt');
  }
}

// ─── آرشیو نسخه‌ها ───
Widget _archiveBox(BeliefsStore store) {
  final list = store.versions;

  return Container(
    padding: const EdgeInsets.all(10),
    constraints: const BoxConstraints(maxHeight: 300),
    decoration: BoxDecoration(
      color: kBeliefsCream,
      borderRadius: BorderRadius.circular(12),
    ),
    child: list.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'هنوز نسخه‌ای ذخیره نشده.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: kBeliefsMuted),
            ),
          )
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('📚 همه‌ی نسخه‌های تو',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kBeliefsInk)),
                ),
                for (var i = list.length - 1; i >= 0; i--)
                  _versionTile(store, list[i], i),
              ],
            ),
          ),
  );
}

Widget _versionTile(BeliefsStore store, FutureVersion v, int index) {
  final isActive = v.id == store.activeVersionId;
  final activeTxt = isActive ? ' • فعال' : '';
  final end = v.endDate ?? 'اکنون';
  final preview =
      v.text.length > 100 ? '${v.text.substring(0, 100)}...' : v.text;

  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: isActive ? _kEmerald.withValues(alpha: 0.06) : kBeliefsCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: isActive ? _kEmerald : kBeliefsBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('نسخه ${_toFa(index + 1)}$activeTxt',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsInk)),
            const Spacer(),
            Text('${_toFa(v.readDays.length)} روز',
                style:
                    const TextStyle(fontSize: 9.5, color: kBeliefsMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Text('${v.startDate} تا $end',
            style: const TextStyle(fontSize: 10, color: kBeliefsMuted)),
        if (v.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: kBeliefsCream,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('«$preview»',
                style: const TextStyle(
                    fontSize: 11,
                    color: _kInkSoft,
                    height: 1.6,
                    fontStyle: FontStyle.italic)),
          ),
        ],
        if (!isActive) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _tinyBtn('فعال کردن', () async {
                  await store.activateVersion(v.id);
                  if (!mounted) return;
                  setState(() => _selectedDay = null);
                  _toast('نسخه فعال شد ✓');
                }),
              ),
              const SizedBox(width: 6),
              _tinyBtn('🗑 حذف', () async {
                final ok = await _confirm(
                    'این نسخه از آرشیو برای همیشه حذف شود؟');
                if (!ok) return;
                await store.deleteVersion(v.id);
                if (!mounted) return;
                _toast('نسخه حذف شد');
              }, color: const Color(0xFFC0392B)),
            ],
          ),
        ],
      ],
    ),
  );
}
    // ─── تقویم پیشرفت ───
  Widget _calendarSection(BeliefsStore store, FutureVersion? v) {
    // تقویم همیشه دیده می‌شه؛ قبل از نوشتن متن، با یک نسخه‌ی خالیِ موقت (از امروز) نشون داده می‌شه.
    final noText = v == null;
    final cal = v ?? FutureVersion(startDate: _dayKey(DateTime.now()));

    final total = store.cycleDays;

    return BeliefsPeriodCalendar(
      pal: GratPalette.of(context),
      startKey: cal.startDate,
      total: total,
      readDays: cal.readDays.toSet(),
      readTimes: cal.readTimes,
      cycles: cal.cycles,
      finished: store.cycleFinished,
      noText: noText,
      onDays: () => _openCycleDaysDialog(store),
      onReset: () => _confirmResetCalendar(store),
    );
  }

  // ─── یادداشت‌های بذر امروز ───
  Widget _notesBox(BeliefsStore store) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBeliefsCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'بذری که امروز می‌کاری رو این‌جا بنویس. با «همین حالا...» شروع کن.',
            style: TextStyle(fontSize: 11.5, color: kBeliefsMuted, height: 1.7),
          ),
          const SizedBox(height: 10),
          _labeledNote(store, 'main', 'بذر اصلی امروز:', 3),
          const SizedBox(height: 10),
          _labeledNote(
              store, 'feel', 'چطور حسش می‌کنم اگه همین حالا حقیقت داشت؟', 2),
          const SizedBox(height: 10),
          _labeledNote(store, 'release', 'چی رو رها می‌کنم؟', 2),
        ],
      ),
    );
  }

  Widget _labeledNote(
      BeliefsStore store, String key, String label, int lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11.5, color: kBeliefsInk)),
        const SizedBox(height: 4),
        _noteField(store, key, lines: lines),
      ],
    );
  }

  TextEditingController _noteCtrl(BeliefsStore store, String key) {
    return _noteCtrls.putIfAbsent(
      key,
      () => TextEditingController(text: store.seedNotes[key] ?? ''),
    );
  }

  Widget _noteField(BeliefsStore store, String key,
      {String? hint, int lines = 2}) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextField(
      controller: _noteCtrl(store, key),
      minLines: lines,
      maxLines: null,
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontSize: 12.5, color: kBeliefsInk, height: 1.8),
      onChanged: (val) {
        store.seedNotes[key] = val;
        _noteTimers[key]?.cancel();
        _noteTimers[key] = Timer(const Duration(milliseconds: 500), () {
          store.setSeedNote(key, val);
        });
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kBeliefsMuted, fontSize: 12),
        filled: true,
        fillColor: kBeliefsCard,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: border(kBeliefsBorder, 1),
        enabledBorder: border(kBeliefsBorder, 1),
        focusedBorder: border(kBeliefsGold, 1.5),
      ),
    );
  }

  // ═══════════════ مرحله‌ی تصاویر ═══════════════
  Widget _imagesStep(BeliefsStore store, Set<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _whyBox([
          _defChip('کاشتن بذر (Seeding):',
              'یه تصویر واضح از واقعیت دلخواهت توی ذهن می‌کاری — بدون حس نیاز یا کمبود.'),
          _bodyText(
              'خودت رو توی صحنه‌ای ببین که به خواسته‌ات رسیدی. هر تعداد عکس یا ویدیو که دوست داری اضافه کن.'),
          const SizedBox(height: 8),
          _defChip('احساس فراوانی (Embodying):',
              'حسِ اون واقعیت رو توی بدنت بساز — شادی، سلامتی، آرامش — تا فرکانست هماهنگ شه.'),
          _bodyText(
              'وقتی خودت رو «کسی که رسیده» می‌بینی و حسش می‌کنی، رفتارهایت خودبه‌خود با همون هویت هم‌راستا می‌شن.'),
        ]),
        const SizedBox(height: 12),
        // یادداشت (ذخیره/لغو) + ضبط صدا + ویدیو + عکس با برش + اسلایدشو
        const BeliefVisualSection(),
        const SizedBox(height: 14),
        const Divider(height: 1, color: kBeliefsBorder),
        const SizedBox(height: 12),
        const Text('🧠 مدار عصبی تمرین',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: kBeliefsInk)),
        const SizedBox(height: 8),
        NeuralPathway(
          container: store.neural,
          label: 'تمرین',
          showDayButtons: false,
          onChange: () {
            store.saveNeural();
          },
        ),
        const SizedBox(height: 16),
        _doneButton(store, 'images', 4),
      ],
    );
  }

  // ═══════════════ مأموریت ذهن ═══════════════
  Widget _missionStep(BeliefsStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ذهنت رو برای دیدن چیزی که تا حالا ازش رد می‌شدی، آموزش بده.',
          style: TextStyle(fontSize: 11.5, color: kBeliefsMuted, height: 1.75),
        ),
        const SizedBox(height: 14),
        const RasMission(),
        const SizedBox(height: 14),
        const Divider(height: 1, color: kBeliefsBorder),
        const SizedBox(height: 12),
        const Text('🧠 مدار عصبی مأموریت',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: kBeliefsInk)),
        const SizedBox(height: 8),
        NeuralPathway(
          container: store.missionNeural,
          label: 'ردیابی RAS',
          showDayButtons: false,
          onChange: () {
            store.saveNeural();
          },
        ),
      ],
    );
  }

  // ═══════════════ اجزای مشترک ═══════════════
  Widget _whyBox(List<Widget> children) {
    return _accentBox(
      bg: _kEmerald.withValues(alpha: 0.06),
      accent: _kEmerald300,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      radius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _accentBox({
    required Color bg,
    required Color accent,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(12),
    double radius = 8,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          border: Border(right: BorderSide(color: accent, width: 3)),
        ),
        child: child,
      ),
    );
  }

  Widget _defChip(String title, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _kYellow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kYellow.withValues(alpha: 0.4)),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kEmerald700,
            height: 1.75,
          ),
          children: [
            const TextSpan(text: '📖 '),
            TextSpan(
              text: title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: ' $text'),
          ],
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11.5, color: _kInkSoft, height: 1.8),
    );
  }

  Widget _rich(String text) {
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd
            ? const TextStyle(fontWeight: FontWeight.w800, color: kBeliefsInk)
            : null,
      ));
    }
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12, color: _kInkSoft, height: 1.9),
        children: spans,
      ),
    );
  }

  Widget _tinyBtn(String label, VoidCallback onTap,
      {Color? color, bool gold = false}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? kBeliefsInk,
        backgroundColor:
            gold ? kBeliefsGold.withValues(alpha: 0.12) : kBeliefsCard,
        side: BorderSide(color: gold ? kBeliefsGold : kBeliefsBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ═══════════════ handlers ═══════════════
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).quietSnack(
      SnackBar(content: Text(msg)),
    );
  }

  Future<bool> _confirm(String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBeliefsCard,
        content: Text(
          msg,
          style: const TextStyle(color: kBeliefsInk, fontSize: 13, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('نه', style: TextStyle(color: kBeliefsMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kBeliefsGold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بله'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _openEditor(BeliefsStore store) async {
    final cur = store.activeVersion;
    final hadVersion = cur != null;
    final initial = cur?.text ?? '';
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextEditor(
        initial: initial,
        format: store.format,
        onFormatChange: store.setFormat,
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    if (result.trim() == initial.trim()) return;
    await store.saveText(result);
    if (!mounted) return;
    // بخش تغییرکرده را هایلایت کن و صفحه را روی همان‌جا ببر
    final range = hadVersion ? diffEditRange(initial.trim(), result.trim()) : null;
    final token = ++_futureMarkToken;
    setState(() => _futureMark = range);
    if (range != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _futureKey.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx,
              alignment: 0.3, duration: const Duration(milliseconds: 400));
        }
      });
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && token == _futureMarkToken) {
          setState(() => _futureMark = null);
        }
      });
    }
    _toast(hadVersion
        ? 'متن ویرایش شد ✏ (دوره و تقویم همان‌طور ماند)'
        : 'متن خواسته‌ات ثبت شد ✨');
  }

  Future<void> _openCycleDaysDialog(BeliefsStore store) async {
    final ctrl = TextEditingController(text: _toFa(store.cycleDays));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBeliefsCard,
        title: const Text('دوره‌ی خواندن چند روزه باشه؟',
            style: TextStyle(fontSize: 15, color: kBeliefsInk)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('بین ۱ تا ${_toFa(kFutureMaxDays)} روز',
                style: const TextStyle(fontSize: 12, color: kBeliefsMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        // راست‌چین: اولین دکمه سمت راست می‌افتد → ذخیره راست، لغو چپ
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kBeliefsGold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ذخیره'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لغو', style: TextStyle(color: kBeliefsMuted)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final n = int.tryParse(_normDigits(ctrl.text.trim()));
    if (n == null || n < 1 || n > kFutureMaxDays) {
      _toast('یه عدد بین ۱ تا ${_toFa(kFutureMaxDays)} وارد کن');
      return;
    }

    final changed = n != store.cycleDays;
    await store.setCycleDays(n);
    if (!mounted) return;

    if (changed && store.activeVersion != null) {
      final restart = await _confirm(
        'دوره از امروز از نو شروع بشه؟\nثبت‌های این دوره در تاریخچه‌ی همین نسخه نگه داشته می‌شن.',
      );
      if (!mounted) return;
      if (restart) {
        await store.resetCalendar();
        if (!mounted) return;
        setState(() => _selectedDay = null);
      }
    }
    _toast('دوره روی ${_toFa(n)} روز تنظیم شد 🌱');
  }

  Future<void> _confirmResetCalendar(BeliefsStore store) async {
    if (store.activeVersion == null) {
      _toast('اول متن خواسته‌ات را بنویس');
      return;
    }
    final ok = await _confirm(
      'تقویم از امروز از نو شروع بشه؟\nثبت‌های این دوره در تاریخچه‌ی همین نسخه نگه داشته می‌شن. متن و مسیر عصبی دست نمی‌خورن.',
    );
    if (!ok) return;
    await store.resetCalendar();
    if (!mounted) return;
    setState(() => _selectedDay = null);
    _toast('تقویم ریست شد — دوره‌ی تازه از امروز 🌱');
  }
}

// ═══════════════ توابع کمکی ═══════════════
String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

DateTime _parseDayKey(String k) {
  final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
  if (p.length != 3) return DateTime.now();
  return DateTime(p[0], p[1], p[2]);
}

bool _isFutureDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return d.isAfter(today);
}

String _faStr(String s) => s.replaceAllMapped(
      RegExp(r'\d'),
      (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
    );

String _toFa(int n) => _faStr(n.toString());

String _normDigits(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = fa.indexOf(ch);
    final j = ar.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (j >= 0) {
      b.write(j);
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

String _fmtTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return _faStr('$hh:$mm');
}

String _fmtTimer(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return _faStr('$m:$s');
}

// ═══════════════ ویرایشگر متن ═══════════════
class _TextEditor extends StatefulWidget {
  final String initial;
  final FutureTextFormat format;
  final ValueChanged<FutureTextFormat> onFormatChange;

  const _TextEditor({
    required this.initial,
    required this.format,
    required this.onFormatChange,
  });

  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final TextEditingController _ctrl;
  late FutureTextFormat _fmt;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
    _fmt = widget.format;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kBeliefsCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'متن خواسته‌ات',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kBeliefsInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'با «بسیار خوشحال و سپاسگزارم حالا که…» شروع کن',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 11.5, color: kBeliefsMuted),
                      ),
                      const SizedBox(height: 12),
                      FormatBar(
                        format: _fmt,
                        onChange: (f) {
                          setState(() => _fmt = f);
                          widget.onFormatChange(f);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _ctrl,
                        maxLines: null,
                        minLines: 5,
                        textAlign: _fmt.textAlign,
                        textDirection: TextDirection.rtl,
                        style: _fmt.buildStyle(color: kBeliefsInk),
                        decoration: InputDecoration(
                          hintText: 'بسیار خوشحال و سپاسگزارم حالا که…',
                          hintStyle: const TextStyle(
                              color: kBeliefsMuted, fontSize: 12, height: 1.8),
                          filled: true,
                          fillColor: kBeliefsCard,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: kBeliefsBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: kBeliefsBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: kBeliefsGold, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // دکمه‌های لغو / ذخیره همیشه پایین و در دسترس می‌مانند
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: kBeliefsGold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final t = _ctrl.text.trim();
                        if (t.isEmpty) {
                          ScaffoldMessenger.of(context).quietSnack(
                            const SnackBar(
                                content: Text('متن نمی‌تونه خالی باشه')),
                          );
                          return;
                        }
                        Navigator.pop(context, t);
                      },
                      child: const Text('💾 ذخیره',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kBeliefsMuted,
                        backgroundColor: kBeliefsCard,
                        side: const BorderSide(color: kBeliefsBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('لغو'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
