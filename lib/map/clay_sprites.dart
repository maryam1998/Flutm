import 'dart:math' as math;
import 'dart:typed_data' show Float64List;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/services.dart' show rootBundle;

import 'wind.dart' show windSway;

/// تصاویرِ سه‌بعدیِ «خمیری» (Clay) برای گیاه‌های نقشه 🌱🌷🌻🍄🌿
///
/// منطقِ استفاده (پیشرفتِ کاربر):
///  • در حال انجام (تایمر/ساعتِ ثبت‌شده/غنچه) → جوانه‌ی خمیری (`sprout`)
///  • تکمیل‌شده (تیک/گل‌شده) → گلِ کامل یا قارچ؛ از بین لاله، آفتابگردان و قارچ
///    به‌صورت تصادفیِ «ثابت برای هر شناسه» انتخاب می‌شود (هر روز/کار شکلِ خودش را دارد)
///  • انبوهیِ تلاش → بوته‌ی خمیری (`bush`) کنارِ جاده؛ هرچه زمانِ بیشتر، بوته‌ی بیشتر
///  • سایه‌ی نرم زیرِ هر گیاه تا روی زمین بنشیند
///  • هنگامِ شکفتنِ گل/قارچِ تازه، درخشش (Sparkles) دورش پخش می‌شود
///
/// اگر تصاویر هنوز بارگذاری نشده بودند (یا فایل‌ها نبودند) ready=false است و
/// نقشه همان رسمِ قبلی (برداری) را نشان می‌دهد؛ پس هیچ‌چیز خراب نمی‌شود.
class ClaySprites {
  ClaySprites._();

  static const List<String> _keys = [
    'sprout',
    'tulip',
    'sunflower',
    'mushroom',
    'bush',
  ];

  /// گل‌ها/قارچ‌هایی که برای «تکمیل‌شده» تصادفی انتخاب می‌شوند
  static const List<String> flowerKeys = ['tulip', 'sunflower', 'mushroom'];

  /// تصاویرِ تازه (اختیاری): اگر فایلی نبود فقط همان نوع کنار گذاشته می‌شود
  static const List<String> _extraKeys = [
    'grass',
    'grass_flower',
    'bush_flower',
    'tree',
    'sprout2',
    'sprout3',
  ];

  // استخرِ تصادفی (ثابت برای هر شناسه). تکرارِ یک نام = شانسِ بیشتر.
  // گلِ تکمیل‌شده: لاله، آفتابگردان، قارچ، چمنِ گل‌دار، بوته‌ی گل‌دار
  static const List<String> _flowerPool = [
    'tulip',
    'sunflower',
    'mushroom',
    'grass_flower',
    'bush_flower',
  ];
  // غنچه/در حال انجام: انواعِ جوانه
  static const List<String> _budPool = ['sprout', 'sprout2', 'sprout3'];
  // پوشش‌گیاهیِ کنارِ جاده: چمن، جوانه، بوته، درختچه
  static const List<String> _groundPool = [
    'bush',
    'grass',
    'tree',
    'sprout',
    'grass',
    'bush',
    'sprout2',
    'tree',
    'grass',
    'sprout3',
  ];
  static List<String> _flowerAvail = const ['tulip'];
  static List<String> _budAvail = const ['sprout'];
  static List<String> _groundAvail = const ['bush'];

  // ارتفاعِ نسبیِ هر نوع در جایگاهِ «بوته» (نسبت به ارتفاعِ بوته‌ی پایه)
  static const Map<String, double> _groundMul = {
    'bush': 1.0,
    'grass': 0.78,
    'tree': 1.05,
    'sprout': 0.9,
    'sprout2': 0.7,
    'sprout3': 0.76,
  };
  // ارتفاعِ نسبیِ هر نوع در جایگاهِ «گل» (ضرب در شعاع)
  static const Map<String, double> _flowerH = {
    'tulip': 3.1,
    'sunflower': 3.1,
    'mushroom': 2.5,
    'grass_flower': 2.3,
    'bush_flower': 2.5,
  };
  // ارتفاعِ نسبیِ هر جوانه (ضرب در شعاع)؛ جوانه‌های پهن کمی کوتاه‌تر
  static const Map<String, double> _budH = {
    'sprout': 2.3,
    'sprout2': 1.8,
    'sprout3': 2.0,
  };
  // کوتاه و پهن‌ها نباید کج شوند
  static const Set<String> _squat = {'mushroom', 'grass_flower', 'bush_flower'};

