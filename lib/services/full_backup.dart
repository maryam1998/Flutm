import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'angel_blob_store.dart';
import 'app_prefs.dart';
import 'media_blob.dart';
import 'storage.dart';

/// کلید زمان آخرین بکاپِ موفق (داخل خود بکاپ نمی‌رود)
const String kBackupLastKey = 'backup_last_at_v1';

/// خلاصه‌ی یک فایل بکاپ (برای پیش‌نمایش قبل از بازیابی)
class BackupInfo {
  const BackupInfo({
    required this.createdAt,
    required this.items,
    required this.mediaFiles,
    required this.includesMedia,
    required this.bytes,
  });
  final DateTime? createdAt;
  final int items;
  final int mediaFiles;
  final bool includesMedia;
  final int bytes;
}

class BackupReport {
  const BackupReport({
    required this.prefs,
    required this.files,
    required this.videos,
  });
  final int prefs;
  final int files;
  final int videos;
}

/// بکاپ کامل: همه‌ی داده‌ی همه‌ی تب‌ها در یک فایل JSON
/// (نقشه/اهداف، تمرین‌ها و سپاسگزاری با عکس و ویدیو و صدا، باورها، شناخت،
/// فراوانی، فرشته‌ها، پس‌زمینه، تنظیمات و ...).
class FullBackup {
  static const _kind = 'maghz-full-backup';
  static const _bgVideoKey = 'bg_video_path';
  static const _storageKeys = {
    kMapKey,
    kYsqProfileKey,
    kYsqProgressKey,
    kYsqCheckinKey,
  };

  /// ساخت متن JSON بکاپ
  static Future<String> build({bool includeMedia = true}) async {
    final sp = await AppPrefs.getInstance();
    final storage = StorageService();

    // ۱) همه‌ی کلیدهای تنظیمات/داده (نوع هر مقدار هم ذخیره می‌شه)
    final prefs = <String, Object>{};
    sp.exportAll().forEach((k, v) {
      if (k.contains('.corrupt-') || k == kBackupLastKey) return;
      if (v is bool) {
        prefs[k] = ['b', v];
      } else if (v is int) {
        prefs[k] = ['i', v];
      } else if (v is double) {
        prefs[k] = ['d', v];
      } else if (v is String) {
        prefs[k] = ['s', v];
      } else if (v is List) {
        prefs[k] = ['l', v.map((e) => e.toString()).toList()];
      }
    });

    // ۲) فایل‌های ذخیره‌ی موبایل (نقشه، شناخت)
    final files = await storage.readAllFiles();

    // ۳) ویدیوهای سنگین فرشته‌ها (IndexedDB وب)
    final blobs = <String, Object>{};
    try {
      if (includeMedia) {
        for (final id in await AngelBlobStore.keys()) {
          final b = await AngelBlobStore.get(id);
          if (b != null) {
            blobs[id] = {'mime': b.mime, 'b64': base64Encode(b.bytes)};
          }
        }
      }
    } catch (_) {}

    // ۴) ویدیوی پس‌زمینه (روی موبایل فقط مسیر فایل ذخیره شده)
    Map<String, Object>? bgVideo;
    if (!kIsWeb && includeMedia) {
      try {
        final p = sp.getString(_bgVideoKey);
        if (p != null && p.isNotEmpty && File(p).existsSync()) {
          final dot = p.lastIndexOf('.');
          bgVideo = {
            'ext': dot >= 0 ? p.substring(dot + 1) : 'mp4',
            'b64': base64Encode(await File(p).readAsBytes()),
          };
        }
      } catch (_) {}
    }

    // ۵) ویدیوهای ذخیره‌شده‌ی بیرونی (موبایل: فایل‌ها؛ وب: همراه بلاب‌ها بالا آمد)
    final mediaFiles = includeMedia
        ? await MediaBlob.exportNativeFilesB64(base64Encode)
        : <String, String>{};

    return jsonEncode({
      'kind': _kind,
      'version': 1,
      'includesMedia': includeMedia,
      'createdAt': DateTime.now().toIso8601String(),
      'prefs': prefs,
      'files': files,
      'angelBlobs': blobs,
      if (bgVideo != null) 'bgVideo': bgVideo,
      if (mediaFiles.isNotEmpty) 'mediaFiles': mediaFiles,
    });
  }

