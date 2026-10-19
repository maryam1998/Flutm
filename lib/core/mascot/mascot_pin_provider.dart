import 'dart:async';

import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';

/// آخرین لحظه‌ی تعامل کاربر با اپ (لمس / اسکرول) — برای پیام‌های «بی‌تعاملی»
/// آدمک. معادل lastActivityRef در useLingovaMascot (Hope).
class MascotActivity {
  MascotActivity._();
  static int last = DateTime.now().millisecondsSinceEpoch;
  static void mark() => last = DateTime.now().millisecondsSinceEpoch;
}

/// موقعیتِ «سنجاق‌شده»ی آدمک، به‌صورت درصد (x,y) از عرض/ارتفاع صفحه — معادل
/// loadLingovaPinnedPos / saveLingovaPinnedPos در lingovaConfig.js.
/// null = آدمک هنوز سنجاق نشده و روی نوار بالای صفحه راه می‌رود.
class MascotPinNotifier extends StateNotifier<Offset?> {
  final LocalStorage _storage;

  MascotPinNotifier(this._storage) : super(_read(_storage));

  static const String _key = 'lingova-mascot-pos-v1';

  static Offset? _read(LocalStorage s) {
    final j = s.readJson(_key);
    final x = j['xPct'];
    final y = j['yPct'];
    if (x is num && y is num && x.isFinite && y.isFinite) {
      return Offset(x.toDouble(), y.toDouble());
    }
    return null;
  }

  void pin(double xPct, double yPct) {
    state = Offset(xPct, yPct);
    unawaited(_storage.writeJson(_key, {'xPct': xPct, 'yPct': yPct}));
  }

  /// ↺ بازگرداندن آدمک به نوار بالای صفحه (resetLingovaMascotPosition).
  void reset() {
    state = null;
    unawaited(_storage.remove(_key));
  }
}

final mascotPinProvider =
    StateNotifierProvider<MascotPinNotifier, Offset?>((ref) {
  return MascotPinNotifier(ref.read(localStorageProvider));
});
