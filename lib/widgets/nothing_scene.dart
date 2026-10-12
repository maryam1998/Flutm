import 'dart:math' as math;
import 'package:flutter/material.dart';

const _kEmerald500 = Color(0xFF2BBFAB);
const _kEmerald700 = Color(0xFF0F5B53);
const _kGold500 = Color(0xFFC9972B);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kCard = Colors.white;

class LayerWave {
  final double baseR, amp, freq, phase;
  final Color color;
  const LayerWave({
    required this.baseR,
    required this.amp,
    required this.freq,
    required this.phase,
    required this.color,
  });
}

const Map<String, LayerWave> kLayerWaves = {
  'body':  LayerWave(baseR: 105, amp: 11.0, freq: 3, phase: 0.0, color: Color(0xFF8B8FA8)),
  'one':   LayerWave(baseR: 88,  amp: 9.5,  freq: 4, phase: 0.8, color: Color(0xFFA0A4B8)),
  'thing': LayerWave(baseR: 72,  amp: 8.0,  freq: 5, phase: 1.6, color: Color(0xFFB0B4C8)),
  'where': LayerWave(baseR: 56,  amp: 6.5,  freq: 6, phase: 2.4, color: Color(0xFFC0C4D8)),
  'time':  LayerWave(baseR: 40,  amp: 5.0,  freq: 7, phase: 3.2, color: Color(0xFFD0D4E8)),
};

const List<String> kLayerKeys = ['body', 'one', 'thing', 'where', 'time'];

const List<Map<String, String>> kLayerLabels = [
  {'key': 'body',  'chip': 'بدن',  'title': 'No body',  'desc': 'من بدنم نیستم. توجه از بدن، دردها و حس‌های جسمی جدا می‌شه.'},
  {'key': 'one',   'chip': 'هویت', 'title': 'No one',   'desc': 'من اون شخصیت، اسم، نقش، گذشته و داستان‌هام نیستم.'},
  {'key': 'thing', 'chip': 'اشیا', 'title': 'No thing', 'desc': 'وابستگی به اشیا، دارایی‌ها و شرایط بیرونی رها می‌شه.'},
  {'key': 'where', 'chip': 'مکان', 'title': 'No where', 'desc': 'آگاهی به اینجا و آنجا گره نخورده.'},
  {'key': 'time',  'chip': 'زمان', 'title': 'In no time', 'desc': 'گذشته و آینده رها می‌شن و فقط حالِ بی‌زمان می‌مونه.'},
];

/// صحنه‌ی «هیچ شدن» — ۵ موج سینوسی + هسته‌ی نورانی + چیپ‌ها + دکمه‌ها
class NothingScene extends StatefulWidget {
  final Set<String> doneLayers;
  final ValueChanged<String> onToggle;

  const NothingScene({
    super.key,
    required this.doneLayers,
    required this.onToggle,
  });

  @override
  State<NothingScene> createState() => _NothingSceneState();
}

