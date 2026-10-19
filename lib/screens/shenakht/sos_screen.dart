// lib/screens/shenakht/sos_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'shenakht_tab.dart';

class SosScreen extends StatefulWidget {
  final VoidCallback onBack;
  const SosScreen({super.key, required this.onBack});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  int _phase = 0; // 0=دم، 1=نگه‌دار، 2=بازدم
  int _seconds = 4;
  Timer? _timer;
  bool _showPhrase = false;

  static const _phases = [
    ['دم', 4],
    ['نگه‌دار', 7],
    ['بازدم', 8],
  ];

  static const _phrases = [
    'این هم می‌گذرد.',
    'تو تنها نیستی.',
    'فقط همین لحظه کافیه.',
    'احساساتت واقعی‌ان، ولی همیشگی نیستن.',
    'یه نفس عمیق، کافیه.',
    'تو قوی‌تر از این لحظه‌ای.',
  ];

  String _phrase = _phrases[0];

  @override
  void initState() {
    super.initState();
    _startCycle();
  }

  void _startCycle() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds > 1) {
        setState(() => _seconds--);
      } else {
        setState(() {
          _phase = (_phase + 1) % 3;
          _seconds = _phases[_phase][1] as int;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showPhrase) {
      _phrase = _phrases[DateTime.now().millisecond % _phrases.length];
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [SK.grad1, SK.grad2, SK.grad3],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💙', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 24),
                Text(
                  _phrase,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, height: 2),
                ),
                const SizedBox(height: 40),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      child: Text('ادامه',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final phaseName = _phases[_phase][0] as String;
    final total = _phases[_phase][1] as int;
    final progress = 1 - (_seconds / total);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SK.grad1, SK.grad2, SK.grad3],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text('این هم می‌گذرد',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2,
                        backgroundColor:
                            Colors.white.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation(
                            Colors.white70),
                      ),
                    ),
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$_seconds',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700)),
                          Text(phaseName,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'با من نفس بکش.\nفقط همین لحظه کافی است.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white70, fontSize: 14, height: 1.9),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _showPhrase = true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('حالم کمی بهتره',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onBack,
                child: const Text('بازگشت',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
