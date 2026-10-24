import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../theme/vazir_font.dart';
import '../widgets/brain_svg_data.dart';

/// تب آزمایشی «سیگنال» — از هیچ شدن تا هم‌فرکانسی.
///
/// انیمیشن مغز: میزِ شلوغ → «هیچ شدن» → انتخاب بین «سیگنال امکان» و
/// «سیگنال کمبود»، با نمودار زنده‌ی آمیگدال / PFC / دوپامین / Salience.
/// مستقل از تب «بازنویسی» و صحنه‌ی «هیچ شدن» آن است (فقط برای مقایسه).
class NeuroSignalTab extends StatefulWidget {
  const NeuroSignalTab({super.key});

  @override
  State<NeuroSignalTab> createState() => _NeuroSignalTabState();
}

class _NeuroSignalTabState extends State<NeuroSignalTab>
    with TickerProviderStateMixin {
  bool emptied = false;
  bool choiceMade = false;

  bool desireShown = false;
  bool amygdalaCalm = false;
  bool pfcActive = false;
  bool dopamineSensitive = false;
  bool salienceTuned = false;

  bool amygdalaAlert = false;
  bool pfcWeak = false;
  bool dopamineLow = false;
  bool salienceThreat = false;

  String status =
      'مرحله ۱: ذهن شلوغ است. آمیگدال فعال، PFC ضعیف، دوپامین کم‌حساس، Salience در حالت شکار خطر.';

  // ---------- «هیچ شدنِ مرحله‌ای» روی مغز واقعی ----------
  // ایستگاه‌ها: ۰ بدن، ۱ هویت، ۲ اشیا، ۳ زمان، ۴ مکان؛ ۵ = «هیچ کامل».
  // به‌ترتیب رها می‌شوند؛ بعد از «هیچ کامل» چهار قدمِ علمی باز می‌شود.
  final Set<int> _released = {};
  int? _stationOpen; // ایستگاهِ بازِ روی تصویر (۰..۵)
  int? _stepOpen; // قدمِ بازِ بعد از هیچ شدن (۰..۳)
  bool _aligned = false; // قدم ۴ (هم‌ترازی) انجام شده
  // ۱ = درگیر، ۰ = رها (نرم برای انیمیشن)
  final List<double> _st = [1, 1, 1, 1, 1];
  double _voidLevel = 0; // ۰..۱: آگاهیِ خالص

  /// قدم‌های بعد از هیچ شدن: انجام‌شده یا نه (PFC، Salience، دوپامین، هم‌ترازی)
  List<bool> get _stepDone =>
      [pfcActive, salienceTuned, dopamineSensitive, _aligned];

  /// اولین قدمِ انجام‌نشده (۰..۳)؛ ۴ یعنی همه انجام شده
  int get _curStep {
    final d = _stepDone;
    for (var i = 0; i < 4; i++) {
      if (!d[i]) return i;
    }
    return 4;
  }

  // ---------- نمای «دایره و موج» ----------
  // 0 = گره‌ها، 1 = دایره و موج، 2 = مغز واقعی
  int viewMode = 2;
  // بخشِ بازِ توضیحات: 0..3 = آمیگدال، PFC، دوپامین، Salience؛ 4 = راهنمای نماها؛ null = همه بسته
  int? _openRegion;
  late final AnimationController _wave;
  final Stopwatch _sw = Stopwatch();
  double _lastT = 0;
  double _ringPhase = 0;
  double _desireShownLevel = 0;
  final List<double> _nodePhase = [0, 0.25, 0.5, 0.75];
  // سطح نرم‌شده‌ی چهار بخش (آمیگدال، PFC، دوپامین، Salience) برای انیمیشن موج
  final List<double> _shown = [0.85, 0.4, 0.35, 0.5];

  void _tick() {
    final now = _sw.elapsedMicroseconds / 1e6;
    final dt = (now - _lastT).clamp(0.0, 0.05).toDouble();
    _lastT = now;
    final tg = [amygdalaLevel, pfcLevel, dopamineLevel, salienceLevel];
    for (var i = 0; i < 4; i++) {
      _shown[i] += (tg[i] - _shown[i]) * (1 - math.exp(-dt * 3));
      _nodePhase[i] = (_nodePhase[i] + dt * (0.15 + _shown[i] * 0.7)) % 1.0;
    }
    for (var i = 0; i < 5; i++) {
      _st[i] += ((_released.contains(i) ? 0.0 : 1.0) - _st[i]) *
          (1 - math.exp(-dt * 2.2));
    }
    _voidLevel +=
        ((emptied ? 1.0 : 0.0) - _voidLevel) * (1 - math.exp(-dt * 1.5));
    _desireShownLevel +=
        ((desireShown ? 1.0 : 0.0) - _desireShownLevel) * (1 - math.exp(-dt * 4));
    _ringPhase += dt * (1.0 + _shown[0] * 4.0);
  }

  late List<AnimationController> paperControllers;
  late List<Animation<double>> paperAnimations;

  @override
  void initState() {
    super.initState();
    paperControllers = List.generate(7, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });
    paperAnimations = paperControllers
        .map((c) => Tween<double>(begin: 1.0, end: 0.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _sw.start();
    _wave.repeat();
  }

  @override
  void dispose() {
    _wave.dispose();
    for (final c in paperControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- سطح فعالیت برای نمودار ----------
  double get amygdalaLevel {
    if (amygdalaAlert) return 1.0;
    if (amygdalaCalm) return 0.25;
    if (choiceMade) return 0.3;
    // با رها شدنِ هر ایستگاه (بدن، هویت، …) هشدار کم‌کم پایین می‌آید
    return 0.85 - 0.1 * _released.length;
  }

  double get pfcLevel {
    if (pfcActive) return 0.95;
    if (pfcWeak) return 0.2;
    return 0.4;
  }

  double get dopamineLevel {
    if (dopamineSensitive) return 0.95;
    if (dopamineLow) return 0.2;
    return 0.35;
  }

  double get salienceLevel {
    if (salienceTuned) return 0.95;
    if (salienceThreat) return 0.9;
    return 0.5;
  }

  // ---------- اکشن‌ها ----------
  Future<void> emptyMind() async {
    for (int i = 0; i < paperControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) paperControllers[i].forward();
      });
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _released.addAll(const [0, 1, 2, 3, 4]);
      amygdalaCalm = true;
      emptied = true;
      status =
          'هیچ شدی: میز خالی شد، آمیگدال آرام شد، بدن حس امنیت می‌کند (اینسولا). حالا Salience آزاد است که چه چیزی را مهم بداند.';
    });
  }

  Future<void> sendPossibilitySignal() async {
    if (!emptied || choiceMade) return;
    setState(() {
      choiceMade = true;
      desireShown = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      pfcActive = true;
      status = 'سیگنال امکان: PFC فعال شد، می‌توانی برنامه بریزی.';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      dopamineSensitive = true;
      status = 'دوپامین حساس شد: فرصت‌ها را می‌بینی، نه فقط خطرها.';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      salienceTuned = true;
      status =
          'Salience روی خواسته تنظیم شد: مثل گیرنده‌ی رادیو، موجِ امکان را می‌گیری. این همان هم‌فرکانسی است.';
    });
  }

  Future<void> sendLackSignal() async {
    if (!emptied || choiceMade) return;
    setState(() {
      choiceMade = true;
      desireShown = true;
      amygdalaCalm = false;
      amygdalaAlert = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      pfcWeak = true;
      pfcActive = false;
      status =
          'سیگنال کمبود: آمیگدال دوباره فعال شد. PFC زیر فشار هشدار ضعیف شد و نمی‌تواند برنامه بریزد.';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      dopamineLow = true;
      dopamineSensitive = false;
      status =
          'دوپامین کم‌حساس شد: فرصت‌ها را نمی‌بینی، هرچیز «کافی نیست».';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      salienceThreat = true;
      salienceTuned = false;
      status =
          'Salience دوباره روی «خطر» تنظیم شد. میزِ خالی دوباره پر از همان ترس‌های قدیمی شد.';
    });
  }

  void resetAll() {
    for (final c in paperControllers) {
      c.reset();
    }
    setState(() {
      _released.clear();
      _stationOpen = null;
      _stepOpen = null;
      _aligned = false;
      emptied = false;
      choiceMade = false;
      desireShown = false;
      amygdalaCalm = false;
      pfcActive = false;
      dopamineSensitive = false;
      salienceTuned = false;
      amygdalaAlert = false;
      pfcWeak = false;
      dopamineLow = false;
      salienceThreat = false;
      status =
          'مرحله ۱: ذهن شلوغ است. آمیگدال فعال، PFC ضعیف، دوپامین کم‌حساس، Salience در حالت شکار خطر.';
    });
  }

  // ---------- هیچ شدنِ مرحله‌ای: اکشن‌ها ----------
  /// هر بخشِ مغز به کدام «قدمِ بعد از هیچ شدن» می‌رسد (-۱ = هیچ‌کدام):
  /// آمیگدال، PFC، دوپامین، Salience
  static const List<int> _regionStep = [-1, 0, 2, 1];

  void _releaseStation(int i) {
    if (emptied || _released.contains(i) || _released.length != i) return;
    setState(() {
      _released.add(i);
      status = _stations[i].after;
    });
  }

  bool _nothingBusy = false;

  Future<void> _completeNothing() async {
    if (emptied || _nothingBusy || _released.length < 5) return;
    _nothingBusy = true;
    await emptyMind();
    _nothingBusy = false;
  }

  void _doStep(int k) {
    if (!emptied || amygdalaAlert || k != _curStep) return;
    setState(() {
      switch (k) {
        case 0:
          choiceMade = true;
          desireShown = true;
          pfcActive = true;
          break;
        case 1:
          salienceTuned = true;
          break;
        case 2:
          dopamineSensitive = true;
          break;
        default:
          _aligned = true;
      }
      status = _steps[k].after;
    });
  }

  void _tapRegion(int i) {
    setState(() {
      _stationOpen = null;
      final k = emptied ? _regionStep[i] : -1;
      if (k >= 0) {
        _stepOpen = _stepOpen == k ? null : k;
        _openRegion = null;
      } else {
        _openRegion = _openRegion == i ? null : i;
        _stepOpen = null;
      }
    });
  }

  void _tapStation(int i) {
    setState(() {
      _openRegion = null;
      if (i == 5 && emptied) {
        // بعد از هیچ شدن، دایره‌ی پایین می‌شود «قدم ۴: هم‌ترازی»
        _stationOpen = null;
        _stepOpen = _stepOpen == 3 ? null : 3;
      } else {
        _stepOpen = null;
        _stationOpen = _stationOpen == i ? null : i;
      }
    });
  }

  void _closePanels() => setState(() {
        _stationOpen = null;
        _stepOpen = null;
        _openRegion = null;
      });

  /// راهنمای کوتاهِ پایینِ تصویر: الان چه کنم؟
  String get _hint {
    if (!emptied) {
      if (_released.length < 5) {
        return 'روی نقطه‌ی «${_stations[_released.length].name}» بزن '
            '(${_faDigits(_released.length + 1)} از ۵)';
      }
      return 'حالا روی دایره‌ی «هیچ کامل» بزن';
    }
    if (amygdalaAlert) return 'سیگنال کمبود فعال است؛ «ریست» را بزن';
    final c = _curStep;
    if (c < 4) return 'قدم ${_faDigits(c + 1)} از ۴: ${_steps[c].hint}';
    return 'هم‌ترازی کامل شد ✓';
  }

  Widget _panelBtn(String label, Color color, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 34,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white12,
          disabledForegroundColor: Colors.white54,
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }

  Widget _panel({
    required Color color,
    required String title,
    String? tag,
    required List<Widget> children,
    required Widget button,
    required double maxH,
  }) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xF20F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              if (tag != null)
                Text(
                  tag,
                  style: const TextStyle(fontSize: 10.5, color: Colors.white60),
                ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _closePanels,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 16, color: Colors.white54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
          const SizedBox(height: 4),
          button,
        ],
      ),
    );
  }

  /// کارتِ توضیحِ یک ایستگاه (بدن، هویت، اشیا، زمان، مکان، هیچ کامل)
  Widget _stationPanel(int i, double maxH) {
    final st = _stations[i];
    var label = '';
    VoidCallback? tap;
    if (i < 5) {
      if (_released.contains(i)) {
        label = 'رها شد ✓';
      } else if (_released.length == i) {
        label = 'رها کن';
        tap = () => _releaseStation(i);
      } else {
        label = 'اول «${_stations[_released.length].name}» را رها کن';
      }
    } else {
      if (emptied) {
        label = 'هیچ شدی ✓';
      } else if (_released.length == 5) {
        label = 'هیچ شو';
        tap = _completeNothing;
      } else {
        label = 'اول پنج مرحله را رها کن';
      }
    }
    return _panel(
      color: _kStationColor,
      title: st.title,
      tag: i < 5 ? 'مرحله‌ی ${_faDigits(i + 1)} از ۵' : null,
      maxH: maxH,
      children: [
        _infoLine('ناحیه (تقریبی)', st.areas, _kStationColor),
        _infoLine('در مغز', st.effect, Colors.cyanAccent),
        _infoLine(i < 5 ? 'تمرین' : 'بعدش', st.practice, Colors.amberAccent),
      ],
      button: _panelBtn(label, _kStationColor, tap),
    );
  }

  /// کارتِ توضیحِ یک قدمِ بعد از هیچ شدن
  Widget _stepPanel(int k, double maxH) {
    final sp = _steps[k];
    final color = sp.region >= 0
        ? _WavePainter._colors[sp.region]
        : Colors.amberAccent;
    final done = _stepDone[k];
    var label = '';
    VoidCallback? tap;
    if (done) {
      label = 'انجام شد ✓';
    } else if (amygdalaAlert) {
      label = 'سیگنال کمبود فعال است؛ ریست بزن';
    } else if (k == _curStep) {
      label = 'این قدم را انجام دادم';
      tap = () => _doStep(k);
    } else {
      label = 'اول قدم ${_faDigits(_curStep + 1)} را انجام بده';
    }
    return _panel(
      color: color,
      title: sp.title,
      tag: sp.region >= 0
          ? '${_regions[sp.region].name} · ${_stateOf(sp.region)}'
          : 'PFC + آمیگدال + دوپامین',
      maxH: maxH,
      children: [
        _infoLine('علم', sp.science, color),
        _infoLine('کار علمی', sp.action, Colors.cyanAccent),
      ],
      button: _panelBtn(label, color, tap),
    );
  }

  Widget _node({
    required String label,
    required Color color,
    required bool glow,
    bool dimmed = false,
    double size = 60,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dimmed
            ? color.withValues(alpha: 0.2)
            : color.withValues(alpha: glow ? 1 : 0.35),
        shape: BoxShape.circle,
        boxShadow: glow
            ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 20)]
            : [],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
    );
  }

  // ---------- ویجت نمودار ----------
  Widget _chartBar({
    required String label,
    required double value,
    required Color color,
    required String state,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) {
                    return FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              state,
              style: TextStyle(fontSize: 10, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chart() {
    String amyState = amygdalaAlert
        ? 'هشدار'
        : amygdalaCalm
            ? 'آرام'
            : 'فعال';
    String pfcState = pfcActive
        ? 'فعال'
        : pfcWeak
            ? 'ضعیف'
            : 'متوسط';
    String dopState = dopamineSensitive
        ? 'حساس'
        : dopamineLow
            ? 'کم‌حساس'
            : 'متوسط';
    String salState = salienceTuned
        ? 'روی خواسته'
        : salienceThreat
            ? 'روی خطر'
            : 'آزاد';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نمودار فعالیت مغز',
            style: TextStyle(fontSize: 13, color: Colors.cyanAccent),
          ),
          const SizedBox(height: 8),
          _chartBar(
            label: 'آمیگدال',
            value: amygdalaLevel,
            color: Colors.redAccent,
            state: amyState,
          ),
          _chartBar(
            label: 'PFC',
            value: pfcLevel,
            color: Colors.blueAccent,
            state: pfcState,
          ),
          _chartBar(
            label: 'دوپامین',
            value: dopamineLevel,
            color: Colors.purpleAccent,
            state: dopState,
          ),
          _chartBar(
            label: 'Salience',
            value: salienceLevel,
            color: Colors.orangeAccent,
            state: salState,
          ),
        ],
      ),
    );
  }

  // ---------- انتخاب نما ----------
  Widget _viewToggle() {
    Widget chip(String label, int mode) => ChoiceChip(
          label: Text(label),
          selected: viewMode == mode,
          onSelected: (_) => setState(() => viewMode = mode),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        chip('مغز واقعی', 2),
        chip('دایره و موج', 1),
        chip('گره‌ها', 0),
      ],
    );
  }

  Widget _waveScene() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _WavePainter(this),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }

  // ---------- مغز واقعی ----------
  Widget _brainScene() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: kBrainSvgAspect,
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  final h = box.maxHeight;
                  final open = _openRegion;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      SvgPicture.string(
                        kBrainSvg,
                        fit: BoxFit.contain,
                        colorFilter: const ColorFilter.mode(
                          Color(0x99CBD5E1),
                          BlendMode.srcIn,
                        ),
                      ),
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: _BrainPainter(this),
                          size: Size.infinite,
                        ),
                      ),
                      // سطح لمس هر بخش
                      for (var i = 0; i < 4; i++)
                        Positioned(
                          left: w * _BrainPainter.pos[i].dx - 24,
                          top: h * _BrainPainter.pos[i].dy - 24,
                          width: 48,
                          height: 48,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _tapRegion(i),
                          ),
                        ),
                      // سطح لمس ایستگاه‌های «هیچ شدن» (بدن، هویت، اشیا، زمان، مکان، هیچ کامل)
                      for (var i = 0; i < 6; i++)
                        Positioned(
                          left: w * _BrainPainter.stPos[i].dx - 24,
                          top: h * _BrainPainter.stPos[i].dy - 24,
                          width: 48,
                          height: 48,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _tapStation(i),
                          ),
                        ),
                      // راهنمای «الان چه کنم؟» وقتی هیچ کارتی باز نیست
                      if (open == null && _stationOpen == null && _stepOpen == null)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC0F172A),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _kStationColor.withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Text(
                                  _hint,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // کارتِ ایستگاه یا قدمِ بازشده، همان‌جا روی مغز
                      if (_stationOpen != null)
                        Positioned(
                          left: 8,
                          right: 8,
                          top: _stationOpen == 5 ? 8 : null,
                          bottom: _stationOpen == 5 ? null : 8,
                          child: _stationPanel(_stationOpen!, h * 0.45),
                        ),
                      if (_stepOpen != null)
                        Positioned(
                          left: 8,
                          right: 8,
                          top: _stepOpen == 3 ? 8 : null,
                          bottom: _stepOpen == 3 ? null : 8,
                          child: _stepPanel(_stepOpen!, h * 0.45),
                        ),
                      // خلاصه‌ی بخشِ انتخاب‌شده، همان‌جا روی تصویر
                      if (open != null && open < 4)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _openRegion = null),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xEE0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _WavePainter._colors[open]
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _regions[open].name,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: _WavePainter._colors[open],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _stateOf(open),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _regions[open].short,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.6,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- اطلاعات بخش‌ها (جمع‌شونده) ----------
  static const List<_RegionInfo> _regions = [
    _RegionInfo(
      name: 'آمیگدال',
      title: 'آمیگدال — دیده‌بانِ هشدار',
      short:
          'مرکز هشدار مغز؛ تهدید را سریع تشخیص می‌دهد و بدن را آماده‌ی دفاع یا فرار می‌کند.',
      what:
          'ساختاری بادامی‌شکل و عمیق در لوب گیجگاهی. تهدید را (واقعی یا فقط فکرش) سریع تشخیص می‌دهد و بدن را آماده‌ی دفاع یا فرار می‌کند.',
      lack: 'روشن می‌شود؛ ذهن پشت هر اتفاقی دنبال خطر می‌گردد.',
      possibility: 'آرام می‌ماند؛ تهدید نمی‌بینی و بدن حس امنیت می‌کند.',
    ),
    _RegionInfo(
      name: 'PFC',
      title: 'PFC (قشر پیش‌پیشانی) — برنامه‌ریز',
      short:
          'جلوی لوب پیشانی؛ برنامه‌ریزی، تصمیم‌های بلندمدت و مهارِ واکنش‌های عجولانه.',
      what:
          'قشر پیش‌پیشانی، جلوی لوب پیشانی. مسئول برنامه‌ریزی، تصمیم‌های بلندمدت و مهار تکانه است و می‌تواند آمیگدال را آرام کند.',
      lack:
          'زیر فشارِ هشدار کم‌کار می‌شود؛ تصمیم‌های عجولانه و فلج تصمیم‌گیری.',
      possibility:
          'فعال می‌ماند؛ می‌توانی برنامه بریزی و قدمِ کوچکِ اول را برداری.',
    ),
    _RegionInfo(
      name: 'دوپامین',
      title: 'دوپامین — سیستم پاداش و انگیزه',
      short:
          'مسیر پاداش در عمق مغز؛ تعیین می‌کند فرصت‌ها را ببینی و برای قدم برداشتن انگیزه بگیری.',
      what:
          'دوپامین در اصل یک پیام‌رسان است، نه یک ناحیه. در این تصویر با ناحیه‌ی مرکزیِ مسیر پاداش (استریاتوم) نشان داده شده؛ منبعش در ساقه‌ی مغز است. در تصویر، جای دقیقش فقط تقریبی است.',
      lack: 'کم‌حساس می‌شود؛ فرصت‌ها دیده نمی‌شوند و حسِ «هیچ‌چیز خوب نیست» می‌آید.',
      possibility: 'حساس می‌شود؛ فرصت‌ها را می‌بینی و انگیزه‌ی قدم برداشتن می‌آید.',
    ),
    _RegionInfo(
      name: 'Salience',
      title: 'Salience (برجستگی) — فیلتر اهمیت',
      short:
          'شبکه‌ای که تعیین می‌کند چه چیزی «مهم» است و توجه‌ات سمت چه برود.',
      what:
          'شبکه‌ی برجستگی؛ شامل اینسولای جلویی و قشر کمربندیِ قدامی (ACC). تعیین می‌کند چه چیزی مهم است. در این تصویر فقط ACC دیده می‌شود؛ اینسولا در عمقِ کناره‌ی مغز است.',
      lack: 'روی خطر تنظیم می‌شود؛ فقط نشانه‌های منفی برجسته می‌شوند.',
      possibility:
          'روی خواسته تنظیم می‌شود؛ مثل گیرنده‌ی رادیو که موجِ امکان را می‌گیرد.',
    ),
  ];

  // ---------- ایستگاه‌های «هیچ شدن» (به ترتیب) ----------
  static const List<_Station> _stations = [
    _Station(
      name: 'بدن',
      title: 'بدن — «من بدنم نیستم»',
      areas: 'قشر حسی‌ـ‌پیکری (S1) و اینسولا',
      effect:
          'نقشه‌ی بدن و حس‌های درونی (ضربان، تنفس، درد) اینجا ساخته می‌شود. با برداشتن توجه از بدن، این ورودی کم‌صدا می‌شود و مرزِ بدن کم‌رنگ.',
      practice: 'توجه را از درد و حس‌های جسمی جدا کن.',
      after:
          'بدن رها شد: ورودیِ حسیِ بدن کم‌صدا شد و هشدار کمی پایین آمد. بعدی: هویت.',
    ),
    _Station(
      name: 'هویت',
      title: 'هویت — «من آن شخص نیستم»',
      areas: 'شبکه‌ی پیش‌فرض (DMN): mPFC و PCC',
      effect:
          'DMN داستانِ «من» (اسم، نقش، خاطره‌ها) را می‌سازد و در نشخوار فکری پرکار است. در مراقبه فعالیتش کاهش می‌یابد.',
      practice: 'اسم، نقش، گذشته و داستان‌هایت را برای لحظه‌ای کنار بگذار.',
      after:
          'هویت رها شد: DMN آرام‌تر شد و داستانِ «من» ساکت‌تر. بعدی: اشیا.',
    ),
    _Station(
      name: 'اشیا',
      title: 'اشیا — رها شدن از دارایی‌ها',
      areas: 'مسیر بینایی شکمی + مسیر پاداش',
      effect:
          'مغز اشیا را در مسیر بینایی شکمی می‌شناسد و مسیر پاداش به آن‌ها «ارزش» می‌دهد (می‌خواهم، دارم). با رها شدن، توجه از چیزها و ارزش‌گذاریِ آن‌ها جدا می‌شود.',
      practice: 'وابستگی به دارایی‌ها و شرایط بیرونی را رها کن.',
      after:
          'اشیا رها شد: ارزش‌گذاریِ چیزها خاموش‌تر شد. بعدی: زمان.',
    ),
    _Station(
      name: 'زمان',
      title: 'زمان — «در هیچ زمانی»',
      areas: 'هیپوکامپ + mPFC',
      effect:
          'هیپوکامپ گذشته را بازسازی می‌کند و همان مدار، آینده‌ی خیالی را می‌سازد (سفر ذهنی در زمان). با رها شدن، مغز روی «اکنون» می‌ماند.',
      practice: 'گذشته و آینده را رها کن؛ فقط حالِ بی‌زمان.',
      after:
          'زمان رها شد: مغز از ساختنِ گذشته و آینده دست کشید و روی اکنون ماند. بعدی: مکان.',
    ),
    _Station(
      name: 'مکان',
      title: 'مکان — «هیچ‌جا»',
      areas: 'لوبول آهیانه‌ای فوقانیِ خلفی (PSPL)',
      effect:
          'این ناحیه جای بدن در فضا را می‌سنجد (اینجا/آنجا، مرز «من» و بیرون). در پژوهش‌های مراقبه‌ی عمیق فعالیتش کم شده و مرز محو می‌شود.',
      practice: 'آگاهی را به «اینجا» و «آنجا» گره نزن.',
      after:
          'مکان رها شد: حسِ مرزِ «من» و بیرون محو شد. حالا «هیچ کامل».',
    ),
    _Station(
      name: 'هیچ کامل',
      title: 'هیچ کامل — جدایی از همه',
      areas: 'کل مغز',
      effect:
          'شبکه‌ی پیش‌فرض (نشخوار و داستانِ گذشته و آینده) کم‌فعال و آمیگدال آرام می‌شود. ذهن مثل یک میز خالی است: «آگاهی خالص». مغز در بهترین وضعیت برای نوروپلاستیسیتی (ساختن مسیرهای عصبی تازه) قرار دارد.',
      practice: 'چهار قدمِ علمیِ «اتصال به قلمرو ممکن‌ها» باز می‌شود.',
      after: '',
    ),
  ];

  // ---------- چهار قدمِ بعد از هیچ شدن ----------
  static const List<_Step> _steps = [
    _Step(
      title: '۱. سیگنال امکان، نه کمبود',
      region: 1,
      hint: 'روی PFC بزن',
      science:
          'مغز موتورِ پیش‌بینی است. اگر بعد از خالی شدن به کمبودها فکر کنی آمیگدال دوباره فعال می‌شود. یک «خواسته‌ی مشخص» در PFC مدلِ پیش‌بینیِ تازه می‌سازد.',
      action:
          'به‌جای «من پول ندارم» بگو «من در حال یادگیری مهارتی هستم که ارزش اقتصادی دارد».',
      after:
          'سیگنال امکان فرستاده شد: PFC فعال شد و مدلِ پیش‌بینیِ تازه ساخت.',
    ),
    _Step(
      title: '۲. توجه گزینشی',
      region: 3,
      hint: 'روی Salience بزن',
      science:
          'وقتی روی خواسته‌ی جدید تمرکز می‌کنی، شبکه‌ی Salience تعیین می‌کند به چه چیزی توجه کنی.',
      action:
          'هر صبح یا شب ۵ تا ۱۰ دقیقه روی خواسته تمرکز کن (نوشتن یا تجسم). مغز یاد می‌گیرد به‌جای موانع، فرصت‌ها را ببیند؛ این همان «هم‌فرکانسی» است: تنظیمِ فیلتر توجه.',
      after:
          'Salience روی خواسته تنظیم شد: فیلتر توجه به‌جای موانع، فرصت‌ها را می‌گیرد.',
    ),
    _Step(
      title: '۳. قدم کوچک و دوپامین',
      region: 2,
      hint: 'روی دوپامین بزن',
      science:
          'مغز برای باور به «ممکن بودن» مدرک می‌خواهد و فقط تجسم کافی نیست. یک قدم کوچک دوپامین (ناقلِ انگیزه) را فعال می‌کند.',
      action:
          'بلافاصله بعد از تمرکز یک اقدام فیزیکیِ کوچک بکن؛ مثلاً اگر می‌خواهی ورزشکار شوی، امروز ۵ دقیقه کشش.',
      after:
          'دوپامین فعال شد: مغز «مدرک» گرفت که این خواسته فقط خیال نیست.',
    ),
    _Step(
      title: '۴. هم‌ترازیِ شناختی',
      region: -1,
      hint: 'روی دایره‌ی پایین بزن',
      science:
          'فکر (باور به امکان‌پذیری، PFC) و احساس (آرامش و امنیت؛ اینسولا و آمیگدال آرام) و عمل (قدم‌های کوچکِ روزانه؛ سیستم پاداش) باید با هم هماهنگ شوند.',
      action:
          'خلاصه: «هیچ شدن» در را باز می‌کند؛ مدلِ پیش‌بینی را از «کمبود» به «فراوانی» بازنویسی کن و با قدم‌های کوچکِ روزانه به مغزت ثابت کن این مسیر امن و ممکن است.',
      after:
          'هم‌ترازی کامل شد: فکر، احساس و عمل با هم هماهنگ‌اند.',
    ),
  ];

  String _stateOf(int i) {
    switch (i) {
      case 0:
        return amygdalaAlert ? 'هشدار' : (amygdalaCalm ? 'آرام' : 'فعال');
      case 1:
        return pfcActive ? 'فعال' : (pfcWeak ? 'ضعیف' : 'متوسط');
      case 2:
        return dopamineSensitive
            ? 'حساس'
            : (dopamineLow ? 'کم‌حساس' : 'متوسط');
      default:
        return salienceTuned
            ? 'روی خواسته'
            : (salienceThreat ? 'روی خطر' : 'آزاد');
    }
  }

  Widget _accTile({
    required int id,
    required Color color,
    required String title,
    String? trailing,
    required Widget body,
  }) {
    final open = _openRegion == id;
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            _openRegion = open ? null : id;
            _stationOpen = null;
            _stepOpen = null;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing,
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more,
                      size: 20, color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 4, 10),
                  child: Align(alignment: Alignment.centerRight, child: body),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _infoLine(String label, String text, Color c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.w800, color: c),
            ),
            TextSpan(text: text),
          ],
        ),
        style: const TextStyle(fontSize: 11.5, height: 1.7, color: Colors.white70),
      ),
    );
  }

  Widget _explainCard() {
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.06),
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اطلاعات بخش‌های مغز',
            style: TextStyle(fontSize: 13, color: Colors.cyanAccent),
          ),
          const SizedBox(height: 2),
          const Text(
            'روی هر بخش بزن تا باز شود (همزمان فقط یکی باز می‌ماند).',
            style: TextStyle(fontSize: 10.5, color: Colors.white38),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < 4; i++) ...[
            divider,
            _accTile(
              id: i,
              color: _WavePainter._colors[i],
              title: _regions[i].title,
              trailing: _stateOf(i),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoLine('چیست', _regions[i].what, _WavePainter._colors[i]),
                  _infoLine('در کمبود', _regions[i].lack, Colors.redAccent),
                  _infoLine(
                      'در امکان', _regions[i].possibility, Colors.cyanAccent),
                ],
              ),
            ),
          ],
          divider,
          _accTile(
            id: 4,
            color: Colors.white70,
            title: 'راهنمای نماها',
            body: const Text(
              'مغز واقعی: روی هر نقطه بزن تا خلاصه‌اش همان‌جا بیاید. هرچه بخش فعال‌تر باشد نقطه‌اش درشت‌تر و موجش تندتر است. خط‌های رنگی مسیر پیام‌اند: قرمز از آمیگدال به PFC (هشدار)، آبی از PFC به آمیگدال (آرام‌کردن)، بنفش از دوپامین (انگیزه) و نارنجی از Salience (توجه).\n'
              'دایره و موج: هر بخش موج می‌فرستد؛ حلقه‌ی وسط «حالِ کلی» است: در امکان آرام و هماهنگ، در کمبود پرتلاطم. کاغذها فکرهای شلوغ‌اند که با «هیچ شدن» بیرون می‌روند.',
              style: TextStyle(fontSize: 11.5, height: 1.7, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'یادآوری: این یک مدلِ ساده‌شده و روی یک طرح خطی است؛ جای بخش‌ها تقریبی است و نقشه‌ی دقیقِ کار مغز نیست.',
            style: TextStyle(fontSize: 10.5, height: 1.6, color: Colors.white38),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // طراحی این صفحه برای زمینه‌ی تیره نوشته شده؛ پس همین‌جا تم تیره می‌گیرد
    // (فونت وزیرمتن از خود darkTheme برنامه می‌آید) و بقیه‌ی برنامه تغییری نمی‌کند.
    return Theme(
      data: darkTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  'از هیچ شدن تا هم‌فرکانسی',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                _viewToggle(),
                const SizedBox(height: 8),

                // صحنه
                if (viewMode == 2)
                  _brainScene()
                else if (viewMode == 1)
                  _waveScene()
                else
                  Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: double.infinity,
                  height: 380,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 20,
                        left: 80,
                        child: _node(
                          label: 'آمیگدال',
                          color: Colors.redAccent,
                          glow: amygdalaAlert || (!amygdalaCalm && !choiceMade),
                        ),
                      ),
                      Positioned(
                        top: 20,
                        right: 80,
                        child: _node(
                          label: 'PFC',
                          color: Colors.blueAccent,
                          glow: pfcActive,
                          dimmed: pfcWeak,
                        ),
                      ),
                      Positioned(
                        top: 100,
                        left: 80,
                        child: _node(
                          label: 'دوپامین',
                          color: Colors.purpleAccent,
                          glow: dopamineSensitive,
                          dimmed: dopamineLow,
                        ),
                      ),
                      Positioned(
                        top: 100,
                        right: 80,
                        child: _node(
                          label: 'Salience',
                          color: Colors.orangeAccent,
                          glow: salienceTuned,
                          dimmed: salienceThreat,
                        ),
                      ),

                      Positioned(
                        bottom: 60,
                        left: 40,
                        right: 40,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: 18,
                          decoration: BoxDecoration(
                            color: emptied
                                ? const Color(0xFF78350F)
                                : const Color(0xFF92400E),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),

                      ...List.generate(paperControllers.length, (i) {
                        final positions = [
                          const Offset(60, 220),
                          const Offset(110, 220),
                          const Offset(160, 220),
                          const Offset(210, 220),
                          const Offset(260, 220),
                          const Offset(85, 250),
                          const Offset(185, 250),
                        ];
                        return Positioned(
                          left: positions[i].dx,
                          top: positions[i].dy,
                          child: AnimatedBuilder(
                            animation: paperAnimations[i],
                            builder: (context, child) {
                              return Opacity(
                                opacity: paperAnimations[i].value,
                                child: Transform.translate(
                                  offset: Offset(
                                      0, -150 * (1 - paperAnimations[i].value)),
                                  child: Transform.rotate(
                                    angle: (1 - paperAnimations[i].value) * 0.8,
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 40,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        );
                      }),

                      Positioned(
                        bottom: 80,
                        left: 150,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 600),
                          scale: desireShown ? 1.0 : 0.0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 600),
                            opacity: desireShown ? 1.0 : 0.0,
                            child: Container(
                              width: 60,
                              height: 40,
                              decoration: BoxDecoration(
                                color: salienceThreat
                                    ? Colors.redAccent
                                    : Colors.cyanAccent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: (salienceThreat
                                            ? Colors.redAccent
                                            : Colors.cyanAccent)
                                        .withValues(alpha: 0.8),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // نمودار
                _chart(),

                // توضیح بخش‌ها
                _explainCard(),

                // وضعیت
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),

                // دکمه‌ها
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: emptied ? null : emptyMind,
                        child: const Text('۱. هیچ شدن'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black),
                        onPressed: emptied && !choiceMade
                            ? sendPossibilitySignal
                            : null,
                        child: const Text('۲. سیگنال امکان'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white),
                        onPressed:
                            emptied && !choiceMade ? sendLackSignal : null,
                        child: const Text('۲. سیگنال کمبود'),
                      ),
                      OutlinedButton(
                        onPressed: resetAll,
                        child: const Text('ریست'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════ نقاش نمای «دایره و موج» ════════════════
class _WavePainter extends CustomPainter {
  _WavePainter(this.s) : super(repaint: s._wave);
  final _NeuroSignalTabState s;

  static const _colors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
  ];
  static const _names = ['آمیگدال', 'PFC', 'دوپامین', 'Salience'];

  Path _ring(Offset c, double r0, double a1, double a2, double ph) {
    final p = Path();
    const n = 120;
    for (var i = 0; i <= n; i++) {
      final th = i / n * 2 * math.pi;
      final r = r0 +
          a1 * math.sin(3 * th + ph) +
          a2 * (math.sin(11 * th - 2 * ph) + 0.6 * math.sin(7 * th + 1.5 * ph));
      final pt = Offset(c.dx + r * math.cos(th), c.dy + r * math.sin(th));
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    return p;
  }

  void _label(Canvas canvas, String t, Offset center, double fs, Color col) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: GoogleFonts.vazirmatn(fontSize: fs, color: col),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final nodes = <Offset>[
      Offset(size.width * 0.18, size.height * 0.15),
      Offset(size.width * 0.82, size.height * 0.15),
      Offset(size.width * 0.18, size.height * 0.85),
      Offset(size.width * 0.82, size.height * 0.85),
    ];
    final lv = s._shown;
    final lack = s.amygdalaAlert;
    final poss = s.choiceMade && !lack;
    final centerColor =
        lack ? Colors.redAccent : (poss ? Colors.cyanAccent : Colors.amber);
    // 0 = آرام و هماهنگ ... 1 = پرتلاطم
    final chaos = (lv[0] - lv[1] * 0.6).clamp(0.0, 1.0).toDouble();

    // خط‌های اتصال + ذره‌های سیگنال که از هر بخش به مرکز می‌روند
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        nodes[i],
        c,
        Paint()
          ..color = _colors[i].withValues(alpha: 0.08 + 0.25 * lv[i])
          ..strokeWidth = 1.2,
      );
      final dot = Offset.lerp(nodes[i], c, s._nodePhase[i])!;
      canvas.drawCircle(
        dot,
        2.5 + 1.5 * lv[i],
        Paint()..color = _colors[i].withValues(alpha: 0.35 + 0.6 * lv[i]),
      );
    }

    // موج‌های دایره‌ای هر بخش
    for (var i = 0; i < 4; i++) {
      for (var k = 0; k < 3; k++) {
        final ph = (s._nodePhase[i] + k / 3) % 1.0;
        canvas.drawCircle(
          nodes[i],
          16 + ph * 70,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 + lv[i]
            ..color = _colors[i]
                .withValues(alpha: (1 - ph) * (0.12 + 0.55 * lv[i])),
        );
      }
      // هسته‌ی بخش
      final core = Paint()
        ..color = _colors[i].withValues(alpha: 0.25 + 0.75 * lv[i]);
      if (lv[i] > 0.6) {
        canvas.drawCircle(
          nodes[i],
          26,
          Paint()
            ..color = _colors[i].withValues(alpha: 0.6)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * lv[i]),
        );
      }
      canvas.drawCircle(nodes[i], 24, core);
      _label(canvas, _names[i], nodes[i], 10, Colors.white);
    }

    // حلقه‌ی مرکزی (حالِ کلی): آرام و هماهنگ ↔ دندانه‌دار و پرتلاطم
    final r0 = 56 + 10 * lv[1];
    final a1 = 5 + 3 * (1 - chaos);
    final a2 = 13 * chaos;
    for (var j = 0; j < 3; j++) {
      final path = _ring(
        c,
        r0 + j * 14,
        a1 * (1 - j * 0.25),
        a2 * (1 - j * 0.25),
        s._ringPhase + j * 0.7,
      );
      if (j == 0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = centerColor.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 - j * 0.7
          ..color = centerColor.withValues(alpha: 0.9 - j * 0.28),
      );
    }

    // هسته‌ی مرکز: «خواسته»
    final dl = s._desireShownLevel;
    final coreR = 6 + 16 * dl;
    canvas.drawCircle(
      c,
      coreR + 8,
      Paint()
        ..color = centerColor.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(c, coreR, Paint()..color = centerColor);

    // کاغذهای فکرهای شلوغ؛ با «هیچ شدن» به بیرون می‌روند و محو می‌شوند
    for (var i = 0; i < s.paperAnimations.length; i++) {
      final v = s.paperAnimations[i].value;
      if (v < 0.01) continue;
      final ang = i / s.paperAnimations.length * 2 * math.pi + s._ringPhase * 0.12;
      final jit = math.sin(s._ringPhase * 3 + i) * 4 * chaos;
      final dist = 112 + jit + (1 - v) * 150;
      final pos = Offset(c.dx + dist * math.cos(ang), c.dy + dist * math.sin(ang));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(ang + (1 - v) * 0.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-13, -9, 26, 18),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.amber.withValues(alpha: v),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => true;
}

const Color _kStationColor = Color(0xFF5EEAD4);

String _faDigits(int n) {
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return n.toString().split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : fa[d];
  }).join();
}

class _Station {
  const _Station({
    required this.name,
    required this.title,
    required this.areas,
    required this.effect,
    required this.practice,
    required this.after,
  });
  final String name, title, areas, effect, practice, after;
}

class _Step {
  const _Step({
    required this.title,
    required this.region,
    required this.hint,
    required this.science,
    required this.action,
    required this.after,
  });
  final String title, hint, science, action, after;
  final int region; // اندیسِ بخش در _regions (-۱ = ترکیبی)
}

class _RegionInfo {
  const _RegionInfo({
    required this.name,
    required this.title,
    required this.short,
    required this.what,
    required this.lack,
    required this.possibility,
  });
  final String name, title, short, what, lack, possibility;
}

// ════════════════ نقاش نمای «مغز واقعی» ════════════════
class _BrainPainter extends CustomPainter {
  _BrainPainter(this.s) : super(repaint: s._wave);
  final _NeuroSignalTabState s;

  /// جای هر بخش روی تصویر (نسبت به عرض و ارتفاع): آمیگدال، PFC، دوپامین، Salience
  static const List<Offset> pos = [
    Offset(0.478, 0.440), // آمیگدال: بیضیِ کوچک در عمق لوب گیجگاهی
    Offset(0.280, 0.260), // PFC: لوب پیشانی (جلوی مغز، سمت چپ تصویر)
    Offset(0.560, 0.375), // دوپامین: ناحیه‌ی مرکزیِ مسیر پاداش
    Offset(0.440, 0.295), // Salience: قشر کمربندی قدامی (ACC)
  ];
  static const List<Offset> _labelOff = [
    Offset(0, 30),
    Offset(0, -28),
    Offset(44, 0),
    Offset(30, -26),
  ];
  /// جای ایستگاه‌های «هیچ شدن»: بدن (S1)، هویت (PCC)، اشیا (مسیر بینایی شکمی)،
  /// زمان (هیپوکامپ)، مکان (PSPL)؛ و دایره‌ی «هیچ کامل / هم‌ترازی» زیر مغز.
  static const List<Offset> stPos = [
    Offset(0.595, 0.15),
    Offset(0.69, 0.28),
    Offset(0.80, 0.46),
    Offset(0.60, 0.465),
    Offset(0.76, 0.17),
    Offset(0.46, 0.74),
  ];
  static const List<Offset> _stLabelOff = [
    Offset(-6, -22),
    Offset(0, -22),
    Offset(0, 22),
    Offset(14, 28),
    Offset(0, -20),
    Offset(0, 36),
  ];
  // سرِ دیگرِ شبکه‌ی پیش‌فرض (mPFC) برای نمایش اتصالش به PCC
  static const Offset _mPfc = Offset(0.33, 0.33);

  // مسیر پیام: مبدأ، مقصد، جهت انحنا
  static const List<List<int>> _links = [
    [0, 1, 1], // آمیگدال → PFC (هشدار)
    [1, 0, -1], // PFC → آمیگدال (آرام‌کردن)
    [2, 1, 1], // دوپامین → PFC (انگیزه)
    [3, 1, -1], // Salience → PFC (توجه)
  ];

  void _pill(Canvas canvas, String text, Offset center, Color c, double k,
      {bool selected = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.vazirmatn(
          fontSize: math.max(9.0, 10 * k),
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: tp.width + 12,
        height: tp.height + 4,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xCC0F172A));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.6 : 1
        ..color = c.withValues(alpha: selected ? 0.95 : 0.55),
    );
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 340.0;
    final lv = s._shown;
    final pts = [for (final o in pos) Offset(o.dx * size.width, o.dy * size.height)];
    final sp = [
      for (final o in stPos) Offset(o.dx * size.width, o.dy * size.height)
    ];

    // آگاهیِ خالص: هاله‌ی نرمِ نفس‌کشنده روی کل مغز
    final vl = s._voidLevel;
    if (vl > 0.01) {
      final bc = Offset(size.width * 0.52, size.height * 0.34);
      final br = size.width * (0.5 + 0.03 * math.sin(s._ringPhase * 0.6));
      canvas.drawCircle(
        bc,
        br,
        Paint()
          ..shader = RadialGradient(colors: [
            _kStationColor.withValues(alpha: 0.22 * vl),
            _kStationColor.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: bc, radius: br)),
      );
    }

    // مسیرهای پیام بین بخش‌ها + نقطه‌هایی که روی مسیر حرکت می‌کنند
    for (final l in _links) {
      final a = pts[l[0]], b = pts[l[1]];
      final st = lv[l[0]];
      final mid = Offset.lerp(a, b, 0.5)!;
      final d = b - a;
      final n = Offset(-d.dy, d.dx) / d.distance;
      final ctrl = mid + n * (l[2] * 0.22 * d.distance);
      final col = _WavePainter._colors[l[0]];
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * k
          ..color = col.withValues(alpha: 0.06 + 0.24 * st),
      );
      for (var m = 0; m < 3; m++) {
        final t = (s._nodePhase[l[0]] + m / 3) % 1.0;
        final u = 1 - t;
        final pt = a * (u * u) + ctrl * (2 * u * t) + b * (t * t);
        canvas.drawCircle(
          pt,
          (1.8 + 1.8 * st) * k,
          Paint()..color = col.withValues(alpha: 0.25 + 0.7 * st),
        );
      }
    }

    // خودِ بخش‌ها: درخشش، موج‌های تپنده و هسته
    for (var i = 0; i < 4; i++) {
      final c = pts[i];
      final col = _WavePainter._colors[i];
      final l = lv[i];
      canvas.drawCircle(
        c,
        (12 + 22 * l) * k,
        Paint()
          ..color = col.withValues(alpha: 0.10 + 0.32 * l)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * k + 6 * l),
      );
      for (var m = 0; m < 3; m++) {
        final ph = (s._nodePhase[i] + m / 3) % 1.0;
        canvas.drawCircle(
          c,
          (7 + ph * (16 + 14 * l)) * k,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 * k
            ..color = col.withValues(alpha: (1 - ph) * (0.15 + 0.6 * l)),
        );
      }
      canvas.drawCircle(
        c,
        (5 + 3 * l) * k,
        Paint()..color = col.withValues(alpha: 0.55 + 0.45 * l),
      );
      canvas.drawCircle(
        c,
        1.8 * k,
        Paint()..color = Colors.white.withValues(alpha: 0.4 + 0.5 * l),
      );
      // بعد از هیچ شدن، سه بخش «قدم» هم هستند (شماره روی برچسبشان می‌آید)
      final stepK = s.emptied ? _NeuroSignalTabState._regionStep[i] : -1;
      final selected =
          s._openRegion == i || (stepK >= 0 && s._stepOpen == stepK);
      if (selected) {
        canvas.drawCircle(
          c,
          22 * k,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 * k
            ..color = Colors.white.withValues(alpha: 0.85),
        );
      }
      // پیش از هیچ شدن برچسبِ این چهار بخش پنهان است تا صحنه شلوغ نشود
      if (s.emptied || selected) {
        final name = _NeuroSignalTabState._regions[i].name;
        final label = stepK < 0
            ? name
            : (s._stepDone[stepK]
                ? '✓ $name'
                : '${_faDigits(stepK + 1)} · $name');
        _pill(canvas, label, c + _labelOff[i] * k, col, k, selected: selected);
      }
    }

    _paintAlignment(canvas, pts, k);
    _paintStations(canvas, sp, k);
  }

  // قدم ۴: مثلثِ طلاییِ هم‌ترازی میان فکر (PFC)، احساس (آمیگدال) و عمل (دوپامین)
  void _paintAlignment(Canvas canvas, List<Offset> pts, double k) {
    if (!s._aligned) return;
    final pulse = 0.5 + 0.5 * math.sin(s._ringPhase * 1.5);
    final tri = Path()
      ..moveTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..close();
    canvas.drawPath(
      tri,
      Paint()..color = Colors.amberAccent.withValues(alpha: 0.10 + 0.08 * pulse),
    );
    canvas.drawPath(
      tri,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * k
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.amberAccent.withValues(alpha: 0.55 + 0.3 * pulse),
    );
  }

  // ایستگاه‌های هیچ شدن: نقطه، موج، برچسب و علامتِ «رها شد»
  void _paintStations(Canvas canvas, List<Offset> sp, double k) {
    final open = s._stationOpen;

    // خطِ شبکه‌ی پیش‌فرض: PCC ↔ mPFC وقتی «هویت» باز است
    if (open == 1) {
      final m = Offset(_mPfc.dx * k * 340, _mPfc.dy * k * 340 * 5000 / 4702);
      canvas.drawLine(
        sp[1],
        m,
        Paint()
          ..strokeWidth = 1.6 * k
          ..color = _kStationColor.withValues(alpha: 0.7),
      );
      canvas.drawCircle(m, 4 * k, Paint()..color = _kStationColor);
    }

    final allReleased = s._released.length >= 5;
    for (var i = 0; i < 6; i++) {
      final c = sp[i];
      final selected = open == i || (i == 5 && s._stepOpen == 3);
      if (i < 5) {
        final l = s._st[i];
        final released = s._released.contains(i);
        final isNext = !s.emptied && s._released.length == i;
        // درخششِ ایستگاهِ درگیر
        canvas.drawCircle(
          c,
          (9 + 14 * l) * k,
          Paint()
            ..color = _kStationColor.withValues(alpha: 0.05 + 0.30 * l)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * k),
        );
        for (var m = 0; m < 3; m++) {
          final ph = (s._ringPhase * 0.25 + i * 0.3 + m / 3) % 1.0;
          canvas.drawCircle(
            c,
            (6 + ph * 20) * k,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2 * k
              ..color = _kStationColor.withValues(alpha: (1 - ph) * 0.5 * l),
          );
        }
        // حلقه‌ی «بعدی» که باید رها شود
        if (isNext) {
          final p = 0.5 + 0.5 * math.sin(s._ringPhase * 2);
          canvas.drawCircle(
            c,
            (13 + 3 * p) * k,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6 * k
              ..color = Colors.white.withValues(alpha: 0.45 + 0.4 * p),
          );
        }
        canvas.drawCircle(
          c,
          5 * k,
          Paint()..color = _kStationColor.withValues(alpha: 0.30 + 0.65 * l),
        );
        if (released) {
          // علامتِ تیک وقتی رها شد
          final a = (1 - l).clamp(0.0, 1.0).toDouble();
          canvas.drawCircle(
            c,
            8 * k,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2 * k
              ..color = _kStationColor.withValues(alpha: 0.5 * a),
          );
          final tick = Path()
            ..moveTo(c.dx - 3 * k, c.dy)
            ..lineTo(c.dx - 0.8 * k, c.dy + 2.4 * k)
            ..lineTo(c.dx + 3.4 * k, c.dy - 2.6 * k);
          canvas.drawPath(
            tick,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6 * k
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white.withValues(alpha: a),
          );
        }
        if (selected) {
          canvas.drawCircle(
            c,
            20 * k,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6 * k
              ..color = Colors.white.withValues(alpha: 0.85),
          );
        }
        final name = _NeuroSignalTabState._stations[i].name;
        _pill(canvas, released ? '✓ $name' : '${_faDigits(i + 1)} · $name',
            c + _stLabelOff[i] * k, _kStationColor, k,
            selected: selected);
      } else {
        // دایره‌ی پایین: «هیچ کامل» (تا قبل از هیچ شدن) و بعد «هم‌ترازی»
        final p = 0.5 + 0.5 * math.sin(s._ringPhase * 1.6);
        final afterNothing = s.emptied;
        final ready = afterNothing
            ? (s._curStep == 3 && !s.amygdalaAlert)
            : allReleased;
        final col = afterNothing ? Colors.amberAccent : _kStationColor;
        final base = afterNothing ? (s._aligned ? 1.0 : 0.35) : (ready ? 0.8 : 0.18);
        final r = (15 + (ready ? 2.5 * p : 0)) * k;
        canvas.drawCircle(
          c,
          r + 8 * k,
          Paint()
            ..color = col.withValues(alpha: 0.10 + 0.35 * base * (0.7 + 0.3 * p))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * k),
        );
        canvas.drawCircle(
          c,
          r,
          Paint()..color = col.withValues(alpha: 0.12 + 0.5 * base),
        );
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (selected ? 2.0 : 1.3) * k
            ..color = (selected ? Colors.white : col)
                .withValues(alpha: selected ? 0.9 : 0.4 + 0.5 * base),
        );
        canvas.drawCircle(
          c,
          3 * k,
          Paint()..color = Colors.white.withValues(alpha: 0.3 + 0.6 * base),
        );
        final label = afterNothing
            ? (s._aligned ? '✓ هم‌ترازی' : '۴ · هم‌ترازی')
            : 'هیچ کامل';
        _pill(canvas, label, c + _stLabelOff[5] * k, col, k,
            selected: selected);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BrainPainter old) => true;
}
