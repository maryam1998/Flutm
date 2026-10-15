import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'idb_kv.dart';

/// جایگزین مستقیم SharedPreferences با همان متدها.
///
/// • وب: همه‌چیز در IndexedDB ذخیره می‌شه (بدون سقف ۵MB، مناسب عکس/صدا/ویدیو).
///   بار اول، داده‌های قدیمیِ localStorage خودکار به IndexedDB منتقل می‌شن
///   (نسخه‌ی قدیمی دست‌نخورده می‌مونه، چیزی پاک نمی‌شه).
/// • اندروید/iOS/دسکتاپ: مثل قبل SharedPreferences.
class AppPrefs {
  AppPrefs._(this._cache, this._sp);

  static const _migratedFlag = '__migrated_from_localstorage_v1';

  final Map<String, Object?> _cache;

  /// اگه null نباشه یعنی حالت SharedPreferences (غیر وب یا خرابیِ IndexedDB)
  final SharedPreferences? _sp;

  static Future<AppPrefs>? _future;

  static Future<AppPrefs> getInstance() {
    final f = _future ??= _init();
    return f.catchError((Object e) {
      _future = null;
      throw e;
    });
  }

  static Future<AppPrefs> _init() async {
    final sp = await SharedPreferences.getInstance();
    if (!IdbKv.supported) return AppPrefs._({}, sp);

    try {
      final all = await IdbKv.loadAll();
      if (all[_migratedFlag] != true) {
        for (final k in sp.getKeys()) {
          if (all.containsKey(k)) continue;
          final v = sp.get(k);
          if (v is String || v is int || v is double || v is bool) {
            all[k] = v;
            await IdbKv.put(k, v!);
          }
        }
        all[_migratedFlag] = true;
        await IdbKv.put(_migratedFlag, true);
      }
      IdbKv.requestPersistent();
      return AppPrefs._(all, null);
    } catch (e) {
      debugPrint('AppPrefs: IndexedDB unavailable, using SharedPreferences: $e');
      return AppPrefs._({}, sp);
    }
  }

  // ───────── خواندن ─────────

  Object? _get(String key) => _sp != null ? _sp.get(key) : _cache[key];

  String? getString(String key) {
    final v = _get(key);
    return v is String ? v : null;
  }

  int? getInt(String key) {
    final v = _get(key);
    return v is num ? v.toInt() : null;
  }

  double? getDouble(String key) {
    final v = _get(key);
    return v is num ? v.toDouble() : null;
  }

  bool? getBool(String key) {
    final v = _get(key);
    return v is bool ? v : null;
  }

  bool containsKey(String key) => _get(key) != null;

  // ───────── نوشتن ─────────

  Future<bool> setString(String key, String value) async {
    if (_sp != null) return _sp.setString(key, value);
    return _put(key, value);
  }

  Future<bool> setInt(String key, int value) async {
    if (_sp != null) return _sp.setInt(key, value);
    return _put(key, value);
  }

  Future<bool> setDouble(String key, double value) async {
    if (_sp != null) return _sp.setDouble(key, value);
    return _put(key, value);
  }

  Future<bool> setBool(String key, bool value) async {
    if (_sp != null) return _sp.setBool(key, value);
    return _put(key, value);
  }

  Future<bool> remove(String key) async {
    if (_sp != null) return _sp.remove(key);
    if (!_cache.containsKey(key)) return true;
    _cache.remove(key);
    try {
      await IdbKv.delete(key);
      return true;
    } catch (e) {
      debugPrint('AppPrefs.remove($key) failed: $e');
      return false;
    }
  }

  Future<bool> _put(String key, Object value) async {
    // مقدار تکراری دوباره نوشته نمی‌شه (برای رشته‌های سنگین مهمه)
    if (_cache.containsKey(key) && _cache[key] == value) return true;
    _cache[key] = value;
    try {
      await IdbKv.put(key, value);
      return true;
    } catch (e) {
      debugPrint('AppPrefs.put($key) failed: $e');
      return false;
    }
  }
}
