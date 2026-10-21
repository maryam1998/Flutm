import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/constants.dart';
import 'panel_kit.dart';
import 'web_color_picker.dart';

const _kGold = Color(0xFF178A7C); // سبز هماهنگ با بقیه‌ی تب‌ها
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF5B5F77);
const _kBorder = Color.fromRGBO(23, 138, 124, 0.28);
const _kField = Color(0xFFF1F2F8);

/// کارت «ظاهر مسیر هدف»: پیش‌نمایش زنده + رنگ هدف + ضخامت خط مسیر.
///
/// ضخامت: ۱ تا ۱۲ (پیش‌فرض نقشه ۳). مقدار `0` یعنی «پیش‌فرض».
class GoalPathCard extends StatelessWidget {
  const GoalPathCard({
    super.key,
    required this.color,
    required this.width,
    required this.styleKey,
    required this.onColor,
    required this.onWidth,
    required this.onStyle,
    required this.onReset,
  });

  /// رنگ فعلی هدف (#rrggbb) — می‌تواند خالی باشد
  final String? color;

  /// ضخامت (۰ = پیش‌فرض)
  final double width;

  /// سبک خط مسیر ('' = مثل نقشه → خط‌چین)
  final String styleKey;

  final ValueChanged<String> onColor;
  final ValueChanged<double> onWidth;
  final ValueChanged<String> onStyle;
  final VoidCallback onReset;

  static const double minW = 1;
  static const double maxW = 12;
  static const double defW = 3;

  static String _hex(Color c) {
    int v(double x) => (x * 255).round().clamp(0, 255);
    return '#${v(c.r).toRadixString(16).padLeft(2, '0')}'
        '${v(c.g).toRadixString(16).padLeft(2, '0')}'
        '${v(c.b).toRadixString(16).padLeft(2, '0')}';
  }

  static String _fa(double w) {
    final isInt = (w - w.roundToDouble()).abs() < 0.01;
    return isInt ? toFa(w.round()) : toFa(w.toStringAsFixed(1)).replaceAll('.', '٫');
  }

