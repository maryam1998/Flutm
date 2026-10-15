import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// کلیدهای ذخیره‌سازی
const String kMapKey         = 'maghz_map_json';       // نقشه (سازگاری با گذشته)
const String kYsqProfileKey  = 'ysq_profile_v2';       // نتیجه YSQ
const String kYsqProgressKey = 'ysq_progress_v3';      // entries چرخه‌ها
const String kYsqCheckinKey  = 'ysq_checkins_v1';      // چک‌این روزانه

/// ذخیره‌سازی عمومی (فایل JSON روی موبایل/دسکتاپ — SharedPreferences روی وب)
class StorageService {
  // ──────────── سازگاری با گذشته: API بدون کلید برای نقشه ────────────
  Future<String?> read() => readKey(kMapKey);
  Future<void> write(String data) => writeKey(kMapKey, data);

  // ──────────── API عمومی کلیددار ────────────
  Future<String?> readKey(String key) async {
    if (kIsWeb) return (await SharedPreferences.getInstance()).getString(key);
    final f = await _fileFor(key);
    return await f.exists() ? f.readAsString() : null;
  }

  Future<void> writeKey(String key, String data) async {
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).setString(key, data);
      return;
    }
    final f = await _fileFor(key);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(f.path);
  }

  Future<void> removeKey(String key) async {
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).remove(key);
      return;
    }
    final f = await _fileFor(key);
    if (await f.exists()) await f.delete();
  }

  // ──────────── کپی خراب ────────────
  Future<void> keepCorruptCopy() async {
    try {
      if (kIsWeb) {
        final p = await SharedPreferences.getInstance();
        final raw = p.getString(kMapKey);
        if (raw != null) {
          await p.setString(
            '$kMapKey.corrupt-${DateTime.now().millisecondsSinceEpoch}',
            raw,
          );
        }
        return;
      }
      final f = await _fileFor(kMapKey);
      if (await f.exists()) {
        await f.copy(
          '${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (_) {
      // نگه‌داشتن کپی خراب نباید جلوی بالا اومدن برنامه رو بگیره
    }
  }

  // ──────────── بکاپ ────────────
  Future<bool> exportBackup(String json) async {
    final bytes = utf8.encode(json);
    final name =
        'maghz-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'ذخیره‌ی بکاپ',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: (kIsWeb || Platform.isAndroid || Platform.isIOS) ? bytes : null,
    );
    if (kIsWeb) return true;
    if (path == null) return false;
    if (!(Platform.isAndroid || Platform.isIOS)) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  }

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

  // ──────────── کمکی: مسیر فایل بر اساس کلید ────────────
  Future<File> _fileFor(String key) async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    // سازگاری: نقشه در فایل قدیمی maghz_map.json ذخیره می‌شد
    final fileName = key == kMapKey
        ? 'maghz_map.json'
        : '${key.replaceAll(RegExp(r'[^\w\-]'), '_')}.json';
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }
}
