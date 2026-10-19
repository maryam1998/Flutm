import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../theme/app_theme_colors.dart';

/// کارتِ بازه‌ی «از # تا #» + نوار پیشرفتِ خوانده‌شده + دکمه‌های
/// «علامت‌گذاری همه / پاک‌کردن» — پورتِ RangeSliderFilter.jsx در Hope.
/// در همه‌ی تب‌ها (لغات، اسلنگ، Vocabulary in Use، علاقه‌مندی‌ها، مکالمات)
/// همین یک ویجت استفاده می‌شود.
class RangeCard extends StatefulWidget {
  final String label;
  final int min;
  final int max;
  final int from;
  final int to;
  final int readInRange;
  final int totalInRange;
  final int readTotal;
  final ValueChanged<int> onFromChanged;
  final ValueChanged<int> onToChanged;
  final VoidCallback onMarkRead;
  final VoidCallback onClear;

  const RangeCard({
    super.key,
    required this.label,
    required this.max,
    required this.from,
    required this.to,
    required this.readInRange,
    required this.totalInRange,
    required this.readTotal,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onMarkRead,
    required this.onClear,
    this.min = 1,
  });

  @override
  State<RangeCard> createState() => _RangeCardState();
}

String _faNum(num n, {bool persian = true}) {
  final s = n.toInt().toString();
  final sb = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) sb.write(persian ? '٬' : ',');
    sb.write(persian ? String.fromCharCode(s.codeUnitAt(i) - 48 + 0x06F0) : s[i]);
  }
  return sb.toString();
}

int? _parseInt(String raw) {
  final b = StringBuffer();
  for (final u in raw.runes) {
    if (u >= 0x06F0 && u <= 0x06F9) {
      b.writeCharCode(u - 0x06F0 + 48);
    } else if (u >= 0x0660 && u <= 0x0669) {
      b.writeCharCode(u - 0x0660 + 48);
    } else {
      b.writeCharCode(u);
    }
  }
  return int.tryParse(b.toString().trim());
}

class _RangeCardState extends State<RangeCard> {
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: '${widget.from}');
    _toCtrl = TextEditingController(text: '${widget.to}');
    _fromFocus.addListener(() {
      if (!_fromFocus.hasFocus) _commitFrom(_fromCtrl.text);
    });
    _toFocus.addListener(() {
      if (!_toFocus.hasFocus) _commitTo(_toCtrl.text);
    });
  }

  @override
  void didUpdateWidget(covariant RangeCard old) {
    super.didUpdateWidget(old);
    if (!_fromFocus.hasFocus) _fromCtrl.text = '${widget.from}';
    if (!_toFocus.hasFocus) _toCtrl.text = '${widget.to}';
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _commitFrom(String raw) {
    final p = _parseInt(raw);
    final v = p == null ? widget.from : p.clamp(widget.min, widget.to).toInt();
    _fromCtrl.text = '$v';
    if (v != widget.from) widget.onFromChanged(v);
  }

  void _commitTo(String raw) {
    final p = _parseInt(raw);
    final v = p == null ? widget.to : p.clamp(widget.from, widget.max).toInt();
    _toCtrl.text = '$v';
    if (v != widget.to) widget.onToChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final w = widget;
    final L = context.l10n;
    // رقم‌های فارسی فقط وقتی زبان رابط فارسی است
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    String num_(num n) => _faNum(n, persian: fa);
    final pct = w.totalInRange > 0 ? w.readInRange / w.totalInRange : 0.0;

    Widget stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
      return InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.cardBorder),
          ),
          child: Icon(icon,
              size: 14, color: enabled ? c.ink : c.inkSoft.withOpacity(0.5)),
        ),
      );
    }

    Widget numField(TextEditingController ctrl, FocusNode focus,
        ValueChanged<String> onSubmit) {
      return SizedBox(
        width: 64,
        height: 34,
        child: TextField(
          controller: ctrl,
          focusNode: focus,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
          ],
          onSubmitted: onSubmit,
          style: TextStyle(
              color: c.ink, fontSize: 13, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.gold, width: 1.5),
            ),
          ),
        ),
      );
    }

    Text small(String t, {FontWeight fw = FontWeight.w600}) => Text(t,
        style: TextStyle(color: c.inkSoft, fontSize: 12, fontWeight: fw));

    Widget actionBtn(String text, VoidCallback onTap, Color bg, Color border) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        child: Text(text,
            style: TextStyle(
                color: c.teal, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.cardBorder),
            boxShadow: [
              BoxShadow(
                color: c.ink.withOpacity(0.07),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (w.label.isNotEmpty) ...[
                Text(w.label,
                    style: TextStyle(
                        color: c.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
              ],
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  small(L.range_from),
                  stepBtn(Icons.remove, w.from > w.min,
                      () => w.onFromChanged(w.from - 1)),
                  numField(_fromCtrl, _fromFocus, _commitFrom),
                  stepBtn(Icons.add, w.from < w.to,
                      () => w.onFromChanged(w.from + 1)),
                  const SizedBox(width: 4),
                  small(L.range_to),
                  stepBtn(Icons.remove, w.to > w.from,
                      () => w.onToChanged(w.to - 1)),
                  numField(_toCtrl, _toFocus, _commitTo),
                  stepBtn(Icons.add, w.to < w.max,
                      () => w.onToChanged(w.to + 1)),
                ],
              ),
              const SizedBox(height: 8),
              Text(L.range_summary(num_(w.from), num_(w.to), num_(w.max)),
                  style: TextStyle(color: c.inkSoft, fontSize: 11)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: 6,
                  color: const Color(0xFFE8E0D0),
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFFD4AF37), Color(0xFFB8860B)]),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                L.range_read_progress(num_(w.readInRange), num_(w.totalInRange),
                    num_(w.readTotal), num_(w.max)),
                style: TextStyle(
                    color: c.teal, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            actionBtn(L.dialogs_mark_range_read, w.onMarkRead,
                const Color(0xFFEAF4F1), const Color(0xFFCFE6DF)),
            actionBtn(L.dialogs_clear_range, w.onClear, c.paper,
                c.cardBorder),
          ],
        ),
      ],
    );
  }
}
