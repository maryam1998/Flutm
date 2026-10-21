import 'dart:math' as math;

import 'package:flutter/material.dart';

/// اجزای مشترک طراحی پنل‌های هدف‌گذاری — همان زبان بصری کارت «ظاهر مسیر هدف»:
/// کارت سفید با گوشه‌ی گرد، آیکونِ رنگیِ کوچک کنار عنوان و محتوای مرتب.
/// سبزِ هماهنگ با بقیه‌ی تب‌ها (emerald500)
const kPanelGold = Color(0xFF178A7C);
const kPanelInk = Color(0xFF000000);
const kPanelMuted = Color(0xFF5B5F77);
const kPanelBorder = Color.fromRGBO(23, 138, 124, 0.28);
const kPanelField = Color(0xFFF1F2F8);

/// کارتِ یک بخش: [icon] داخل مربع رنگی + [title] + توضیح کوتاه (اختیاری).
///
/// با [collapsible] کارت بسته شروع می‌شود و با تپ روی عنوان باز می‌شود؛
/// برای گزینه‌های کم‌استفاده تا صفحه شلوغ نشود.
class PanelCard extends StatefulWidget {
  const PanelCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.accent = kPanelGold,
    this.trailing,
    this.collapsible = false,
    this.initiallyOpen = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final Widget? trailing;
  final List<Widget> children;
  final bool collapsible;
  final bool initiallyOpen;

  @override
  State<PanelCard> createState() => _PanelCardState();
}

class _PanelCardState extends State<PanelCard> {
  late bool _open = !widget.collapsible || widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final header = Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: w.accent.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(w.icon, size: 16, color: w.accent),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(w.title,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: kPanelInk)),
        ),
        if (w.trailing != null) w.trailing!,
        if (w.collapsible)
          AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 22, color: kPanelMuted),
          ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: EdgeInsets.fromLTRB(
          14, w.collapsible && !_open ? 10 : 14, 14, w.collapsible && !_open ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (w.collapsible)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _open = !_open),
              child: header,
            )
          else
            header,
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _open
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (w.subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(w.subtitle!,
                              style: const TextStyle(
                                  fontSize: 11, height: 1.6, color: kPanelMuted)),
                        ),
                      const SizedBox(height: 10),
                      ...w.children,
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// برچسب کوچک بالای یک زیربخش داخل کارت
class PanelLabel extends StatelessWidget {
  const PanelLabel(this.text, {super.key, this.value});
  final String text;

  /// قرص کوچک کنار برچسب (مثلاً عدد یا نام انتخاب‌شده)
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kPanelInk)),
          const Spacer(),
          if (value != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: kPanelField,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(value!,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kPanelMuted)),
            ),
        ],
      ),
    );
  }
}

/// یک گزینه‌ی گرید: کلید + عنوان فارسی
class PanelChoice {
  const PanelChoice(this.key, this.label);
  final String key;
  final String label;
}

/// گریدِ گزینه‌ها با پیش‌نمایش نقاشی‌شده‌ی هر گزینه.
/// گزینه‌ی انتخاب‌شده قاب و زمینه‌ی طلایی می‌گیرد.
class PanelChoiceGrid extends StatelessWidget {
  const PanelChoiceGrid({
    super.key,
    required this.choices,
    required this.current,
    required this.onPick,
    required this.preview,
    this.columns = 4,
  });

  final List<PanelChoice> choices;
  final String current;
  final ValueChanged<String> onPick;
  final int columns;

