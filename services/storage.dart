import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'app_prefs.dart';
import 'media_db.dart';

/// کلید ذخیره در مرورگر (نسخه‌ی وب؛ dart:io و path_provider روی وب کار نمی‌کنن)
const _webKey = 'maghz_map_json';

/// ذخیره‌سازی روی فایل JSON (جایگزین localStorage / IndexedDB)
class StorageService {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}maghz_map.json');
  }

  Future<String?> read() async {
    await MediaDb.init();
    String? raw;
    if (kIsWeb) {
      raw = (await AppPrefs.getInstance()).getString(_webKey);
    } else {
      final f = await _file();
      raw = await f.exists() ? await f.readAsString() : null;
    }
    // مهاجرت: عکس‌های داخل JSON نقشه → فایل جدا
    if (raw != null && raw.contains(';base64,')) {
      final out = await MediaDb.externalizeJson(raw);
      if (out != raw) {
        await write(out);
        raw = out;
      }
    }
    return raw;
  }

  /// نوشتن امن: اول فایل موقت، بعد جایگزینی
  Future<void> write(String data) async {
    if (kIsWeb) {
      await (await AppPrefs.getInstance()).setString(_webKey, data);
      return;
    }
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(f.path);
  }

  /// اگه فایل خراب بود یک کپی نگه می‌داریم تا داده از بین نره
  Future<void> keepCorruptCopy() async {
    try {
      if (kIsWeb) {
        final p = await AppPrefs.getInstance();
        final raw = p.getString(_webKey);
        if (raw != null) await p.setString('$_webKey.corrupt-${DateTime.now().millisecondsSinceEpoch}', raw);
        return;
      }
      final f = await _file();
      if (await f.exists()) {
        await f.copy('${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      }
    } catch (_) {
      // نگه‌داشتن کپی خراب نباید جلوی بالا اومدن برنامه رو بگیره
    }
  }

  /// خروجی بکاپ؛ true یعنی ذخیره شد
  Future<bool> exportBackup(String json) async {
    final bytes = utf8.encode(json);
    final name = 'maghz-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'ذخیره‌ی بکاپ',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: (kIsWeb || Platform.isAndroid || Platform.isIOS) ? bytes : null,
    );
    if (kIsWeb) return true; // روی وب مرورگر خودش فایل رو دانلود می‌کنه
    if (path == null) return false;
    if (!(Platform.isAndroid || Platform.isIOS)) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  }

  /// ورودی بکاپ؛ متن فایل یا null اگه کاربر انصراف داد
  Future<String?> pickBackup() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.first;
    if (f.bytes != null) return utf8.decode(f.bytes!);
    if (!kIsWeb && f.path != null) return File(f.path!).readAsString();
    return null;
  }
}
