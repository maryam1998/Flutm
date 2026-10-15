import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import '../services/app_prefs.dart';

import '../services/angel_blob_store.dart';
import '../services/media_db.dart';

/// یک عکس — bytes جدا در MediaDb ذخیره می‌شه و در JSON فقط ارجاعش (ref) می‌مونه
class AngelImage {
  final String id;
  final Uint8List bytes;
  String? ref;
  AngelImage({required this.id, required this.bytes, this.ref});
}

/// یک ویدیو — bytes در IndexedDB، فقط metadata اینجا
class AngelVideo {
  final String id;
  final String name;
  final String mime;
  final int size;
  AngelVideo({
    required this.id,
    required this.name,
    required this.mime,
    required this.size,
  });
}

/// تنظیمات و لیست موارد شناور (عکس + ویدیو).
class AngelsStore extends ChangeNotifier {
  static const _kOn = 'angels_on';
  static const _kSize = 'angels_size';
  static const _kSpeed = 'angels_speed';
  static const _kOpacity = 'angels_opacity';
  static const _kSoft = 'angels_soft';
  static const _kBlend = 'angels_blend';
  static const _kFs = 'angels_fs';
  static const _kImages = 'angels_images_v1';
  static const _kVideos = 'angels_videos_v1';

  static const int maxImageBytes = 10 * 1024 * 1024;    // ۱۰ مگ
  static const int maxVideoBytes = 300 * 1024 * 1024;   // ۳۰۰ مگ

  bool _on = false;
  double _size = 140;
  double _speed = 3;
  double _opacity = 0.85;
  bool _soft = true;
  String _blend = 'normal';
  bool _fs = true;
  final List<AngelImage> _images = [];
  final List<AngelVideo> _videos = [];

  bool get on => _on;
  double get size => _size;
  double get speed => _speed;
  double get opacity => _opacity;
  bool get soft => _soft;
  String get blend => _blend;
  bool get fs => _fs;
  List<AngelImage> get images => List.unmodifiable(_images);
  List<AngelVideo> get videos => List.unmodifiable(_videos);
  bool get hasAssets => _images.isNotEmpty || _videos.isNotEmpty;
  int get count => _images.length + _videos.length;

