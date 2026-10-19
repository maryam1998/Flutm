import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/emotion_store.dart';
import 'emotion_chart.dart';

const double kPanelWMin = 170;
const double kPanelWMax = 460;
const double kPanelAspect = 400 / 260;

const double _glassRadius = 22;

/// پنل ویجت. فقط ظاهر؛ درگ/پینچ و جای پنل را EmotionWidgetLayer مدیریت می‌کند.
/// [opacity] برای انیمیشن باز/بسته شدن است. blur پس‌زمینه با opacity کم می‌شود تا
/// BackdropFilter داخل Opacity (که پس‌زمینه را نمی‌بیند) لازم نباشد.
class EmotionPanel extends StatelessWidget {
  const EmotionPanel({
    super.key,
    required this.width,
    required this.glass,
    required this.isDark,
    required this.opacity,
    required this.chartVisible,
    required this.onToggleGlass,
    required this.tapSuppressed,
  });

  final double width;
  final bool glass;
  final bool isDark;
  final double opacity;
  final bool chartVisible;
  final VoidCallback onToggleGlass;
  final bool Function() tapSuppressed;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EmotionStore>();
    final pad = glass
        ? const EdgeInsets.fromLTRB(12, 16, 12, 10)
        : EdgeInsets.zero;
    final chartW = width - pad.horizontal;
    final chartH = chartW * kPanelAspect;

    Widget chart = SizedBox(
      width: chartW,
      height: chartH,
      child: chartVisible
          ? FittedBox(
              fit: BoxFit.contain,
              child: EmotionChart(
                selectedIds: store.selectedIds.toSet(),
                isDark: isDark,
                onToggle: (id) => context.read<EmotionStore>().toggle(id),
                tapSuppressed: tapSuppressed,
              ),
            )
          : null,
    );
    if (opacity < 1) chart = Opacity(opacity: opacity.clamp(0.0, 1.0), child: chart);

    Widget content = Padding(
      padding: pad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          chart,
          if (store.isCapturing && chartVisible)
            Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: _CaptureBar(isDark: isDark),
            ),
        ],
      ),
    );

    if (glass) {
      content = _GlassFrame(isDark: isDark, opacity: opacity, child: content);
    }

    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: width,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            content,
            Positioned(
              left: 6,
              top: 6,
              child: _GlassToggle(
                active: glass,
                isDark: isDark,
                opacity: opacity,
                onTap: onToggleGlass,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────── قاب شیشه‌ای ─────────────────────

class _GlassFrame extends StatelessWidget {
  const _GlassFrame({
    required this.isDark,
    required this.opacity,
    required this.child,
  });

  final bool isDark;
  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final op = opacity.clamp(0.0, 1.0);
    final fill = isDark
        ? Color.fromRGBO(16, 18, 30, 0.46 * op)
        : Color.fromRGBO(255, 255, 255, 0.16 * op);
    final sigma = math.max(22 * op, 0.01);

    return CustomPaint(
      painter: _GlassShadowPainter(isDark: isDark, opacity: op),
      foregroundPainter: _GlassBorderPainter(isDark: isDark, opacity: op),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_glassRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: ColoredBox(color: fill, child: child),
        ),
      ),
    );
  }
}

/// سایه‌ی بیرونیِ قاب (box-shadow وب) — فقط بیرون قاب کشیده می‌شه، نه زیر شیشه
class _GlassShadowPainter extends CustomPainter {
  _GlassShadowPainter({required this.isDark, required this.opacity});

  final bool isDark;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_glassRadius),
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(-300, -300, size.width + 600, size.height + 600))
      ..addRRect(rrect);

    final dy = isDark ? 14.0 : 12.0;
    final blur = isDark ? 40.0 : 36.0;
    final color = isDark
        ? Color.fromRGBO(0, 0, 0, 0.55 * opacity)
        : Color.fromRGBO(20, 30, 60, 0.22 * opacity);

    canvas.save();
    canvas.clipPath(outside);
    canvas.drawRRect(
      rrect.shift(Offset(0, dy)),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter old) =>
      old.isDark != isDark || old.opacity != opacity;
}

/// حاشیه‌ی ۱px + هایلایت داخلیِ بالا (inset 0 1px 0)
class _GlassBorderPainter extends CustomPainter {
  _GlassBorderPainter({required this.isDark, required this.opacity});

  final bool isDark;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_glassRadius),
    );

    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: (isDark ? 0.14 : 0.38) * opacity),
    );

    final inner = rrect.deflate(1);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addRRect(inner),
      Path()..addRRect(inner.shift(const Offset(0, 1))),
    );
    canvas.drawPath(
      crescent,
      Paint()
        ..color = Colors.white.withValues(alpha: (isDark ? 0.08 : 0.35) * opacity),
    );
  }

  @override
  bool shouldRepaint(_GlassBorderPainter old) =>
      old.isDark != isDark || old.opacity != opacity;
}

