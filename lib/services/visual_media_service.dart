import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gratitude_entry.dart';

/// انتخاب ویدیو و موسیقی برای بخش «تصویرسازی» تب باورها.
/// همان قواعد تب شکرگذاری: ویدیو تا ۸ مگابایت، به‌صورت data-URL.
class VisualMediaService {
  static const int maxVideoBytes = 8 * 1024 * 1024;
  static const int maxAudioBytes = 5 * 1024 * 1024;

  static final ImagePicker _picker = ImagePicker();

  /// ویدیو از گالری. اگه نشد، `error` پیام فارسی می‌دهد (لغو کاربر = هر دو null).
  static Future<({GratitudeVideo? video, String? error})> pickVideo() async {
    try {
      final f = await _picker.pickVideo(source: ImageSource.gallery);
      if (f == null) return (video: null, error: null);
      final bytes = await f.readAsBytes();
      if (bytes.length > maxVideoBytes) {
        return (video: null, error: 'ویدیو بزرگ‌تر از ۸ مگابایت ذخیره نمی‌شه');
      }
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

  /// موسیقی مدیتیشن از فایل‌های گوشی.
  static Future<({GratitudeAudio? track, String? error})> pickMusic() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
      );
      if (res == null || res.files.isEmpty) return (track: null, error: null);
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) return (track: null, error: 'فایل خوانده نشد');
      if (bytes.length > maxAudioBytes) {
        return (track: null, error: 'موسیقی بزرگ‌تر از ۵ مگابایت ذخیره نمی‌شه');
      }
      return (
        track: GratitudeAudio(
          src: 'data:${_mimeOfAudio(f.name)};base64,${base64Encode(bytes)}',
          name: f.name,
        ),
        error: null,
      );
    } catch (e) {
      debugPrint('VisualMediaService.pickMusic failed: $e');
      return (track: null, error: 'موسیقی اضافه نشد');
    }
  }

  static String _mimeOfAudio(String name) {
    final l = name.toLowerCase();
    if (l.endsWith('.wav')) return 'audio/wav';
    if (l.endsWith('.m4a') || l.endsWith('.aac')) return 'audio/mp4';
    if (l.endsWith('.ogg') || l.endsWith('.opus')) return 'audio/ogg';
    if (l.endsWith('.webm')) return 'audio/webm';
    return 'audio/mpeg';
  }
}