  static String _pick(List<String> pool, int h) => pool[h.abs() % pool.length];

  static final Map<String, ui.Image> _imgs = {};
  static Future<void>? _loading;
  static bool ready = false;

  /// بارگذاری را (یک‌بار) شروع می‌کند؛ نقشه چون هر فریم دوباره رسم می‌شود،
  /// بعد از آماده‌شدنِ تصاویر خودکار از آن‌ها استفاده می‌کند.
  static void ensure() {
    _loading ??= _load();
  }

  static Future<void> _load() async {
    for (final k in _keys) {
      try {
        final data = await rootBundle.load('assets/plants/$k.png');
        final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        final f = await codec.getNextFrame();
        _imgs[k] = f.image;
      } catch (_) {
        // فایلی نبود: همان رسمِ برداریِ قبلی می‌ماند
      }
    }
    for (final k in _extraKeys) {
      try {
        final data = await rootBundle.load('assets/plants/$k.png');
        final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        final f = await codec.getNextFrame();
        _imgs[k] = f.image;
      } catch (_) {
        // این نوع نبود: از استخر کنار گذاشته می‌شود
      }
    }
    List<String> avail(List<String> pool, String fallback) {
      final l = [
        for (final k in pool)
          if (_imgs.containsKey(k)) k
      ];
      return l.isEmpty ? [fallback] : l;
    }

    _flowerAvail = avail(_flowerPool, 'tulip');
    _budAvail = avail(_budPool, 'sprout');
    _groundAvail = avail(_groundPool, 'bush');
    ready = _keys.every(_imgs.containsKey);
  }

  // ───────────────────── جلوگیری از روی‌هم‌افتادن ─────────────────────
  // نقشه در هر فریم یک‌بار از [beginFrame] تا [endFrame] می‌کشد؛ هر گیاه جای
  // خودش (در مختصاتِ صفحه) را «رزرو» می‌کند. بوته‌های تزئینی (soft) اگر جایشان
  // پر باشد کشیده نمی‌شوند؛ گل/غنچه‌ی روزها (hard) همیشه کشیده می‌شوند، ولی اگر
  // روی چیزی بیفتند کمی کنار می‌روند. ردپا و بقیه‌ی اجزای نقشه دست‌نخورده‌اند.
  static bool _frameOn = false;
  static final List<ui.Rect> _occ = <ui.Rect>[];

  static void beginFrame() {
    _occ.clear();
    _frameOn = true;
  }

  static void endFrame() {
    _frameOn = false;
    _occ.clear();
  }

  /// جابه‌جاییِ لازم (مختصاتِ محلی) یا null = این گیاه کشیده نشود.
  /// [h] ارتفاعِ کاملِ گیاه (نه ارتفاعِ فعلیِ انیمیشن؛ تا تصمیم‌ها پایدار بماند)،
  /// [aspect] = پهنا/ارتفاع.
  static ui.Offset? _claim(
      ui.Canvas canvas, ui.Offset base, double h, double aspect,
      {required bool hard}) {
    if (!_frameOn) return ui.Offset.zero;
    final Float64List m = canvas.getTransform();
    final s = math.sqrt(m[0] * m[0] + m[1] * m[1]);
    if (s * h < 3.0) return ui.Offset.zero; // ریزِ نامرئی
    final clip = canvas.getDestinationClipBounds().inflate(120);
    ui.Rect rectAt(ui.Offset b) {
      final dx = m[0] * b.dx + m[4] * b.dy + m[12];
      final dy = m[1] * b.dx + m[5] * b.dy + m[13];
      final hh = h * s, ww = hh * aspect;
      return ui.Rect.fromLTWH(dx - ww * 0.36, dy - hh * 0.88, ww * 0.72, hh * 0.8);
    }

    bool free(ui.Rect r) {
      for (final o in _occ) {
        if (o.overlaps(r)) return false;
      }
      return true;
    }

    final r = rectAt(base);
    if (!r.overlaps(clip)) return ui.Offset.zero; // بیرونِ صفحه
    if (free(r)) {
      _occ.add(r);
      return ui.Offset.zero;
    }
    if (!hard) return null;
    final w = h * aspect;
    final cands = <ui.Offset>[
      ui.Offset(-0.6 * w, 0),
      ui.Offset(0.6 * w, 0),
      ui.Offset(0, 0.4 * h),
      ui.Offset(0, -0.4 * h),
      ui.Offset(-1.1 * w, 0),
      ui.Offset(1.1 * w, 0),
      ui.Offset(-0.6 * w, 0.4 * h),
      ui.Offset(0.6 * w, 0.4 * h),
      ui.Offset(-0.6 * w, -0.4 * h),
      ui.Offset(0.6 * w, -0.4 * h),
    ];
    for (final d in cands) {
      final rr = rectAt(base + d);
      if (free(rr)) {
        _occ.add(rr);
        return d;
      }
    }
    _occ.add(r);
    return ui.Offset.zero;
  }

