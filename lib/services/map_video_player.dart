import 'package:flutter/foundation.dart' show ValueNotifier;

/// درخواست نمایش ویدیو روی نقشه
class MapVideoRequest {
  const MapVideoRequest(this.id, this.src, this.token);
  final String id;
  final String src;
  final int token;
}

/// نمایش ویدیوی هر گره (من، هدف، شاخه، زیرشاخه، حلقه، انیمیشن) روی نقشه.
/// فقط یک ویدیو هم‌زمان نمایش داده می‌شود.
class MapVideoPlayer {
  MapVideoPlayer._();
  static final MapVideoPlayer instance = MapVideoPlayer._();

  final ValueNotifier<MapVideoRequest?> current =
      ValueNotifier<MapVideoRequest?>(null);
  int _n = 0;

  /// دکمه‌ی ویدیو روی نقشه: اگر همین ویدیو باز است بسته می‌شود، وگرنه باز می‌شود
  void toggle(String id, Map<String, dynamic>? extra, String key) {
    if (current.value?.id == id) {
      close();
      return;
    }
    final v = extra?[key];
    if (v is! String || v.isEmpty) return;
    current.value = MapVideoRequest(id, v, ++_n);
  }

  void close() => current.value = null;
}
