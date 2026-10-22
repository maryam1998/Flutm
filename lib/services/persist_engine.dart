import 'dart:async';
import 'dart:convert' show latin1;

import 'package:flutter/foundation.dart' show debugPrint;

import 'media_blob.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  موتور ذخیره‌سازی (Persist Engine)
//
//  مشکل قبلی: صدای ضبط‌شده، GIF و عکس‌ها به‌صورت data-URL (base64) داخل همون JSON
//  اصلی نقشه / شکرگذاری / باورها بودن. با هر تغییر کوچک (حتی تایپ یک حرف) کل این
//  رشته‌ی چندده‌مگابایتی دوباره ساخته (jsonEncode) و نوشته می‌شد؛ چند ذخیره هم
//  می‌تونست هم‌زمان اجرا بشه. نتیجه: هنگ موقع رفتن بین تب‌ها، ثبت لیست و ...
//
//  راه‌حل:
//   1) [BlobOffload]  — هر data-URL بزرگ (صدا/GIF/عکس) فقط یک‌بار در فضای جدا
//      (IndexedDB روی وب / فایل روی موبایل) ذخیره می‌شه و در JSON فقط یک مرجع کوتاه
//      می‌مونه. محتوای یکسان = همون فایل (بدون تکرار)، پس ذخیره‌های بعدی تقریباً
//      هیچ هزینه‌ای ندارن. موقع بالا اومدن برنامه مرجع‌ها دوباره به data-URL
//      برمی‌گردن؛ پس بقیه‌ی برنامه هیچ تغییری حس نمی‌کنه.
//   2) [CoalescedTask] — ذخیره‌ها تک‌صف می‌شن: درخواست‌های پشت‌سرهم یکی می‌شن و
//      همیشه «آخرین وضعیت» نوشته می‌شه؛ دو نوشتن هم‌زمان (که می‌تونست داده‌ی
//      قدیمی‌تر رو روی جدیدتر بنویسه) دیگه ممکن نیست.
// ═══════════════════════════════════════════════════════════════════════════

/// اجرای تک‌صفِ یک کار async. درخواست‌هایی که وسط اجرا برسن، در یک دور بعدی ادغام
/// می‌شن و کار همیشه با جدیدترین وضعیت اجرا می‌شه.
class CoalescedTask {
  CoalescedTask(this._run);

  final Future<void> Function() _run;
  Future<void>? _inflight;
  bool _again = false;

  /// وقتی کار (و هر دور پشت‌سرش) تموم شد کامل می‌شه.
  Future<void> request() {
    final cur = _inflight;
    if (cur != null) {
      _again = true;
      return cur;
    }
    final f = _loop();
    _inflight = f;
    return f;
  }

  Future<void> _loop() async {
    // وقفه‌ی کوتاه: درخواست‌های هم‌زمان ادغام می‌شن و فریمِ جاری سریع تموم می‌شه
    await Future<void>.delayed(Duration.zero);
    try {
      do {
        _again = false;
        try {
          await _run();
        } catch (e, st) {
          debugPrint('CoalescedTask failed: $e\n$st');
        }
      } while (_again);
    } finally {
      _inflight = null;
    }
  }
}

/// جداکردنِ data-URLهای بزرگ از JSON ذخیره‌سازی.
class BlobOffload {
  BlobOffload._();

  /// رشته‌های data: بلندتر از این (حدود ۱۸ کیلوبایت داده) بیرون JSON ذخیره می‌شن
  static const int minChars = 24 * 1024;

  static const String _refPrefix = 'mblob:ob_';

  /// اثرانگشتِ محتوا → مرجعی که مطمئنیم روی دیسک هست
  static final Map<String, String> _refs = <String, String>{};

  static bool _isBig(Object? v) =>
      v is String && v.length >= minChars && v.startsWith('data:');

  static bool _isOurRef(Object? v) => v is String && v.startsWith(_refPrefix);

  /// اثرانگشت ارزان ولی قابل‌اعتماد: طول + ~۲۰۰۰ نمونه‌ی پخش‌شده + ابتدا/انتهای رشته
  static String _key(String s) {
    final n = s.length;
    var h1 = n & 0x1fffffff;
    var h2 = 7;
    final step = (n ~/ 2048) < 1 ? 1 : (n ~/ 2048);
    for (var i = 0; i < n; i += step) {
      final c = s.codeUnitAt(i);
      h1 = (h1 * 31 + c) & 0x1fffffff;
      h2 = (h2 * 131 + c + i) & 0x1fffffff;
    }
    final edge = n < 256 ? n : 256;
    for (var i = 0; i < edge; i++) {
      h1 = (h1 * 31 + s.codeUnitAt(i)) & 0x1fffffff;
      h2 = (h2 * 131 + s.codeUnitAt(n - 1 - i)) & 0x1fffffff;
    }
    return '${n}_${h1}_$h2';
  }