  Future<void> load() async {
    var legacyImages = false;
    try {
      await AngelBlobStore.init();

      final sp = await AppPrefs.getInstance();
      _on = sp.getBool(_kOn) ?? false;
      _size = (sp.getDouble(_kSize) ?? 140).clamp(60, 320);
      _speed = (sp.getDouble(_kSpeed) ?? 3).clamp(1, 12);
      _opacity = (sp.getDouble(_kOpacity) ?? 0.85).clamp(0.2, 1.0);
      _soft = sp.getBool(_kSoft) ?? true;
      _blend = sp.getString(_kBlend) ?? 'normal';
      _fs = sp.getBool(_kFs) ?? true;

      // images
      final rawImgs = sp.getString(_kImages);
      if (rawImgs != null && rawImgs.isNotEmpty) {
        try {
          final list = jsonDecode(rawImgs);
          if (list is List) {
            _images.clear();
            for (final e in list) {
              if (e is Map) {
                final id = e['id'] as String? ?? '';
                final ref = e['ref'] as String? ?? '';
                final b64 = e['b64'] as String? ?? '';
                if (id.isEmpty) continue;
                if (ref.isNotEmpty) {
                  final b = MediaDb.bytes(ref);
                  if (b != null) {
                    _images.add(AngelImage(id: id, bytes: b, ref: ref));
                  }
                } else if (b64.isNotEmpty) {
                  // فرمت قدیمی: base64 داخل JSON؛ در ذخیره‌ی بعدی منتقل می‌شه
                  try {
                    legacyImages = true;
                    _images.add(
                        AngelImage(id: id, bytes: base64Decode(b64)));
                  } catch (_) {}
                }
              }
            }
          }
        } catch (_) {}
      }

      // videos (metadata)
      final rawVids = sp.getString(_kVideos);
      if (rawVids != null && rawVids.isNotEmpty) {
        try {
          final list = jsonDecode(rawVids);
          if (list is List) {
            _videos.clear();
            for (final e in list) {
              if (e is Map) {
                final id = e['id'] as String? ?? '';
                if (id.isEmpty) continue;
                _videos.add(AngelVideo(
                  id: id,
                  name: e['name'] as String? ?? 'video',
                  mime: e['mime'] as String? ?? 'video/mp4',
                  size: (e['size'] as num?)?.toInt() ?? 0,
                ));
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    if (legacyImages) await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setBool(_kOn, _on);
      await sp.setDouble(_kSize, _size);
      await sp.setDouble(_kSpeed, _speed);
      await sp.setDouble(_kOpacity, _opacity);
      await sp.setBool(_kSoft, _soft);
      await sp.setString(_kBlend, _blend);
      await sp.setBool(_kFs, _fs);

      for (final im in _images) {
        im.ref ??= await MediaDb.putBytes(im.bytes, 'image/jpeg');
      }
      final imgsJson =
          _images.map((im) => {'id': im.id, 'ref': im.ref}).toList();
      await sp.setString(_kImages, jsonEncode(imgsJson));

      final vidsJson = _videos
          .map((v) => {
                'id': v.id,
                'name': v.name,
                'mime': v.mime,
                'size': v.size,
              })
          .toList();
      await sp.setString(_kVideos, jsonEncode(vidsJson));
    } catch (_) {}
  }

  // ─────── تنظیمات ───────

  Future<void> setOn(bool v) async {
    _on = v;
    await _persist();
    notifyListeners();
  }

  Future<void> setSize(double v) async {
    _size = v.clamp(60, 320);
    await _persist();
    notifyListeners();
  }

  Future<void> setSpeed(double v) async {
    _speed = v.clamp(1, 12);
    await _persist();
    notifyListeners();
  }

  Future<void> setOpacity(double v) async {
    _opacity = v.clamp(0.2, 1.0);
    await _persist();
    notifyListeners();
  }

  Future<void> setSoft(bool v) async {
    _soft = v;
    await _persist();
    notifyListeners();
  }

  Future<void> setBlend(String v) async {
    _blend = (v == 'screen' || v == 'multiply') ? v : 'normal';
    await _persist();
    notifyListeners();
  }

  Future<void> setFs(bool v) async {
    _fs = v;
    await _persist();
    notifyListeners();
  }

  // ─────── افزودن / حذف ───────

  Future<bool> addImage(Uint8List bytes) async {
    if (bytes.isEmpty) return false;
    if (bytes.length > maxImageBytes) return false;
    final id = 'ai${DateTime.now().millisecondsSinceEpoch}';
    _images.add(AngelImage(id: id, bytes: bytes));
    await _persist();
    notifyListeners();
    return true;
  }

  /// افزودن ویدیو — bytes در IndexedDB ذخیره می‌شه.
  /// اگر از ۳۰۰ مگ بزرگ‌تر یا ذخیره ناموفق بود، false برمی‌گردونه.
  Future<bool> addVideo({
    required String name,
    required String mime,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) return false;
    if (bytes.length > maxVideoBytes) return false;
    final id = 'av${DateTime.now().millisecondsSinceEpoch}';
    try {
      await AngelBlobStore.put(id, bytes, mime);
    } catch (_) {
      return false;
    }
    _videos.add(AngelVideo(
      id: id,
      name: name,
      mime: mime,
      size: bytes.length,
    ));
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> removeImage(String id) async {
    _images.removeWhere((im) => im.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> removeVideo(String id) async {
    _videos.removeWhere((v) => v.id == id);
    try {
      await AngelBlobStore.delete(id);
    } catch (_) {}
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _images.clear();
    for (final v in _videos) {
      try {
        await AngelBlobStore.delete(v.id);
      } catch (_) {}
    }
    _videos.clear();
    await _persist();
    notifyListeners();
  }

  /// بارگذاری bytes یک ویدیو + ساخت blob URL
  Future<AngelBlob?> loadVideoBlob(String id) async {
    try {
      return await AngelBlobStore.get(id);
    } catch (_) {
      return null;
    }
  }

  Future<String?> videoBlobUrl(Uint8List bytes, String mime) =>
      AngelBlobStore.createBlobUrl(bytes, mime);

  Future<void> revokeBlobUrl(String url) =>
      AngelBlobStore.revokeBlobUrl(url);
}
