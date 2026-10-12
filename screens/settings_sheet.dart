import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/constants.dart';
import '../state/map_store.dart';
import '../state/theme_store.dart';
import '../theme/app_theme.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFFBF6EA),
    builder: (_) => Theme(data: lightTheme, child: const _SettingsSheet()),
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
    _fontSize = s.fontSize.clamp(8.0, 28.0).toDouble();
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
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFBF6EA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // هدر
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'تنظیمات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A2218),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('انصراف',
                          style: TextStyle(color: Color(0xFF7A6B57))),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC9972B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                      ),
                      onPressed: _save,
                      child: const Text('ذخیره',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE0D5C0)),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // سوییچ تم
                      Consumer<ThemeStore>(
                        builder: (_, theme, __) => _tile(
                          title: 'تم تاریک',
                          subtitle: theme.isDark
                              ? 'پس‌زمینه‌ی تیره با متن روشن'
                              : 'پس‌زمینه‌ی روشن (مثل نسخه‌ی وب)',
                          trailing: Switch(
                            value: theme.isDark,
                            activeThumbColor: const Color(0xFFC9972B),
                            onChanged: (v) => theme.setDark(v),
                          ),
                        ),
                      ),
                      const _SectionDivider(),

                      _sectionTitle('رنگ نوشته‌ها'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final hex in [
                            ...kPalette,
                            '#eef0fa',
                            '#ffffff',
                            '#000000'
                          ])
                            GestureDetector(
                              onTap: () => setState(
                                  () => _textColor = hexColor(hex, Colors.white)),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: hexColor(hex),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _hexFromColor(_textColor) ==
                                            hex.toLowerCase()
                                        ? const Color(0xFFC9972B)
                                        : const Color(0xFFE0D5C0),
                                    width: _hexFromColor(_textColor) ==
                                            hex.toLowerCase()
                                        ? 3
                                        : 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('اندازه فونت (پیش‌فرض ۱۴)'),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFFC9972B),
                                thumbColor: const Color(0xFFC9972B),
                                inactiveTrackColor: const Color(0xFFE0D5C0),
                              ),
                              child: Slider(
                                min: 8,
                                max: 28,
                                divisions: 20,
                                value: _fontSize,
                                label: toFa(_fontSize.round()),
                                onChanged: (v) =>
                                    setState(() => _fontSize = v),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            child: Text(
                              toFa(_fontSize.round()),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2A2218),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const _SectionDivider(),

                      _checkTile(
                        title: 'نمایش «تاریخ» ثبت هدف‌ها و شاخه‌ها روی صفحه اصلی',
                        value: _showDates,
                        onChanged: (v) => setState(() => _showDates = v),
                      ),
                      _checkTile(
                        title: 'نمایش «ساعت» ثبت هدف‌ها و شاخه‌ها روی صفحه اصلی',
                        value: _showTimes,
                        onChanged: (v) => setState(() => _showTimes = v),
                      ),
                      _checkTile(
                        title:
                            'نمایش خط‌چینِ اتصال نشانه‌های نزدیکی به هدف',
                        value: _showRingLinks,
                        onChanged: (v) => setState(() => _showRingLinks = v),
                      ),
                      const _SectionDivider(),

                      _sectionTitle(
                          'نوع خط پیش‌فرض مسیر اهداف (برای هر هدف جداگانه هم می‌شه عوضش کرد)'),
                      const SizedBox(height: 10),
                      _trunkPicker(),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFC9972B),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _save,
                          child: const Text(
                            'ذخیره',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'انصراف',
                            style: TextStyle(
                              color: Color(0xFF2A2218),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7A6B57),
        ),
      );

  Widget _tile({
    required String title,
    String? subtitle,
    required Widget trailing,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2A2218))),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF7A6B57))),
                ],
              ),
            ),
            trailing,
          ],
        ),
      );

  Widget _checkTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: value,
              activeColor: const Color(0xFFC9972B),
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF2A2218)),
              ),
            ),
          ],
        ),
      );

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
                value: value.clamp(0.0, 1.0).toDouble(),
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
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: [
        for (final e in kTrunkStyles.entries)
          GestureDetector(
            onTap: () => setState(() => _trunkStyle = e.key),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _trunkStyle == e.key
                      ? const Color(0xFFC9972B)
                      : const Color(0xFFE0D5C0),
                  width: _trunkStyle == e.key ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 26,
                    child: CustomPaint(
                      painter: _TrunkPreviewPainter(
                        style: e.key,
                        color: _trunkStyle == e.key
                            ? const Color(0xFFC9972B)
                            : const Color(0xFF7A6B57),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: _trunkStyle == e.key
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: const Color(0xFF2A2218),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, color: Color(0xFFE0D5C0)),
      );
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
