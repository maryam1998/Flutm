import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/constants.dart';
import 'panel_kit.dart';
import 'web_color_picker.dart';

const _kGold = Color(0xFFC9962B);
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF5B5F77);
const _kBorder = Color.fromRGBO(20, 24, 50, 0.10);
const _kField = Color(0xFFF1F2F8);

/// رنگ‌های بیشتر برای هدف (علاوه بر ۸ رنگ پیش‌فرض نقشه)
const _kMoreColors = <Color>[
  Color(0xFFE5484D), // قرمز
  Color(0xFF2DD4BF), // فیروزه‌ای تیره
  Color(0xFF3B82F6), // آبی
  Color(0xFF22C55E), // سبز
];

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
    final hex = _hex(col);

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F141832), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── عنوان ──
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: col.withAlpha(36),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.timeline_rounded, size: 17, color: col),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text('ظاهر مسیر هدف',
                    style: TextStyle(
                        fontSize: 14,
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
                label: const Text('بازنشانی خط', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── پیش‌نمایش زنده ──
          Container(
            height: 92,
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
          const SizedBox(height: 16),

          // ── رنگ ──
          Row(
            children: [
              const Text('رنگ هدف و مسیر',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _kInk)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _kField,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: col, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(hex.toUpperCase(),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GoalColorGrid(color: col, onColor: onColor),
          // ── نوع خط ──
          const PanelLabel('نوع خط مسیر'),
          const Text(
            'ظاهرِ خطِ اصلی که از «من» تا این هدف کشیده می‌شود (فقط شکل خط؛ شکل خم‌شدنِ شاخه‌ها جدا و پایین‌تر است).',
            style: TextStyle(fontSize: 11.5, height: 1.6, color: _kMuted),
          ),
          const SizedBox(height: 10),
          PanelChoiceGrid(
            current: styleKey,
            onPick: onStyle,
            preview: (k, c) => TrunkLinePainter(k.isEmpty ? 'dashed' : k, c),
            choices: [
              const PanelChoice('', 'مثل نقشه'),
              for (final e in kTrunkStyles.entries) PanelChoice(e.key, e.value),
            ],
          ),
          const SizedBox(height: 18),

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
                child: Text(isDefault ? 'پیش‌فرض (${_fa(defW)})' : _fa(eff),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _kGold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _RoundBtn(
                icon: Icons.remove_rounded,
                onTap: eff <= minW
                    ? null
                    : () => onWidth(math.max(minW, eff - 0.5)),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    activeTrackColor: col,
                    inactiveTrackColor: _kBorder,
                    thumbColor: col,
                    overlayColor: col.withAlpha(40),
                  ),
                  child: Slider(
                    min: minW,
                    max: maxW,
                    divisions: ((maxW - minW) * 2).round(),
                    value: eff,
                    onChanged: (v) => onWidth(v),
                  ),
                ),
              ),
              _RoundBtn(
                icon: Icons.add_rounded,
                onTap: eff >= maxW
                    ? null
                    : () => onWidth(math.min(maxW, eff + 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 6),
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

/// شبکه‌ی رنگِ مشترک برای همه‌ی بخش‌های هدف‌گذاری (همان ظاهر کارت «ظاهر مسیر هدف»):
/// ۸ رنگ پیش‌فرض نقشه + ۴ رنگ بیشتر + رنگ دلخواه (چرخه‌ی رنگ). رنگ انتخاب‌شده تیک دارد.
/// [extra] رنگ‌های اضافه‌ی خاص یک بخش (مثلاً رنگ حلقه) را به انتهای پالت می‌افزاید.
class GoalColorGrid extends StatelessWidget {
  const GoalColorGrid({
    super.key,
    required this.color,
    required this.onColor,
    this.extra = const [],
    this.noSelection = false,
  });

  /// true ⇒ هیچ رنگی تیک نمی‌خورد (مثلاً وقتی «مثل هدف» انتخاب شده)
  final bool noSelection;
  final Color color;
  final ValueChanged<String> onColor;
  final List<Color> extra;

  @override
  Widget build(BuildContext context) {
    final hex = GoalPathCard._hex(color);
    final all = <Color>[...kWebPalette, ..._kMoreColors];
    for (final e in extra) {
      if (!all.any((c) => GoalPathCard._hex(c) == GoalPathCard._hex(e))) all.add(e);
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final c in all)
          _Swatch(
            color: c,
            active: !noSelection && GoalPathCard._hex(c) == hex,
            onTap: () => onColor(GoalPathCard._hex(c)),
          ),
        // رنگ دلخواه (چرخه‌ی رنگ کامل)
        GestureDetector(
          onTap: () async {
            final picked = await showWebColorDialog(context, initial: color);
            if (picked != null) onColor(GoalPathCard._hex(picked));
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(colors: [
                Color(0xFFFF4D4D),
                Color(0xFFFFD93D),
                Color(0xFF6BFF6B),
                Color(0xFF4DFFEA),
                Color(0xFF4D79FF),
                Color(0xFFD14DFF),
                Color(0xFFFF4D4D),
              ]),
              border: Border.all(color: const Color(0x22000000), width: 1.5),
            ),
            child: const Icon(Icons.add, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(
      {required this.color, required this.active, required this.onTap});
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? _kInk : const Color(0x22000000),
            width: active ? 3 : 1.5,
          ),
        ),
        child: active
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _kField,
          shape: BoxShape.circle,
          border: Border.all(color: _kBorder),
        ),
        child: Icon(icon, size: 18, color: on ? _kInk : _kMuted.withAlpha(90)),
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
