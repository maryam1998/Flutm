import 'dart:io' show Directory, File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';

import 'angel_blob_store.dart';

/// ذخیره‌ی ویدیوهای سنگین **بیرون از JSON**.
///
/// قبلاً ویدیو به base64 تبدیل می‌شد (۳۳٪ بزرگ‌تر)، داخل یک رشته‌ی عظیم JSON می‌رفت و
/// با هر تغییر کوچک (حتی افزودن یک عکس) کل اون رشته دوباره نوشته می‌شد؛ برای همین
/// آپلود ویدیو و بعدش همه‌چیز کند می‌شد.
///
/// حالا:
///  • وب: بایت‌ها در IndexedDB (همون دیتابیس بلاب فرشته‌ها) و در JSON فقط یک مرجع کوتاه
///    مثل `mblob:mb123.mp4` ذخیره می‌شه.
///  • موبایل/دسکتاپ: فایل مستقیم (بدون خوندن کل ویدیو در RAM) در پوشه‌ی برنامه کپی می‌شه.
class MediaBlob {
  static const String scheme = 'mblob:';
  static const String _prefix = 'mb';

  static bool isRef(String? s) => s != null && s.startsWith(scheme);

  static String idOf(String ref) => ref.substring(scheme.length);

  static final Map<String, String> _urlCache = <String, String>{};

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/media');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static String _extOf(String name, {String fallback = 'mp4'}) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return fallback;
    final e = name.substring(i + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(e) ? e : fallback;
  }

  static String _newId(String name) =>
      '$_prefix${DateTime.now().microsecondsSinceEpoch}.${_extOf(name)}';

  /// ذخیره‌ی فایل انتخاب‌شده؛ مرجع (`mblob:...`) برمی‌گردونه.
  static Future<String> saveXFile(XFile f, {required String mime}) async {
    final id = _newId(f.name);
    if (kIsWeb) {
      final bytes = await f.readAsBytes();
      await AngelBlobStore.put(id, bytes, mime);
    } else {
      final d = await _dir();
      await f.saveTo('${d.path}/$id');
    }
    return '$scheme$id';
  }

  static Future<String> saveBytes(Uint8List bytes,
      {required String name, required String mime}) async {
    final id = _newId(name);
    if (kIsWeb) {
      await AngelBlobStore.put(id, bytes, mime);
    } else {
      final d = await _dir();
      await File('${d.path}/$id').writeAsBytes(bytes, flush: true);
    }
    return '$scheme$id';
  }

  /// آدرس قابل پخش: روی وب blob-URL، روی موبایل مسیر فایل. null = پیدا نشد.
  static Future<String?> playableSource(String ref) async {
    final id = idOf(ref);
    if (kIsWeb) {
      final hit = _urlCache[id];
      if (hit != null) return hit;
      final b = await AngelBlobStore.get(id);
      if (b == null) return null;
      final url = await AngelBlobStore.createBlobUrl(b.bytes, b.mime);
      if (url != null) _urlCache[id] = url;
      return url;
    }
    final d = await _dir();
    final f = File('${d.path}/$id');
    return await f.exists() ? f.path : null;
  }

  /// خواندن کامل بایت‌های یک مرجع (برای عکس‌های متحرک مثل GIF/WebP). null = پیدا نشد.
  static Future<Uint8List?> readBytes(String ref) async {
    if (!isRef(ref)) return null;
    final id = idOf(ref);
    try {
      if (kIsWeb) {
        final b = await AngelBlobStore.get(id);
        return b?.bytes;
      }
      final d = await _dir();
      final f = File('${d.path}/$id');
      return await f.exists() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String ref) async {
    if (!isRef(ref)) return;
    final id = idOf(ref);
    try {
      if (kIsWeb) {
        final u = _urlCache.remove(id);
        if (u != null) await AngelBlobStore.revokeBlobUrl(u);
        await AngelBlobStore.delete(id);
      } else {
        final d = await _dir();
        final f = File('${d.path}/$id');
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }

  // ─────────── برای بکاپ (فقط موبایل؛ روی وب همراه بلاب فرشته‌هاست) ───────────

  static Future<Map<String, String>> exportNativeFilesB64(
      String Function(Uint8List) enc) async {
    final out = <String, String>{};
    if (kIsWeb) return out;
    try {
      final d = await _dir();
      await for (final e in d.list()) {
        if (e is File) {
          final name = e.path.split(RegExp(r'[\\/]')).last;
          out[name] = enc(await e.readAsBytes());
        }
      }
    } catch (_) {}
    return out;
  }

  static Future<void> importNativeFile(String name, Uint8List bytes) async {
    if (kIsWeb) return;
    final safe = name.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final d = await _dir();
    await File('${d.path}/$safe').writeAsBytes(bytes, flush: true);
  }
}
