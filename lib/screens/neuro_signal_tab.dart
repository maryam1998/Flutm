import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/vazir_font.dart';

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

  // ---------- نمای «دایره و موج» ----------
  bool waveView = true;
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
    return 0.85;
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('دایره و موج'),
          selected: waveView,
          onSelected: (_) => setState(() => waveView = true),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('گره‌ها'),
          selected: !waveView,
          onSelected: (_) => setState(() => waveView = false),
        ),
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

  // ---------- توضیح بخش‌ها ----------
  Widget _explainRow(Color c, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.7,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _explainCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: darkTheme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: const Text(
            'این بخش‌ها یعنی چی؟',
            style: TextStyle(fontSize: 13, color: Colors.cyanAccent),
          ),
          children: [
            _explainRow(
              Colors.redAccent,
              'آمیگدال — دیده‌بانِ هشدار',
              'مرکز هشدار مغز است. وقتی خطری حس کند (واقعی یا فقط فکرش) روشن می‌شود؛ بدن آماده‌ی دفاع یا فرار می‌شود و ذهن پشت هر اتفاقی دنبال تهدید می‌گردد.',
            ),
            _explainRow(
              Colors.blueAccent,
              'PFC (قشر پیش‌پیشانی) — برنامه‌ریز',
              'بخشِ برنامه‌ریزی و تصمیم‌های بلندمدت. زیر فشارِ هشدار کم‌کار می‌شود؛ برای همین در ترس و کمبود تصمیم‌های عجولانه می‌گیریم.',
            ),
            _explainRow(
              Colors.purpleAccent,
              'دوپامین — سیستم پاداش و انگیزه',
              'وقتی حساس باشد فرصت‌ها و چیزهای خوب را می‌بینی و دلت می‌خواهد قدم برداری. وقتی کم‌حساس شود، حسِ «هیچ‌چیز خوب نیست» می‌آید.',
            ),
            _explainRow(
              Colors.orangeAccent,
              'Salience (برجستگی) — فیلتر اهمیت',
              'تعیین می‌کند چه چیزی «مهم» است و توجه‌ات سمت چه برود. مثل گیرنده‌ی رادیو روی یک موج تنظیم می‌شود: یا موجِ خطر، یا موجِ امکان.',
            ),
            const SizedBox(height: 2),
            const Text(
              'در نمای «دایره و موج»: هر بخش موج می‌فرستد و هرچه فعال‌تر باشد موجش تندتر و پررنگ‌تر است. حلقه‌ی وسط «حالِ کلی» است: در امکان آرام و هماهنگ، در کمبود پرتلاطم و دندانه‌دار. کاغذهای دورِ حلقه همان فکرهای شلوغ‌اند که با «هیچ شدن» بیرون می‌روند.',
              style: TextStyle(fontSize: 11.5, height: 1.7, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'یادآوری: این یک مدلِ ساده‌شده برای فهمیدن است، نه نقشه‌ی دقیقِ کار مغز.',
              style: TextStyle(fontSize: 10.5, height: 1.6, color: Colors.white38),
            ),
          ],
        ),
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
                if (waveView) _waveScene() else Container(
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
