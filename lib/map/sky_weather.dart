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

  // باد: سرعتِ افقیِ ابرها (کسری از عرضِ صفحه در ثانیه؛ مثبت = به‌سمتِ راست)
  double _wind = 0.010, _tWind = 0.010;
  double _drift = 0; // جابه‌جایی‌ی تجمعی (تا با عوض‌شدنِ باد، ابرها نپرند)

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
    // باد واقعیِ شهر → جهت و سرعتِ حرکتِ ابرها (۰.۰۰۴ تا ۰.۰۲۲ عرضِ صفحه در ثانیه)
    final kmh = w?.wind ?? 12;
    final dir = (w?.windDir ?? 270) * math.pi / 180;
    var east = -math.sin(dir); // بادِ غربی ابر را به شرق می‌برد
    if (east.abs() < 0.3) east = east >= 0 ? 0.3 : -0.3; // بادِ شمالی/جنوبی هم کمی بجنباند
    _tWind = east * (0.004 + kmh * 0.0005).clamp(0.004, 0.022).toDouble();
    if (initial) {
      _cloud = _tCloud;
      _rain = _tRain;
      _snow = _tSnow;
      _wind = _tWind;
    }
  }

  void _tick(Duration d) {
    final dt = ((d - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = d;
    _time += dt;
    _cloud += (_tCloud - _cloud) * math.min(1.0, dt * 0.35);
    _rain += (_tRain - _rain) * math.min(1.0, dt * 0.5);
    _snow += (_tSnow - _snow) * math.min(1.0, dt * 0.5);
    _wind += (_tWind - _wind) * math.min(1.0, dt * 0.2);
    _drift += _wind * dt;
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
  const _Cloud(this.x, this.y, this.s, this.d, this.ph, this.puffs);
  final double x, y; // جای پایه (کسری از عرض/ارتفاع)
  final double s; // اندازه
  final double d; // عمق: ابرِ دورتر کوچک‌تر، کم‌رنگ‌تر و کندتر
  final double ph; // فازِ «نفس‌کشیدنِ» آرامِ شکل
  final List<List<double>> puffs; // [x, y, r] به واحدِ u
}

/// ابرِ کومه‌ای: کفِ تقریباً تخت، بالای گنبدی و برآمدگی‌های ریزِ رویِ آن
List<List<double>> _makePuffs(math.Random r) {
  final n = 8 + r.nextInt(4);
  final out = <List<double>>[];
  for (var i = 0; i < n; i++) {
    final t = (i + 0.5) / n;
    final env = math.pow(math.sin(math.pi * t), 0.7).toDouble();
    final x = (t - 0.5) * 4.6 + (r.nextDouble() - 0.5) * 0.3;
    final rad = 0.42 + 0.78 * env * (0.65 + 0.35 * r.nextDouble());
    final y = 0.35 - rad * 0.8 - r.nextDouble() * 0.06;
    out.add([x, y, rad]);
  }
  // برآمدگی‌های ریز روی بزرگ‌ترین‌ها
  final big = [...out]..sort((a, b) => b[2].compareTo(a[2]));
  for (var k = 0; k < 3 && k < big.length; k++) {
    final p = big[k];
    out.add([
      p[0] + (r.nextDouble() - 0.5) * 0.5,
      p[1] - p[2] * 0.62,
      p[2] * (0.45 + 0.15 * r.nextDouble()),
    ]);
  }
  return out;
}

/// ابرها فقط در نوارِ بالای نقشه‌اند؛ ابرِ دور (d کم) کوچک و کندتر است.
final List<_Cloud> _clouds = () {
  final r = math.Random(41);
  const spec = <List<double>>[
    // x, y, s, d
    [0.10, 0.040, 1.00, 1.00],
    [0.58, 0.085, 0.80, 0.80],
    [0.84, 0.030, 0.90, 0.95],
    [0.34, 0.125, 0.55, 0.55],
    [0.70, 0.150, 0.50, 0.50],
    [0.02, 0.140, 0.60, 0.60],
    [0.46, 0.012, 0.65, 0.70],
  ];
  return [
    for (var i = 0; i < spec.length; i++)
      _Cloud(spec[i][0], spec[i][1], spec[i][2], spec[i][3],
          r.nextDouble() * 6.28, _makePuffs(r)),
  ];
}();

/// یک «پف» نرم: مرکز غلیظ و لبه‌ی محو (شعاع ۱؛ با scale بزرگ می‌شود)
Paint _puffPaint(Color c, double k) => Paint()
  ..shader = RadialGradient(
    colors: [
      c.withValues(alpha: k),
      c.withValues(alpha: k * 0.88),
      c.withValues(alpha: 0),
    ],
    stops: const [0.0, 0.55, 1.0],
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));

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
      // ابرهای نرم و طبیعی؛ رنگِ خنثی (سفید/خاکستریِ ملایم) و هماهنگ با روشن/تیره‌بودنِ نقشه
      final dim = (rain * 0.55 + snow * 0.25).clamp(0.0, 0.6).toDouble();
      final body = Color.lerp(
          night ? const Color(0xFF727994) : const Color(0xFFFFFFFF),
          night ? const Color(0xFF555B75) : const Color(0xFFB9C0CC),
          dim)!;
      final shade = Color.lerp(
          night ? const Color(0xFF454B66) : const Color(0xFFBCC3CF),
          night ? const Color(0xFF353A52) : const Color(0xFF8E96A5),
          dim)!;
      final light = Color.lerp(
          night ? const Color(0xFFA3A9C2) : const Color(0xFFFFFFFF),
          night ? const Color(0xFF7C829B) : const Color(0xFFD7DCE4),
          dim)!;
      final shadePaint = _puffPaint(shade, 0.85);
      final bodyPaint = _puffPaint(body, 0.95);
      final lightPaint = _puffPaint(light, 0.8);
      final maxA = night ? 0.42 : 0.82;
      for (var i = 0; i < _clouds.length; i++) {
        final c = _clouds[i];
        final a = (cover * 1.3 - i * 0.15).clamp(0.0, 1.0).toDouble() *
            maxA *
            (0.55 + 0.45 * c.d);
        if (a <= 0.02) continue;
        final u = w * 0.058 * c.s;
        // حرکتِ آرامِ ابر با بادِ واقعی؛ هر ابر کمی سریع‌تر/کندتر (عمق)
        final span = 1.7; // عرضِ صفحه + حاشیه‌ی دو طرف
        final cx = (((c.x + st._drift * (0.5 + c.d)) % span) - 0.35) * w;
        final cy = (c.y + math.sin(t * 0.11 + c.ph) * 0.004) * h + u * 0.9;
        final breath = 1 + 0.035 * math.sin(t * 0.23 + c.ph);
        canvas.saveLayer(
            Rect.fromLTWH(cx - 3.6 * u, cy - 2.4 * u, 7.2 * u, 4.2 * u),
            Paint()..color = Color.fromRGBO(0, 0, 0, a));
        void puffs(Paint pt, double dy, double sx, double sy, double shrink,
            {double dx = 0, bool topOnly = false}) {
          for (final q in c.puffs) {
            if (topOnly && q[1] > 0.0) continue;
            final r = q[2] * u * breath * shrink;
            canvas.save();
            canvas.translate(cx + q[0] * u + dx * q[2] * u,
                cy + q[1] * u + dy * u);
            canvas.scale(r * sx, r * sy);
            canvas.drawCircle(Offset.zero, 1, pt);
            canvas.restore();
          }
        }

        puffs(shadePaint, 0.14, 1.12, 0.86, 1.0); // سایه‌ی زیرِ ابر
        puffs(bodyPaint, -0.04, 1.0, 0.82, 0.92); // تنه‌ی ابر
        puffs(lightPaint, -0.14, 0.82, 0.66, 0.62,
            dx: -0.15, topOnly: true); // روشناییِ بالا (نور از بالا-چپ)
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
