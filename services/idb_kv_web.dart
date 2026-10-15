import 'dart:js_interop';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:web/web.dart' as web;

/// ذخیره‌ی کلید/مقدار در IndexedDB مرورگر.
/// برخلاف localStorage سقف ۵ مگابایتی نداره، پس عکس‌ها و صداهای
/// ثبت‌شده‌ی کاربر (data URL) بدون مشکل ذخیره می‌شن.
class IdbKv {
  static const bool supported = true;

  static const _dbName = 'maghz_kv_v1';
  static const _storeName = 'kv';
  static Future<Database>? _dbFuture;

  static Future<Database> _open() {
    return _dbFuture ??= idbFactoryBrowser.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );
  }

  static Future<Map<String, Object?>> loadAll() async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadOnly);
    final store = tx.objectStore(_storeName);
    final keys = await store.getAllKeys();
    final out = <String, Object?>{};
    for (final k in keys) {
      out[k.toString()] = await store.getObject(k);
    }
    await tx.completed;
    return out;
  }

  static Future<void> put(String key, Object value) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadWrite);
    await tx.objectStore(_storeName).put(value, key);
    await tx.completed;
  }

  static Future<void> delete(String key) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadWrite);
    await tx.objectStore(_storeName).delete(key);
    await tx.completed;
  }

  /// از مرورگر می‌خوایم داده‌ها رو خودکار پاک نکنه (در صورت کمبود فضا).
  static Future<void> requestPersistent() async {
    try {
      await web.window.navigator.storage.persist().toDart;
    } catch (_) {}
  }
}
