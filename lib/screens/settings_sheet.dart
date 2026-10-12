import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/constants.dart';
import '../state/map_store.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF14172F),
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late Color _textColor;
  late double _fontSize;
  late bool _showDates;
  late bool _showTimes;
  late bool _showRingLinks;
  late String _trunkStyle;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final s = context.read<MapStore>().state;
    _textColor = _parseTextColor(s.textColor);
    _fontSize = s.fontSize.clamp(8.0, 28.0);
    _showDates = s.showDateStamps;
    _showTimes = s.showTimeStamps;
    _showRingLinks = s.showRingLinks;
    _trunkStyle = kTrunkStyles.containsKey(s.trunkStyle) ? s.trunkStyle : 'dashed';
  }

  Color _parseTextColor(String c) {
    final lc = c.toLowerCase().trim();
    const auto = {'', '#eef0fa', '#ffffff', '#fff', '#000000', '#000'};
    if (auto.contains(lc)) return Colors.white;
    return hexColor(c, Colors.white);
  }

  void _save() {
    final store = context.read<MapStore>();
    final s = store.state;
    s.textColor = _hexFromColor(_textColor);
    s.fontSize = _fontSize;
    s.showDateStamps = _showDates;
    s.showTimeStamps = _showTimes;
    s.showRingLinks = _showRingLinks;
    s.trunkStyle = _trunkStyle;
    store.changed();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تنظیمات ذخیره شد')),
    );
  }

  String _hexFromColor(Color c) {
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    return '#${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings, size: 20),
                  const SizedBox(width: 8),
                  const Text('تنظیمات نقشه',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('لغو'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(onPressed: _save, child: const Text('ذخیره')),
                ],
              ),
              const SizedBox(height: 14),

              // ---------- رنگ متن ----------
              const _Label('رنگ نوشته‌های نقشه'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final hex in [...kPalette, '#eef0fa', '#ffffff', '#000000'])
                    GestureDetector(
                      onTap: () => setState(
                          () => _textColor = hexColor(hex, Colors.white)),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: hexColor(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _hexFromColor(_textColor) ==
                                    hex.toLowerCase()
                                ? Colors.white
                                : Colors.white24,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // انتخاب رنگ دلخواه
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _textColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('رنگ فعلی — برای انتخاب دقیق‌تر از اسلایدر پایین استفاده کن',
                        style: TextStyle(fontSize: 12, color: Colors.white60)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _rgbSlider('R', _textColor.r, (v) {
                setState(() => _textColor = Color.fromARGB(
                    255,
                    (v * 255).round(),
                    (_textColor.g * 255).round(),
                    (_textColor.b * 255).round()));
              }),
              _rgbSlider('G', _textColor.g, (v) {
                setState(() => _textColor = Color.fromARGB(
                    255,
                    (_textColor.r * 255).round(),
                    (v * 255).round(),
                    (_textColor.b * 255).round()));
              }),
              _rgbSlider('B', _textColor.b, (v) {
                setState(() => _textColor = Color.fromARGB(
                    255,
                    (_textColor.r * 255).round(),
                    (_textColor.g * 255).round(),
                    (v * 255).round()));
              }),

              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 6),

              // ---------- اندازه فونت ----------
              Row(
                children: [
                  const _Label('اندازه فونت'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(toFa(_fontSize.round()),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ],
              ),
              Slider(
                min: 8,
                max: 28,
                divisions: 20,
                value: _fontSize,
                label: toFa(_fontSize.round()),
                onChanged: (v) => setState(() => _fontSize = v),
              ),

              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 6),

              // ---------- سوییچ‌ها ----------
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('نمایش تاریخ روی نقشه'),
                subtitle: const Text('زیر نام هدف‌ها و شاخه‌ها',
                    style: TextStyle(fontSize: 11.5, color: Colors.white54)),
                value: _showDates,
                onChanged: (v) => setState(() => _showDates = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('نمایش ساعت روی نقشه'),
                subtitle: const Text('زیر تاریخ',
                    style: TextStyle(fontSize: 11.5, color: Colors.white54)),
                value: _showTimes,
                onChanged: (v) => setState(() => _showTimes = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('اتصال نشانه‌های نزدیکی به هدف'),
                subtitle: const Text(
                    'خط‌چین نازک از هدف به هر نشانه‌ی متصل',
                    style: TextStyle(fontSize: 11.5, color: Colors.white54)),
                value: _showRingLinks,
                onChanged: (v) => setState(() => _showRingLinks = v),
              ),

              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 6),

              // ---------- سبک تنه ----------
              const _Label('سبک پیش‌فرض خط مسیر اهداف'),
              const SizedBox(height: 4),
              const Text(
                'برای هر هدف به‌صورت جداگانه هم می‌تونی از توی ویرایش هدف عوضش کنی',
                style: TextStyle(fontSize: 11.5, color: Colors.white54),
              ),
              const SizedBox(height: 10),
              _trunkPicker(),

              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('ذخیره تنظیمات'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rgbSlider(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 20,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                      fontSize: 12))),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
              ),
              child: Slider(
                min: 0,
                max: 1,
                value: value.clamp(0.0, 1.0),
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              toFa((value * 255).round()),
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trunkPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in kTrunkStyles.entries)
          ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(28, 14),
                  painter: _TrunkPreviewPainter(
                    style: e.key,
                    color: e.key == _trunkStyle
                        ? Colors.white
                        : Colors.white54,
                  ),
                ),
                const SizedBox(width: 6),
                Text(e.value),
              ],
            ),
            selected: _trunkStyle == e.key,
            onSelected: (_) => setState(() => _trunkStyle = e.key),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
      );
}

