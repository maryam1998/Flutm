import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _kGreen = Color(0xFF178A7C);

const _kPraise = <String>[
  'آفرین! ✨',
  'یه قدم دیگه جلو رفتی 👣',
  'مغزت همین الان یه امتیاز گرفت 🧠',
  'قدم‌های کوچیک آدم رو می‌رسونه 🌱',
  'عالی بود! 🎉',
  'دیدی سخت نبود؟ 😄',
  'همین الان پیشرفت کردی 🚀',
];
int _lastPraise = -1;

String _pickPraise() {
  var i = math.Random().nextInt(_kPraise.length);
  if (i == _lastPraise) i = (i + 1) % _kPraise.length;
  _lastPraise = i;
  return _kPraise[i];
}

/// پاداش فوریِ بعد از تیک زدنِ یک قدم: صدای سکه + لرزش + انیمیشن کوتاه (~۱.۴ ثانیه).
/// روی Overlay ریشه می‌آید، پس روی پنجره‌ی اهداف هم دیده می‌شود.
class StepReward {
  StepReward._();

  static AudioPlayer? _player;
  static OverlayEntry? _entry;

  static void play(BuildContext context, {String? sub}) {
    HapticFeedback.mediumImpact();
    _sound();
    final ov = Overlay.maybeOf(context, rootOverlay: true);
    if (ov == null) return;
    final old = _entry;
    if (old != null) {
      _entry = null;
      try {
        old.remove();
      } catch (_) {}
    }
    final title = _pickPraise();
    late final OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => _RewardBurst(
        title: title,
        sub: sub,
        onDone: () {
          if (_entry == e) {
            _entry = null;
            try {
              e.remove();
            } catch (_) {}
          }
        },
      ),
    );
    _entry = e;
    ov.insert(e);
  }

  static Future<void> _sound() async {
    try {
      final p = _player ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.stop();
      await p.play(AssetSource('coin.wav'), volume: 0.6);
    } catch (_) {
      // بدون صدا هم کار می‌کنه
    }
  }
}

class _RewardBurst extends StatefulWidget {
  const _RewardBurst({required this.title, this.sub, required this.onDone});
  final String title;
  final String? sub;
  final VoidCallback onDone;

  @override
  State<_RewardBurst> createState() => _RewardBurstState();
}

class _RewardBurstState extends State<_RewardBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward().whenComplete(() {
      if (mounted) widget.onDone();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Align(
            alignment: const Alignment(0, -0.45),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final t = _c.value;
                final pop = Curves.elasticOut.transform((t / 0.4).clamp(0.0, 1.0));
                final fade = t > 0.75 ? (1 - (t - 0.75) / 0.25) : 1.0;
                return SizedBox(
                  width: 300,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: const Size(300, 220),
                        painter: _BurstPainter(t),
                      ),
                      Opacity(
                        opacity: fade.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * pop,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: _kGreen,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (widget.sub != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.sub!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);
  final double t;

  static const _colors = <Color>[
    Color(0xFFF4C542),
    Color(0xFF178A7C),
    Color(0xFFE8567A),
    Color(0xFF5B8DEF),
    Color(0xFFFF9A3C),
    Color(0xFF9B6BE8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final alpha = t < 0.55 ? 1.0 : (1 - (t - 0.55) / 0.45).clamp(0.0, 1.0);
    const n = 26;
    for (var i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 + (i.isEven ? 0.12 : -0.08);
      final dist = (70 + (i % 5) * 16) * p;
      final pos = c +
          Offset(math.cos(a) * dist * 1.25,
              math.sin(a) * dist * 0.9 + 46 * t * t);
      final r = (4.2 - 2.4 * t) * (i % 3 == 0 ? 1.3 : 1.0);
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: alpha);
      if (i % 2 == 0) {
        canvas.drawCircle(pos, r, paint);
      } else {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(a + t * 6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: r * 2.4, height: r),
              const Radius.circular(1.5)),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