  /// ثبت زمان آخرین بکاپِ موفق
  static Future<void> markBackedUp() async {
    final sp = await AppPrefs.getInstance();
    await sp.setInt(kBackupLastKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<DateTime?> lastBackupAt() async {
    final sp = await AppPrefs.getInstance();
    final ms = sp.getInt(kBackupLastKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// بررسی و خلاصه‌ی فایل بکاپ بدون اعمال آن (FormatException اگر بکاپ نباشد)
  static BackupInfo describe(String raw) {
    final d = jsonDecode(raw);
    if (d is! Map || d['kind'] != _kind) {
      throw const FormatException('این فایل، «بکاپ کامل» برنامه نیست');
    }
    final prefs = d['prefs'];
    final files = d['files'];
    final blobs = d['angelBlobs'];
    final mf = d['mediaFiles'];
    final media = (blobs is Map ? blobs.length : 0) +
        (mf is Map ? mf.length : 0) +
        (d['bgVideo'] is Map ? 1 : 0);
    return BackupInfo(
      createdAt: DateTime.tryParse('${d['createdAt']}'),
      items: (prefs is Map ? prefs.length : 0) +
          (files is Map ? files.length : 0),
      mediaFiles: media,
      includesMedia: d['includesMedia'] != false,
      bytes: raw.length,
    );
  }

  /// بازیابی از متن بکاپ. بعدش باید برنامه بسته و دوباره باز بشه.
  static Future<BackupReport> restore(String raw) async {
    final d = jsonDecode(raw);
    if (d is! Map || d['kind'] != _kind) {
      throw const FormatException('این فایل، «بکاپ کامل» برنامه نیست');
    }
    final sp = await AppPrefs.getInstance();
    final storage = StorageService();
    var nPrefs = 0, nFiles = 0, nVideos = 0;

    // ویدیوی پس‌زمینه → کپی در پوشه‌ی برنامه
    String? newBgPath;
    final bg = d['bgVideo'];
    if (!kIsWeb && bg is Map && bg['b64'] is String) {
      try {
        final dir = await getApplicationSupportDirectory();
        await dir.create(recursive: true);
        final ext = (bg['ext'] as String?) ?? 'mp4';
        final f = File('${dir.path}/bg_video.$ext');
        await f.writeAsBytes(base64Decode(bg['b64'] as String), flush: true);
        newBgPath = f.path;
        nVideos++;
      } catch (_) {}
    }

    // فایل‌های ذخیره (نقشه/شناخت)
    final files = d['files'];
    if (files is Map) {
      for (final e in files.entries) {
        if (e.value is String) {
          await storage.writeKey(e.key as String, e.value as String);
          nFiles++;
        }
      }
    }

    // کلیدها
    final prefs = d['prefs'];
    if (prefs is Map) {
      for (final e in prefs.entries) {
        final k = e.key as String;
        final t = e.value;
        if (t is! List || t.length != 2) continue;
        final type = t[0], v = t[1];
        if (k == _bgVideoKey) {
          if (newBgPath != null) {
            await sp.setString(k, newBgPath);
          } else if (v is String && MediaBlob.isRef(v)) {
            await sp.setString(k, v);
          }
          continue;
        }
        // نقشه/شناخت روی موبایل از فایل خونده می‌شن، نه AppPrefs
        if (!kIsWeb && _storageKeys.contains(k) && v is String) {
          await storage.writeKey(k, v);
          nFiles++;
          continue;
        }
        switch (type) {
          case 'b':
            if (v is bool) await sp.setBool(k, v);
          case 'i':
            if (v is num) await sp.setInt(k, v.toInt());
          case 'd':
            if (v is num) await sp.setDouble(k, v.toDouble());
          case 's':
            if (v is String) await sp.setString(k, v);
          case 'l':
            if (v is List) {
              await sp.setStringList(k, v.map((e) => e.toString()).toList());
            }
          default:
            continue;
        }
        nPrefs++;
      }
    }

    // ویدیوهای فرشته‌ها (وب)
    final blobs = d['angelBlobs'];
    if (blobs is Map) {
      for (final e in blobs.entries) {
        final m = e.value;
        if (m is Map && m['b64'] is String) {
          try {
            await AngelBlobStore.put(
              e.key as String,
              Uint8List.fromList(base64Decode(m['b64'] as String)),
              (m['mime'] as String?) ?? 'video/mp4',
            );
            nVideos++;
          } catch (_) {}
        }
      }
    }

    // ویدیوهای بیرونی موبایل
    final mf = d['mediaFiles'];
    if (mf is Map) {
      for (final e in mf.entries) {
        if (e.value is String) {
          try {
            await MediaBlob.importNativeFile(
                e.key as String, base64Decode(e.value as String));
            nVideos++;
          } catch (_) {}
        }
      }
    }

    return BackupReport(prefs: nPrefs, files: nFiles, videos: nVideos);
  }
}