  static double _aspect(String key) {
    final i = _imgs[key];
    return i == null ? 1.0 : i.width / i.height;
  }

  static double _sm(double x) {
    final t = x.clamp(0.0, 1.0).toDouble();
    return t * t * (3 - 2 * t);
  }

  // سایه‌ی نرم: یک بیضیِ گرادیانیِ مشترک (بدونِ MaskFilter/blur که پرهزینه است)
  static final ui.Paint _shadowPaint = ui.Paint()
    ..shader = ui.Gradient.radial(ui.Offset.zero, 1.0, const [
      ui.Color(0x38503C28),
      ui.Color(0x1A503C28),
      ui.Color(0x00503C28),
    ], const [
      0.0,
      0.55,
      1.0
    ]);

  static final ui.Paint _imgPaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.medium
    ..isAntiAlias = true;

  static final ui.Paint _sparkPaint = ui.Paint()..isAntiAlias = true;

  /// رسمِ یک تصویر: [base] = نقطه‌ی ریشه (وسطِ پایین)، [height] = ارتفاع،
  /// [lean] = کجیِ کم (رادیان) حولِ ریشه، [flip] = آینه‌ی افقی
  static void draw(ui.Canvas canvas, String key, ui.Offset base, double height,
      {double lean = 0.0,
      bool flip = false,
      double alpha = 1.0,
      double shadowW = 0.5,
      bool shadow = true}) {
    final img = _imgs[key];
    if (img == null || height < 0.8 || alpha <= 0.01) return;
    final w = height * img.width / img.height;
    final a = alpha.clamp(0.0, 1.0).toDouble();

    canvas.save();
    canvas.translate(base.dx, base.dy);
    if (shadow) {
      // سایه‌ی ملایم زیرِ گیاه (روی زمین)
      canvas.save();
      // (Paint.color با shader اثر ندارد؛ محوشدن با کوچک‌شدنِ سایه انجام می‌شود)
      final sw = math.max(1.0, w * shadowW * a);
      canvas.scale(sw, math.max(0.6, sw * 0.3));
      canvas.drawCircle(ui.Offset.zero, 1.0, _shadowPaint);
      canvas.restore();
    }
    if (lean != 0.0) canvas.rotate(lean);
    if (flip) canvas.scale(-1.0, 1.0);
    _imgPaint.color = ui.Color.fromRGBO(255, 255, 255, a);
    canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        ui.Rect.fromLTWH(-w / 2, -height, w, height),
        _imgPaint);
    canvas.restore();
  }

  /// غنچه/گلِ سرِ شاخه یا کنارِ جاده؛ جایگزینِ `MapPainter._sprig`.
  /// [h] هشِ ثابتِ شناسه، [p] ۰..۱ انیمیشنِ شکفتن، [budOnly] = در حال انجام (جوانه)
  static void sprig(ui.Canvas canvas, ui.Offset tip, double dir, double r,
      int h, double p,
      {required bool budOnly, double? windT}) {
    final k = Curves.easeOutBack.transform(p.clamp(0.0, 1.0).toDouble());
    if (k <= 0.02) return;
    final String key = budOnly
        ? _pick(_budAvail, h ~/ 3)
        : _pick(_flowerAvail, h ~/ 7);
    final size = (0.92 + ((h ~/ 11) % 5) * 0.04);
    final base = r * size * (budOnly ? (_budH[key] ?? 2.3) : (_flowerH[key] ?? 3.1));
    // جای گیاه را (با اندازه‌ی کاملش) رزرو کن؛ اگر رویِ چیزی افتاد کمی کنار می‌رود
    final shift = _claim(canvas, tip, base, _aspect(key), hard: true) ??
        ui.Offset.zero;
    tip = tip + shift;
    // کجیِ کم به سمتِ جهتِ رشد + نسیم؛ همیشه رو به بالا می‌ماند (گلِ خوابیده نمی‌شود)
    var lean = math.cos(dir) * 0.16;
    if (windT != null) {
      lean += windSway(windT, tip.dx, (h % 6283) / 1000.0) * 0.12;
    }
    if (_squat.contains(key)) lean *= 0.35;
    final flip = ((h >> 5) & 1) == 1;
    draw(canvas, key, tip, base * k,
        lean: lean,
        flip: flip,
        alpha: math.min(1.0, k * 1.6),
        shadowW: budOnly ? 0.5 : 0.42);
    if (!budOnly && p < 1.0) {
      _sparkles(canvas, tip - ui.Offset(0, base * 0.55), base, p, h);
    }
  }

  /// بوته‌ی خمیری؛ جایگزینِ `drawRoadBush`. [size] ≈ ارتفاعِ بوته‌ی کامل، [g] ۰..۱ رشد
  static void bush(ui.Canvas canvas, ui.Offset base, double size, double g,
      int seed, double sway) {
    final k = g.clamp(0.0, 1.0).toDouble();
    // نوعِ پوشش‌گیاهی (چمن/جوانه/بوته/درختچه): تصادفی ولی ثابت برای هر seed
    final mix = (seed.abs() % 100003) * 7919;
    final key = _pick(_groundAvail, mix >> 5);
    final full = size * 1.35 * (_groundMul[key] ?? 1.0);
    // جایِ کاملِ بوته رزرو می‌شود؛ اگر پر بود، این بوته‌ی تزئینی کشیده نمی‌شود
    if (_claim(canvas, base, full, _aspect(key), hard: false) == null) return;
    final height = full * (0.12 + 0.88 * _sm(k));
    if (height < 1.2) return;
    draw(canvas, key, base, height,
        lean: _squat.contains(key) ? 0.0 : sway * 0.3,
        flip: (seed.abs() >> 4).isOdd,
        alpha: math.min(1.0, 0.25 + k * 3.0),
        shadowW: 0.55);
  }

  /// گیاهِ در حال رشد (تایمر روشن/غنچه‌ی امروز): جوانه‌ای که با دقیقه‌ها بزرگ می‌شود
  static void growingSprout(ui.Canvas canvas, ui.Offset tip, double r,
      int h, double minutes, double? windT) {
    final m = math.max(0.0, minutes);
    final key = _pick(_budAvail, h ~/ 3);
    final mul = key == 'sprout' ? 1.0 : (_budH[key] ?? 2.3) / 2.3;
    final height = r *
        (1.5 + 1.6 * _sm(m / 15) + 1.2 * _sm((m - 15) / 60)) *
        (0.94 + ((h ~/ 11) % 4) * 0.03) *
        mul;
    // جای کاملِ جوانه (ارتفاعِ نهاییِ ۴٫۴ r) رزرو می‌شود تا تصمیم‌ها پایدار بماند
    final shift =
        _claim(canvas, tip, r * 4.4 * mul, _aspect(key), hard: true) ??
            ui.Offset.zero;
    tip = tip + shift;
    var lean = 0.0;
    if (windT != null) {
      lean = windSway(windT, tip.dx, (h % 628) / 100.0) * 0.10;
    }
    draw(canvas, key, tip, height,
        lean: lean, flip: ((h >> 5) & 1) == 1, shadowW: 0.45);
  }

  // ✨ درخششِ ملایم دورِ گل/قارچِ تازه‌شکفته
  static void _sparkles(
      ui.Canvas canvas, ui.Offset c, double size, double p, int h) {
    final fade = (1.0 - p).clamp(0.0, 1.0).toDouble();
    for (var i = 0; i < 7; i++) {
      final ang = i * 2.399963 + p * 1.8 + (h % 10) * 0.3;
      final dist = size * (0.38 + 0.55 * p) * (0.85 + (i % 3) * 0.14);
      final pos = c + ui.Offset(math.cos(ang) * dist, math.sin(ang) * dist * 0.85);
      final s = math.max(1.4, size * (0.07 + (i % 3) * 0.025)) *
          (0.55 + 0.45 * math.sin(p * math.pi));
      _star(canvas, pos, s,
          (i.isEven ? const ui.Color(0xFFFFE9A6) : const ui.Color(0xFFFFFFFF))
              .withValues(alpha: 0.55 + 0.45 * fade));
    }
  }

  static void _star(ui.Canvas canvas, ui.Offset c, double s, ui.Color col) {
    final path = ui.Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    _sparkPaint.color = col;
    canvas.drawPath(path, _sparkPaint);
  }
}
