import 'dart:convert';
import 'dart:typed_data';

/// کش دیکُد data-URL → بایت.
/// قبلاً هر بار build، base64 دوباره دیکُد می‌شد و چون هر بار یک Uint8List جدید
/// می‌ساخت، Flutter هم عکس رو از نو دیکُد می‌کرد؛ برای همین عکس‌ها دیر ظاهر می‌شدن.
/// با این کش، همان شیء بایت برمی‌گرده و ImageCache خودِ Flutter هم کار می‌کنه.
class DataUrlCache {
  static final Map<int, Uint8List> _m = <int, Uint8List>{};
  static int _total = 0;
  static const int _maxBytes = 160 * 1024 * 1024;

  static int _key(String src, int comma) {
    final n = src.length;
    final a = comma + 1;
    final head = src.substring(a, a + 96 > n ? n : a + 96);
    final tail = src.substring(n - 96 < a ? a : n - 96);
    final mid = n > a + 400 ? src.substring(n ~/ 2, n ~/ 2 + 64) : '';
    return Object.hash(n, head, tail, mid);
  }

  /// بایت‌های از قبل موجود را (بدون دیکُد دوباره‌ی base64) در کش می‌گذارد.
  static void seed(String src, Uint8List b) {
    final i = src.indexOf(',');
    if (i < 0) return;
    final k = _key(src, i);
    if (_m.containsKey(k)) return;
    _m[k] = b;
    _total += b.length;
    while (_total > _maxBytes && _m.length > 1) {
      final first = _m.keys.first;
      _total -= _m.remove(first)!.length;
    }
  }

  static Uint8List? bytes(String? src) {
    if (src == null || !src.startsWith('data:')) return null;
    final i = src.indexOf(',');
    if (i < 0) return null;
    final k = _key(src, i);
    final hit = _m.remove(k);
    if (hit != null) {
      _m[k] = hit; // تازه‌ترین
      return hit;
    }
    try {
      final b = base64Decode(src.substring(i + 1));
      _m[k] = b;
      _total += b.length;
      while (_total > _maxBytes && _m.length > 1) {
        final first = _m.keys.first;
        _total -= _m.remove(first)!.length;
      }
      return b;
    } catch (_) {
      return null;
    }
  }
}
