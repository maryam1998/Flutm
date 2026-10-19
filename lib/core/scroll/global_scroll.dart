import 'package:flutter/material.dart';

/// اسکرول همه‌ی Scrollable‌های درخت ویجت به بالا
class GlobalScroll {
  /// پیدا کردن همه‌ی ScrollableStateها و اسکرول همه به بالا
  static void toTop() {
    final scrollables = <ScrollableState>[];

    void collect(Element el) {
      if (el is StatefulElement && el.state is ScrollableState) {
        scrollables.add(el.state as ScrollableState);
      }
      el.visitChildren(collect);
    }

    final rootEl = WidgetsBinding.instance.rootElement;
    if (rootEl != null) {
      rootEl.visitChildren(collect);
    }

    for (final s in scrollables) {
      if (s.position.hasPixels && s.position.pixels > 0) {
        s.position.animateTo(
          0,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }
}