// ---------- پیش‌نمایش سبک خط ----------
class _TrunkPreviewPainter extends CustomPainter {
  _TrunkPreviewPainter({required this.style, required this.color});
  final String style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = color;

    final a = Offset(0, size.height);
    final b = Offset(size.width, 0);

    switch (style) {
      case 'solid':
        canvas.drawLine(a, b, p);
      case 'dotted':
        for (var i = 0; i < 8; i++) {
          final t = i / 7;
          final pt = Offset.lerp(a, b, t)!;
          canvas.drawCircle(pt, 1, Paint()..color = color);
        }
      case 'dashdot':
        _dashLine(canvas, a, b, p, [5, 3, 1, 3]);
      case 'long':
        _dashLine(canvas, a, b, p, [8, 4]);
      case 'double':
        final perp = Offset(size.width == 0 ? 0 : 1.5, 1.5);
        canvas.drawLine(a + perp, b + perp, p..strokeWidth = 1.6);
        canvas.drawLine(a - perp, b - perp,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round
              ..color = color);
      case 'glow':
        canvas.drawLine(
            a,
            b,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeCap = StrokeCap.round
              ..color = color.withAlpha(60));
        canvas.drawLine(a, b, p..strokeWidth = 1.8);
      case 'taper':
        for (var i = 0; i < 7; i++) {
          final t0 = i / 7, t1 = (i + 1) / 7;
          final p1 = Offset.lerp(a, b, t0)!;
          final p2 = Offset.lerp(a, b, t1)!;
          final w = 3.5 - i * 0.4;
          canvas.drawLine(
              p1,
              p2,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = w
                ..strokeCap = StrokeCap.round
                ..color = color);
        }
      default:
        _dashLine(canvas, a, b, p, [4, 3]);
    }
  }

  void _dashLine(Canvas canvas, Offset a, Offset b, Paint p, List<double> dashes) {
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    var i = 0;
    while (d < total) {
      final len = dashes[i % dashes.length];
      if (i.isEven) {
        final s = a + dir * d;
        final e = a + dir * (d + len > total ? total : d + len);
        canvas.drawLine(s, e, p);
      }
      d += len;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _TrunkPreviewPainter old) =>
      old.style != style || old.color != color;
}
