import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/future_text_format.dart';
import '../models/future_version.dart';
import '../state/beliefs_store.dart';
import '../widgets/breath_circle.dart';
import '../widgets/format_bar.dart';
import '../widgets/mini_calendar_90.dart';
import '../widgets/neural_pathway.dart';
import '../widgets/nothing_scene.dart';
import '../widgets/quantum_connect.dart';
import '../widgets/ras_mission.dart';

const Color _kEmerald = Color(0xFF178A7C);
const Color _kEmerald300 = Color(0xFF54B3A4);
const Color _kEmerald700 = Color(0xFF0F5B53);
const Color _kSky = Color(0xFF5EC8F0);
const Color _kInkSoft = Color(0xFF3D5551);
const Color _kYellow = Color(0xFFF4C542);

/// مدت تایمر تمرین (۱۵ دقیقه)
const int _kTimerTotal = 15 * 60;

class BeliefsTab extends StatefulWidget {
  const BeliefsTab({super.key});
  @override
  State<BeliefsTab> createState() => _BeliefsTabState();
}

class _BeliefsTabState extends State<BeliefsTab> {
  bool _showReminder = false;
  bool _showNotes = false;
  bool _showMission = false;
  bool _showArchive = false;
  String? _selectedDay;

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
            const SizedBox(height: 16),

            // ═══ کارت قلمرو ممکن‌ها ═══
            _quantumFieldCard(),
            const SizedBox(height: 14),

            // ═══ کارت چرا باید هیچ شوی؟ ═══
            _whyNothingCard(),
            const SizedBox(height: 14),

            // ═══ کارت تمرین روزانه ═══
            _dailyPracticeCard(store),
          ],
        ),
      ),
    );
  }

  // ═══════════════ هدر + یادآوری ═══════════════
  Widget _header(BeliefsStore store) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('بازنویسی باورها',
                  style: TextStyle(
                    fontSize: 20,
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
        IconButton(
          tooltip: 'یادآوری روزانه',
          onPressed: () => setState(() => _showReminder = !_showReminder),
          icon: const Text('🔔', style: TextStyle(fontSize: 18)),
        ),
      ],
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
  // ═══════════════ کارت تمرین روزانه ═══════════════
Widget _dailyPracticeCard(BeliefsStore store) {
  final steps = store.todaySteps;

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
        // هدر
        Row(
          children: [
            const Text('🌌 ', style: TextStyle(fontSize: 14)),
            const Expanded(
              child: Text(
                'تمرین روزانه',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: kBeliefsInk,
                ),
              ),
            ),
            Text(
              '${_toFa(store.readDayCount * 2)} جلسه',
              style: const TextStyle(fontSize: 10.5, color: kBeliefsMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'شش مرحله. هر کدوم رو جدا تیک بزن. لازم نیست یه‌جا انجام بدی.',
          style: TextStyle(fontSize: 11, color: kBeliefsMuted, height: 1.7),
        ),
        const SizedBox(height: 14),

        // ─── موسیقی مدیتیشن ───
        const Text(
          '🎵 موسیقی مدیتیشن (اختیاری)',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: kBeliefsInk),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: kBeliefsMuted,
              side: const BorderSide(color: kBeliefsBorder),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () =>
                _toast('افزودن موسیقی به‌زودی به نسخه‌ی اپ اضافه می‌شود'),
            icon: const Icon(Icons.add, size: 14),
            label:
                const Text('افزودن موسیقی', style: TextStyle(fontSize: 11)),
          ),
        ),
        const SizedBox(height: 12),

        // ─── تایمر ───
        _timerBlock(),
        const SizedBox(height: 16),

        // ─── مرحله ۱: رهاسازی ───
        _stepHeader(
          number: '۱',
          title: 'رهاسازی — آرام شدن',
          isDone: steps.contains('breath'),
          onToggle: () => store.toggleStep('breath'),
        ),
        const SizedBox(height: 10),
        _whyBox([
          _defChip('رهاسازی (Relaxation):',
              'بدنت رو عمیقاً آروم کن تا از حالت آماده‌باش و تنش فاصله بگیری.'),
          _bodyText(
              'وقتی بدن آروم می‌شه، توجهت از فشارها و فکرهای روزمره جدا می‌شه. ذهنت آماده می‌شه برای تمرکز، تجسم و تجربه‌ی درونی.'),
        ]),
        const SizedBox(height: 14),
        const BreathCircle(),
        const SizedBox(height: 18),

        // ─── مرحله ۲: هیچ شدن ───
        _stepHeader(
          number: '۲',
          title: 'هیچ شدن',
          isDone: steps.contains('nothing'),
          onToggle: () => store.toggleStep('nothing'),
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 18),

        // ─── مرحله ۳: اتصال به قلمرو ممکن‌ها ───
        _stepHeader(
          number: '۳',
          title: 'اتصال به قلمرو ممکن‌ها',
          isDone: steps.contains('connection'),
          onToggle: () => store.toggleStep('connection'),
        ),
        const SizedBox(height: 10),
        _whyBox([
          _defChip('اتصال (Connection):',
              'در این حالت خالی و آروم، RAS مغزت دوباره تنظیم می‌شه و می‌تونه فرصت‌ها و نشانه‌هایی رو ببینه که قبلاً از فیلتر توجهت رد می‌شدن.'),
          _bodyText(
              'این یه تمرین ذهن‌آگاهی برای بازکردن کانال توجهه — نه ارسال سیگنال به یک میدان بیرونی.'),
        ]),
        const SizedBox(height: 10),
        const QuantumConnect(),
        const SizedBox(height: 18),

        // ─── مرحله ۴: متن خواسته + تقویم ───
        _seedStep(store, steps),
        const SizedBox(height: 18),

        // ─── مرحله ۴ (تصاویر) ───
        _imagesStep(store, steps),
        const SizedBox(height: 18),

        // ─── مأموریت ذهن ───
        _missionStep(store),
      ],
    ),
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
      _stepHeader(
        title: '',
        isDone: steps.contains('seed'),
        onToggle: () => store.toggleStep('seed'),
        trailing: _expandIcon(
          open: _showNotes,
          onTap: () => setState(() => _showNotes = !_showNotes),
        ),
      ),
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
    ],
  );
}

