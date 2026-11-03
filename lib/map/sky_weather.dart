import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/real_weather.dart';

/// هوای واقعیِ شهرِ کاربر روی آسمانِ نقشه (صاف، ابری، بارانی، برفی).
/// اگر هوا هنوز معلوم نباشد (اولین نصب/بدونِ اینترنت) چیزی نشان نمی‌دهد.
/// لمس را نمی‌گیرد و فقط روی نقشه می‌نشیند.
class SkyWeatherLayer extends StatefulWidget {
  const SkyWeatherLayer({super.key, required this.night});

  /// نقشه تیره است؟ (رنگِ ابرها طبقِ روشن/تیره‌بودنِ خودِ نقشه، نه ساعت)
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
  _Cloud(0.06, 0.075, 1.00, 0.0016),
  _Cloud(0.46, 0.135, 0.80, 0.0011),
  _Cloud(0.80, 0.095, 0.90, 0.0019),
  _Cloud(0.25, 0.200, 0.70, 0.0013),
  _Cloud(0.64, 0.235, 0.75, 0.0010),
];

/// شکلِ ابر: چند دایره‌ی هم‌پوشان + کفِ تقریباً صاف (واحد = u)
const _puffs = <List<double>>[
  [-1.35, 0.30, 0.62],
  [-0.55, -0.05, 0.86],
  [0.45, -0.30, 1.00],
  [1.35, 0.02, 0.74],
  [1.95, 0.34, 0.52],
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
      // ابرهای کوچک و نرم، فقط در نوارِ بالای نقشه؛ رنگ از روشن/تیره‌بودنِ خودِ نقشه
      final dim = (rain * 0.55 + snow * 0.25).clamp(0.0, 0.6).toDouble();
      final top = Color.lerp(
          night ? const Color(0xFF8590BC) : const Color(0xFFFFFFFF),
          night ? const Color(0xFF5A6286) : const Color(0xFFB4BED0),
          dim)!;
      final bot = Color.lerp(
          night ? const Color(0xFF3F4772) : const Color(0xFFC3CDE2),
          night ? const Color(0xFF2B3252) : const Color(0xFF8D99B2),
          dim)!;
      final maxA = night ? 0.50 : 0.78;
      for (var i = 0; i < _clouds.length; i++) {
        final c = _clouds[i];
        final a = (cover * 1.3 - i * 0.18).clamp(0.0, 1.0).toDouble() * maxA;
        if (a <= 0.02) continue;
        final u = w * 0.040 * c.s;
        final cx = (((c.x + t * c.v) % 1.4) - 0.2) * w;
        final cy = c.y * h;
        final bounds = Rect.fromLTWH(cx - 3 * u, cy - 2 * u, 7 * u, 4 * u);
        canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, a));
        final fill = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bot],
          ).createShader(Rect.fromLTWH(cx - 2.2 * u, cy - 1.3 * u, 4.8 * u, 2.3 * u))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
        for (final q in _puffs) {
          canvas.drawCircle(Offset(cx + q[0] * u, cy + q[1] * u), q[2] * u, fill);
        }
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTRB(cx - 1.9 * u, cy + 0.15 * u, cx + 2.5 * u, cy + 0.95 * u),
                Radius.circular(0.4 * u)),
            fill);
        canvas.restore();
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
