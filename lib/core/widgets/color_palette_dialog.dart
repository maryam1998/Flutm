import 'package:flutter/material.dart';

import '../../app.dart';
import '../../features/tabs/_hope_panel.dart' show uiContentDirection;
import '../theme/app_theme_colors.dart';

/// 🎨 پالت رنگِ پیشرفته — بدون نیاز به کدِ رنگ.
/// حالت ۱: سواچ‌های آماده  |  حالت ۲ («پیشرفته»): اسلایدرهای Hue / Saturation / Value.
/// خروجی: '#RRGGBB' (حروف بزرگ) یا null اگر لغو شد.
Future<String?> showColorPaletteDialog(
  BuildContext context, {
  required String initial,
  String? title,
  List<Color>? swatches,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: uiContentDirection(ctx),
      child: _ColorPaletteDialog(
        initial: colorFromHex(initial),
        title: title ?? ctx.l10n.cp_title,
        swatches: swatches ?? kPaletteSwatches,
      ),
    ),
  );
}

/// '#RRGGBB' → Color (اگر نامعتبر بود، [fallback]).
Color colorFromHex(String hex, {Color fallback = const Color(0xFF1C2541)}) {
  final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex.trim());
  if (m == null) return fallback;
  return Color(int.parse('FF${m.group(1)}', radix: 16));
}

/// Color → '#RRGGBB'
String colorToHex(Color c) {
  String h(int x) => x.toRadixString(16).padLeft(2, '0');
  return '#${h(c.red)}${h(c.green)}${h(c.blue)}'.toUpperCase();
}

const List<Color> kPaletteSwatches = [
  Color(0xFF00FF00), Color(0xFF0000FF), Color(0xFF00FFFF), Color(0xFFFF0000),
  Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFFFFFF00), Color(0xFFFF00FF),
  Color(0xFFFF9800), Color(0xFF9C27B0), Color(0xFFF48FB1), Color(0xFF9E9E9E),
];

class _ColorPaletteDialog extends StatefulWidget {
  final Color initial;
  final String title;
  final List<Color> swatches;
  const _ColorPaletteDialog({
    required this.initial,
    required this.title,
    required this.swatches,
  });

  @override
  State<_ColorPaletteDialog> createState() => _ColorPaletteDialogState();
}

class _ColorPaletteDialogState extends State<_ColorPaletteDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  bool _advanced = false;

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final ml = MaterialLocalizations.of(context);
    final selectedHex = colorToHex(_color);

    return AlertDialog(
      backgroundColor: c.paper,
      title: Text(widget.title,
          style: TextStyle(color: c.ink, fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_advanced)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final sw in widget.swatches)
                      GestureDetector(
                        onTap: () => setState(() => _hsv = HSVColor.fromColor(sw)),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: sw,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sw.value == _color.value ? c.gold : Colors.black26,
                              width: sw.value == _color.value ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              else
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(context.l10n.cp_hue, c),
                      _GradSlider(
                        value: _hsv.hue / 360,
                        colors: [
                          for (var h = 0; h <= 360; h += 60)
                            HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
                        ],
                        onChanged: (v) => setState(
                            () => _hsv = _hsv.withHue((v * 360).clamp(0, 359.999))),
                      ),
                      _label(context.l10n.cp_saturation, c),
                      _GradSlider(
                        value: _hsv.saturation,
                        colors: [
                          HSVColor.fromAHSV(1, _hsv.hue, 0, 1).toColor(),
                          HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                        ],
                        onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
                      ),
                      _label(context.l10n.cp_value, c),
                      _GradSlider(
                        value: _hsv.value,
                        colors: [
                          Colors.black,
                          HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
                        ],
                        onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.cp_selected_color,
                            style: TextStyle(color: c.ink, fontSize: 13)),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(selectedHex,
                              style: TextStyle(color: c.inkSoft, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _advanced = !_advanced),
                    child: Text(_advanced ? context.l10n.cp_swatches : context.l10n.cp_advanced),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ml.cancelButtonLabel)),
        TextButton(
            onPressed: () => Navigator.pop(context, selectedHex),
            child: Text(ml.okButtonLabel)),
      ],
    );
  }

  Widget _label(String t, AppThemeColorsExt c) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(t, style: TextStyle(color: c.inkSoft, fontSize: 13)),
      );
}

/// اسلایدرِ گرادیانی با دستگیره‌ی سفید (۰..۱).
class _GradSlider extends StatelessWidget {
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;
  const _GradSlider({
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      void setFrom(double dx) => onChanged((dx / w).clamp(0.0, 1.0));
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => setFrom(d.localPosition.dx),
        onHorizontalDragStart: (d) => setFrom(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => setFrom(d.localPosition.dx),
        child: SizedBox(
          height: 32,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 26,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  border: Border.all(color: Colors.black26),
                ),
              ),
              Positioned(
                left: (value.clamp(0.0, 1.0) * w) - 11,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 3,
                          offset: const Offset(0, 1)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
