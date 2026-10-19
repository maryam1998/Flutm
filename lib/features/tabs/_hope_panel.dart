import 'package:flutter/material.dart';

import '../../core/theme/app_theme_colors.dart';
import '../../core/widgets/selection_card.dart' show SelectableSyncText, SelectableRun;
import '../shell/widgets/shell_header.dart';

/// اسکلتِ مشترکِ تب‌های «هم‌شکل Hope» (گرامر، تمرین مکالمه، داستان‌ساز،
/// لغات ذخیره‌شده): هدرِ شل داخلِ اسکرول، بعد عنوان + توضیح، بعد محتوا با
/// فاصله‌ی ۱۶ (معادل `flex flex-col gap-4` در Hope).
/// جهتِ محتوا بر اساسِ زبانِ رابط: فارسی/عربی → راست‌به‌چپ، بقیه → چپ‌به‌راست.
/// (خودِ اپ همیشه RTL می‌ماند؛ این فقط برای پنل‌هایی است که می‌خواهند متنِ
/// انگلیسی/اروپایی را چپ‌به‌راست نشان بدهند.)
TextDirection uiContentDirection(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode;
  return (code == 'fa' || code == 'ar') ? TextDirection.rtl : TextDirection.ltr;
}

class HopePanel extends StatelessWidget {
  /// عنوانِ بزرگ (۱۸، ضخیم). اگر null باشد عنوان نشان داده نمی‌شود.
  final String? title;

  /// توضیحِ زیرِ عنوان (۱۳، رنگِ inkSoft).
  final String? intro;

  /// اندازه‌ی عنوان — گرامر/مکالمه/لغات ۱۸، داستان‌ساز ۱۶.
  final double titleSize;

  final List<Widget> children;

  /// اگر داده شود، محتوای پنل (نه هدرِ بالای صفحه) با این جهت چیده می‌شود.
  final TextDirection? contentDirection;

