import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/constants.dart';
import '../state/map_store.dart';
import '../state/theme_store.dart';
import 'motivation_sheet.dart';

const _kCream = Color(0xFFFBF6EA);
const _kCard = Colors.white;
const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(100),
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
    _fontSize = s.fontSize.clamp(8.0, 28.0).toDouble();
    _showDates = s.showDateStamps;
    _showTimes = s.showTimeStamps;
    _showRingLinks = s.showRingLinks;
    _trunkStyle =
        kTrunkStyles.containsKey(s.trunkStyle) ? s.trunkStyle : 'dashed';
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
    int v(double x) => (x * 255).round().clamp(0, 255);
    return '#${v(c.r).toRadixString(16).padLeft(2, '0')}'
            '${v(c.g).toRadixString(16).padLeft(2, '0')}'
            '${v(c.b).toRadixString(16).padLeft(2, '0')}'
        .toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),

            // هدر
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'تنظیمات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('انصراف',
                        style: TextStyle(color: _kMuted)),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: _save,
                    child: const Text('ذخیره',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorder),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- تم ----------
                    Consumer<ThemeStore>(
                      builder: (_, theme, __) => _tile(
                        title: 'تم تاریک',
                        subtitle: theme.isDark
                            ? 'پس‌زمینه‌ی تیره با متن روشن'
                            : 'پس‌زمینه‌ی روشن (مثل نسخه‌ی وب)',
                        trailing: Switch(
                          value: theme.isDark,
                          activeThumbColor: _kGold,
                          onChanged: (v) => theme.setDark(v),
                        ),
                      ),
                    ),
                    const _SectionDivider(),

                    // ---------- رنگ نوشته‌ها ----------
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
                          '#000000',
                        ])
                          _colorSwatch(hex),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // پیش‌نمایش رنگ + sliders RGB
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _textColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: _kBorder, width: 2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hexFromColor(_textColor),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _kInk,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'برای رنگ دلخواه، اسلایدرهای زیر را جابه‌جا کن',
                                style: TextStyle(
                                    fontSize: 10.5, color: _kMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _rgbSlider(
                      'R',
                      _textColor.r,
                      (v) => setState(() {
                        _textColor = Color.fromARGB(
                          255,
                          (v * 255).round(),
                          (_textColor.g * 255).round(),
                          (_textColor.b * 255).round(),
                        );
                      }),
                    ),
                    _rgbSlider(
                      'G',
                      _textColor.g,
                      (v) => setState(() {
                        _textColor = Color.fromARGB(
                          255,
                          (_textColor.r * 255).round(),
                          (v * 255).round(),
                          (_textColor.b * 255).round(),
                        );
                      }),
                    ),
                    _rgbSlider(
                      'B',
                      _textColor.b,
                      (v) => setState(() {
                        _textColor = Color.fromARGB(
                          255,
                          (_textColor.r * 255).round(),
                          (_textColor.g * 255).round(),
                          (v * 255).round(),
                        );
                      }),
                    ),
                    const _SectionDivider(),

                    // ---------- اندازه فونت ----------
                    Row(
                      children: [
                        _sectionTitle('اندازه فونت (پیش‌فرض ۱۴)'),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            toFa(_fontSize.round()),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _kGold,
                        thumbColor: _kGold,
                        inactiveTrackColor: _kBorder,
                        overlayColor: _kGold.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        min: 8,
                        max: 28,
                        divisions: 20,
                        value: _fontSize,
                        label: toFa(_fontSize.round()),
                        onChanged: (v) => setState(() => _fontSize = v),
                      ),
                    ),
                    const _SectionDivider(),

                    // ---------- چک‌باکس‌ها ----------
                    _checkTile(
                      title:
                          'نمایش «تاریخ» ثبت هدف‌ها و شاخه‌ها روی صفحه اصلی',
                      value: _showDates,
                      onChanged: (v) => setState(() => _showDates = v),
                    ),
                    _checkTile(
                      title:
                          'نمایش «ساعت» ثبت هدف‌ها و شاخه‌ها روی صفحه اصلی',
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

                    // ---------- جملات انگیزشی ----------
                    _sectionTitle('جمله‌های انگیزه‌بخش'),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kInk,
                          side: const BorderSide(color: _kBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => showMotivationSheet(context),
                        icon: const Icon(Icons.auto_awesome, size: 18, color: _kGold),
                        label: const Text('مدیریت جمله‌های انگیزه‌بخش',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const _SectionDivider(),

                    // ---------- سبک خط پیش‌فرض ----------
                    _sectionTitle(
                        'نوع خط پیش‌فرض مسیر اهداف (برای هر هدف جداگانه هم می‌شه عوضش کرد)'),
                    const SizedBox(height: 10),
                    _trunkPicker(),
                    const SizedBox(height: 20),

                    // ذخیره
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _kGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _save,
                        child: const Text(
                          'ذخیره تنظیمات',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'انصراف',
                          style:
                              TextStyle(color: _kMuted, fontSize: 13),
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
    );
  }

  Widget _colorSwatch(String hex) {
    final c = hexColor(hex, Colors.white);
    final active = _hexFromColor(_textColor) == hex.toLowerCase();
    return GestureDetector(
      onTap: () => setState(() => _textColor = c),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? _kGold : _kBorder,
            width: active ? 3 : 1.5,
          ),
        ),
      ),
    );
  }

  Widget _rgbSlider(String label, double value, ValueChanged<double> onChanged) {
    final col = label == 'R'
        ? const Color(0xFFE5484D)
        : label == 'G'
            ? const Color(0xFF63D6A8)
            : const Color(0xFF5EC8F0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: col,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: col,
                thumbColor: col,
                inactiveTrackColor: _kBorder,
                trackHeight: 4,
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
            width: 34,
            child: Text(
              toFa((value * 255).round()),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: _kMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: _kMuted,
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _kInk)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11.5, color: _kMuted)),
                    ),
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
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: value,
              activeColor: _kGold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: _kBorder, width: 1.5),
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 12.5, color: _kInk),
              ),
            ),
          ],
        ),
      );

  Widget _trunkPicker() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: [
        for (final e in kTrunkStyles.entries)
          GestureDetector(
            onTap: () => setState(() => _trunkStyle = e.key),
            child: Container(
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _trunkStyle == e.key ? _kGold : _kBorder,
                  width: _trunkStyle == e.key ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 24,
                    child: CustomPaint(
                      painter: _TrunkPreviewPainter(
                        style: e.key,
                        color: _trunkStyle == e.key
                            ? _kGold
                            : _kMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: _trunkStyle == e.key
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _trunkStyle == e.key ? _kGold : _kInk,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
        child: Divider(height: 1, color: _kBorder),
      );
}

// ============================================================
// پیش‌نمایش خط (برای گرید سبک تنه)
// ============================================================
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

    final a = Offset(2, size.height * 0.8);
    final b = Offset(size.width - 2, size.height * 0.2);
    final dir = b - a;
    final len = dir.distance;
    if (len == 0) return;
    final n = dir / len;

    switch (style) {
      case 'solid':
        canvas.drawLine(a, b, p);
      case 'dotted':
        for (var i = 0; i < 8; i++) {
          final pt = a + n * (len * i / 7);
          canvas.drawCircle(pt, 1, Paint()..color = color);
        }
      case 'dashdot':
        _dash(canvas, a, b, p, len, n, [4, 2, 1, 2]);
      case 'long':
        _dash(canvas, a, b, p, len, n, [7, 4]);
      case 'double':
        final perp = Offset(-n.dy, n.dx) * 1.3;
        canvas.drawLine(a + perp, b + perp, p..strokeWidth = 1.3);
        canvas.drawLine(
            a - perp,
            b - perp,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.3
              ..strokeCap = StrokeCap.round
              ..color = color);
      case 'glow':
        canvas.drawLine(
            a,
            b,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round
              ..color = color.withValues(alpha: 0.30));
        canvas.drawLine(a, b, p..strokeWidth = 1.5);
      case 'taper':
        for (var i = 0; i < 6; i++) {
          final p1 = a + n * (len * i / 6);
          final p2 = a + n * (len * (i + 1) / 6);
          canvas.drawLine(
              p1,
              p2,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3 - i * 0.35
                ..strokeCap = StrokeCap.round
                ..color = color);
        }
      default:
        _dash(canvas, a, b, p, len, n, [3, 3]);
    }
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint p, double len, Offset n,
      List<double> dashes) {
    var d = 0.0;
    var i = 0;
    while (d < len) {
      final seg = dashes[i % dashes.length];
      if (i.isEven) {
        final s = a + n * d;
        final e = a + n * (d + seg > len ? len : d + seg);
        canvas.drawLine(s, e, p);
      }
      d += seg;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _TrunkPreviewPainter old) =>
      old.style != style || old.color != color;
}
