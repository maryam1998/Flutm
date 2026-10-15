import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class MediaBlob {
  final Uint8List bytes;
  final String mime;
  final int createdAt;
  const MediaBlob(this.bytes, this.mime, this.createdAt);
}

/// اندروید/iOS/دسکتاپ: هر فایل رسانه‌ای یک فایل واقعی در پوشه‌ی اپ است
/// (`<id>.bin` + یک فایل کوچک `<id>.meta` برای نوع فایل و زمان ساخت).
class MediaBackend {
  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}media');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static String _p(Directory d, String name) =>
      '${d.path}${Platform.pathSeparator}$name';

  static Future<Map<String, MediaBlob>> loadAll() async {
    final d = await _dir();
    final out = <String, MediaBlob>{};
    await for (final e in d.list()) {
      if (e is! File || !e.path.endsWith('.bin')) continue;
      final name = e.uri.pathSegments.last;
      final id = name.substring(0, name.length - 4);
      try {
        final bytes = await e.readAsBytes();
        var mime = 'application/octet-stream';
        var t = 0;
        final meta = File(_p(d, '$id.meta'));
        if (await meta.exists()) {
          final lines = (await meta.readAsString()).split('\n');
          if (lines.isNotEmpty && lines[0].isNotEmpty) mime = lines[0];
          if (lines.length > 1) t = int.tryParse(lines[1]) ?? 0;
        }
        out[id] = MediaBlob(bytes, mime, t);
      } catch (_) {}
    }
    return out;
  }

  static Future<void> put(String id, MediaBlob b) async {
    final d = await _dir();
    final bin = File(_p(d, '$id.bin'));
    final tmp = File(_p(d, '$id.bin.tmp'));
    await tmp.writeAsBytes(b.bytes, flush: true);
    await tmp.rename(bin.path);
    await File(_p(d, '$id.meta'))
        .writeAsString('${b.mime}\n${b.createdAt}', flush: true);
  }

  static Future<void> delete(String id) async {
    final d = await _dir();
    for (final n in ['$id.bin', '$id.meta']) {
      final f = File(_p(d, n));
      if (await f.exists()) await f.delete();
    }
  }
}
