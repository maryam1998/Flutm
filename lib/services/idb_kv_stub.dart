/// روی پلتفرم‌های غیر وب لازم نیست (AppPrefs مستقیم از SharedPreferences استفاده می‌کند).
class IdbKv {
  static Future<Map<String, Object?>> readAll() async =>
      throw UnsupportedError('IdbKv فقط روی وب موجوده');
  static Future<void> put(String key, Object value) async =>
      throw UnsupportedError('IdbKv فقط روی وب موجوده');
  static Future<void> delete(String key) async =>
      throw UnsupportedError('IdbKv فقط روی وب موجوده');
}
