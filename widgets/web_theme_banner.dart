import 'package:flutter/material.dart';

import '../theme/grat_palette.dart';

/// بنر فازِ تب تمرین — کپی .theme-banner وب:
///   linear-gradient(135deg, var(--emerald-900), var(--emerald-700))
///   + درخشش طلایی گوشه‌ی بالا-راست: radial-gradient(rgba(230,205,142,.28), transparent 55%)
/// رنگ‌های emerald در حالت تاریک همان مقادیر html[data-theme="dark"] #grat-root هستند.
class WebThemeBanner extends StatelessWidget {
  const WebThemeBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = GratPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.emerald900, p.emerald700],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.1,
                    colors: [
                      const Color(0xFFE6CD8E).withValues(alpha: 0.28),
                      const Color(0xFFE6CD8E).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// نوار پیشرفت بنر — .tb-bar و .tb-bar-fill وب
///   fill: linear-gradient(90deg, var(--gold-300), var(--gold-500))
class WebBannerBar extends StatelessWidget {
  const WebBannerBar({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final p = GratPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 5,
        color: Colors.white.withValues(alpha: 0.2),
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [p.gold300, p.gold500],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
