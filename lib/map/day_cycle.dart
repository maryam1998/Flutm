import 'dart:async';
import 'dart:math' as math;

import 'dart:ui' show Path, PathOperation;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

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
    required this.ground,
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

  /// رنگِ زمینِ نقشه‌ی دوبعدی (بیابان) در این ساعت؛ آسمان ندارد
  final Color ground;
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
    // آسمان همیشه طبق ساعتِ گوشی است؛ روشن/تیره بودنِ برنامه را تمِ انتخابیِ
    // کاربر تعیین می‌کند (نه این‌جا).
    if (_loaded) return;
    _loaded = true;
    mode.value = 'auto';
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

  // رنگِ زمین (بیابانِ نقشه‌ی دوبعدی) بر حسبِ ارتفاعِ خورشید: [deg, color]
  static const List<List<int>> _gKeys = [
    [-18, 0xFF0A0C18],
    [-10, 0xFF12162B],
    [-4, 0xFF2A2440],
    [0, 0xFFF3D9B8],
    [6, 0xFFF8EBD6],
    [20, 0xFFFFFFFF],
    [90, 0xFFFFFFFF],
  ];

  static Color _ground(double altDeg) {
    final a = altDeg.clamp(-18.0, 90.0).toDouble();
    var i = 0;
    while (i < _gKeys.length - 2 && a > _gKeys[i + 1][0]) {
      i++;
    }
    final k0 = _gKeys[i], k1 = _gKeys[i + 1];
    final t = ((a - k0[0]) / (k1[0] - k0[0])).clamp(0.0, 1.0).toDouble();
    return Color.lerp(Color(k0[1]), Color(k1[1]), t)!;
  }

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

    final night = altDeg < -2.0;
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
      ground: _ground(altDeg),
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

/// «روشناییِ» نقشه‌ی دوبعدی را با ساعتِ گوشی هماهنگ می‌کند (رنگِ زمینِ بیابان؛
/// صبح و ظهر روشن، غروب گرم، شب تیره). نقشه‌ی دوبعدی آسمان ندارد؛ خورشید، ماه و
/// ستاره فقط در نمای ۳بعدی و قدم‌زدن دیده می‌شوند.
/// هر ۳۰ ثانیه با ساعت به‌روز می‌شود. اگر [enabled] نباشد، [builder] با `sky == null` صدا زده می‌شود.
/// ساعتِ مشترکِ انیمیشنِ آسمان (چشمکِ ستاره‌ها، شهاب، کرم‌های شب‌تاب).
/// فقط وقتی DayCycleScope روی صفحه است تیک می‌زند.
class SkyClock {
  SkyClock._();
  static final ValueNotifier<double> time = ValueNotifier<double>(0);
  static Ticker? _tk;
  static int _refs = 0;

  static void acquire() {
    _refs++;
    if (_tk != null) return;
    _tk = Ticker((d) => time.value = d.inMicroseconds / 1e6)..start();
  }

  static void release() {
    if (_refs > 0) _refs--;
    if (_refs == 0) {
      _tk?.dispose();
      _tk = null;
    }
  }
}

class DayCycleScope extends StatefulWidget {
  const DayCycleScope({
    super.key,
    required this.enabled,
    required this.builder,
    this.paintGround = true,
  });

  final bool enabled;

  /// false = رنگِ زمین را تمِ برنامه تعیین می‌کند و این‌جا زیرِ نقشه رنگ نمی‌ریزد
  final bool paintGround;
  final Widget Function(BuildContext context, SkyState? sky) builder;

  @override
  State<DayCycleScope> createState() => _DayCycleScopeState();
}

class _DayCycleScopeState extends State<DayCycleScope> {
  Timer? _timer;
  late SkyState _sky;

  @override
  void initState() {
    super.initState();
    SkyClock.acquire();
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
    SkyClock.release();
    _timer?.cancel();
    DayCycle.mode.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.builder(context, null);
    if (!widget.paintGround) return widget.builder(context, _sky);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              color: _sky.ground,
            ),
          ),
        ),
        widget.builder(context, _sky),
      ],
    );
  }
}

/// نقاشیِ خورشید، ماه و ستاره (برای آسمانِ نمای ۳بعدی و قدم‌زدن)
class SkyArt {
  SkyArt._();

  static final List<List<double>> stars = () {
    final r = math.Random(1405);
    return List.generate(
        90,
        (_) => [
              r.nextDouble(),
              r.nextDouble() * 0.9,
              0.6 + r.nextDouble() * 1.2,
              r.nextDouble() * 6.283
            ]);
  }();

  static void sun(Canvas canvas, Offset c, SkyState s, {double r = 24}) {
    if (s.sunA <= 0.01) return;
    final warmK = (s.altDeg / 25).clamp(0.0, 1.0).toDouble();
    final col =
        Color.lerp(const Color(0xFFFF8A3D), const Color(0xFFFFC21F), warmK)!;
    canvas.drawCircle(
        c,
        r * 3.6,
        Paint()
          ..shader = RadialGradient(colors: [
            col.withValues(alpha: 0.55 * s.sunA),
            col.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: c, radius: r * 3.6)));
    canvas.drawCircle(c, r, Paint()..color = col.withValues(alpha: s.sunA));
  }