// ───────────────────── دکمه‌ی شیشه‌ای/بدون پس‌زمینه ─────────────────────

class _GlassToggle extends StatelessWidget {
  const _GlassToggle({
    required this.active,
    required this.isDark,
    required this.opacity,
    required this.onTap,
  });

  final bool active;
  final bool isDark;
  final double opacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final op = opacity.clamp(0.0, 1.0);
    final Color bg, border, fg;
    if (!isDark) {
      bg = active
          ? const Color.fromRGBO(20, 22, 34, 0.78)
          : const Color.fromRGBO(255, 255, 255, 0.65);
      border = active
          ? const Color.fromRGBO(255, 255, 255, 0.28)
          : const Color.fromRGBO(0, 0, 0, 0.12);
      fg = active ? const Color(0xFFEEF1FB) : const Color(0xFF20232B);
    } else {
      bg = active
          ? const Color.fromRGBO(255, 255, 255, 0.24)
          : const Color.fromRGBO(255, 255, 255, 0.10);
      border = active
          ? const Color.fromRGBO(255, 255, 255, 0.35)
          : const Color.fromRGBO(255, 255, 255, 0.18);
      fg = active ? const Color(0xFF0F1220) : const Color(0xFFEEF1FB);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 24,
        height: 24,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.14 * op),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: math.max(6 * op, 0.01),
                sigmaY: math.max(6 * op, 0.01),
              ),
              child: CustomPaint(
                foregroundPainter:
                    _ToggleIconPainter(active: active, color: fg.withValues(alpha: op)),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg.withValues(alpha: bg.a * op),
                    border: Border.all(color: border.withValues(alpha: border.a * op)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleIconPainter extends CustomPainter {
  _ToggleIconPainter({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // آیکون ۱۳px داخل viewBox ۱۶، وسط دکمه‌ی ۲۴px
    canvas.save();
    canvas.translate((size.width - 13) / 2, (size.height - 13) / 2);
    canvas.scale(13 / 16);
    final rr = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2, 2, 12, 12),
      const Radius.circular(3.5),
    );
    if (!active) {
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = color,
      );
    } else {
      canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: color.a * 0.30));
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = color,
      );
      canvas.drawCircle(
        const Offset(6.3, 6.1),
        1.15,
        Paint()..color = color.withValues(alpha: color.a * 0.55),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ToggleIconPainter old) =>
      old.active != active || old.color != color;
}

// ───────────────────── نوار ثبتِ «حس قبل/بعد از تمرین» ─────────────────────

// ───────────────────── نوار ثبتِ «حس قبل/بعد/ویرایش» ─────────────────────

class _CaptureBar extends StatelessWidget {
  const _CaptureBar({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EmotionStore>();
    final phase = store.capturePhase;
    final label = store.captureLabel ?? store.capturePracticeKey ?? '';
    final cnt = store.selectedIds.length;

    final String header;
    if (phase == 'before') {
      header = '💗 قبل از تمرین';
    } else if (phase == 'after') {
      header = '✨ بعد از تمرین';
    } else if (phase == 'entry') {
      header = '📝 ویرایش احساس';
    } else {
      header = '📝 انتخاب احساس';
    }

    final String emptyHint;
    if (phase == 'entry') {
      emptyHint = 'یک یا چند احساس برای این روز انتخاب کن';
    } else {
      emptyHint = 'از لیست کنار آدمک، یک یا چند احساس را انتخاب کن';
    }

    final String filledHint;
    if (phase == 'entry') {
      filledHint = '$cnt احساس — دکمه ثبت را بزن تا رنگ رشته عوض شود';
    } else {
      filledHint = '$cnt احساس انتخاب شد — دکمه ثبت را بزن';
    }

    final ink = isDark ? Colors.white : const Color(0xFF0F5B53);
    final border = isDark
        ? const Color.fromRGBO(84, 201, 184, 0.55)
        : const Color.fromRGBO(43, 191, 171, 0.55);
    final grad = isDark
        ? const [
            Color.fromRGBO(43, 191, 171, 0.22),
            Color.fromRGBO(94, 200, 240, 0.14)
          ]
        : const [
            Color.fromRGBO(43, 191, 171, 0.18),
            Color.fromRGBO(94, 200, 240, 0.12)
          ];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: grad,
        ),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.isEmpty ? header : '$header — $label',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: GoogleFonts.vazirmatn(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            cnt > 0 ? filledHint : emptyHint,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: GoogleFonts.vazirmatn(
              fontSize: 10.5,
              color: ink.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.read<EmotionStore>().saveCapture(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFF0F5B53), Color(0xFF178A7C)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      phase == 'entry' ? '✓ ذخیره' : '✓ ثبت',
                      style: GoogleFonts.vazirmatn(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.read<EmotionStore>().cancelCapture(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color.fromRGBO(255, 255, 255, 0.12)
                          : const Color.fromRGBO(0, 0, 0, 0.06),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      'انصراف',
                      style: GoogleFonts.vazirmatn(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
