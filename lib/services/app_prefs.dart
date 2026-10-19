import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'idb_kv.dart';

/// جایگزین هم‌امضای `SharedPreferences`:
///  • وب: همه‌چیز در **IndexedDB** مرورگرِ همین گوشی ذخیره می‌شود (نه localStorage با سقف ~۵MB،
///    نه سرور). با اولین اجرا، داده‌های قدیمیِ localStorage خودکار به IndexedDB منتقل می‌شوند.
///  • موبایل/دسکتاپ: همان SharedPreferences.
///
/// خواندن از حافظه‌ی RAM است (همه‌ی کلیدها هنگام شروع بارگذاری می‌شوند)،
/// نوشتن هم در RAM و هم در IndexedDB.
class AppPrefs {
  AppPrefs._(this._sp, this._mem);

  final SharedPreferences _sp;

  /// null = حالت SharedPreferences خالص (غیر وب، یا IndexedDB در دسترس نیست)
  final Map<String, Object>? _mem;

  /// کلیدهایی که آخرین نوشتنشان در IndexedDB ناموفق بود (باید دوباره نوشته شوند)
  final Set<String> _failed = <String>{};

  static Future<AppPrefs>? _future;
  static Future<AppPrefs> getInstance() => _future ??= _create();

  static Future<AppPrefs> _create() async {
    final sp = await SharedPreferences.getInstance();
    if (!kIsWeb) return AppPrefs._(sp, null);
    try {
      final all = await IdbKv.readAll();
      final mem = <String, Object>{};
      all.forEach((k, v) {
        if (v != null) mem[k] = v;
      });
      // انتقال یک‌باره از localStorage → IndexedDB
      for (final k in sp.getKeys().toList()) {
        try {
          if (!mem.containsKey(k)) {
            final v = sp.get(k);
            if (v == null) continue;
            await IdbKv.put(k, v);
            mem[k] = v;
          }
          await sp.remove(k); // فقط بعد از اینکه مطمئنیم تو IndexedDB هست
        } catch (e) {
          debugPrint('AppPrefs: migrate "$k" failed: $e');
        }
      }
      return AppPrefs._(sp, mem);
    } catch (e) {
      debugPrint('AppPrefs: IndexedDB unavailable, using localStorage: $e');
      return AppPrefs._(sp, null);
    }
  }

  // ─────────── خواندن ───────────
  String? getString(String key) {
    final m = _mem;
    if (m == null) return _sp.getString(key);
    final v = m[key];
    return v is String ? v : null;
  }

  int? getInt(String key) {
    final m = _mem;
    if (m == null) return _sp.getInt(key);
    final v = m[key];
    return v is num ? v.toInt() : null;
  }

  double? getDouble(String key) {
    final m = _mem;
    if (m == null) return _sp.getDouble(key);
    final v = m[key];
    return v is num ? v.toDouble() : null;
  }

  bool? getBool(String key) {
    final m = _mem;
    if (m == null) return _sp.getBool(key);
    final v = m[key];
    return v is bool ? v : null;
  }

  /// همه‌ی کلید–مقدارها (برای بکاپ کامل)
  Map<String, Object> exportAll() {
    final m = _mem;
    if (m != null) return Map<String, Object>.of(m);
    final out = <String, Object>{};
    for (final k in _sp.getKeys()) {
      final v = _sp.get(k);
      if (v != null) out[k] = v;
    }
    return out;
  }

  Future<bool> setStringList(String key, List<String> value) =>
      _set(key, value);

  // ─────────── نوشتن ───────────
  Future<bool> setString(String key, String value) => _set(key, value);
  Future<bool> setInt(String key, int value) => _set(key, value);
  Future<bool> setDouble(String key, double value) => _set(key, value);
  Future<bool> setBool(String key, bool value) => _set(key, value);

  Future<bool> _set(String key, Object value) async {
    final m = _mem;
    if (m == null) {
      if (value is String) return _sp.setString(key, value);
      if (value is int) return _sp.setInt(key, value);
      if (value is double) return _sp.setDouble(key, value);
      if (value is bool) return _sp.setBool(key, value);
      if (value is List<String>) return _sp.setStringList(key, value);
      return false;
    }
    if (m[key] == value && !_failed.contains(key)) {
      return true; // بدون تغییر → دوباره نوشتن کل داده لازم نیست
    }
    m[key] = value;
    try {
      await IdbKv.put(key, value);
      _failed.remove(key);
      return true;
    } catch (e) {
      _failed.add(key);
      debugPrint('AppPrefs: write "$key" failed: $e');
      return false;
    }
  }

  Future<bool> remove(String key) async {
    final m = _mem;
    if (m == null) return _sp.remove(key);
    m.remove(key);
    try {
      await IdbKv.delete(key);
      return true;
    } catch (e) {
      debugPrint('AppPrefs: remove "$key" failed: $e');
      return false;
    }
  }
}
