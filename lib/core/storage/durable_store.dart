// 📁 مسیر: lib/core/storage/durable_store.dart
//
// نسخه‌ی «دائمی» داده‌های کاربر روی خودِ دستگاه:
//   • وب: IndexedDB مرورگر   • اندروید/iOS: فایل دیتابیس (sembast) در پوشه‌ی برنامه
//
// همه‌ی داده‌های کاربر (لغات ذخیره‌شده، داستان‌ها، یادداشت‌های گرامر، لایتنر، مرور،
// علاقه‌مندی‌ها، تنظیمات و ...) قبلاً فقط در SharedPreferences بودند. اگر آن
// خالی/پاک می‌شد (پاک‌شدنِ localStorage مرورگر، خرابیِ prefs، بازیابیِ بکاپِ
// قدیمی)، همه‌چیز از بین می‌رفت. حالا:
//   ۱) هر تغییرِ کلیدهای کاربر کمی بعد در این دیتابیس هم کپی می‌شود (mirror)؛
//   ۲) هنگام باز شدنِ برنامه، کلیدی که در prefs نیست از این دیتابیس برمی‌گردد.
// مرجعِ زنده همچنان SharedPreferences است؛ این فقط یک نسخه‌ی پشتیبانِ محلی است.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_factory.dart';

/// کلیدهایی که جزو داده‌ی کاربرند و باید ماندگار شوند.
bool isDurableKey(String k) {
  if (k.startsWith('zflut-auth-')) return false; // حالت مهمان
  return k.startsWith('phrasebook-') ||
      k.startsWith('zflut-') ||
      k == 'voiceEnginePref' ||
      k == 'syncModelSize';
}

class DurableStore with WidgetsBindingObserver {
  DurableStore._();
  static final DurableStore instance = DurableStore._();

  static const String _dbName = 'zflut-userdata.db';
  final StoreRef<String, String> _store = StoreRef<String, String>('kv');

  /// آخرین مقداری که در دیتابیس نوشته شده (برای نوشتنِ فقط تغییرها).
  final Map<String, String> _last = <String, String>{};

  Database? _db;
  SharedPreferences? _prefs;
  bool _ready = false;
  bool _aborted = false;
  bool _started = false;
  bool _flushing = false;
  bool _flushAgain = false;
  Timer? _debounce;
  Timer? _periodic;

  bool get isReady => _ready;

  /// دیتابیس را باز می‌کند، کلیدهای گم‌شده‌ی prefs را برمی‌گرداند و mirror را
  /// روشن می‌کند. تعداد کلیدهای بازیابی‌شده را برمی‌گرداند. هیچ‌وقت خطا نمی‌دهد.
  Future<int> init(SharedPreferences prefs) async {
    if (_started) return 0;
    _started = true;
    _prefs = prefs;
    try {
      return await _open(prefs).timeout(const Duration(seconds: 6));
    } catch (e) {
      _aborted = true; // اگر دیرتر آماده شد، دیگر چیزی را برنگردان
      _ready = false;
      debugPrint('DurableStore init failed: $e');
      return 0;
    }
  }

  Future<int> _open(SharedPreferences prefs) async {
    final db = await openCacheDatabase(_dbName);
    if (_aborted) {
      await db.close();
      return 0;
    }
    _db = db;
    final records = await _store.find(db);
    var restored = 0;
    for (final r in records) {
      final k = r.key;
      final v = r.value;
      if (!isDurableKey(k)) continue;
      _last[k] = v;
      final cur = prefs.get(k);
      if (cur == null) {
        // کلید در prefs نیست (پاک شده) → از نسخه‌ی دائمی برگردان
        await prefs.setString(k, v);
        restored++;
      } else if (cur is String &&
          cur != v &&
          _isEmptyish(cur) &&
          !_isEmptyish(v)) {
        // prefs خالی شده ولی نسخه‌ی دائمی پر است
        await prefs.setString(k, v);
        restored++;
      }
    }
    if (_aborted) return restored;
    _ready = true;
    _startObserving();
    _scheduleFlush(const Duration(seconds: 2));
    return restored;
  }

  /// «{items: []}» / «[]» / «{}» و مشابه.
  static bool _isEmptyish(String s) {
    final t = s.trim();
    if (t.isEmpty || t == '{}' || t == '[]' || t == 'null') return true;
    try {
      final d = jsonDecode(t);
      if (d is List) return d.isEmpty;
      if (d is Map) {
        if (d.isEmpty) return true;
        return d.values.every(
            (v) => (v is List && v.isEmpty) || (v is Map && v.isEmpty));
      }
    } catch (_) {}
    return false;
  }

  void _startObserving() {
    _periodic ??= Timer.periodic(
        const Duration(seconds: 30), (_) => unawaited(flush()));
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(flush());
    }
  }

  /// بعد از هر نوشتن در prefs صدا زده می‌شود (با تأخیرِ کوتاه تجمیع می‌شود).
  void schedule(SharedPreferences prefs) {
    if (!_ready) return;
    _prefs ??= prefs;
    _scheduleFlush(const Duration(milliseconds: 900));
  }

  void _scheduleFlush(Duration d) {
    _debounce?.cancel();
    _debounce = Timer(d, () => unawaited(flush()));
  }

  /// هر کلیدِ تغییرکرده‌ی prefs را در دیتابیس می‌نویسد.
  Future<void> flush() async {
    final db = _db;
    final prefs = _prefs;
    if (!_ready || db == null || prefs == null) return;
    if (_flushing) {
      _flushAgain = true;
      return;
    }
    _flushing = true;
    try {
      do {
        _flushAgain = false;
        final changed = <String, String>{};
        for (final k in prefs.getKeys()) {
          if (!isDurableKey(k)) continue;
          final v = prefs.get(k);
          if (v is! String) continue;
          if (_last[k] != v) changed[k] = v;
        }
        if (changed.isEmpty) continue;
        await db.transaction((txn) async {
          for (final e in changed.entries) {
            await _store.record(e.key).put(txn, e.value);
          }
        });
        _last.addAll(changed);
      } while (_flushAgain);
    } catch (e) {
      debugPrint('DurableStore flush failed: $e');
    } finally {
      _flushing = false;
    }
  }

  /// حذفِ عمدیِ کلیدها (مثلاً پاک‌کردنِ داده‌ی حسابِ قبلی).
  Future<void> removeKeys(Iterable<String> keys) async {
    final list = keys.toList();
    for (final k in list) {
      _last.remove(k);
    }
    final db = _db;
    if (!_ready || db == null || list.isEmpty) return;
    try {
      await db.transaction((txn) async {
        for (final k in list) {
          await _store.record(k).delete(txn);
        }
      });
    } catch (_) {}
  }

  void noteRemoved(String key) => unawaited(removeKeys(<String>[key]));
}
