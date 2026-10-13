import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../state/angels_store.dart';

/// لایه‌ی تصاویر متحرک شناور روی همه‌ی تب‌ها.
/// دقیقاً همان منطق `angels.js`:
///   - هر تصویر یک موقعیت، یک بردار سرعت، و یک فاز نوسان دارد
///   - هر فریم: زاویه‌ی حرکت با sin(phase) کمی منحرف می‌شود
///   - bounce در لبه‌ها
///   - جابه‌جایی عمودی آرام با sin(phase*2)
class AngelsLayer extends StatefulWidget {
  const AngelsLayer({super.key});

  @override
  State<AngelsLayer> createState() => _AngelsLayerState();
}

class _AngelsLayerState extends State<AngelsLayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final List<_AngelItem> _items = [];
  final math.Random _rng = math.Random();

  String _imageSignature = '';
  Size _screen = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // مثل نسخه‌ی وب: بعد از برگشت به اپ، زمان از نو حساب کن
      _lastElapsed = Duration.zero;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    var dtMs = (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;
    if (dtMs < 0) dtMs = 16;
    dtMs = dtMs.clamp(0, 50);
    final dt = dtMs / 1000.0;

    final store = context.read<AngelsStore>();
    final sp = store.speed * 14.0;
    final s = store.size;
    final w = _screen.width;
    final h = _screen.height;
    if (w <= 0 || h <= 0) return;

    for (final it in _items) {
      // خودترمیمی اگر NaN شد
      if (!it.x.isFinite || !it.y.isFinite || !it.vx.isFinite || !it.vy.isFinite) {
        final a0 = _rng.nextDouble() * math.pi * 2;
        it.x = _rng.nextDouble() * math.max(10, w - s);
        it.y = _rng.nextDouble() * math.max(10, h - s);
        it.vx = math.cos(a0);
        it.vy = math.sin(a0);
        it.ph = 0;
      }

      it.ph += dt * 0.7;

      // انحراف آرام مسیر
      final ang = math.atan2(it.vy, it.vx) + math.sin(it.ph) * dt * 0.8;
      it.vx = math.cos(ang);
      it.vy = math.sin(ang);

      it.x += it.vx * sp * dt;
      it.y += it.vy * sp * dt;

      final m = -s * 0.15;
      if (it.x < m) {
        it.x = m;
        it.vx = it.vx.abs();
      }
      if (it.x > w - s * 0.85) {
        it.x = w - s * 0.85;
        it.vx = -it.vx.abs();
      }
      if (it.y < m) {
        it.y = m;
        it.vy = it.vy.abs();
      }
      if (it.y > h - s * 0.85) {
        it.y = h - s * 0.85;
        it.vy = -it.vy.abs();
      }

      it.dispY = it.y + math.sin(it.ph * 2) * 6;
    }
    if (mounted) setState(() {});
  }

  void _syncItems(AngelsStore store, Size screen) {
    final sig = store.images.map((e) => e.id).join('|');
    if (sig == _imageSignature && _screen == screen) return;
    _imageSignature = sig;
    _screen = screen;

    final alive = store.images.map((e) => e.id).toSet();
    _items.removeWhere((it) => !alive.contains(it.id));

    final existing = _items.map((it) => it.id).toSet();
    for (final im in store.images) {
      if (existing.contains(im.id)) continue;
      final a = _rng.nextDouble() * math.pi * 2;
      _items.add(_AngelItem(
        id: im.id,
        x: _rng.nextDouble() * math.max(10, screen.width - store.size),
        y: _rng.nextDouble() * math.max(10, screen.height - store.size),
        vx: math.cos(a),
        vy: math.sin(a),
        ph: _rng.nextDouble() * 6.28,
      ));
    }
  }

  void _ensureTickerRunning(AngelsStore store) {
    final shouldRun = store.on && store.hasImages;
    if (shouldRun && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
      _lastElapsed = Duration.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AngelsStore>();
    final screen = MediaQuery.sizeOf(context);

    // بعد از فریم، بر اساس state جدید ticker و items را sync کن
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncItems(store, screen);
      _ensureTickerRunning(store);
    });

    if (!store.on || !store.hasImages) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final it in _items)
            Positioned(
              left: it.x,
              top: it.dispY,
              child: _AngelImage(
                bytes: _bytesFor(store, it.id),
                size: store.size,
                opacity: store.opacity,
                soft: store.soft,
              ),
            ),
        ],
      ),
    );
  }

  static Uint8ListLike? _bytesFor(AngelsStore store, String id) {
    for (final im in store.images) {
      if (im.id == id) return im.bytes;
    }
    return null;
  }
}

// این کلاس کمکی صرفاً برای type-safety است؛ عملاً Uint8List است.
typedef Uint8ListLike = List<int>;

class _AngelImage extends StatelessWidget {
  final Uint8ListLike? bytes;
  final double size;
  final double opacity;
  final bool soft;

  const _AngelImage({
    required this.bytes,
    required this.size,
    required this.opacity,
    required this.soft,
  });

  @override
  Widget build(BuildContext context) {
    if (bytes == null || bytes!.isEmpty) return const SizedBox.shrink();

    Widget img = Image.memory(
      bytes is Uint8List ? bytes as Uint8List : Uint8List.fromList(bytes!),
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
    );

    if (soft) {
      img = ShaderMask(
        shaderCallback: (rect) => const RadialGradient(
          colors: [
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.52, 0.72],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: img,
      );
    }

    return Opacity(opacity: opacity, child: img);
  }
}

class _AngelItem {
  final String id;
  double x, y, vx, vy, ph, dispY;
  _AngelItem({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.ph,
  }) : dispY = y;
}