Widget _futureBox(BeliefsStore store) {
  final text = (store.activeVersion?.text ?? '').trim();

  return GestureDetector(
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
          ? Text(
              '«$text»',
              style: store.format.buildStyle(color: kBeliefsInk),
              textAlign: store.format.textAlign,
              textDirection: TextDirection.rtl,
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
    if (v == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kBeliefsCream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBeliefsBorder),
        ),
        child: const Text(
          'بعد از نوشتن متن خواسته، تقویم پیشرفت روزانه اینجا ساخته می‌شود.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: kBeliefsMuted, height: 1.7),
        ),
      );
    }

    final total = store.cycleDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MiniCalendar90(
          version: v,
          totalDays: total,
          dayKeyOf: _dayKey,
          isFuture: _isFutureDay,
          selectedKey: _selectedDay,
          onDayTap: (key) => setState(() => _selectedDay = key),
        ),
        _dayInfo(v),
        if (store.cycleFinished) ...[
          const SizedBox(height: 10),
          _accentBox(
            bg: _kYellow.withValues(alpha: 0.12),
            accent: kBeliefsGold,
            padding: const EdgeInsets.all(10),
            radius: 10,
            child: Text(
              '🎉 این دوره‌ی ${_toFa(total)} روزه تموم شد — ${_toFa(store.readDayCount)} روز از ${_toFa(total)} روز خوندی. برای شروع دوره‌ی تازه، تقویم رو ریست کن.',
              style: const TextStyle(
                  fontSize: 11.5, color: kBeliefsInk, height: 1.7),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _tinyBtn(
                '⚙ روزهای دوره (الان ${_toFa(total)} روزه)',
                () => _openCycleDaysDialog(store),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _tinyBtn(
                '🔄 ریست تقویم',
                () => _confirmResetCalendar(store),
                gold: store.cycleFinished,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dayInfo(FutureVersion v) {
    final key = _selectedDay;
    if (key == null) return const SizedBox.shrink();

    final date = _parseDayKey(key);
    final read = v.readDays.contains(key);
    final ms = v.readTimes[key];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String status;
    if (read) {
      status = ms != null
          ? '✓ خوانده شد — ساعت ${_fmtTime(ms)}'
          : '✓ خوانده شد — ساعت ثبت نشده (قدیمی)';
    } else if (date.isAfter(today)) {
      status = 'هنوز نرسیده';
    } else {
      status = 'خوانده نشده';
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kBeliefsCream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(MiniCalendar90.faDateFull(date),
              style: const TextStyle(fontSize: 11.5, color: kBeliefsInk)),
          const SizedBox(height: 3),
          Text(status,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: read ? FontWeight.w800 : FontWeight.w400,
                color: read ? _kEmerald700 : kBeliefsMuted,
              )),
        ],
      ),
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
        _stepHeader(
          number: '۴',
          title: 'تصاویر',
          isDone: steps.contains('images'),
          onToggle: () => store.toggleStep('images'),
        ),
        const SizedBox(height: 10),
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
        _noteField(store, 'visual',
            hint: 'توضیح این تصویرسازی (اختیاری)...', lines: 3),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: kBeliefsCream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBeliefsBorder),
          ),
          child: const Column(
            children: [
              Text('✨', style: TextStyle(fontSize: 28)),
              SizedBox(height: 6),
              Text('هنوز تصویری اضافه نکردی',
                  style: TextStyle(fontSize: 12, color: kBeliefsMuted)),
              SizedBox(height: 4),
              Text('عکس یا ویدیوی مورد دلخواهت رو اضافه کن',
                  style: TextStyle(fontSize: 10.5, color: kBeliefsMuted)),
            ],
          ),
        ),
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
      ],
    );
  }

  // ═══════════════ مأموریت ذهن ═══════════════
  Widget _missionStep(BeliefsStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          emoji: '🎯',
          title: 'مأموریت ذهن',
          trailing: _expandIcon(
            open: _showMission,
            onTap: () => setState(() => _showMission = !_showMission),
          ),
        ),
        if (_showMission) ...[
          const SizedBox(height: 12),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kBeliefsInk)),
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
      ],
    );
  }

  // ═══════════════ اجزای مشترک ═══════════════
  Widget _stepHeader({
    String? number,
    String? emoji,
    required String title,
    bool? isDone,
    VoidCallback? onToggle,
    Widget? trailing,
  }) {
    final done = isDone ?? false;

    return Row(
      children: [
        if (isDone != null) ...[
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? _kEmerald : kBeliefsCard,
                border: Border.all(
                  color: done ? _kEmerald : kBeliefsBorder,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: Text(
                done ? '✓' : '○',
                style: TextStyle(
                  fontSize: 14,
                  color: done ? Colors.white : kBeliefsMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (number != null) ...[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: kBeliefsCream,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kBeliefsMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (emoji != null) ...[
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kBeliefsInk,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _expandIcon({required bool open, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedRotation(
        turns: open ? 0.5 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: open ? const Color(0xFFDCF3EE) : kBeliefsCard,
            border: Border.all(
              color: open ? _kEmerald : kBeliefsBorder,
              width: 1.5,
            ),
          ),
          child: Text(
            '▾',
            style: TextStyle(
              fontSize: 11,
              color: open ? _kEmerald700 : kBeliefsMuted,
            ),
          ),
        ),
      ),
    );
  }

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
    ScaffoldMessenger.of(context).showSnackBar(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لغو', style: TextStyle(color: kBeliefsMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kBeliefsGold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ذخیره'),
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
                  style: TextStyle(fontSize: 11.5, color: kBeliefsMuted),
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
                      borderSide: const BorderSide(color: kBeliefsBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBeliefsBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: kBeliefsGold, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kBeliefsMuted,
                          side: const BorderSide(color: kBeliefsBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                            ScaffoldMessenger.of(context).showSnackBar(
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
