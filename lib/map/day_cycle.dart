import 'dart:async';
import 'dart:math' as math;

import 'dart:ui' show Path, PathOperation;

import 'package:flutter/material.dart';

import '../services/app_prefs.dart';

/// آسمانِ زنده‌ی نقشه: بر پایه‌ی ساعت و منطقه‌ی زمانیِ گوشیِ کاربر
/// (صبح زود، صبح، ظهر، عصر، غروب، شفق، شب) + خورشید، ماه (با فازِ واقعی) و ستاره.
/// بدونِ نیاز به GPS: طولِ جغرافیایی از اختلافِ ساعتِ منطقه‌ی زمانی با UTC حدس زده می‌شود.
class SkyState {
  const SkyState({
    required this.altDeg,
    required this.rising,
    required this.dayFrac,
    required this.nightFrac,
    required this.top,
    required this.bottom,
    required this.starA,
    required this.sunA,
    required this.moonA,
    required this.moonPhase,
    required this.night,
    required this.emoji,
    required this.label,
  });

  /// ارتفاعِ خورشید بر حسبِ درجه (منفی = زیرِ افق)
  final double altDeg;

  /// قبل از ظهر؟
  final bool rising;

  /// جایگاهِ خورشید روی کمانِ روز (۰ = طلوع، ۱ = غروب)
  final double dayFrac;

  /// جایگاهِ ماه روی کمانِ شب (۰ = غروب، ۱ = طلوع)
  final double nightFrac;
  final Color top, bottom;
  final double starA, sunA, moonA;

  /// ۰..۱ (۰ = هلالِ نو، ۰٫۵ = ماهِ کامل)
  final double moonPhase;

  /// آسمان تاریک است ← نقشه در حالتِ تیره رسم شود
  final bool night;
  final String emoji;
  final String label;
}

class DayCycle {
  DayCycle._();

  static const _prefKey = 'mapSkyMode';