  /// پیش‌نمایش هر گزینه با رنگ مناسب (طلایی وقتی انتخاب شده)
  final CustomPainter Function(String key, Color color) preview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      final w = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final ch in choices)
            _tile(ch, w, ch.key == current),
        ],
      );
    });
  }

  Widget _tile(PanelChoice ch, double w, bool on) {
    final col = on ? kPanelGold : kPanelMuted;
    return GestureDetector(
      onTap: () => onPick(ch.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: w,
        padding: const EdgeInsets.fromLTRB(4, 9, 4, 7),
        decoration: BoxDecoration(
          color: on ? kPanelGold.withAlpha(22) : kPanelField,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: on ? kPanelGold : Colors.transparent,
            width: on ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 26,
              width: double.infinity,
              child: CustomPaint(painter: preview(ch.key, col)),
            ),
            const SizedBox(height: 6),
            Text(
              ch.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                color: on ? kPanelGold : kPanelInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// پیش‌نمایش «شکل شاخه» — همان فرمول‌های هندسه‌ی نقشه، در مقیاس کوچک
/// (از پایین-چپ تا بالا-راست).
class BranchShapePainter extends CustomPainter {
  BranchShapePainter(this.style, this.color);
  final String style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final pad = 6.0;
    final o = Offset(pad, size.height - 3);
    final e = Offset(size.width - pad, 3);
    final dx = e.dx - o.dx, dy = e.dy - o.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final ux = dx / len, uy = dy / len, px = -uy, py = ux;
    Offset at(double a, double b) =>
        Offset(o.dx + ux * len * a + px * len * b, o.dy + uy * len * a + py * len * b);

    Path cubic(Offset c1, Offset c2) => Path()
      ..moveTo(o.dx, o.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
    Path poly(List<Offset> pts) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final q in pts.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      return path;
    }

    Path path;
    switch (style) {
      case 'straight':
        path = poly([o, e]);
      case 'curve':
        path = cubic(at(0.22, 0.40), at(0.78, 0.40));
      case 'wave':
        path = cubic(at(0.25, 0.45), at(0.75, -0.45));
      case 'elbow':
        path = poly([o, Offset(e.dx, o.dy), e]);
      case 'step':
        final mx = (o.dx + e.dx) / 2;
        path = poly([o, Offset(mx, o.dy), Offset(mx, e.dy), e]);
      case 'zigzag':
        const n = 6;
        final amp = math.min(0.13 * len, 13.0) * 0.7;
        final pts = <Offset>[o];
        for (var i = 1; i < n; i++) {
          final k = (i % 2 == 1 ? 1 : -1) * amp;
          final b = at(i / n, 0);
          pts.add(Offset(b.dx + px * k, b.dy + py * k));
        }
        pts.add(e);
        path = poly(pts);
      case 'organic':
        path = cubic(at(0.33, 0.14), at(0.72, -0.10));
      default:
        // «مثل مجموعه / مثل هدف» — خط‌چین ساده
        final base = poly([o, e]);
        for (final m in base.computeMetrics()) {
          var d = 0.0;
          while (d < m.length) {
            canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), p);
            d += 8;
          }
        }
        return;
    }
    canvas.drawPath(path, p);
    canvas.drawCircle(o, 2.2, Paint()..color = color);
    canvas.drawCircle(e, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BranchShapePainter old) =>
      old.style != style || old.color != color;
}

/// پیش‌نمایش «نوع خط مسیر» (خط اصلی از «من» تا هدف) — کوچک و افقی.
class TrunkLinePainter extends CustomPainter {
  TrunkLinePainter(this.style, this.color);
  final String style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(4, size.height * 0.78);
    final b = Offset(size.width - 4, size.height * 0.22);
    final d = b - a;
    final len = d.distance;
    final n = d / len;
    final perp = Offset(-n.dy, n.dx);

    Paint stroke(double w, [double op = 1, StrokeCap cap = StrokeCap.round]) =>
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = cap
          ..color = color.withValues(alpha: op);

    void dash(List<double> pat, Paint p) {
      var t = 0.0, i = 0;
      while (t < len) {
        final l = pat[i % pat.length];
        if (i.isEven) {
          canvas.drawLine(a + n * t, a + n * math.min(t + l, len), p);
        }
        t += l;
        i++;
      }
    }

    switch (style) {
      case 'solid':
        canvas.drawLine(a, b, stroke(2.2));
      case 'dotted':
        dash([0.1, 5], stroke(3.2));
      case 'dashdot':
        dash([7, 3.5, 1.5, 3.5], stroke(2.2, 1, StrokeCap.butt));
      case 'long':
        dash([13, 6], stroke(2.2, 1, StrokeCap.butt));
      case 'double':
        canvas.drawLine(a + perp * 2, b + perp * 2, stroke(1.4));
        canvas.drawLine(a - perp * 2, b - perp * 2, stroke(1.4));
      case 'glow':
        canvas.drawLine(a, b, stroke(7, 0.18));
        canvas.drawLine(a, b, stroke(2));
      case 'taper':
        const seg = 8;
        for (var s = 0; s < seg; s++) {
          final w = 4.6 - 3.2 * ((s + 0.5) / seg);
          canvas.drawLine(a + n * (len * s / seg), a + n * (len * (s + 1) / seg),
              stroke(w));
        }
      default: // dashed / «مثل نقشه»
        dash([6, 5], stroke(2.2, 1, StrokeCap.butt));
    }
  }

  @override
  bool shouldRepaint(TrunkLinePainter old) =>
      old.style != style || old.color != color;
}
