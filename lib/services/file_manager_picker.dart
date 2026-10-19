import 'dart:io' show File;
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show ImageSource, XFile;

import 'img_downscale.dart';

/// جایگزین ImagePicker: عکس و ویدیو رو از «فایل‌منیجر» گوشی انتخاب می‌کنه
/// (نه گالری). با FileType.custom و پسوندهای مشخص، انتخاب‌گر فایل سیستم باز می‌شه
/// و می‌شه مستقیم به هر پوشه‌ای رفت. امضای متدها مثل ImagePicker نگه داشته شده
/// تا بقیه‌ی کد تقریباً بدون تغییر کار کنه.
class FileManagerPicker {
  static const imageExts = [
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif',
  ];
  static const videoExts = [
    'mp4', 'mov', 'webm', 'm4v', 'mkv', '3gp', 'avi',
  ];

  Future<List<XFile>> pickMultiImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) =>
      _pickImages(
        multiple: true,
        maxSide: _maxSide(maxWidth, maxHeight),
        quality: imageQuality ?? 85,
      );

  Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    final l = await _pickImages(
      multiple: false,
      maxSide: _maxSide(maxWidth, maxHeight),
      quality: imageQuality ?? 85,
    );
    return l.isEmpty ? null : l.first;
  }

  /// [maxDuration] فقط برای سازگاری با ImagePicker هست و اعمال نمی‌شه.
  Future<XFile?> pickVideo({
    ImageSource source = ImageSource.gallery,
    Duration? maxDuration,
  }) async {
    final l = await pickVideos(multiple: false);
    return l.isEmpty ? null : l.first;
  }

  Future<List<XFile>> pickVideos({bool multiple = true}) async {
    final res = await FilePicker.platform.pickFiles(
      // روی وب با پسوند مشخص، کروم اندروید «گالری/Google Photos» رو باز می‌کنه؛
      // با FileType.any انتخاب‌گر فایل (فایل‌منیجر) باز می‌شه.
      type: kIsWeb ? FileType.any : FileType.custom,
      allowedExtensions: kIsWeb ? null : videoExts,
      allowMultiple: multiple,
      withData: kIsWeb, // روی موبایل فقط مسیر کافیه (ویدیوی بزرگ تو رم نمی‌آد)
    );
    if (res == null) return const [];
    final out = <XFile>[];
    for (final f in res.files) {
      if (!_hasExt(f.name, videoExts)) continue;
      if (!kIsWeb && f.path != null) {
        out.add(XFile(f.path!, name: f.name));
      } else if (f.bytes != null && f.bytes!.isNotEmpty) {
        out.add(XFile.fromData(f.bytes!, name: f.name));
      }
    }
    return out;
  }

  bool _hasExt(String name, List<String> exts) {
    final i = name.lastIndexOf('.');
    return i >= 0 && exts.contains(name.substring(i + 1).toLowerCase());
  }

  int? _maxSide(int? w, int? h) {
    if (w == null && h == null) return null;
    return math.max(w ?? 0, h ?? 0);
  }

  Future<List<XFile>> _pickImages({
    required bool multiple,
    required int? maxSide,
    required int quality,
  }) async {
    final res = await FilePicker.platform.pickFiles(
      type: kIsWeb ? FileType.any : FileType.custom,
      allowedExtensions: kIsWeb ? null : imageExts,
      allowMultiple: multiple,
      withData: kIsWeb,
    );
    if (res == null) return const [];
    final out = await Future.wait(res.files.map((f) async {
      if (!_hasExt(f.name, imageExts)) return null;
      Uint8List? bytes = f.bytes;
      if (bytes == null && !kIsWeb && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) return null;
      var name = f.name;
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      // gif (انیمیشن) و بدون سقف اندازه: دست‌نخورده
      if (maxSide != null && ext != 'gif') {
        final small = await downscaleToJpeg(bytes, maxSide, quality);
        if (small != null) {
          bytes = small;
          name = '${name.replaceAll(RegExp(r'\.[^.]*$'), '')}.jpg';
        }
      }
      return XFile.fromData(bytes, name: name);
    }));
    return out.whereType<XFile>().toList();
  }
}
