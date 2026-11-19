import 'dart:math' as math;
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
    ready = _keys.every(_imgs.containsKey);
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
    final String key = budOnly ? 'sprout' : flowerKeys[(h ~/ 7) % flowerKeys.length];
    final size = (0.92 + ((h ~/ 11) % 5) * 0.04);
    final base = r *
        size *
        (budOnly ? 2.3 : (key == 'mushroom' ? 2.5 : 3.1));
    // کجیِ کم به سمتِ جهتِ رشد + نسیم؛ همیشه رو به بالا می‌ماند (گلِ خوابیده نمی‌شود)
    var lean = math.cos(dir) * 0.16;
    if (windT != null) {
      lean += windSway(windT, tip.dx, (h % 6283) / 1000.0) * 0.12;
    }
    if (key == 'mushroom') lean *= 0.35;
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
    final height = size * 1.35 * (0.12 + 0.88 * _sm(k));
    if (height < 1.2) return;
    draw(canvas, 'bush', base, height,
        lean: sway * 0.3,
        flip: (seed.abs() >> 4).isOdd,
        alpha: math.min(1.0, 0.25 + k * 3.0),
        shadowW: 0.55);
  }

  /// گیاهِ در حال رشد (تایمر روشن/غنچه‌ی امروز): جوانه‌ای که با دقیقه‌ها بزرگ می‌شود
  static void growingSprout(ui.Canvas canvas, ui.Offset tip, double r,
      int h, double minutes, double? windT) {
    final m = math.max(0.0, minutes);
    final height = r *
        (1.5 + 1.6 * _sm(m / 15) + 1.2 * _sm((m - 15) / 60)) *
        (0.94 + ((h ~/ 11) % 4) * 0.03);
    var lean = 0.0;
    if (windT != null) {
      lean = windSway(windT, tip.dx, (h % 628) / 100.0) * 0.10;
    }
    draw(canvas, 'sprout', tip, height,
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