  /// 'auto' (ساعتِ گوشی) | 'day' | 'night'
  static final ValueNotifier<String> mode = ValueNotifier<String>('auto');
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await AppPrefs.getInstance();
      final v = sp.getString(_prefKey);
      if (v == 'day' || v == 'night' || v == 'auto') mode.value = v!;
    } catch (_) {}
  }

  static Future<void> cycleMode() async {
    final next = switch (mode.value) {
      'auto' => 'day',
      'day' => 'night',
      _ => 'auto',
    };
    mode.value = next;
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setString(_prefKey, next);
    } catch (_) {}
  }

  static String modeLabel(String m) => switch (m) {
        'day' => 'نقشه همیشه روز',
        'night' => 'نقشه همیشه شب',
        _ => 'نقشه خودکار (طبق ساعت گوشی)',
      };

  // ───────────── محاسبه ─────────────

  static const double _lat = 35.0; // عرضِ فرضی (برای فصل‌ها)؛ تأثیرِ کمی دارد

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0).toDouble();
    return t * t * (3 - 2 * t);
  }

  // کلیدهای رنگِ آسمان بر حسبِ ارتفاعِ خورشید (درجه)
  // [deg, top, bottomMorning, bottomEvening]
  static const List<List<int>> _keys = [
    [-18, 0xFF060A1A, 0xFF111733, 0xFF111733],
    [-12, 0xFF121A40, 0xFF2E3466, 0xFF3A2F5E],
    [-6, 0xFF2D3A78, 0xFFB78AA8, 0xFFC9708A],
    [-1, 0xFF5C74B8, 0xFFFFB38A, 0xFFFF9A5C],
    [4, 0xFF7FAEE0, 0xFFFFDDB0, 0xFFFFD08A],
    [12, 0xFF6FB1EA, 0xFFDCEBF7, 0xFFEFE6D0],
    [30, 0xFF4F9FE6, 0xFFBFE2F8, 0xFFC4E4F7],
    [90, 0xFF3F93E2, 0xFFB5DCF6, 0xFFB5DCF6],
  ];

  static SkyState _skyFor(double altDeg, bool rising, double dayFrac,
      double nightFrac, double moonPhase) {
    final a = altDeg.clamp(-18.0, 90.0).toDouble();
    var i = 0;
    while (i < _keys.length - 2 && a > _keys[i + 1][0]) {
      i++;
    }
    final k0 = _keys[i], k1 = _keys[i + 1];
    final t = ((a - k0[0]) / (k1[0] - k0[0])).clamp(0.0, 1.0).toDouble();
    final bi = rising ? 2 : 3;
    final top = Color.lerp(Color(k0[1]), Color(k1[1]), t)!;
    final bottom = Color.lerp(Color(k0[bi]), Color(k1[bi]), t)!;

    final night = altDeg < -3.0;
    final String emoji, label;
    if (altDeg < -12) {
      emoji = '🌙';
      label = 'شب';
    } else if (altDeg < -3) {
      emoji = rising ? '🌄' : '🌆';
      label = rising ? 'سپیده‌دم' : 'شفق';
    } else if (altDeg < 8) {
      emoji = rising ? '🌅' : '🌇';
      label = rising ? 'طلوع' : 'غروب';
    } else if (altDeg < 25) {
      emoji = '🌤️';
      label = rising ? 'صبح' : 'عصر';
    } else {
      emoji = '☀️';
      label = 'ظهر';
    }

    return SkyState(
      altDeg: altDeg,
      rising: rising,
      dayFrac: dayFrac,
      nightFrac: nightFrac,
      top: top,
      bottom: bottom,
      starA: _smooth(-5, -14, altDeg),
      sunA: _smooth(-4, 1, altDeg),
      moonA: _smooth(3, -7, altDeg),
      moonPhase: moonPhase,
      night: night,
      emoji: emoji,
      label: label,
    );
  }

  static double _moonPhase(DateTime now) {
    // هلالِ نوی مرجع: ۲۰۰۰-۰۱-۰۶ ۱۸:۱۴ UTC
    final ref = DateTime.utc(2000, 1, 6, 18, 14);
    const syn = 29.530588853;
    final d = now.toUtc().difference(ref).inMinutes / 1440.0;
    final p = (d / syn) % 1.0;
    return p < 0 ? p + 1 : p;
  }

  static SkyState compute(DateTime now, String mode) {
    final ph = _moonPhase(now);
    if (mode == 'day') return _skyFor(62, true, 0.5, 0.5, ph);
    if (mode == 'night') return _skyFor(-32, false, 0.5, 0.5, ph);

    final hour = now.hour + now.minute / 60.0 + now.second / 3600.0;
    final doy = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final decl = -23.44 *
        math.pi /
        180 *
        math.cos(2 * math.pi / 365.0 * (doy + 10));
    final latR = _lat * math.pi / 180;
    // ظهرِ خورشیدی ≈ ۱۲ ساعتِ محلی (طولِ جغرافیایی از منطقه‌ی زمانی)
    final solarHour = hour;
    final ha = (solarHour - 12.0) * 15.0 * math.pi / 180;
    final sinAlt = math.sin(latR) * math.sin(decl) +
        math.cos(latR) * math.cos(decl) * math.cos(ha);
    final altDeg = math.asin(sinAlt.clamp(-1.0, 1.0).toDouble()) * 180 / math.pi;

    final cosH0 =
        (-math.tan(latR) * math.tan(decl)).clamp(-1.0, 1.0).toDouble();
    final h0 = math.acos(cosH0) * 180 / math.pi / 15.0; // نیمه‌ی روز (ساعت)
    final rise = 12.0 - h0, set = 12.0 + h0;
    final dayLen = math.max(0.5, set - rise);
    final dayFrac = ((solarHour - rise) / dayLen).clamp(0.0, 1.0).toDouble();
    final nightLen = math.max(0.5, 24.0 - dayLen);
    var sinceSet = solarHour - set;
    if (sinceSet < 0) sinceSet += 24.0;
    final nightFrac = (sinceSet / nightLen).clamp(0.0, 1.0).toDouble();

    return _skyFor(altDeg, solarHour < 12.0, dayFrac, nightFrac, ph);
  }
}

/// آسمان را پشتِ [builder] می‌کشد و هر ۳۰ ثانیه با ساعتِ گوشی به‌روز می‌کند.
/// اگر [enabled] نباشد فقط [builder] با `sky == null` صدا زده می‌شود.
class DayCycleScope extends StatefulWidget {
  const DayCycleScope({super.key, required this.enabled, required this.builder});

  final bool enabled;
  final Widget Function(BuildContext context, SkyState? sky) builder;

  @override
  State<DayCycleScope> createState() => _DayCycleScopeState();
}