  @override
  Widget build(BuildContext context) {
    final col = hexColor(color, kWebPalette.first);
    final eff = width > 0 ? width.clamp(minW, maxW).toDouble() : defW;
    final isDefault = width <= 0;
    final style = styleKey.isEmpty ? 'dashed' : styleKey;

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── عنوان ──
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _kGold.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.timeline_rounded, size: 16, color: _kGold),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text('ظاهر مسیر هدف',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _kInk)),
              ),
              TextButton.icon(
                onPressed: onReset,
                style: TextButton.styleFrom(
                  foregroundColor: _kMuted,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('بازنشانی', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── پیش‌نمایش زنده ──
          Container(
            height: 76,
            decoration: BoxDecoration(
              color: _kField,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: _PathPreviewPainter(
                color: col,
                width: eff,
                style: style,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 12),

          // ── رنگ ──
          const Text('رنگ هدف و مسیر',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _kInk)),
          const SizedBox(height: 10),
          GoalColorGrid(color: col, onColor: onColor),
          // ── نوع خط ──
          const PanelLabel('نوع خط مسیر'),
          const SizedBox(height: 2),
          PanelChoiceGrid(
            current: styleKey,
            onPick: onStyle,
            preview: (k, c) => TrunkLinePainter(k.isEmpty ? 'dashed' : k, c),
            choices: [
              const PanelChoice('', 'مثل نقشه'),
              for (final e in kTrunkStyles.entries) PanelChoice(e.key, e.value),
            ],
          ),
          const SizedBox(height: 14),

          // ── ضخامت ──
          Row(
            children: [
              const Text('ضخامت مسیر',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _kInk)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _kGold.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(isDefault ? 'پیش‌فرض' : _fa(eff),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _kGold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: _kGold,
              inactiveTrackColor: _kBorder,
              thumbColor: _kGold,
              overlayColor: _kGold.withAlpha(36),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              min: minW,
              max: maxW,
              divisions: ((maxW - minW) * 2).round(),
              value: eff,
              onChanged: (v) => onWidth(v),
            ),
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in const [
                ('نازک', 1.5),
                ('معمولی', 3.0),
                ('ضخیم', 6.0),
                ('خیلی ضخیم', 10.0),
              ])
                _Chip(
                  label: p.$1,
                  active: (eff - p.$2).abs() < 0.05,
                  onTap: () => onWidth(p.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// انتخاب رنگِ مشترک برای همه‌ی بخش‌های هدف‌گذاری (شاخه، زیرشاخه، هدف، من، ...).
///
/// به‌جای شبکه‌ی شلوغِ رنگ‌ها، فقط یک مستطیل با رنگِ انتخاب‌شده نشان داده می‌شود؛
/// با لمس آن، پالت رنگ (دیالوگ «Select color») باز می‌شود.
/// [extra] فقط برای سازگاری با فراخوانی‌های قبلی مانده و دیگر استفاده نمی‌شود.
class GoalColorGrid extends StatelessWidget {
  const GoalColorGrid({
    super.key,
    required this.color,
    required this.onColor,
    this.extra = const [],
    this.noSelection = false,
  });

  /// true ⇒ هنوز رنگی انتخاب نشده (مثلاً وقتی «مثل هدف» انتخاب شده)
  final bool noSelection;
  final Color color;
  final ValueChanged<String> onColor;
  final List<Color> extra;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        (noSelection || color.computeLuminance() > 0.6) ? _kMuted : Colors.white;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: GestureDetector(
        onTap: () async {
          final picked = await showWebColorDialog(context, initial: color);
          if (picked != null) onColor(GoalPathCard._hex(picked));
        },
        child: Container(
          width: 92,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: noSelection ? _kField : color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: noSelection ? _kBorder : const Color(0x55000000),
              width: noSelection ? 1.2 : 1.6,
            ),
          ),
          child: Icon(Icons.colorize_rounded, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _kGold.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? _kGold : _kBorder, width: active ? 1.6 : 1.2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? _kGold : _kMuted)),
      ),
    );
  }
}

/// پیش‌نمایش مسیر «من ← هدف» با همان منطق رسم نقشه (ضخامت پایه ۳)
class _PathPreviewPainter extends CustomPainter {
  _PathPreviewPainter(
      {required this.color, required this.width, required this.style});
  final Color color;
  final double width;
  final String style;

  Paint _p(double w, double op, {StrokeCap cap = StrokeCap.round}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = cap
    ..strokeJoin = StrokeJoin.round
    ..color = color.withValues(alpha: op);

  void _dashed(Canvas c, Path path, Paint p, List<double> dashes) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      var i = 0;
      while (d < m.length) {
        final len = dashes[i % dashes.length];
        if (i.isEven) c.drawPath(m.extractPath(d, math.min(d + len, m.length)), p);
        d += len;
        i++;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(34, size.height * 0.68);
    final b = Offset(size.width - 34, size.height * 0.32);
    final c1 = Offset(a.dx + (b.dx - a.dx) * 0.35, a.dy - size.height * 0.34);
    final c2 = Offset(a.dx + (b.dx - a.dx) * 0.65, b.dy + size.height * 0.34);
    Path cubic(Offset o) => Path()
      ..moveTo(a.dx + o.dx, a.dy + o.dy)
      ..cubicTo(c1.dx + o.dx, c1.dy + o.dy, c2.dx + o.dx, c2.dy + o.dy,
          b.dx + o.dx, b.dy + o.dy);

    final path = cubic(Offset.zero);
    final k = width / 3.0;
    final dk = k.clamp(0.7, 2.6).toDouble();

    switch (style) {
      case 'solid':
        canvas.drawPath(path, _p(3 * k, 0.9));
      case 'dotted':
        _dashed(canvas, path, _p(3.6 * k, 0.9), [0.1, 8 * dk]);
      case 'dashdot':
        _dashed(canvas, path, _p(3 * k, 0.9, cap: StrokeCap.butt),
            [14 * dk, 7 * dk, 2 * dk, 7 * dk]);
      case 'long':
        _dashed(canvas, path, _p(3 * k, 0.9, cap: StrokeCap.butt),
            [26 * dk, 13 * dk]);
      case 'double':
        final off = 2.6 * k + (k > 1 ? (k - 1) * 0.8 : 0);
        canvas.drawPath(cubic(Offset(0, -off)), _p(1.6 * k, 0.9));
        canvas.drawPath(cubic(Offset(0, off)), _p(1.6 * k, 0.9));
      case 'glow':
        canvas.drawPath(path, _p(9 * k, 0.16));
        canvas.drawPath(path, _p(2.8 * k, 0.95));
      case 'taper':
        final ms = path.computeMetrics().first;
        const seg = 14;
        for (var s = 0; s < seg; s++) {
          final w = 5.2 * k + (1.6 * k - 5.2 * k) * ((s + 0.5) / seg);
          final t0 = ms.length * s / seg, t1 = ms.length * (s + 1) / seg;
          canvas.drawPath(ms.extractPath(t0, t1), _p(w, 0.9));
        }
      default:
        _dashed(canvas, path, _p(3 * k, 0.9, cap: StrokeCap.butt),
            [9 * dk, 9 * dk]);
    }

    // «من» (سمت راست در RTL → اینجا ابتدای خط) و هدف
    canvas.drawCircle(a, 7, Paint()..color = const Color(0xFF5B5F77));
    canvas.drawCircle(
        a,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white);
    canvas.drawCircle(b, 11, Paint()..color = color);
    canvas.drawCircle(
        b, 11, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PathPreviewPainter old) =>
      old.color != color || old.width != width || old.style != style;
}
