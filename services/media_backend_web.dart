import 'dart:typed_data';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';

class MediaBlob {
  final Uint8List bytes;
  final String mime;
  final int createdAt;
  const MediaBlob(this.bytes, this.mime, this.createdAt);
}

/// ذخیره‌ی فایل‌های رسانه‌ای (عکس/صدا/ویدیو) در IndexedDB، جدا از JSON.
class MediaBackend {
  static const _dbName = 'maghz_media_v1';
  static const _storeName = 'blobs';
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

  static Uint8List? _asBytes(Object? b) {
    if (b is Uint8List) return b;
    if (b is List) return Uint8List.fromList(b.cast<int>());
    return null;
  }

  static Future<Map<String, MediaBlob>> loadAll() async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadOnly);
    final store = tx.objectStore(_storeName);
    final keys = await store.getAllKeys();
    final out = <String, MediaBlob>{};
    for (final k in keys) {
      final obj = await store.getObject(k);
      if (obj is Map) {
        final bytes = _asBytes(obj['bytes']);
        final mime = obj['mime'];
        final t = obj['t'];
        if (bytes != null && mime is String) {
          out[k.toString()] =
              MediaBlob(bytes, mime, t is num ? t.toInt() : 0);
        }
      }
    }
    await tx.completed;
    return out;
  }

  static Future<void> put(String id, MediaBlob b) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadWrite);
    await tx.objectStore(_storeName).put({
      'bytes': b.bytes,
      'mime': b.mime,
      't': b.createdAt,
    }, id);
    await tx.completed;
  }

  static Future<void> delete(String id) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadWrite);
    await tx.objectStore(_storeName).delete(id);
    await tx.completed;
  }
}
