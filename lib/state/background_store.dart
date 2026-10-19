import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext, MediaQuery;
import 'package:image_picker/image_picker.dart' show XFile;

import '../services/app_prefs.dart';
import '../services/media_blob.dart';
import '../widgets/photo_cropper.dart';

enum BgKind { none, image, video }

/// پس‌زمینه‌ی برنامه — دقیقاً مثل وب (`js/background-picker.js`):
///  • دو حالت: «ساده (Calm)» و «پس‌زمینه دلخواه»
///  • تصویر (jpg/png/gif، با برش به نسبت صفحه‌نمایش، کمتر از ۴MB)
///    یا ویدیو (mp4/webm/mov/m4v، بی‌صدا، کمتر از ۶۰MB)
///  • محو بودن (Blur) ۰ تا ۲۰ و شفافیت ۱۰ تا ۱۰۰ (پیش‌فرض ۵۰)
class BackgroundStore extends ChangeNotifier {
  static const _kMode = 'bg_mode';
  static const _kKind = 'bg_kind';
  static const _kImgKey = 'bg_image';
  static const _kVidPath = 'bg_video_path';
  static const _kBlurKey = 'bg_blur';
  static const _kOpKey = 'bg_opacity';

  static const int maxImageBytes = 4 * 1024 * 1024;
  static const int maxVideoBytes = 60 * 1024 * 1024;
  static const _imgExts = ['jpg', 'jpeg', 'png', 'gif'];
  static const _vidExts = ['mp4', 'webm', 'mov', 'm4v'];

  bool _custom = false; // false = calm
  BgKind _kind = BgKind.none;
  Uint8List? _imageBytes;
  String? _videoPath; // مرجع mblob:... یا (قدیمی) مسیر فایل
  double _blur = 0;
  double _opacity = 0.5;

  bool get custom => _custom;
  BgKind get kind => _kind;
  Uint8List? get imageBytes => _imageBytes;
  String? get videoPath => _videoPath;
  double get blur => _blur;
  double get opacity => _opacity;
  bool get hasBackground => _kind != BgKind.none;

  /// تصویر/ویدیو واقعاً دیده می‌شود (تب‌ها باید شفاف شوند)
  bool get active => _custom && hasBackground;
  bool get overridesBackdrop => active;