class _NothingSceneState extends State<NothingScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = widget.doneLayers.length;
    final progress = doneCount / 5.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // صحنه‌ی موج‌ها
        AspectRatio(
          aspectRatio: 1,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _NothingWavePainter(
                t: _ctrl.value,
                doneLayers: widget.doneLayers,
                progress: progress,
              ),
              child: Stack(
                children: [
                  // چیپ‌های پنج‌گانه
                  ..._buildChips(),
                  // برچسب آگاهی خالص
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'آگاهی خالص',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _kEmerald700,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: _kGold500.withValues(alpha: 0.5 * progress),
                              blurRadius: 8 * progress,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ۵ دکمه‌ی مرحله
        ...kLayerLabels.map((m) {
          final key = m['key']!;
          final isDone = widget.doneLayers.contains(key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _LayerStepButton(
              number: (kLayerKeys.indexOf(key) + 1).toString(),
              title: m['title']!,
              desc: m['desc']!,
              isDone: isDone,
              onTap: () => widget.onToggle(key),
            ),
          );
        }),

        const SizedBox(height: 8),

        // پیام پایانی
        AnimatedOpacity(
          opacity: doneCount >= 5 ? 1 : 0,
          duration: const Duration(milliseconds: 800),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PulseDot(),
                SizedBox(width: 8),
                Text(
                  'Pure consciousness — آگاهی خالص',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _kEmerald700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        // دکمه‌ی ریست
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () {
              for (final k in kLayerKeys) {
                if (widget.doneLayers.contains(k)) widget.onToggle(k);
              }
            },
            child: const Text(
              '↺ شروع دوباره',
              style: TextStyle(fontSize: 11.5, color: _kMuted),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChips() {
    // موقعیت چیپ‌ها حول هسته (نسبت به مربع)
    const positions = <String, Alignment>{
      'body':  Alignment(-0.42, -0.35),
      'one':   Alignment(0.42, -0.35),
      'thing': Alignment(-0.42, 0.42),
      'where': Alignment(0.42, 0.42),
      'time':  Alignment(0.0, 0.05),
    };

    return kLayerLabels.map((m) {
      final key = m['key']!;
      final isDone = widget.doneLayers.contains(key);
      return Align(
        alignment: positions[key]!,
        child: AnimatedOpacity(
          opacity: isDone ? 0 : 1,
          duration: const Duration(milliseconds: 500),
          child: GestureDetector(
            onTap: () => widget.onToggle(key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kCard.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                m['chip']!,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: _kEmerald700,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ═══════════════ Painter ═══════════════
class _NothingWavePainter extends CustomPainter {
  final double t; // 0..1 cycle
  final Set<String> doneLayers;
  final double progress;

  _NothingWavePainter({
    required this.t,
    required this.doneLayers,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width / 300.0;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);

    final phase = t * 2 * math.pi;

    // ۵ موج لایه‌ای
    for (final key in kLayerKeys) {
      final wave = kLayerWaves[key]!;
      final isDone = doneLayers.contains(key);
      final targetAmp = isDone ? 0.0 : wave.amp;
      // انیمیشن نرم برای کاهش دامنه
      final curAmp = targetAmp; // ساده: مستقیم

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = wave.color.withValues(alpha: isDone ? 0.15 : 0.78);

      final path = _buildSinePath(
        baseR: wave.baseR,
        amp: curAmp,
        freq: wave.freq,
        phase: wave.phase + phase * (isDone ? 1.8 : 1.0),
      );
      canvas.drawPath(path, paint);
    }

    // هسته‌ی نورانی
    final allDone = doneLayers.length >= 5;
    final pureAmp = allDone ? 0.4 : 1.6;
    final purePath = _buildSinePath(
      baseR: 26,
      amp: pureAmp,
      freq: 8,
      phase: phase * 2.4,
    );
    final purePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _kGold500.withValues(alpha: 0.9);
    canvas.drawPath(purePath, purePaint);

    // هاله‌ی هسته
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _kGold500.withValues(alpha: 0.20 + progress * 0.55),
          _kEmerald500.withValues(alpha: 0.08 + progress * 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 0.72],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 75));
    canvas.drawCircle(Offset.zero, 75, glowPaint);

    // حلقه‌ی هسته
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 + progress * 1.2
      ..color = _kGold500.withValues(alpha: 0.45 + progress * 0.5);
    canvas.drawCircle(Offset.zero, 24, ringPaint);

    // نقطه‌ی مرکزی
    final dotPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          _kGold500,
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 8));
    canvas.drawCircle(Offset.zero, 8 + progress * 3, dotPaint);

    canvas.restore();
  }

  Path _buildSinePath({
    required double baseR,
    required double amp,
    required double freq,
    required double phase,
  }) {
    final path = Path();
    const pts = 160;
    for (var i = 0; i <= pts; i++) {
      final theta = (i / pts) * 2 * math.pi;
      final r = baseR + amp * math.sin(freq * theta + phase);
      final x = r * math.cos(theta);
      final y = r * math.sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _NothingWavePainter old) =>
      old.t != t || old.progress != progress ||
      old.doneLayers.length != doneLayers.length;
}

// ═══════════════ دکمه‌ی هر لایه ═══════════════
class _LayerStepButton extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  final bool isDone;
  final VoidCallback onTap;

  const _LayerStepButton({
    required this.number,
    required this.title,
    required this.desc,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFDCF3EE) : _kCard,
          border: Border.all(
            color: isDone ? const Color(0xFF54C9B8) : _kBorder,
            width: isDone ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDone ? _kEmerald500 : const Color(0xFFDCF3EE),
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDone ? Colors.white : _kEmerald700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _kEmerald700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: _kMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isDone ? '✓' : '○',
              style: TextStyle(
                fontSize: 14,
                color: isDone ? _kEmerald700 : _kMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════ نقطه‌ی تپنده ═══════════════
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final s = 1 + _c.value * 0.15;
        return Container(
          width: 8 * s,
          height: 8 * s,
          decoration: BoxDecoration(
            color: _kEmerald500,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _kEmerald500.withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
