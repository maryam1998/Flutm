import 'package:flutter/material.dart';

/// ۸ رنگ پیش‌فرض (همان PALETTE نسخه‌ی وب در map-tab.js)
const kWebPalette = <Color>[
  Color(0xFFF4C542), // زرد
  Color(0xFF5EC8F0), // آبی روشن
  Color(0xFFF0708A), // صورتی
  Color(0xFF8F7BF0), // بنفش
  Color(0xFF63D6A8), // سبز
  Color(0xFFF0A15E), // نارنجی
  Color(0xFFE06BD6), // سرخابی
  Color(0xFF7BD0F0), // فیروزه‌ای
];

/// ۸ رنگ داخل دیالوگ مرحله‌ی اول (همان رنگ‌های دیالوگ اندروید)
const _kSimpleGrid = <Color>[
  Color(0xFFFF0000), // red
  Color(0xFF00FFFF), // cyan
  Color(0xFF0000FF), // blue
  Color(0xFF00FF00), // green
  Color(0xFFFF00FF), // magenta
  Color(0xFFFFFF00), // yellow
  Color(0xFF000000), // black
  Color(0xFFFFFFFF), // white
];

class WebColorPicker extends StatelessWidget {
  final Color value;
  final ValueChanged<Color> onChanged;
  final List<Color> palette;

  const WebColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.palette = kWebPalette,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in palette)
          _swatch(c, _same(c, value), () => onChanged(c)),
        _customButton(context),
      ],
    );
  }

  Widget _swatch(Color c, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? const Color(0xFF2A2218) : const Color(0x22000000),
            width: active ? 3 : 1.5,
          ),
        ),
      ),
    );
  }

  Widget _customButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showWebColorDialog(context, initial: value);
        if (picked != null) onChanged(picked);
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: value,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2A2218), width: 1.8),
        ),
        child: const Icon(Icons.colorize, size: 18, color: Colors.white),
      ),
    );
  }

  static bool _same(Color a, Color b) => a.r == b.r && a.g == b.g && a.b == b.b;
}

// ───────────────────── دیالوگ رنگ ─────────────────────

Future<Color?> showWebColorDialog(
  BuildContext context, {
  required Color initial,
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _WebColorDialog(initial: initial),
  );
}

class _WebColorDialog extends StatefulWidget {
  final Color initial;
  const _WebColorDialog({required this.initial});

  @override
  State<_WebColorDialog> createState() => _WebColorDialogState();
}

class _WebColorDialogState extends State<_WebColorDialog> {
  late Color _current;
  int _page = 0; // 0 = simple, 1 = hsv

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
  }

  static bool _same(Color a, Color b) => a.r == b.r && a.g == b.g && a.b == b.b;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _page == 0 ? _simplePage() : _hsvPage(),
        ),
      ),
    );
  }

  // ────── صفحه‌ی ۱: ۸ مربع + Custom ──────

  Widget _simplePage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select color',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final c in _kSimpleGrid)
              GestureDetector(
                onTap: () => setState(() => _current = c),
                child: Container(
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(
                      color: _same(c, _current)
                          ? Colors.black
                          : const Color(0x33000000),
                      width: _same(c, _current) ? 3 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => setState(() => _page = 1),
              child: const Text('Custom', style: TextStyle(fontSize: 14)),
            ),
            const Spacer(),
            const Text('Chosen color',
                style: TextStyle(fontSize: 14, color: Colors.black87)),
            const SizedBox(width: 8),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _current,
                border: Border.all(color: const Color(0x44000000)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 4),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
              ),
              onPressed: () => Navigator.pop(context, _current),
              child: const Text('Set', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }

  // ────── صفحه‌ی ۲: HSV ──────

  Widget _hsvPage() {
    final hsv = HSVColor.fromColor(_current);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select color',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _label('Hue'),
        _hueSlider(hsv),
        const SizedBox(height: 10),
        _label('Saturation'),
        _satSlider(hsv),
        const SizedBox(height: 10),
        _label('Value'),
        _valSlider(hsv),
        const SizedBox(height: 14),
        Row(
          children: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => setState(() => _page = 0),
              child: const Text('Suggestions', style: TextStyle(fontSize: 14)),
            ),
            const Spacer(),
            const Text('Chosen color',
                style: TextStyle(fontSize: 14, color: Colors.black87)),
            const SizedBox(width: 8),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _current,
                border: Border.all(color: const Color(0x44000000)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 4),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
              ),
              onPressed: () => Navigator.pop(context, _current),
              child: const Text('Set', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s,
            style: const TextStyle(fontSize: 15, color: Colors.black87)),
      );

  Widget _hueSlider(HSVColor hsv) => _track(
        gradient: LinearGradient(
          colors: [
            for (var i = 0; i <= 6; i++)
              HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
          ],
        ),
        value: hsv.hue,
        max: 360,
        onChanged: (v) =>
            setState(() => _current = hsv.withHue(v).toColor()),
      );

  Widget _satSlider(HSVColor hsv) => _track(
        gradient: LinearGradient(
          colors: [
            HSVColor.fromAHSV(1, hsv.hue, 0, hsv.value).toColor(),
            HSVColor.fromAHSV(1, hsv.hue, 1, hsv.value).toColor(),
          ],
        ),
        value: hsv.saturation,
        max: 1,
        onChanged: (v) =>
            setState(() => _current = hsv.withSaturation(v).toColor()),
      );

  Widget _valSlider(HSVColor hsv) => _track(
        gradient: LinearGradient(
          colors: [
            HSVColor.fromAHSV(1, hsv.hue, hsv.saturation, 0).toColor(),
            HSVColor.fromAHSV(1, hsv.hue, hsv.saturation, 1).toColor(),
          ],
        ),
        value: hsv.value,
        max: 1,
        onChanged: (v) =>
            setState(() => _current = hsv.withValue(v).toColor()),
      );

  Widget _track({
    required Gradient gradient,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 22,
        activeTrackColor: Colors.transparent,
        inactiveTrackColor: Colors.transparent,
        disabledActiveTrackColor: Colors.transparent,
        disabledInactiveTrackColor: Colors.transparent,
        thumbColor: Colors.white,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 9,
          elevation: 2,
          pressedElevation: 4,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 22,
            decoration: BoxDecoration(
              gradient: gradient,
              border: Border.all(color: const Color(0x33000000)),
            ),
          ),
          Slider(
            min: 0,
            max: max,
            value: value.clamp(0, max),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
