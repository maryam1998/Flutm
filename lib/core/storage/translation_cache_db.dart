import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_factory.dart';

/// کشِ دائمیِ ترجمه‌ها — معادلِ app/storage/translationCacheDb.js در Hope.
///
///   • وب: IndexedDB (دیتابیس `phrasebook-translations`، مثل Hope)
///   • اندروید/iOS/دسکتاپ: فایلِ دیتابیس (sembast) در پوشه‌ی برنامه
///
/// کلید همان فرمتِ Hope است: `مبدأ::مقصد::متن`. یک‌بار که چیزی ترجمه شد
/// برای همیشه (حتی بعد از بستنِ برنامه/آفلاین) ذخیره می‌ماند.
///
/// برای اسکرولِ روان، همه‌ی رکوردها هنگامِ باز شدن در حافظه هم نگه داشته
/// می‌شوند و [peek] همگام (بدونِ await) جواب می‌دهد. اگر دیتابیس به هر دلیلی
/// باز نشد (مثلاً حالتِ خصوصیِ مرورگر)، کش فقط در حافظه کار می‌کند.
class TranslationCacheDb {
  TranslationCacheDb._();
  static final TranslationCacheDb instance = TranslationCacheDb._();

  static const String _dbName = 'phrasebook-translations.db';
  static const String _legacyPrefix = 'tr3::';

  final StoreRef<String, String> _store =
      StoreRef<String, String>('translations');
  final Map<String, String> _mem = {};

  Database? _db;
  Future<void>? _opening;

  /// باز کردنِ دیتابیس + بارگذاریِ رکوردها در حافظه + انتقالِ کشِ قدیمی
  /// (SharedPreferences). چندبار صدا زدن امن است.
  Future<void> init([SharedPreferences? legacyPrefs]) =>
      _opening ??= _open(legacyPrefs);

  Future<void> _open(SharedPreferences? legacy) async {
    try {
      final db = await openCacheDatabase(_dbName);
      _db = db;
      final records = await _store.find(db);
      for (final r in records) {
        _mem[r.key] = r.value;
      }
    } catch (_) {
      _db = null; // فقط حافظه
    }
    if (legacy != null) await _migrateLegacy(legacy);
  }

  /// ترجمه‌هایی که قبلاً تک‌به‌تک در SharedPreferences بودند (کلید `tr3::…`)
  /// یک‌بار به دیتابیس منتقل و از prefs پاک می‌شوند.
  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    try {
      final keys =
          prefs.getKeys().where((k) => k.startsWith(_legacyPrefix)).toList();
      if (keys.isEmpty) return;
      final moved = <String, String>{};
      for (final k in keys) {
        final v = prefs.getString(k);
        if (v != null && v.isNotEmpty) {
          moved[k.substring(_legacyPrefix.length)] = v;
        }
      }
      final db = _db;
      if (db != null && moved.isNotEmpty) {
        await db.transaction((txn) async {
          for (final e in moved.entries) {
            if (!_mem.containsKey(e.key)) {
              await _store.record(e.key).put(txn, e.value);
            }
          }
        });
      } else if (db == null) {
        return; // دیتابیس نیست؛ کشِ قدیمی را پاک نکن
      }
      for (final e in moved.entries) {
        _mem.putIfAbsent(e.key, () => e.value);
      }
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  /// خواندنِ همگام (فقط از حافظه).
  String? peek(String key) => _mem[key];

  /// خواندنِ ناهمگام (منتظرِ آماده‌شدنِ دیتابیس می‌ماند).
  Future<String?> get(String key) async {
    final hit = _mem[key];
    if (hit != null) return hit;
    final op = _opening;
    if (op != null) await op;
    return _mem[key];
  }

  Future<void> put(String key, String value) async {
    _mem[key] = value;
    final op = _opening;
    if (op != null) await op;
    final db = _db;
    if (db == null) return;
    try {
      await _store.record(key).put(db, value);
    } catch (_) {
      // سهمیه‌ی ذخیره‌سازی پر بود — فقط حافظه
    }
  }

  /// تعدادِ ترجمه‌های ذخیره‌شده (برای «دانلود آفلاین»).
  int get count => _mem.length;

  /// همه‌ی ترجمه‌های کش‌شده‌ی یک زبانِ مقصد: متنِ اصلی ← ترجمه
  /// (معادلِ getCachedTranslationMap در Hope؛ برای جستجو روی ترجمه‌ها).
  Map<String, String> mapForTarget(String targetLang, [String source = 'en']) {
    final prefix = '$source::$targetLang::';
    final out = <String, String>{};
    _mem.forEach((k, v) {
      if (k.startsWith(prefix)) out[k.substring(prefix.length)] = v;
    });
    return out;
  }

  Future<void> clear() async {
    _mem.clear();
    final db = _db;
    if (db != null) {
      try {
        await _store.delete(db);
      } catch (_) {}
    }
  }
}
