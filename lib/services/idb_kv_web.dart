import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';

/// ذخیره‌ی کلید–مقدار در IndexedDB مرورگر (روی خودِ گوشی، نه سرور).
/// برخلاف localStorage سقف ۵ مگابایتی ندارد، پس عکس‌ها و ویدیوهای کوچک جا می‌شوند.
class IdbKv {
  static const _dbName = 'maghz_kv_v1';
  static const _storeName = 'kv';
  static Database? _db;

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    _db = await idbFactoryBrowser.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );
    return _db!;
  }

  /// همه‌ی کلیدها یک‌جا (هنگام شروع برنامه).
  /// getAllKeys + getAll چند برابر سریع‌تر از خواندن با cursor و یکی‌یکی است.
  static Future<Map<String, Object?>> readAll() async {
    final db = await _open();
    try {
      final tx = db.transaction(_storeName, idbModeReadOnly);
      final store = tx.objectStore(_storeName);
      final keysF = store.getAllKeys();
      final valsF = store.getAll();
      final keys = await keysF;
      final vals = await valsF;
      await tx.completed;
      if (keys.length == vals.length) {
        final out = <String, Object?>{};
        for (var i = 0; i < keys.length; i++) {
          out[keys[i].toString()] = vals[i];
        }
        return out;
      }
    } catch (_) {
      // مرورگر/کتابخانه getAll نداشت → روش قدیمی
    }
    final tx = db.transaction(_storeName, idbModeReadOnly);
    final store = tx.objectStore(_storeName);
    final out = <String, Object?>{};
    await store
        .openCursor(autoAdvance: true)
        .listen((cursor) {
          out[cursor.key.toString()] = cursor.value;
        })
        .asFuture<void>();
    await tx.completed;
    return out;
  }

  static Future<void> put(String key, Object value) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadWrite);
    tx.objectStore(_storeName).put(value, key);
    await tx.completed;
  }

  static Future<void> delete(String key) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadWrite);
    tx.objectStore(_storeName).delete(key);
    await tx.completed;
  }
}
