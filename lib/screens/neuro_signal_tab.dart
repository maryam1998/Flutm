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
                            onTap: () => setState(
                                () => _openRegion = open == i ? null : i),
                          ),
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
          onTap: () => setState(() => _openRegion = open ? null : id),
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
      final selected = s._openRegion == i;
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
      _pill(canvas, _NeuroSignalTabState._regions[i].name,
          c + _labelOff[i] * k, col, k,
          selected: selected);
    }
  }

  @override
  bool shouldRepaint(covariant _BrainPainter old) => true;
}
