import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
  }

  @override
  void dispose() {
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

                // صحنه
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
