import 'dart:math' as math;
import 'package:flutter/material.dart';

const _kEmerald500 = Color(0xFF2BBFAB);
const _kEmerald700 = Color(0xFF0F5B53);
const _kGold500 = Color(0xFFC9972B);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kCard = Colors.white;

class _Layer {
  final String key;
  final String chip;
  final String title;
  final String desc;
  final double baseR;
  final double amp;
  final double freq;
  final double phase;
  const _Layer({
    required this.key,
    required this.chip,
    required this.title,
    required this.desc,
    required this.baseR,
    required this.amp,
    required this.freq,
    required this.phase,
  });
}

const List<_Layer> _layers = [
  _Layer(key: 'body',  chip: 'بدن',  title: 'No body',    desc: 'من بدنم نیستم. توجه از بدن، دردها و حس‌های جسمی جدا می‌شه.',           baseR: 105, amp: 11.0, freq: 3, phase: 0.0),
  _Layer(key: 'one',   chip: 'هویت', title: 'No one',     desc: 'من اون شخصیت، اسم، نقش، گذشته و داستان‌هام نیستم.',                  baseR: 88,  amp: 9.5,  freq: 4, phase: 0.8),
  _Layer(key: 'thing', chip: 'اشیا', title: 'No thing',   desc: 'وابستگی به اشیا، دارایی‌ها و شرایط بیرونی رها می‌شه.',                baseR: 72,  amp: 8.0,  freq: 5, phase: 1.6),
  _Layer(key: 'where', chip: 'مکان', title: 'No where',   desc: 'آگاهی به اینجا و آنجا گره نخورده.',                                    baseR: 56,  amp: 6.5,  freq: 6, phase: 2.4),
  _Layer(key: 'time',  chip: 'زمان', title: 'In no time', desc: 'گذشته و آینده رها می‌شن و فقط حالِ بی‌زمان می‌مونه.',                baseR: 40,  amp: 5.0,  freq: 7, phase: 3.2),
];

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
        // صحنه
        AspectRatio(
          aspectRatio: 1,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _NothingPainter(
                t: _ctrl.value,
                doneLayers: widget.doneLayers,
                progress: progress,
              ),
              child: Stack(
                children: [
                  // چیپ‌های داخل دایره
                  ..._buildChips(),
                  // برچسب «آگاهی خالص»
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'آگاهی خالص',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _kEmerald700,
                          letterSpacing: 0.4,
                          shadows: [
                            Shadow(
                              color: _kGold500.withValues(alpha: 0.2 + progress * 0.5),
                              blurRadius: 4 + progress * 8,
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

        // ۵ دکمه
        ..._layers.map((l) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _LayerButton(
            number: (_layers.indexOf(l) + 1).toString(),
            title: l.title,
            desc: l.desc,
            isDone: widget.doneLayers.contains(l.key),
            onTap: () => widget.onToggle(l.key),
          ),
        )),

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

        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () {
              for (final l in _layers) {
                if (widget.doneLayers.contains(l.key)) widget.onToggle(l.key);
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
    // دو ردیف چیپ داخل دایره: [بدن][هویت] / [اشیا][مکان] / [زمان]
    return _layers.map((l) {
      final isDone = widget.doneLayers.contains(l.key);
      // ترتیب: body, one → ردیف اول؛ thing, where → ردیف دوم؛ time → ردیف سوم
      return Align(
        alignment: _alignmentFor(l.key),
        child: AnimatedOpacity(
          opacity: isDone ? 0 : 1,
          duration: const Duration(milliseconds: 500),
          child: GestureDetector(
            onTap: () => widget.onToggle(l.key),
            child: Container(
              margin: const EdgeInsets.all(2),
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
                l.chip,
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

  Alignment _alignmentFor(String key) {
    // چیدمان مثل وب:
    //      [بدن] [هویت]
    //      [اشیا] [مکان]
    //         [زمان]
    switch (key) {
      case 'body':  return const Alignment(-0.38, -0.62);
      case 'one':   return const Alignment( 0.38, -0.62);
      case 'thing': return const Alignment(-0.38, -0.20);
      case 'where': return const Alignment( 0.38, -0.20);
      case 'time':  return const Alignment( 0.0,  0.22);
    }
    return Alignment.center;
  }
}

class _LayerButton extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  final bool isDone;
  final VoidCallback onTap;

  const _LayerButton({
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

class _NothingPainter extends CustomPainter {
  final double t;
  final Set<String> doneLayers;
  final double progress;

  _NothingPainter({
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

    // موج‌های ۵ لایه
    for (final l in _layers) {
      final isDone = doneLayers.contains(l.key);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF8B8FA8).withValues(alpha: isDone ? 0.15 : 0.78);

      final path = _sinePath(
        baseR: l.baseR,
        amp: isDone ? 0 : l.amp,
        freq: l.freq,
        phase: l.phase + phase * (isDone ? 1.8 : 1.0),
      );
      canvas.drawPath(path, paint);
    }

    // هسته‌ی نورانی
    final allDone = doneLayers.length >= 5;
    final pureAmp = allDone ? 0.4 : 1.6;
    final purePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _kGold500.withValues(alpha: 0.9);
    canvas.drawPath(
      _sinePath(baseR: 26, amp: pureAmp, freq: 8, phase: phase * 2.4),
      purePaint,
    );

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

    // حلقه‌ی مرکزی
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 + progress * 1.2
      ..color = _kGold500.withValues(alpha: 0.45 + progress * 0.5);
    canvas.drawCircle(Offset.zero, 24, ringPaint);

    // نقطه‌ی مرکزی
    final dotPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, _kGold500],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 8));
    canvas.drawCircle(Offset.zero, 8 + progress * 3, dotPaint);

    canvas.restore();
  }

  Path _sinePath({
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
  bool shouldRepaint(covariant _NothingPainter old) =>
      old.t != t ||
      old.progress != progress ||
      old.doneLayers.length != doneLayers.length;
}
