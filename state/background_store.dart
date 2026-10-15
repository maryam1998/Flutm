import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../services/media_db.dart';
import '../services/app_prefs.dart';

enum BgKind { none, image, video }

class BackgroundStore extends ChangeNotifier {
  static const _kKind = 'bg_kind';
  static const _kImgKey = 'bg_image';
  static const _kImgRefKey = 'bg_image_ref';
  static const _kVidPath = 'bg_video_path';
  static const _kBlurKey = 'bg_blur';
  static const _kOpKey = 'bg_opacity';

  BgKind _kind = BgKind.none;
  Uint8List? _imageBytes;
  String? _imageRef;
  String? _videoPath;
  double _blur = 0;
  double _opacity = 0.6;

  BgKind get kind => _kind;
  Uint8List? get imageBytes => _imageBytes;
  String? get videoPath => _videoPath;
  double get blur => _blur;
  double get opacity => _opacity;
  bool get hasBackground => _kind != BgKind.none;

  final _picker = ImagePicker();

  Future<void> load() async {
    try {
      final sp = await AppPrefs.getInstance();
      final k = sp.getString(_kKind);
      var legacyBg = false;
      if (k == 'image') {
        final ref = sp.getString(_kImgRefKey);
        final refBytes = (ref != null && ref.isNotEmpty) ? MediaDb.bytes(ref) : null;
        if (refBytes != null) {
          _imageBytes = refBytes;
          _imageRef = ref;
          _kind = BgKind.image;
        } else {
          final b64 = sp.getString(_kImgKey);
          if (b64 != null && b64.isNotEmpty) {
            _imageBytes = base64Decode(b64);
            _kind = BgKind.image;
            legacyBg = true; // فرمت قدیمی؛ در ذخیره‌ی بعدی منتقل می‌شه
          }
        }
      } else if (k == 'video') {
        final p = sp.getString(_kVidPath);
        if (p != null && p.isNotEmpty && File(p).existsSync()) {
          _videoPath = p;
          _kind = BgKind.video;
        }
      }
      _blur = sp.getDouble(_kBlurKey) ?? 0;
      _opacity = sp.getDouble(_kOpKey) ?? 0.6;
      if (legacyBg) await _persist();
    } catch (_) {}
    notifyListeners();
  }

  /// انتخاب تصویر (jpg/png/gif/webp)
  Future<bool> pickImage() async {
    try {
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (f == null) return false;
      _imageBytes = await f.readAsBytes();
      _imageRef = null;
      _videoPath = null;
      _kind = BgKind.image;
      await _persist();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('pickImage failed: $e');
      return false;
    }
  }

  /// انتخاب ویدیو از گالری (روی موبایل) یا فایل‌سیستم (روی دسکتاپ)
  Future<bool> pickVideo() async {
    try {
      final f = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      if (f == null) return false;
      // روی موبایل: کپی به مسیر دائمی اپ
      // روی وب: پشتیبانی نمی‌شه از video_player برای فایل انتخابی
      if (kIsWeb) return false;
      final path = f.path;
      _videoPath = path;
      _imageBytes = null;
      _kind = BgKind.video;
      await _persist();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('pickVideo failed: $e');
      return false;
    }
  }

  Future<void> setBlur(double v) async {
    _blur = v.clamp(0, 20);
    await _persist();
    notifyListeners();
  }

  Future<void> setOpacity(double v) async {
    _opacity = v.clamp(0.1, 1.0);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _kind = BgKind.none;
    _imageBytes = null;
    _imageRef = null;
    _videoPath = null;
    _blur = 0;
    _opacity = 0.6;
    try {
      final sp = await AppPrefs.getInstance();
      await sp.remove(_kKind);
      await sp.remove(_kImgKey);
      await sp.remove(_kImgRefKey);
      await sp.remove(_kVidPath);
      await sp.remove(_kBlurKey);
      await sp.remove(_kOpKey);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setString(_kKind, _kind.name);
      if (_imageBytes != null) {
        _imageRef ??= await MediaDb.putBytes(_imageBytes!, 'image/jpeg');
        await sp.setString(_kImgRefKey, _imageRef!);
        await sp.remove(_kImgKey);
      } else {
        await sp.remove(_kImgKey);
        await sp.remove(_kImgRefKey);
      }
      if (_videoPath != null) {
        await sp.setString(_kVidPath, _videoPath!);
      } else {
        await sp.remove(_kVidPath);
      }
      await sp.setDouble(_kBlurKey, _blur);
      await sp.setDouble(_kOpKey, _opacity);
    } catch (_) {}
  }
}
