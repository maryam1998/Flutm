import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme_colors.dart';
import '../shell/widgets/shell_header.dart';

class PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isAiPowered;
  final List<String> previewChips;   // چیپ‌های پیش‌نمایش (مثلاً «A1», «A2»)

  const PlaceholderTab({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isAiPowered = false,
    this.previewChips = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      color: c.paper,
      child: Stack(
        children: [
          // الگوی نقطه‌چین ظریف
          Positioned.fill(
            child: CustomPaint(
              painter: _DotsPainter(
                color: c.inkSoft.withOpacity(0.06),
                spacing: 26,
              ),
            ),
          ),

          // شکل‌های تزئینی محو در گوشه‌ها
          Positioned(
            top: -40,
            right: -40,
            child: _DecoCircle(
              size: 140,
              color: c.gold.withOpacity(0.06),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _DecoCircle(
              size: 180,
              color: c.teal.withOpacity(0.05),
            ),
          ),

          // محتوای اصلی
          Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: double.infinity, child: ShellHeader()),
                  const SizedBox(height: 24),
                  // ── تصویرسازی مرکزی ──
                  _Illustration(icon: icon, isAi: isAiPowered, c: c),
                  const SizedBox(height: 28),

                  // ── AI badge (اختیاری) ──
                  if (isAiPowered) ...[
                    _AiPill(c: c),
                    const SizedBox(height: 14),
                  ],

                  // ── عنوان ──
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── توضیح ──
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.inkSoft,
                        fontSize: 14.5,
                        height: 1.7,
                      ),
                    ),
                  ),

                  // ── چیپ‌های پیش‌نمایش (سطوح، فیلترها) ──
                  if (previewChips.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _PreviewChips(chips: previewChips, c: c),
                  ],

                  const SizedBox(height: 28),

                  // ── نشان «به‌زودی» ──
                  _ComingSoonBadge(c: c),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// تصویرسازی مرکزی — دایره‌های تودرتو با آیکون
// ═══════════════════════════════════════════════════════════════════
class _Illustration extends StatelessWidget {
  final IconData icon;
  final bool isAi;
  final dynamic c;

  const _Illustration({
    required this.icon,
    required this.isAi,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // حلقه‌ی بیرونی
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  c.gold.withOpacity(0.08),
                  c.teal.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // حلقه‌ی میانی
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  c.gold.withOpacity(0.18),
                  c.teal.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: c.gold.withOpacity(0.25),
                width: 1.5,
              ),
            ),
          ),
          // دایره‌ی داخلی + آیکون
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  c.gold,
                  c.gold.withOpacity(0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: c.gold.withOpacity(0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, size: 38, color: Colors.white),
          ),

          // جرقه‌های کوچک اطراف (فقط برای AI)
          if (isAi) ...[
            Positioned(
              top: 12,
              right: 20,
              child: _Spark(size: 14, color: c.gold),
            ),
            Positioned(
              bottom: 20,
              left: 12,
              child: _Spark(size: 10, color: c.teal),
            ),
            Positioned(
              top: 40,
              left: 6,
              child: _Spark(size: 8, color: c.gold.withOpacity(0.7)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  final double size;
  final Color color;
  const _Spark({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// پیل AI
// ═══════════════════════════════════════════════════════════════════
class _AiPill extends StatelessWidget {
  final dynamic c;
  const _AiPill({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B7CF6), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: Colors.white),
          SizedBox(width: 5),
          Text(
            'قدرت‌گرفته از هوش مصنوعی',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// چیپ‌های پیش‌نمایش (سطوح CEFR یا فیلترها)
// ═══════════════════════════════════════════════════════════════════
class _PreviewChips extends StatelessWidget {
  final List<String> chips;
  final dynamic c;
  const _PreviewChips({required this.chips, required this.c});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: chips.map((label) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: c.paperDark.withOpacity(0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: c.cardBorder,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: c.inkSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Badge «به‌زودی»
// ═══════════════════════════════════════════════════════════════════
class _ComingSoonBadge extends StatelessWidget {
  final dynamic c;
  const _ComingSoonBadge({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: c.gold.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: c.gold.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_top_rounded, size: 14, color: c.gold),
          const SizedBox(width: 7),
          Text(
            'به‌زودی در دسترس',
            style: TextStyle(
              color: c.gold,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Decorative circle
// ═══════════════════════════════════════════════════════════════════
class _DecoCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _DecoCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Dots background painter
// ═══════════════════════════════════════════════════════════════════
class _DotsPainter extends CustomPainter {
  final Color color;
  final double spacing;
  _DotsPainter({required this.color, this.spacing = 24});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const radius = 1.2;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.color != color || old.spacing != spacing;
}
