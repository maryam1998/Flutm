import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/real_weather.dart';

/// هوای واقعیِ شهرِ کاربر روی آسمانِ نقشه (صاف، ابری، بارانی، برفی).
/// اگر هوا هنوز معلوم نباشد (اولین نصب/بدونِ اینترنت) چیزی نشان نمی‌دهد.
/// لمس را نمی‌گیرد و فقط روی نقشه می‌نشیند.
class SkyWeatherLayer extends StatefulWidget {
  const SkyWeatherLayer({super.key, required this.night});

  /// شب = ابرِ تیره‌تر، روز = ابرِ روشن‌تر
  final bool night;

  @override
  State<SkyWeatherLayer> createState() => _SkyWeatherLayerState();
}

class _SkyWeatherLayerState extends State<SkyWeatherLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);

  double _cloud = 0, _rain = 0, _snow = 0; // مقدارِ فعلی (۰..۱)
  double _tCloud = 0, _tRain = 0, _tSnow = 0; // هدف
  double _time = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _apply(RealWeather.now.value, initial: true);
    RealWeather.now.addListener(_onWeather);
    RealWeather.attach(); // در پس‌زمینه؛ جلوی نمایشِ نقشه را نمی‌گیرد
    _ticker = createTicker(_tick)..start();
  }

  void _onWeather() => _apply(RealWeather.now.value);

  void _apply(WeatherNow? w, {bool initial = false}) {
    _tCloud = w?.cloud ?? 0;
    _tRain = w?.rain ?? 0;
    _tSnow = w?.snow ?? 0;
    if (initial) {
      _cloud = _tCloud;
      _rain = _tRain;
      _snow = _tSnow;
    }
  }

  void _tick(Duration d) {
    final dt = ((d - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = d;
    _time += dt;
    _cloud += (_tCloud - _cloud) * math.min(1.0, dt * 0.35);
    _rain += (_tRain - _rain) * math.min(1.0, dt * 0.5);
    _snow += (_tSnow - _snow) * math.min(1.0, dt * 0.5);
    _repaint.value++;
  }

  @override
  void dispose() {
    RealWeather.now.removeListener(_onWeather);
    RealWeather.release();
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _WeatherPainter(this, widget.night, _repaint),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Cloud {
  const _Cloud(this.x, this.y, this.s, this.v);
  final double x, y, s, v;
}

const _clouds = <_Cloud>[
  _Cloud(0.05, 0.05, 1.0, 0.0040),
  _Cloud(0.42, 0.11, 1.3, 0.0028),
  _Cloud(0.75, 0.04, 0.9, 0.0050),
  _Cloud(0.20, 0.17, 1.1, 0.0034),
  _Cloud(0.62, 0.20, 1.4, 0.0024),
  _Cloud(0.92, 0.14, 1.0, 0.0044),
];

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.st, this.night, Listenable repaint)
      : super(repaint: repaint);
  final _SkyWeatherLayerState st;
  final bool night;

  static final List<List<double>> _drops = () {
    final r = math.Random(77);
    return List.generate(
        80,
        (_) => [
              r.nextDouble(), // x
              r.nextDouble(), // فاز
              0.7 + r.nextDouble() * 0.6, // سرعت
            ]);
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final cover = st._cloud, rain = st._rain, snow = st._snow, t = st._time;

    if (cover > 0.02) {
      final base = night ? const Color(0xFF3A4260) : const Color(0xFFF2F5FA);
      final shade = night ? const Color(0xFF262C45) : const Color(0xFFB9C3D3);
      for (var i = 0; i < _clouds.length; i++) {
        final c = _clouds[i];
        final a = (cover * 1.25 - i * 0.12).clamp(0.0, 1.0).toDouble() *
            (night ? 0.55 : 0.75);
        if (a <= 0.01) continue;
        final x = (((c.x + t * c.v) % 1.5) - 0.25) * w;
        final y = c.y * h;
        final u = w * 0.075 * c.s;
        final blur = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
        void puff(double dx, double dy, double r, Color col) {
          canvas.drawCircle(Offset(x + dx * u, y + dy * u), r * u,
              blur..color = col.withValues(alpha: a));
        }

        puff(0, 0.25, 0.9, shade);
        puff(1.3, 0.3, 1.0, shade);
        puff(-1.2, 0.35, 0.75, shade);
        puff(0.2, -0.15, 1.0, base);
        puff(1.2, -0.05, 0.85, base);
        puff(-0.9, 0.05, 0.7, base);
      }
    }

    if (rain > 0.03) {
      final p = Paint()
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = (night ? const Color(0xFFBFD0F0) : const Color(0xFF8FA6C8))
            .withValues(alpha: 0.42 * rain);
      final n = (_drops.length * rain).round();
      final top = h * 0.06;
      final span = h - top;
      for (var i = 0; i < n; i++) {
        final d = _drops[i];
        final fall = ((d[1] + t * 0.9 * d[2]) % 1.0);
        final y = top + fall * span;
        final x = (d[0] * w + fall * span * 0.12) % w;
        canvas.drawLine(Offset(x, y), Offset(x - 2.2, y + 13), p);
      }
    }

    if (snow > 0.03) {
      final p = Paint()
        ..color = (night ? const Color(0xFFE6ECFA) : const Color(0xFFFFFFFF))
            .withValues(alpha: (0.75 * snow).clamp(0.0, 1.0).toDouble());
      final n = (_drops.length * snow).round();
      final top = h * 0.06;
      final span = h - top;
      for (var i = 0; i < n; i++) {
        final d = _drops[i];
        final fall = ((d[1] + t * 0.14 * d[2]) % 1.0);
        final y = top + fall * span;
        final sway = math.sin(t * 0.9 * d[2] + d[1] * 12) * 14;
        final x = (d[0] * w + sway) % w;
        canvas.drawCircle(Offset(x, y), 1.2 + d[2] * 1.1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter old) => old.night != night;
}
