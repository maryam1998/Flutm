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
    _drift += _wind * dt * 1.0; // پایه‌ی حرکتِ ابرها؛ سرعتِ هر ابر جدا حساب می‌شود
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
  const _Cloud(this.x, this.y, this.s, this.d, this.ph, this.puffs, this.kind,
      this.ext);
  final double x, y; // جای پایه (کسری از عرض/ارتفاع)
  final double s; // اندازه
  final double d; // عمق: ابرِ دورتر کوچک‌تر، کم‌رنگ‌تر و کندتر
  final double ph; // فازِ «نفس‌کشیدنِ» آرامِ شکل
  final List<List<double>> puffs; // [x, y, r, کشیدگیِ افقی] به واحدِ u
  final int kind; // 0 کومه‌ای بلند، 1 پهنِ لایه‌ای، 2 کومه‌ی کوچک، 3 رشته‌ای (سیروس)
  final double ext; // نیمه‌عرضِ ابر (برای کادرِ رسم)
}

double _cloudExtent(List<List<double>> p) {
  var e = 1.0;
  for (final q in p) {
    e = math.max(e, q[0].abs() + q[2] * (q.length > 3 ? q[3] : 1.0) * 1.15);
  }
  return e;
}

/// ابرِ طبیعی: چند نوع (کومه‌ای بلند، پهنِ لایه‌ای، کوچک، رشته‌ای) که هر کدام
/// با پف‌های تصادفیِ متفاوت ساخته می‌شوند تا هیچ دو ابری شبیه هم نباشند.
/// کف تقریباً تخت، بالا گنبدی و «گل‌کلمی»، و کمی کج به سمتِ باد.
List<List<double>> _makePuffs(math.Random r, [int kind = 0]) {
  final out = <List<double>>[];
  switch (kind) {
    case 1: // پهن و لایه‌ای
      final w = 5.0 + r.nextDouble() * 2.2;
      final n = 16 + r.nextInt(7);
      for (var i = 0; i < n; i++) {
        final t = (i + 0.5) / n;
        final env = math.pow(math.sin(math.pi * t), 0.55).toDouble();
        final rad = 0.28 + 0.36 * env * (0.55 + 0.45 * r.nextDouble());
        out.add([
          (t - 0.5) * w + (r.nextDouble() - 0.5) * 0.35,
          0.32 - rad * 0.55 - r.nextDouble() * 0.10,
          rad,
          1.35 + r.nextDouble() * 0.5,
        ]);
      }
      // یک یا دو برآمدگیِ بالاتر روی ابر
      for (var k = 0; k < 2; k++) {
        final p = out[r.nextInt(out.length)];
        out.add([p[0], p[1] - p[2] * 0.7, p[2] * 0.7, 1.1]);
      }
    case 2: // کومه‌ی کوچکِ هوای خوب
      final n = 4 + r.nextInt(3);
      final w = 1.8 + r.nextDouble() * 1.0;
      for (var i = 0; i < n; i++) {
        final t = (i + 0.5) / n;
        final env = math.pow(math.sin(math.pi * t), 0.8).toDouble();
        final rad = 0.34 + 0.55 * env * (0.6 + 0.4 * r.nextDouble());
        out.add([
          (t - 0.5) * w + (r.nextDouble() - 0.5) * 0.25,
          0.34 - rad * 0.8,
          rad,
          1.0
        ]);
      }
    case 3: // رشته‌ای و نازک (سیروس)
      final n = 7 + r.nextInt(3);
      final w = 5.4 + r.nextDouble() * 1.6;
      final slope = (r.nextDouble() - 0.5) * 0.6;
      for (var i = 0; i < n; i++) {
        final t = (i + 0.5) / n;
        final rad = 0.16 + 0.12 * math.sin(math.pi * t) * (0.5 + r.nextDouble());
        out.add([
          (t - 0.5) * w,
          0.15 + slope * (t - 0.5) * 2 + (r.nextDouble() - 0.5) * 0.14,
          rad,
          2.4 + r.nextDouble() * 1.4,
        ]);
      }
    default: // کومه‌ای بلند با بالای گل‌کلمی
      final n = 11 + r.nextInt(5);
      final w = 3.2 + r.nextDouble() * 1.6;
      final lean = (r.nextDouble() - 0.5) * 0.9;
      for (var i = 0; i < n; i++) {
        final t = (i + 0.5) / n;
        final env = math.pow(math.sin(math.pi * t), 0.85).toDouble();
        final rad = 0.34 + 0.95 * env * (0.5 + 0.5 * r.nextDouble());
        final y = 0.35 - rad * 0.85 - r.nextDouble() * 0.05;
        out.add([
          (t - 0.5) * w + lean * (-y) * 0.35 + (r.nextDouble() - 0.5) * 0.3,
          y,
          rad,
          1.0
        ]);
      }
      final big = [...out]..sort((a, b) => b[2].compareTo(a[2]));
      for (var k = 0; k < 4 && k < big.length; k++) {
        final p = big[k];
        final cnt = 1 + r.nextInt(2);
        for (var j = 0; j < cnt; j++) {
          final ang = -math.pi / 2 + (r.nextDouble() - 0.5) * 1.8;
          final rr = p[2] * (0.38 + 0.22 * r.nextDouble());
          out.add([
            p[0] + math.cos(ang) * p[2] * 0.7,
            p[1] + math.sin(ang) * p[2] * 0.7,
            rr,
            1.0
          ]);
        }
      }
  }
  return out;
}