  // ───────────────────────── ذخیره ─────────────────────────

  /// [tree] = خروجی toJson (Map/List/String/...). نسخه‌ی جدیدی برمی‌گردونه که
  /// data-URLهای بزرگش با مرجع کوتاه عوض شده. ورودی دست‌نخورده می‌مونه.
  /// اگه هر مشکلی پیش بیاد همون [tree] برمی‌گرده (ذخیره‌ی معمولی؛ داده گم نمی‌شه).
  static Future<Object?> offload(Object? tree) async {
    try {
      final missing = <String, String>{};
      _collect(tree, missing);
      if (missing.isNotEmpty) {
        await Future.wait(
          missing.entries.map((e) => _store(e.key, e.value)).toList(),
        );
      }
      return _swapOut(tree);
    } catch (e, st) {
      debugPrint('BlobOffload.offload failed: $e\n$st');
      return tree;
    }
  }

  static Future<void> _store(String key, String data) async {
    try {
      final bytes = latin1.encode(data);
      final ref = await MediaBlob.saveBytesWithId(
        bytes,
        id: 'ob_$key.dat',
        mime: 'application/octet-stream',
      );
      _refs[key] = ref;
    } catch (e) {
      // ذخیره‌ی بلاب نشد → همین رشته داخل JSON می‌مونه (بدون از دست رفتن داده)
      debugPrint('BlobOffload: store failed: $e');
    }
  }

  static void _collect(Object? n, Map<String, String> out) {
    if (n is String) {
      if (_isBig(n)) {
        final k = _key(n);
        if (!_refs.containsKey(k)) out[k] = n;
      }
    } else if (n is Map) {
      for (final v in n.values) {
        _collect(v, out);
      }
    } else if (n is List) {
      for (final v in n) {
        _collect(v, out);
      }
    }
  }

  static Object? _swapOut(Object? n) {
    if (n is String) {
      if (_isBig(n)) {
        final ref = _refs[_key(n)];
        if (ref != null) return ref;
      }
      return n;
    }
    if (n is Map) {
      return <String, dynamic>{
        for (final e in n.entries) e.key.toString(): _swapOut(e.value),
      };
    }
    if (n is List) {
      return <dynamic>[for (final v in n) _swapOut(v)];
    }
    return n;
  }

  // ───────────────────────── خواندن ─────────────────────────

  /// [tree] = خروجی jsonDecode. مرجع‌ها دوباره به data-URL برمی‌گردن.
  /// مرجعی که بلابش پیدا نشه همون‌طور دست‌نخورده می‌مونه (چیزی پاک نمی‌شه).
  static Future<Object?> rehydrate(Object? tree) async {
    try {
      final refs = <String>{};
      _collectRefs(tree, refs);
      if (refs.isEmpty) return tree;
      final data = <String, String>{};
      final list = refs.toList();
      const batch = 4;
      for (var i = 0; i < list.length; i += batch) {
        final end = i + batch > list.length ? list.length : i + batch;
        await Future.wait(list.sublist(i, end).map((r) async {
          try {
            final b = await MediaBlob.readBytes(r);
            if (b == null) return;
            final s = latin1.decode(b);
            data[r] = s;
            _refs[_key(s)] = r;
          } catch (_) {}
        }).toList());
      }
      return _swapIn(tree, data);
    } catch (e, st) {
      debugPrint('BlobOffload.rehydrate failed: $e\n$st');
      return tree;
    }
  }

  static void _collectRefs(Object? n, Set<String> out) {
    if (n is String) {
      if (_isOurRef(n)) out.add(n);
    } else if (n is Map) {
      for (final v in n.values) {
        _collectRefs(v, out);
      }
    } else if (n is List) {
      for (final v in n) {
        _collectRefs(v, out);
      }
    }
  }

  static Object? _swapIn(Object? n, Map<String, String> data) {
    if (n is String) return _isOurRef(n) ? (data[n] ?? n) : n;
    if (n is Map) {
      return <String, dynamic>{
        for (final e in n.entries) e.key.toString(): _swapIn(e.value, data),
      };
    }
    if (n is List) {
      return <dynamic>[for (final v in n) _swapIn(v, data)];
    }
    return n;
  }
}