class _DayCycleScopeState extends State<DayCycleScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  Timer? _timer;
  late SkyState _sky;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 40))
      ..repeat();
    _sky = DayCycle.compute(DateTime.now(), DayCycle.mode.value);
    DayCycle.mode.addListener(_refresh);
    DayCycle.load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _sky = DayCycle.compute(DateTime.now(), DayCycle.mode.value));
  }

  @override
  void dispose() {
    _timer?.cancel();
    DayCycle.mode.removeListener(_refresh);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.builder(context, null);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _SkyPainter(_sky, _anim),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        widget.builder(context, _sky),
      ],
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.s, this.anim) : super(repaint: anim);
  final SkyState s;
  final Animation<double> anim;

  static final List<List<double>> _stars = () {
    final r = math.Random(1405);
    return List.generate(
        90, (_) => [r.nextDouble(), r.nextDouble() * 0.9, 0.5 + r.nextDouble() * 1.3, r.nextDouble() * 6.283]);
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.top, s.bottom],
          ).createShader(Offset.zero & size));

    final t = anim.value * 2 * math.pi;

    // ستاره‌ها
    if (s.starA > 0.01) {
      final p = Paint();
      for (final st in _stars) {
        final tw = 0.65 + 0.35 * math.sin(t * 3 + st[3]);
        p.color = Colors.white.withValues(alpha: (s.starA * tw * 0.9).clamp(0.0, 1.0).toDouble());
        canvas.drawCircle(Offset(st[0] * w, st[1] * h), st[2], p);
      }
    }

    // ابرهای نرم (روز و غروب)
    final cloudA = (0.55 * (1 - s.starA)).clamp(0.0, 1.0).toDouble();
    if (cloudA > 0.02) {
      final warm = Color.lerp(Colors.white, const Color(0xFFFFC9A0),
          s.altDeg < 8 ? 0.6 : 0.0)!;
      final cp = Paint()..color = warm.withValues(alpha: cloudA);
      for (var i = 0; i < 4; i++) {
        final x = ((i * 0.31 + anim.value * (0.4 + i * 0.1)) % 1.3 - 0.15) * w;
        final y = h * (0.12 + 0.09 * i);
        final k = 0.9 + 0.25 * (i % 2);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 150 * k, height: 26 * k), cp);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(x + 28 * k, y - 10 * k), width: 78 * k, height: 26 * k),
            cp);
      }
    }

    // خورشید
    if (s.sunA > 0.01) {
      final x = w * (0.12 + 0.76 * s.dayFrac);
      final y = h * (0.22 - 0.12 * math.sin(math.pi * s.dayFrac));
      final warmK = (s.altDeg / 25).clamp(0.0, 1.0).toDouble();
      final c = Color.lerp(const Color(0xFFFF8A3D), const Color(0xFFFFF1B8), warmK)!;
      final glow = Paint()
        ..shader = RadialGradient(colors: [
          c.withValues(alpha: 0.55 * s.sunA),
          c.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: Offset(x, y), radius: 90));
      canvas.drawCircle(Offset(x, y), 90, glow);
      canvas.drawCircle(Offset(x, y), 24, Paint()..color = c.withValues(alpha: s.sunA));
    }

    // ماه
    if (s.moonA > 0.01) {
      final x = w * (0.12 + 0.76 * s.nightFrac);
      final y = h * (0.22 - 0.12 * math.sin(math.pi * s.nightFrac));
      const r = 20.0;
      final c = Offset(x, y);
      final a = s.moonA;
      canvas.drawCircle(
          c,
          70,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xFFDDE6FF).withValues(alpha: 0.28 * a),
              const Color(0xFFDDE6FF).withValues(alpha: 0.0),
            ]).createShader(Rect.fromCircle(center: c, radius: 70)));
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2A3050).withValues(alpha: 0.55 * a));
      final ph = s.moonPhase;
      final k = (1 - math.cos(2 * math.pi * ph)) / 2; // نورانیت ۰..۱
      final waxing = ph < 0.5;
      final moon = Path()..addOval(Rect.fromCircle(center: c, radius: r));
      final shift = 2 * r * k;
      final shadow = Path()
        ..addOval(Rect.fromCircle(
            center: Offset(c.dx + (waxing ? -shift : shift), c.dy), radius: r));
      final lit = k > 0.97 ? moon : Path.combine(PathOperation.difference, moon, shadow);
      canvas.drawPath(lit, Paint()..color = const Color(0xFFF6F1D8).withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.s != s;
}
