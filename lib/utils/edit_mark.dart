import 'package:flutter/material.dart';

/// محدوده‌ی تغییرکرده در متن جدید (معادل EditMark.diffRange در edit-mark.js).
/// اگه فقط چیزی حذف شده باشه، start == end یعنی «نشانه‌ی مکان».
class EditRange {
  final int start;
  final int end;
  const EditRange(this.start, this.end);
  bool get isCaret => start == end;
}

bool _isSpace(int unit) =>
    unit == 0x20 || unit == 0x0A || unit == 0x09 || unit == 0x0D || unit == 0xA0;

/// تفاوت بین متن قبلی و جدید، با گسترش تا مرز کلمه.
EditRange? diffEditRange(String oldT, String newT) {
  if (oldT == newT) return null;
  final max = oldT.length < newT.length ? oldT.length : newT.length;
  var p = 0;
  while (p < max && oldT.codeUnitAt(p) == newT.codeUnitAt(p)) {
    p++;
  }
  var s = 0;
  while (s < max - p &&
      oldT.codeUnitAt(oldT.length - 1 - s) ==
          newT.codeUnitAt(newT.length - 1 - s)) {
    s++;
  }
  var start = p;
  var end = newT.length - s;
  if (end > start) {
    while (start > 0 && !_isSpace(newT.codeUnitAt(start - 1))) {
      start--;
    }
    while (end < newT.length && !_isSpace(newT.codeUnitAt(end))) {
      end++;
    }
  }
  return EditRange(start, end);
}

/// متنی که بعد از ذخیره‌ی ویرایش، بخش تغییرکرده را هایلایت می‌کند و
/// بعد از چند ثانیه محو می‌شود (مثل `mark.em-mark` در edit-mark.js).
class EditMarkedText extends StatefulWidget {
  const EditMarkedText({
    super.key,
    required this.text,
    required this.range,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.textAlign = TextAlign.start,
    this.textDirection = TextDirection.rtl,
  });

  final String text;

  /// null = بدون هایلایت
  final EditRange? range;
  final TextStyle style;

  /// مثلاً «» دور متن — داخل محدوده‌ی هایلایت حساب نمی‌شن
  final String prefix;
  final String suffix;
  final TextAlign textAlign;
  final TextDirection textDirection;

  @override
  State<EditMarkedText> createState() => _EditMarkedTextState();
}

class _EditMarkedTextState extends State<EditMarkedText>
    with SingleTickerProviderStateMixin {
  static const Color _hi = Color(0xFFF4C542);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void initState() {
    super.initState();
    if (widget.range != null) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant EditMarkedText old) {
    super.didUpdateWidget(old);
    if (widget.range != null &&
        (old.range != widget.range || old.text != widget.text)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _alpha {
    final v = _c.value;
    if (v <= 0.6) return 0.55;
    return 0.55 * (1 - (v - 0.6) / 0.4).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.range;
    if (r == null) return _plain();
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = widget.text;
        final a = r.start.clamp(0, t.length).toInt();
        final b = r.end.clamp(a, t.length).toInt();
        final a8 = _alpha;
        final spans = <InlineSpan>[
          if (widget.prefix.isNotEmpty) TextSpan(text: widget.prefix),
          TextSpan(text: t.substring(0, a)),
          if (b > a)
            TextSpan(
              text: t.substring(a, b),
              style: TextStyle(backgroundColor: _hi.withValues(alpha: a8)),
            )
          else
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                width: 3,
                height: (widget.style.fontSize ?? 14) * 1.1,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _hi.withValues(alpha: (a8 / 0.55).clamp(0.0, 1.0)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          TextSpan(text: t.substring(b)),
          if (widget.suffix.isNotEmpty) TextSpan(text: widget.suffix),
        ];
        return Text.rich(
          TextSpan(style: widget.style, children: spans),
          textAlign: widget.textAlign,
          textDirection: widget.textDirection,
        );
      },
    );
  }

  Widget _plain() => Text(
        '${widget.prefix}${widget.text}${widget.suffix}',
        style: widget.style,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
      );
}