  static void moon(Canvas canvas, Offset c, SkyState s,
      {double r = 20, bool plain = false}) {
    if (s.moonA <= 0.01) return;
    final a = s.moonA;
    if (!plain) {
    canvas.drawCircle(
        c,
        r * 3.5,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFDDE6FF).withValues(alpha: 0.28 * a),
            const Color(0xFFDDE6FF).withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: c, radius: r * 3.5)));
    canvas.drawCircle(c, r,
        Paint()..color = const Color(0xFF2A3050).withValues(alpha: 0.55 * a));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF8A93B8).withValues(alpha: 0.45 * a));
    }
    final ph = s.moonPhase;
    final k = (1 - math.cos(2 * math.pi * ph)) / 2; // نورانیت ۰..۱
    final waxing = ph < 0.5;
    final moonP = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final shift = 2 * r * k;
    final shadow = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(c.dx + (waxing ? -shift : shift), c.dy), radius: r));
    final lit = k > 0.95
        ? moonP
        : Path.combine(PathOperation.difference, moonP, shadow);
    canvas.drawPath(
        lit, Paint()..color = const Color(0xFFF6F1D8).withValues(alpha: a));
  }

  /// ستاره‌های صفحه (برای نمای ۳بعدیِ نقشه).
  /// اگر [t] (ثانیه) داده شود بعضی ستاره‌ها چشمک می‌زنند و گاهی شهاب می‌گذرد.
  static void starField(Canvas canvas, Size size, double alpha,
      {double scale = 1.0, double? t}) {
    if (alpha <= 0.01) return;
    final p = Paint();
    final tw = t == null ? null : t * 0.4; // چشمکِ آهسته
    for (var i = 0; i < stars.length; i++) {
      final st = stars[i];
      var a = alpha * (0.55 + 0.35 * (st[3] % 1.0));
      var rad = st[2] * scale;
      final c = Offset(st[0] * size.width, st[1] * size.height);
      if (tw != null) {
        if (i % 3 == 0) {
          // ستاره‌ی چشمک‌زن
          final k = 0.5 + 0.5 * math.sin(tw * (1.4 + (i % 5) * 0.37) + st[3]);
          a *= 0.15 + 0.85 * k;
          rad *= 0.8 + 0.45 * k;
          if (st[2] > 1.2 && k > 0.6) {
            final len = rad * 3.2 * k;
            final sp = Paint()
              ..strokeWidth = 0.8
              ..strokeCap = StrokeCap.round
              ..color = Colors.white
                  .withValues(alpha: (a * 0.8).clamp(0.0, 1.0).toDouble());
            canvas.drawLine(c.translate(-len, 0), c.translate(len, 0), sp);
            canvas.drawLine(c.translate(0, -len), c.translate(0, len), sp);
          }
        } else {
          // لرزشِ بسیار ملایم
          a *= 0.88 + 0.12 * math.sin(tw * 0.9 + st[3] * 3);
        }
      }
      p.color = Colors.white.withValues(alpha: a.clamp(0.0, 1.0).toDouble());
      canvas.drawCircle(c, rad, p);
    }
    if (t != null) _shootingStar(canvas, size, alpha, t);
  }

  /// شهابِ بسیار گاه‌به‌گاه (هر ~۶۰ ثانیه یک‌بار، آرام و حدودِ ۲ ثانیه)
  static void _shootingStar(Canvas canvas, Size size, double alpha, double t) {
    const period = 60.0, dur = 2.0;
    final n = (t / period).floor();
    final lt = t - n * period;
    if (lt > dur) return;
    final r = math.Random(n * 7919 + 13);
    final k = lt / dur;
    final start = Offset(size.width * (0.2 + 0.7 * r.nextDouble()),
        size.height * (0.05 + 0.4 * r.nextDouble()));
    final dir = Offset(-0.8 - 0.3 * r.nextDouble(), 0.45 + 0.2 * r.nextDouble());
    final len = size.width * 0.22;
    final head = start + dir * (len * k * 1.6);
    final tail = head - dir * (len * 0.35);
    final fade = math.sin(math.pi * k).clamp(0.0, 1.0).toDouble();
    canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..shader = _trail(tail, head, alpha * fade));
    canvas.drawCircle(head, 1.6,
        Paint()..color = Colors.white.withValues(alpha: alpha * fade));
  }

  static Shader _trail(Offset a, Offset b, double alpha) {
    return ui.Gradient.linear(a, b, [
      Colors.white.withValues(alpha: 0.0),
      Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0).toDouble()),
    ]);
  }
}

/// آسمانِ نمای ۳بعدیِ نقشه: ستاره، خورشید و ماه روی ناحیه‌ی بالای افق
class SkyObjectsPainter extends CustomPainter {
  SkyObjectsPainter(this.s, {Listenable? repaint, this.clock})
      : super(repaint: repaint);
  final SkyState s;

  /// زمانِ انیمیشن (ثانیه)؛ null = ستاره‌ها ثابت
  final double Function()? clock;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    SkyArt.starField(canvas, size, s.starA, t: clock?.call());
    if (s.sunA > 0.01) {
      final x = w * (0.12 + 0.76 * s.dayFrac);
      final y = h * (0.78 - 0.5 * math.sin(math.pi * s.dayFrac));
      SkyArt.sun(canvas, Offset(x, y), s);
    }
    if (s.moonA > 0.01) {
      final x = w * (0.12 + 0.76 * s.nightFrac);
      final y = h * (0.78 - 0.5 * math.sin(math.pi * s.nightFrac));
      SkyArt.moon(canvas, Offset(x, y), s);
    }
  }

  @override
  bool shouldRepaint(covariant SkyObjectsPainter old) => old.s != s;
}
