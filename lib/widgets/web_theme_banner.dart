import 'package:flutter/material.dart';

/// بنر فازِ تب تمرین — کپی .theme-banner وب:
///   linear-gradient(135deg, emerald-900, emerald-700) + درخشش طلایی گوشه‌ی بالا-راست
class WebThemeBanner extends StatelessWidget {
  const WebThemeBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A3D38), Color(0xFF0F5B53)],
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
class WebBannerBar extends StatelessWidget {
  const WebBannerBar({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 5,
        color: Colors.white.withValues(alpha: 0.2),
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE6CD8E), Color(0xFFC9A24B)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
