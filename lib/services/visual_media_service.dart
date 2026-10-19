import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gratitude_entry.dart';
import 'audio_mime.dart';

/// انتخاب ویدیو و موسیقی برای بخش «تصویرسازی» تب باورها.
/// بدون محدودیت حجم (همه‌چیز روی خود گوشی ذخیره می‌شه)، به‌صورت data-URL.
class VisualMediaService {
  static final ImagePicker _picker = ImagePicker();

  /// ویدیو از گالری. اگه نشد، `error` پیام فارسی می‌دهد (لغو کاربر = هر دو null).
  static Future<({GratitudeVideo? video, String? error})> pickVideo() async {
    try {
      final f = await _picker.pickVideo(source: ImageSource.gallery);
      if (f == null) return (video: null, error: null);
      final bytes = await f.readAsBytes();
      final lower = f.name.toLowerCase();
      final mime = lower.endsWith('.webm')
          ? 'video/webm'
          : (lower.endsWith('.mov') ? 'video/quicktime' : 'video/mp4');
      return (
        video: GratitudeVideo(
          path: 'data:$mime;base64,${base64Encode(bytes)}',
          name: f.name,
          size: bytes.length,
        ),
        error: null,
      );
    } catch (e) {
      debugPrint('VisualMediaService.pickVideo failed: $e');
      return (video: null, error: 'ویدیو اضافه نشد');
    }
  }

  /// موسیقی مدیتیشن از فایل‌های گوشی — همه‌ی فرمت‌های صوتی، بدون سقف حجم.
  /// (FileType.any تا فایل‌هایی مثل flac/opus/amr/wma هم در انتخابگر دیده بشن)
  static Future<({GratitudeAudio? track, String? error})> pickMusic() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (res == null || res.files.isEmpty) return (track: null, error: null);
      final f = res.files.first;
      Uint8List? bytes = f.bytes;
      if (bytes == null && !kIsWeb && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        return (track: null, error: 'فایل خوانده نشد');
      }
      return (
        track: GratitudeAudio(
          src: audioDataUrl(bytes, name: f.name),
          name: f.name,
        ),
        error: null,
      );
    } catch (e) {
      debugPrint('VisualMediaService.pickMusic failed: $e');
      return (track: null, error: 'موسیقی اضافه نشد');
    }
  }
}
