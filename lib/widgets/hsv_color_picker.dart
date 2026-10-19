import 'package:flutter/material.dart';

const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);

/// انتخابگر رنگ HSV — ظاهری شبیه سیستم انتخابگر عکس دوم
class HsvColorPicker extends StatefulWidget {
  const HsvColorPicker({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final Color initial;
  final ValueChanged<Color> onChanged;

  @override
  State<HsvColorPicker> createState() => _HsvColorPickerState();
}

class _HsvColorPickerState extends State<HsvColorPicker> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  @override
  void didUpdateWidget(covariant HsvColorPicker old) {
    super.didUpdateWidget(old);
    // اگه رنگ از بیرون عوض شد، ولی کاربر در حال کار نبود
    if (old.initial != widget.initial &&
        HSVColor.fromColor(widget.initial).toColor() != _hsv.toColor()) {
      _hsv = HSVColor.fromColor(widget.initial);
    }
  }

  void _set(HSVColor c) {
    setState(() => _hsv = c);
    widget.onChanged(c.toColor());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------- Hue ----------
        _label('Hue'),
        const SizedBox(height: 6),
        _gradientSlider(
          value: _hsv.hue,
          min: 0,
          max: 360,
          gradient: _hueGradient(),
          onChanged: (v) => _set(_hsv.withHue(v)),
        ),
        const SizedBox(height: 14),

        // ---------- Saturation ----------
        _label('Saturation'),
        const SizedBox(height: 6),
        _gradientSlider(
          value: _hsv.saturation,
          min: 0,
          max: 1,
          gradient: LinearGradient(
            colors: [
              HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
              HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
            ],
          ),
          onChanged: (v) => _set(_hsv.withSaturation(v)),
        ),
        const SizedBox(height: 14),

        // ---------- Value ----------
        _label('Value'),
        const SizedBox(height: 6),
        _gradientSlider(
          value: _hsv.value,
          min: 0,
          max: 1,
          gradient: LinearGradient(
            colors: [
              Colors.black,
              HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
            ],
          ),
          onChanged: (v) => _set(_hsv.withValue(v)),
        ),
        const SizedBox(height: 16),

        // ---------- پیش‌نمایش ----------
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _hsv.toColor(),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder, width: 1.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chosen color',
                      style: TextStyle(fontSize: 12, color: _kMuted)),
                  const SizedBox(height: 4),
                  Text(
                    _hexOf(_hsv.toColor()),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            // پیشنهادها
            Wrap(
              spacing: 4,
              children: [
                for (final hex in const [
                  '#E5484D',
                  '#C9972B',
                  '#63D6A8',
                  '#5EC8F0',
                  '#8F7BF0',
                  '#F4C542',
                ])
                  GestureDetector(
                    onTap: () =>
                        _set(HSVColor.fromColor(_hexColor(hex))),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _hexColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(color: _kBorder, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String s) => Text(
        s,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: _kInk,
        ),
      );

  Widget _gradientSlider({
    required double value,
    required double min,
    required double max,
    required Gradient gradient,
    required ValueChanged<double> onChanged,
  }) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            top: 6,
            bottom: 6,
            child: Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder, width: 1),
              ),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 28,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              disabledActiveTrackColor: Colors.transparent,
              disabledInactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayColor: Colors.white.withValues(alpha: 0.24),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              min: min,
              max: max,
              value: value.clamp(min, max),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _hueGradient() {
    const stops = [
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ];
    return const LinearGradient(colors: stops);
  }

  String _hexOf(Color c) {
    final v = c.toARGB32();
    return '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(0xFF000000 | int.parse(h, radix: 16));
  }
}
