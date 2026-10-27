import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/abundance_models.dart';
import '../services/data_url_cache.dart';
import '../utils/money_format.dart';

const _kGold = Color(0xFFC9A24B);
const _kGoldLight = Color(0xFFF2D98B);

/// لحظهٔ «مال من شد» بعد از خرید در بازی فراوانی:
/// ۱) جشن کوتاه: عکسِ خرید بزرگ + بارون سکه + لرزش + صدای سکه
/// ۲) ۱۰ ثانیه «حس کردنِ داشتن» با دایرهٔ تپنده (قابل رد کردن)
class PurchaseCelebration extends StatefulWidget {
  final Purchase record;
  const PurchaseCelebration({super.key, required this.record});

  static Future<void> show({
    required BuildContext context,
    required Purchase record,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'celebration',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => PurchaseCelebration(record: record),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  State<PurchaseCelebration> createState() => _PurchaseCelebrationState();
}

class _PurchaseCelebrationState extends State<PurchaseCelebration>
    with TickerProviderStateMixin {
  static const _celebrateMs = 2800;
  static const _feelSeconds = 10;

  late final AnimationController _coins;
  late final AnimationController _pop;
  late final AnimationController _pulse;
  final AudioPlayer _player = AudioPlayer();
  final List<_Coin> _coinList = _makeCoins();

  Timer? _toFeel;
  Timer? _tick;
  bool _feel = false;
  bool _closed = false;
  int _left = _feelSeconds;

  static List<_Coin> _makeCoins() {
    final r = math.Random(7);
    return List.generate(
      38,
      (_) => _Coin(
        x: r.nextDouble(),
        phase: r.nextDouble(),
        speed: 0.7 + r.nextDouble() * 0.8,
        size: 7 + r.nextDouble() * 8,
        sway: r.nextDouble() * 2 * math.pi,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _coins = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat();
    _pop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);

    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!_closed) HapticFeedback.mediumImpact();
    });
    _playCoin();

    _toFeel = Timer(const Duration(milliseconds: _celebrateMs), _startFeel);
  }

  Future<void> _playCoin() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource('coin.wav'), volume: 0.7);
    } catch (_) {
      // بدون صدا هم کار می‌کنه
    }
  }

  void _startFeel() {
    if (!mounted || _closed) return;
    HapticFeedback.lightImpact();
    setState(() => _feel = true);
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _closed) return;
      if (_left <= 1) {
        _finish();
        return;
      }
      setState(() => _left--);
    });
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    _toFeel?.cancel();
    _tick?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _closed = true;
    _toFeel?.cancel();
    _tick?.cancel();
    _coins.dispose();
    _pop.dispose();
    _pulse.dispose();
    _player.dispose();
    super.dispose();
  }

  PurchaseItem get _first => widget.record.items.first;

  Widget _hero() {
    final it = _first;
    final bytes = it.image != null ? DataUrlCache.bytes(it.image!) : null;
    final scale = CurvedAnimation(parent: _pop, curve: Curves.elasticOut);
    return ScaleTransition(
      scale: scale,
      child: Container(
        width: 168,
        height: 168,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _kGoldLight, width: 2),
          boxShadow: [
            BoxShadow(
              color: _kGold.withValues(alpha: 0.55),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: bytes != null
            ? Image.memory(bytes,
                width: 168, height: 168, fit: BoxFit.cover, cacheWidth: 480)
            : Text(it.icon, style: const TextStyle(fontSize: 72)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.record.items;
    final headline = items.length == 1
        ? '«${_first.name}» الان مال منه ✨'
        : '${toFaDigits(items.length.toString())} تا چیز الان مال منه ✨';

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B2623), Color(0xFF1A1508)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _coins,
                  builder: (_, __) => CustomPaint(
                    painter: _CoinPainter(
                      _coinList,
                      _coins.value,
                      _feel ? 0.22 : 1,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _feel ? _feelView() : _celebrateView(headline),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton(
                      onPressed: _finish,
                      child: Text('رد کردن',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _celebrateView(String headline) {
    return Column(
      key: const ValueKey('celebrate'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _hero(),
        const SizedBox(height: 28),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'فراوانی داره به سمتت میاد 🌱',
          style: TextStyle(
              color: _kGoldLight.withValues(alpha: 0.9), fontSize: 14),
        ),
      ],
    );
  }

  Widget _feelView() {
    return Column(
      key: const ValueKey('feel'),
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(_pulse.value);
            final s = 0.82 + 0.28 * t;
            return SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 200 * s,
                    height: 200 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        _kGold.withValues(alpha: 0.55),
                        _kGold.withValues(alpha: 0.05),
                      ]),
                    ),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.10),
                      border: Border.all(color: _kGoldLight, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      toFaDigits(_left.toString()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'چشمات رو ببند و حسِ داشتنش رو توی بدنت حس کن',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'یه نفس عمیق… ببین فراوانی کجای بدنت حس می‌شه',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: _kGoldLight.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.6),
        ),
      ],
    );
  }
}

class _Coin {
  final double x, phase, speed, size, sway;
  const _Coin({
    required this.x,
    required this.phase,
    required this.speed,
    required this.size,
    required this.sway,
  });
}

class _CoinPainter extends CustomPainter {
  final List<_Coin> coins;
  final double t;
  final double opacity;
  _CoinPainter(this.coins, this.t, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in coins) {
      final p = ((t * c.speed) + c.phase) % 1.0;
      final y = -20 + p * (size.height + 40);
      final x = c.x * size.width + math.sin(p * 6 + c.sway) * 14;
      // کشیدگیِ افقی برای حالتِ چرخیدنِ سکه
      final squash =
          (math.cos(p * 14 + c.sway)).abs().clamp(0.25, 1.0).toDouble();
      final a = ((0.35 + 0.65 * (1 - (p - 0.5).abs() * 2)) * opacity)
          .clamp(0.0, 1.0)
          .toDouble();
      final fill = Paint()..color = _kGold.withValues(alpha: a);
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _kGoldLight.withValues(alpha: a);
      final rect = Rect.fromCenter(
          center: Offset(x, y), width: c.size * 2 * squash, height: c.size * 2);
      canvas.drawOval(rect, fill);
      canvas.drawOval(rect.deflate(c.size * 0.28), rim);
    }
  }

  @override
  bool shouldRepaint(_CoinPainter old) =>
      old.t != t || old.opacity != opacity;
}