  Future<void> load() async {
    try {
      final sp = await AppPrefs.getInstance();
      final k = sp.getString(_kKind);
      if (k == 'image') {
        final b64 = sp.getString(_kImgKey);
        if (b64 != null && b64.isNotEmpty) {
          _imageBytes = base64Decode(b64);
          _kind = BgKind.image;
        }
      } else if (k == 'video') {
        final p = sp.getString(_kVidPath);
        if (p != null && p.isNotEmpty) {
          _videoPath = p;
          _kind = BgKind.video;
        }
      }
      _blur = (sp.getDouble(_kBlurKey) ?? 0).clamp(0, 20).toDouble();
      _opacity = (sp.getDouble(_kOpKey) ?? 0.5).clamp(0.1, 1.0).toDouble();
      final m = sp.getString(_kMode);
      // کاربرهای قبلی که تصویر گذاشته بودند، حالت «دلخواه» می‌مونن
      _custom = m == null ? hasBackground : m == 'image';
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setCustom(bool v) async {
    _custom = v;
    await _put((sp) => sp.setString(_kMode, v ? 'image' : 'calm'));
    notifyListeners();
  }

  /// انتخاب تصویر یا ویدیو (یک انتخابگر برای هر دو، مثل وب).
  /// برمی‌گرداند: null = موفق یا انصراف ، وگرنه پیام خطا (فارسی).
  Future<String?> pickAndSet(BuildContext context) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [..._imgExts, ..._vidExts],
        withData: kIsWeb,
      );
      if (res == null || res.files.isEmpty) return null;
      final f = res.files.first;
      final dot = f.name.lastIndexOf('.');
      final ext = dot < 0 ? '' : f.name.substring(dot + 1).toLowerCase();

      if (_vidExts.contains(ext)) {
        if (f.size > maxVideoBytes) {
          return 'حجم ویدیو باید کمتر از ۶۰ مگابایت باشد';
        }
        final XFile x;
        if (kIsWeb) {
          if (f.bytes == null) return 'ذخیره ویدیو ممکن نشد';
          x = XFile.fromData(f.bytes!, name: f.name);
        } else {
          if (f.path == null) return 'ذخیره ویدیو ممکن نشد';
          x = XFile(f.path!, name: f.name);
        }
        final mime = ext == 'webm'
            ? 'video/webm'
            : (ext == 'mov' ? 'video/quicktime' : 'video/mp4');
        final ref = await MediaBlob.saveXFile(x, mime: mime);
        await _dropOldVideo();
        _videoPath = ref;
        _imageBytes = null;
        _kind = BgKind.video;
        _custom = true;
        await _persist();
        notifyListeners();
        return null;
      }

      if (!_imgExts.contains(ext)) {
        return 'فقط عکس (jpg، png، gif) یا ویدیو (mp4، webm، mov) مجاز است';
      }
      Uint8List? bytes = f.bytes;
      if (bytes == null && !kIsWeb && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) return 'تصویر خوانده نشد';

      // برش به نسبت صفحه‌نمایش (مثل cropImage(file,{screen:true}) در وب)
      var mime = ext == 'png'
          ? 'image/png'
          : (ext == 'gif' ? 'image/gif' : 'image/jpeg');
      if (context.mounted) {
        final sz = MediaQuery.sizeOf(context);
        final c = await showPhotoCropper(
          context,
          bytes,
          mime: mime,
          initialRatio: sz.height <= 0 ? null : sz.width / sz.height,
          maxSide: 1600,
        );
        if (c == null) return null; // انصراف
        bytes = c.bytes;
        mime = c.mime;
      }
      if (bytes.length > maxImageBytes) {
        return 'حجم تصویر باید کمتر از ۴ مگابایت باشد';
      }
      await _dropOldVideo();
      _imageBytes = bytes;
      _videoPath = null;
      _kind = BgKind.image;
      _custom = true;
      await _persist();
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('background pick failed: $e');
      return 'ذخیره پس‌زمینه ممکن نشد (فضای گوشی یا حجم زیاد است)';
    }
  }

  Future<void> _dropOldVideo() async {
    final p = _videoPath;
    if (p != null && MediaBlob.isRef(p)) await MediaBlob.delete(p);
  }

  Future<void> setBlur(double v) async {
    _blur = v.clamp(0, 20).toDouble();
    await _put((sp) => sp.setDouble(_kBlurKey, _blur));
    notifyListeners();
  }

  Future<void> setOpacity(double v) async {
    _opacity = v.clamp(0.1, 1.0).toDouble();
    await _put((sp) => sp.setDouble(_kOpKey, _opacity));
    notifyListeners();
  }

  /// «حذف پس‌زمینه» — فقط تصویر/ویدیو پاک می‌شه؛ تنظیم‌ها (blur/شفافیت) می‌مونن
  Future<void> clear() async {
    await _dropOldVideo();
    _kind = BgKind.none;
    _imageBytes = null;
    _videoPath = null;
    try {
      final sp = await AppPrefs.getInstance();
      await sp.remove(_kKind);
      await sp.remove(_kImgKey);
      await sp.remove(_kVidPath);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _put(Future<Object?> Function(AppPrefs sp) fn) async {
    try {
      await fn(await AppPrefs.getInstance());
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setString(_kKind, _kind.name);
      await sp.setString(_kMode, _custom ? 'image' : 'calm');
      if (_imageBytes != null) {
        await sp.setString(_kImgKey, base64Encode(_imageBytes!));
      } else {
        await sp.remove(_kImgKey);
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