  const HopePanel({
    super.key,
    this.title,
    this.intro,
    this.titleSize = 18,
    required this.children,
    this.contentDirection,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final body = <Widget>[
      if (title != null || intro != null)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                title!,
                style: TextStyle(
                  color: c.ink,
                  fontSize: titleSize,
                  fontWeight: titleSize >= 18 ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            if (title != null && intro != null) const SizedBox(height: 4),
            if (intro != null)
              Text(
                intro!,
                style: TextStyle(color: c.inkSoft, fontSize: 13, height: 1.7),
              ),
          ],
        ),
      for (final w in children) w,
    ];

    return Container(
      color: c.paper,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: ShellHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                for (var i = 0; i < body.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  contentDirection == null
                      ? body[i]
                      : Directionality(
                          textDirection: contentDirection!,
                          child: body[i]),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// کارتِ سفیدِ Hope: حاشیه‌ی cardBorder، شعاع ۱۶، پدینگ ۱۶.
class HopeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? background;
  final double radius;

  const HopeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.background,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? Colors.white,
        border: Border.all(color: borderColor ?? c.cardBorder, width: 1),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// متنِ حالتِ خالی — دقیقاً مثل Hope: یک پاراگرافِ ساده‌ی ۱۳px با رنگِ inkSoft.
class HopeEmptyText extends StatelessWidget {
  final String text;
  const HopeEmptyText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Text(
      text,
      style: TextStyle(color: c.inkSoft, fontSize: 13, height: 1.7),
    );
  }
}

/// چیپِ انتخابیِ گِرد (زبان / سطح / نوع محتوا / طول).
class HopeChoiceChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeBorder;
  final Color activeFill;
  final Color activeText;
  final Color? inactiveFill;
  final Color? inactiveBorder;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final VoidCallback onTap;

  const HopeChoiceChip({
    super.key,
    required this.label,
    required this.active,
    required this.activeBorder,
    required this.activeFill,
    required this.activeText,
    required this.onTap,
    this.inactiveFill,
    this.inactiveBorder,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        // حالتِ فعال دقیقاً مثلِ تبِ فعالِ Story (بالای صفحه): داخلِ چیپ طلایی
        // + متنِ تیره‌ی هدر — رنگ‌های activeFill/Text نادیده‌اند.
        decoration: BoxDecoration(
          color: active ? c.gold : (inactiveFill ?? Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? c.gold : (inactiveBorder ?? c.cardBorder),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? c.headerTo : c.ink,
            fontSize: fontSize,
            fontWeight: active ? FontWeight.w800 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// دکمه‌ی متنیِ کوچک با آیکون (مثل «انتخاب / حذف»، «پاک کردن گفتگو»).
class HopeTextAction extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double fontSize;

  const HopeTextAction({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// جهتِ خودکار (مثل dir="auto" در وب): اولین حرفِ قوی تعیین می‌کند.
TextDirection autoDir(String s) {
  for (final r in s.runes) {
    if ((r >= 0x0590 && r <= 0x08FF) ||
        (r >= 0xFB1D && r <= 0xFDFF) ||
        (r >= 0xFE70 && r <= 0xFEFF)) {
      return TextDirection.rtl;
    }
    if ((r >= 0x41 && r <= 0x5A) ||
        (r >= 0x61 && r <= 0x7A) ||
        (r >= 0xC0 && r <= 0x24F) ||
        (r >= 0x400 && r <= 0x4FF) ||
        (r >= 0x3040 && r <= 0x9FFF) ||
        (r >= 0xAC00 && r <= 0xD7AF)) {
      return TextDirection.ltr;
    }
  }
  return TextDirection.rtl;
}

/// آیا متن عمدتاً با حروفِ فارسی/عربی نوشته شده؟
bool isMostlyArabicScript(String s) {
  var arabic = 0;
  var latin = 0;
  for (final r in s.runes) {
    if (r >= 0x0600 && r <= 0x06FF) {
      arabic++;
    } else if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) {
      latin++;
    }
  }
  return arabic > 0 && arabic >= latin;
}

/// مارک‌داونِ سبک (معادلِ MiniMarkdown وب): **bold**، *italic*، `code`،
/// عنوان (#)، لیست (- / *)، خط‌جداکننده (---).
class MiniMarkdown extends StatelessWidget {
  final String text;
  final double fontSize;

  /// اگر بدهید (زبانِ پیش‌فرضِ متن)، لمسِ لغت یا انتخابِ محدوده کادرِ پاپ‌آپِ مشترک را باز می‌کند
  /// و زبانِ هر انتخاب از روی خودِ متن تشخیص داده می‌شود.
  final String? code;

  const MiniMarkdown({super.key, required this.text, this.fontSize = 13, this.code});

  List<InlineSpan> _inline(String s, Color codeBg) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
          text: m.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else {
        spans.add(TextSpan(
          text: m.group(3),
          style: TextStyle(fontFamily: 'monospace', backgroundColor: codeBg),
        ));
      }
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final lines = text.split(RegExp(r'\r?\n'));
    final out = <Widget>[];
    var lineNo = 0;
    for (final raw in lines) {
      lineNo++;
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        out.add(const SizedBox(height: 6));
        continue;
      }
      if (RegExp(r'^\s*-{3,}\s*$').hasMatch(line)) {
        out.add(Divider(height: 14, color: c.cardBorder));
        continue;
      }
      var body = line;
      var weight = FontWeight.w400;
      var size = fontSize;
      var bullet = false;
      final h = RegExp(r'^\s*#{1,6}\s+(.*)$').firstMatch(line);
      if (h != null) {
        body = h.group(1)!;
        weight = FontWeight.w800;
        size = fontSize + 1;
      } else {
        final b = RegExp(r'^\s*[-•]\s+(.*)$').firstMatch(line) ??
            RegExp(r'^\s*\*\s+(.*)$').firstMatch(line);
        if (b != null) {
          body = b.group(1)!;
          bullet = true;
        }
      }
      final dir = autoDir(body);
      final lineStyle = TextStyle(
        color: c.ink,
        fontSize: size,
        height: 1.7,
        fontWeight: weight,
      );
      final inline = _inline(body, c.paperDark);
      final Widget rich;
      if (code != null) {
        final runs = <SelectableRun>[
          for (final s in inline)
            if (s is TextSpan) SelectableRun(s.text ?? '', s.style),
        ];
        final plain = runs.map((r) => r.text).join();
        rich = SelectableSyncText(
          code: code!,
          id: 'md-${text.hashCode}-$lineNo',
          text: plain,
          runs: runs,
          autoLang: true,
          style: lineStyle,
          textDirection: dir,
          textAlign: TextAlign.start,
        );
      } else {
        rich = Text.rich(
          TextSpan(children: inline, style: lineStyle),
          textDirection: dir,
          textAlign: TextAlign.start,
        );
      }
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: bullet
            ? Directionality(
                textDirection: dir,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 9, left: 4, right: 4),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: c.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: rich),
                  ],
                ),
              )
            : Align(
                alignment: dir == TextDirection.rtl
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: rich,
              ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: out,
    );
  }
}
