/// روی پلتفرم‌هایی که IndexedDB ندارن (اندروید/iOS/دسکتاپ) فعلاً استفاده نمی‌شه.
class IdbKv {
  static const bool supported = false;

  static Future<Map<String, Object?>> loadAll() async => <String, Object?>{};
  static Future<void> put(String key, Object value) async {}
  static Future<void> delete(String key) async {}
  static Future<void> requestPersistent() async {}
}
