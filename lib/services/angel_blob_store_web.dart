import 'dart:js_interop';
import 'dart:typed_data';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:web/web.dart' as web;

class AngelBlob {
  final Uint8List bytes;
  final String mime;
  const AngelBlob(this.bytes, this.mime);
}

/// ذخیره‌سازی blob های سنگین (ویدیو) در IndexedDB روی وب.
class AngelBlobStore {
  static const _dbName = 'angels_media_v1';
  static const _storeName = 'media';
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

  static Future<void> init() async {
    try {
      await _open();
    } catch (_) {}
  }

  static Future<void> put(String id, Uint8List bytes, String mime) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadWrite);
    tx.objectStore(_storeName).put({
      'bytes': bytes,
      'mime': mime,
    }, id);
    await tx.completed;
  }

  static Future<AngelBlob?> get(String id) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadOnly);
    final obj = await tx.objectStore(_storeName).getObject(id);
    await tx.completed;
    if (obj is Map) {
      final bytes = obj['bytes'];
      final mime = obj['mime'];
      if (bytes is Uint8List && mime is String) {
        return AngelBlob(bytes, mime);
      }
    }
    return null;
  }

  static Future<void> delete(String id) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadWrite);
    tx.objectStore(_storeName).delete(id);
    await tx.completed;
  }

  static Future<List<String>> keys() async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadOnly);
    final keys = await tx.objectStore(_storeName).getAllKeys();
    await tx.completed;
    return keys.map((k) => k.toString()).toList();
  }

  /// ساخت blob URL برای پخش ویدیو توسط `VideoPlayerController`.
  static Future<String?> createBlobUrl(Uint8List bytes, String mime) async {
    try {
      final jsBytes = bytes.toJS;
      final parts = <JSAny>[jsBytes].toJS;
      final blob = web.Blob(parts, web.BlobPropertyBag(type: mime));
      return web.URL.createObjectURL(blob);
    } catch (_) {
      return null;
    }
  }

  static Future<void> revokeBlobUrl(String url) async {
    try {
      web.URL.revokeObjectURL(url);
    } catch (_) {}
  }
}
