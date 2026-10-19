import 'dart:async';
import 'package:flutter/material.dart';

const _kEmerald500 = Color(0xFF2BBFAB);
const _kEmerald700 = Color(0xFF0F5B53);
const _kMuted = Color(0xFF7A6B57);
const _kInk = Color(0xFF2A2218);
const _kBorder = Color(0xFFE0D5C0);

class BreathCircle extends StatefulWidget {
  const BreathCircle({super.key});
  @override
  State<BreathCircle> createState() => _BreathCircleState();
}

class _BreathCircleState extends State<BreathCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  String _phase = 'idle';
  Timer? _timer;

  static const _phases = [
    {'name': 'inhale', 'dur': 4, 'label': 'دم', 'hint': 'به‌آرامی نفس بکش'},
    {'name': 'hold',   'dur': 7, 'label': 'نگه‌دار', 'hint': 'نفس را نگه‌ دار'},
    {'name': 'exhale', 'dur': 8, 'label': 'بازدم', 'hint': 'به‌آرامی رها کن'},
  ];
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _idx = 0;
    _runPhase();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _ctrl.stop();
    setState(() {
      _phase = 'idle';
      _ctrl.value = 0;
    });
  }

  void _runPhase() {
    final p = _phases[_idx];
    final dur = p['dur'] as int;
    setState(() => _phase = p['name'] as String);

    _ctrl.duration = Duration(seconds: dur);
    _ctrl.forward(from: 0);

    _timer = Timer(Duration(seconds: dur), () {
      if (!mounted) return;
      _idx = (_idx + 1) % _phases.length;
      _runPhase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _phase != 'idle';
    final label = isActive
        ? _phases.firstWhere((p) => p['name'] == _phase)['label'] as String
        : 'آماده';
    final hint = isActive
        ? _phases.firstWhere((p) => p['name'] == _phase)['hint'] as String
        : 'برای شروع دکمه را بزن';

    return Column(
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            double scale = 1;
            if (_phase == 'inhale') {
              scale = 0.9 + t * 0.24;
            } else if (_phase == 'exhale') {
              scale = 1.14 - t * 0.24;
            } else if (_phase == 'hold') {
              scale = 1.14;
            }

            return SizedBox(
              width: 172,
              height: 172,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _kEmerald500.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.72],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 168,
                    height: 168,
                    child: CircularProgressIndicator(
                      value: isActive ? t : 0,
                      strokeWidth: 3,
                      backgroundColor: _kMuted.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(_kEmerald500),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _kEmerald700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hint,
                        style: const TextStyle(fontSize: 11, color: _kMuted),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            SizedBox(
              height: 40,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kInk,
                  side: const BorderSide(color: _kBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isActive ? _stop : _start,
                child: Text(
                  isActive ? '⏸ توقف تنفس' : '▶ شروع تنفس',
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '۴ ثانیه دم • ۷ نگه‌دار • ۸ بازدم',
              style: TextStyle(fontSize: 11, color: _kMuted),
            ),
          ],
        ),
      ],
    );
  }
}