/// ابرها فقط در نوارِ بالای نقشه‌اند؛ ابرِ دور (d کم) کوچک و کندتر است.
final List<_Cloud> _clouds = () {
  final r = math.Random(41);
  const spec = <List<double>>[
    // x, y, s, d, نوع
    [0.10, 0.040, 1.05, 1.00, 0],
    [0.58, 0.085, 0.80, 0.80, 1],
    [0.84, 0.030, 0.55, 0.95, 2],
    [0.34, 0.125, 0.70, 0.55, 1],
    [0.70, 0.150, 0.50, 0.50, 3],
    [0.02, 0.140, 0.45, 0.60, 2],
    [0.46, 0.012, 0.85, 0.70, 0],
  ];
  return [
    for (var i = 0; i < spec.length; i++)
      () {
        final pf = _makePuffs(r, spec[i][4].toInt());
        return _Cloud(spec[i][0], spec[i][1], spec[i][2], spec[i][3],
            r.nextDouble() * 6.28, pf, spec[i][4].toInt(), _cloudExtent(pf));
      }(),
  ];
}();

/// مجموعه‌ی شکل‌های آماده برای نمای راه‌رفتن و نقشه‌ی دور
final List<List<List<double>>> _sharedPuffSets = () {
  final r = math.Random(913);
  const kinds = [0, 1, 0, 2, 3, 1, 0, 2];
  return [for (final k in kinds) _makePuffs(r, k)];
}();

/// کشیدنِ یک ابرِ طبیعی (هر seed شکل و نوعِ متفاوتی دارد) در مرکزِ [c]
/// u = واحدِ اندازه (عرضِ ابر ≈ ۴ تا ۶ برابرِ u)
void paintNaturalCloud(Canvas canvas, Offset c, double u, int seed,
    {required Color body,
    required Color shade,
    required Color light,
    required double alpha}) {
  if (alpha <= 0.01 || u <= 0) return;
  final set = _sharedPuffSets[seed.abs() % _sharedPuffSets.length];
  final ext = _cloudExtent(set);
  canvas.saveLayer(
      Rect.fromLTWH(c.dx - (ext + 0.6) * u, c.dy - 2.6 * u,
          (ext + 0.6) * 2 * u, 4.6 * u),
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)));
  final shadeP = _puffPaint(shade, 0.85);
  final bodyP = _puffPaint(body, 0.95);
  final lightP = _puffPaint(light, 0.8);
  void pass(Paint pt, double dy, double sx, double sy, double shrink,
      {double dx = 0, bool topOnly = false}) {
    for (final q in set) {
      if (topOnly && q[1] > 0.0) continue;
      final r = q[2] * u * shrink;
      canvas.save();
      canvas.translate(c.dx + q[0] * u + dx * q[2] * u, c.dy + q[1] * u + dy * u);
      canvas.scale(r * sx * q[3], r * sy);
      canvas.drawCircle(Offset.zero, 1, pt);
      canvas.restore();
    }
  }

  pass(shadeP, 0.14, 1.12, 0.86, 1.0);
  pass(bodyP, -0.04, 1.0, 0.82, 0.92);
  pass(lightP, -0.14, 0.82, 0.66, 0.62, dx: -0.15, topOnly: true);
  canvas.restore();
}

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
        // سرعتِ مخصوصِ هر ابر (بعضی خیلی کند، بعضی کمی تندتر)
        final spd = (0.3 + 1.1 * ((c.ph * 3.7) % 1.0)) * (0.6 + 0.4 * c.d);
        final cx = (((c.x + st._drift * spd) % span) - 0.35) * w;
        final cy = (c.y + math.sin(t * 0.2 + c.ph) * 0.006) * h + u * 0.9;
        final breath = 1 + 0.045 * math.sin(t * 0.35 + c.ph);
        canvas.saveLayer(
            Rect.fromLTWH(cx - (c.ext + 0.6) * u, cy - 2.6 * u,
                (c.ext + 0.6) * 2 * u, 4.6 * u),
            Paint()..color = Color.fromRGBO(0, 0, 0, a));
        void puffs(Paint pt, double dy, double sx, double sy, double shrink,
            {double dx = 0, bool topOnly = false}) {
          for (final q in c.puffs) {
            if (topOnly && q[1] > 0.0) continue;
            final r = q[2] * u * breath * shrink;
            canvas.save();
            canvas.translate(cx + q[0] * u + dx * q[2] * u,
                cy + q[1] * u + dy * u);
            canvas.scale(r * sx * q[3], r * sy);
            canvas.drawCircle(Offset.zero, 1, pt);
            canvas.restore();
          }
        }

        if (c.kind != 3) puffs(shadePaint, 0.14, 1.12, 0.86, 1.0); // سایه‌ی زیرِ ابر
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
