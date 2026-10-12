import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// ذخیره‌سازی روی فایل JSON (جایگزین localStorage / IndexedDB)
class StorageService {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}maghz_map.json');
  }

  Future<String?> read() async {
    final f = await _file();
    return await f.exists() ? f.readAsString() : null;
  }

  /// نوشتن امن: اول فایل موقت، بعد جایگزینی
  Future<void> write(String data) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(f.path);
  }

  /// اگه فایل خراب بود یک کپی نگه می‌داریم تا داده از بین نره
  Future<void> keepCorruptCopy() async {
    final f = await _file();
    if (await f.exists()) {
      await f.copy('${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
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
      bytes: (Platform.isAndroid || Platform.isIOS) ? bytes : null,
    );
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
    if (f.path != null) return File(f.path!).readAsString();
    return null;
  }
}
