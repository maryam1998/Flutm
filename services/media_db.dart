import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'media_backend.dart';

/// فایل‌های رسانه‌ای (عکس/صدا/ویدیو) جدا از JSON ذخیره می‌شن:
/// • وب: IndexedDB   • اندروید و بقیه: فایل در پوشه‌ی اپ
/// داخل JSON فقط یک ارجاع کوتاه به شکل `idb:<id>` می‌مونه.
/// همه‌ی فایل‌ها هنگام شروع برنامه در حافظه بارگذاری می‌شن تا نمایش
/// عکس‌ها مثل قبل همگام (sync) باشه.
class MediaDb {
  static const prefix = 'idb:';
  static final _cache = <String, MediaBlob>{};
  static Future<void>? _initFuture;

  static final _dataUrlRe = RegExp(
      r'data:([A-Za-z0-9.+\-]+/[A-Za-z0-9.+\-]+);base64,([A-Za-z0-9+/=]+)');
  static final _refRe = RegExp(r'idb:([a-z0-9]+)');

  static Future<void> init() => _initFuture ??= _load();

  static Future<void> _load() async {
    try {
      _cache.addAll(await MediaBackend.loadAll());
    } catch (e) {
      debugPrint('MediaDb: load failed: $e');
    }
  }

  static bool isRef(String s) => s.startsWith(prefix);

  static String _newId() {
    final r = Random();
    final tail = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$tail';
  }

  /// ذخیره‌ی بایت‌ها و برگرداندن ارجاع. اگه ذخیره ممکن نبود، به‌جای از دست
  /// رفتن داده یک data URL برمی‌گردونه (که مثل قبل داخل JSON می‌مونه).
  static Future<String> putBytes(Uint8List bytes, String mime) async {
    final id = _newId();
    final blob = MediaBlob(bytes, mime, DateTime.now().millisecondsSinceEpoch);
    try {
      await init();
      await MediaBackend.put(id, blob);
      _cache[id] = blob;
      return '$prefix$id';
    } catch (e) {
      debugPrint('MediaDb.putBytes failed, keeping data URL: $e');
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }
  }

  /// data URL → ارجاع (بقیه‌ی مقدارها بدون تغییر برمی‌گردن)
  static Future<String> internDataUrl(String src) async {
    if (!src.startsWith('data:')) return src;
    final m = _dataUrlRe.matchAsPrefix(src);
    if (m == null) return src;
    try {
      return putBytes(base64Decode(m.group(2)!), m.group(1)!);
    } catch (_) {
      return src;
    }
  }

  /// بایت‌های یک ارجاع یا data URL (همگام)
  static Uint8List? bytes(String src) {
    if (src.startsWith(prefix)) return _cache[src.substring(prefix.length)]?.bytes;
    if (src.startsWith('data:')) {
      try {
        return base64Decode(src.substring(src.indexOf(',') + 1));
      } catch (_) {}
    }
    return null;
  }

  static String? mime(String src) {
    if (src.startsWith(prefix)) return _cache[src.substring(prefix.length)]?.mime;
    final m = _dataUrlRe.matchAsPrefix(src);
    return m?.group(1);
  }

  static bool isVideo(String src) => (mime(src) ?? '').startsWith('video/');

  /// ارجاع (یا data URL) → data URL؛ برای پخش‌کننده‌ها و خروجی بکاپ
  static String? toDataUrl(String src) {
    if (src.startsWith('data:')) return src;
    if (!src.startsWith(prefix)) return null;
    final b = _cache[src.substring(prefix.length)];
    if (b == null) return null;
    return 'data:${b.mime};base64,${base64Encode(b.bytes)}';
  }

  /// همه‌ی data URL های داخل یک متن JSON رو به ارجاع تبدیل می‌کنه
  /// (مهاجرت داده‌ی قدیمی و ورودی بکاپ).
  static Future<String> externalizeJson(String json) async {
    if (!json.contains(';base64,')) return json;
    final matches = _dataUrlRe.allMatches(json).toList();
    if (matches.isEmpty) return json;
    final done = <String, String>{};
    final out = StringBuffer();
    var last = 0;
    for (final m in matches) {
      out.write(json.substring(last, m.start));
      final whole = m.group(0)!;
      var ref = done[whole];
      if (ref == null) {
        try {
          ref = await putBytes(base64Decode(m.group(2)!), m.group(1)!);
        } catch (_) {
          ref = whole;
        }
        done[whole] = ref;
      }
      out.write(ref);
      last = m.end;
    }
    out.write(json.substring(last));
    return out.toString();
  }

  /// معکوس externalizeJson؛ برای ساخت فایل بکاپ قابل‌حمل
  static String inlineJson(String json) {
    if (!json.contains(prefix)) return json;
    return json.replaceAllMapped(_refRe, (m) {
      final b = _cache[m.group(1)!];
      if (b == null) return m.group(0)!;
      return 'data:${b.mime};base64,${base64Encode(b.bytes)}';
    });
  }

  /// پاک‌کردن فایل‌های یتیم (که دیگه هیچ جای داده‌ها بهشون ارجاع نیست).
  /// محافظه‌کارانه: فقط فایل‌های قدیمی‌تر از [grace] پاک می‌شن.
  static Future<void> collectGarbage(Iterable<String> texts,
      {Duration grace = const Duration(days: 3)}) async {
    try {
      await init();
      final live = <String>{};
      for (final t in texts) {
        if (!t.contains(prefix)) continue;
        for (final m in _refRe.allMatches(t)) {
          live.add(m.group(1)!);
        }
      }
      final cutoff = DateTime.now().subtract(grace).millisecondsSinceEpoch;
      final dead = _cache.entries
          .where((e) => !live.contains(e.key) && e.value.createdAt < cutoff)
          .map((e) => e.key)
          .toList();
      for (final id in dead) {
        try {
          await MediaBackend.delete(id);
          _cache.remove(id);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('MediaDb.collectGarbage failed: $e');
    }
  }
}
