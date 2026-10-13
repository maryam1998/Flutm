import 'dart:typed_data';

class AngelBlob {
  final Uint8List bytes;
  final String mime;
  const AngelBlob(this.bytes, this.mime);
}

/// روی پلتفرم‌هایی که هنوز پشتیبانی نمی‌شن، فقط stub برمی‌گردونه.
class AngelBlobStore {
  static Future<void> init() async {}
  static Future<void> put(String id, Uint8List bytes, String mime) async {
    throw UnsupportedError('AngelBlobStore not available on this platform');
  }
  static Future<AngelBlob?> get(String id) async => null;
  static Future<void> delete(String id) async {}
  static Future<List<String>> keys() async => [];
  static Future<String?> createBlobUrl(Uint8List bytes, String mime) async =>
      null;
  static Future<void> revokeBlobUrl(String url) async {}
}
