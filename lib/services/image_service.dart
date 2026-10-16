import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:image_picker/image_picker.dart';

import '../widgets/photo_cropper.dart';

class ImageService {
  static final _picker = ImagePicker();

  static Future<List<String>> pickImages() async {
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (files.isEmpty) return const [];
      final out = <String>[];
      for (final f in files) {
        final bytes = await f.readAsBytes();
        final mime = _mimeOf(f.name);
        out.add('data:$mime;base64,${base64Encode(bytes)}');
      }
      return out;
    } catch (e) {
      debugPrint('pickImages failed: $e');
      return const [];
    }
  }

  /// انتخاب چندتایی + برش تک‌تک عکس‌ها (صفحه‌ی «برش عکس»).
  /// «انصراف» همون عکس رو رد می‌کنه؛ «بدون برش» عکس اصلی رو نگه می‌داره.
  static Future<List<String>> pickImagesCropped({BuildContext? context}) async {
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (files.isEmpty) return const [];
      final out = <String>[];
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final bytes = await f.readAsBytes();
        final mime = _mimeOf(f.name);
        final res = await showPhotoCropper(
          context,
          bytes,
          mime: mime,
          progress: files.length > 1 ? '${i + 1} از ${files.length}' : null,
        );
        if (res == null) continue;
        out.add('data:${res.mime};base64,${base64Encode(res.bytes)}');
      }
      return out;
    } catch (e) {
      debugPrint('pickImagesCropped failed: $e');
      return const [];
    }
  }

  /// یک عکس با برش (برای عکس پاهای متحرک / قدم‌زن) — پیش‌فرض ۱:۱
  static Future<String?> pickSingleCropped({
    BuildContext? context,
    double? ratio = 1,
    int maxSide = 640,
  }) async {
    try {
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (f == null) return null;
      final bytes = await f.readAsBytes();
      final res = await showPhotoCropper(
        context,
        bytes,
        mime: _mimeOf(f.name),
        initialRatio: ratio,
        maxSide: maxSide,
      );
      if (res == null) return null;
      return 'data:${res.mime};base64,${base64Encode(res.bytes)}';
    } catch (e) {
      debugPrint('pickSingleCropped failed: $e');
      return null;
    }
  }

  /// یک عکس برای «چهره‌ی قدم‌زن» (دایره‌ی جلوی پاها)
  static Future<String?> pickSingleImage() async {
    try {
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 85,
      );
      if (f == null) return null;
      final bytes = await f.readAsBytes();
      return 'data:${_mimeOf(f.name)};base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('pickSingleImage failed: $e');
      return null;
    }
  }

  static Future<String?> pickVideo() async {
    try {
      final f = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      if (f == null) return null;
      final bytes = await f.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) return null;
      final mime = _mimeOfVideo(f.name);
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('pickVideo failed: $e');
      return null;
    }
  }

  static Future<String?> pickAudio() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
      );
      if (res == null || res.files.isEmpty) return null;
      final f = res.files.first;
      if (f.bytes == null) return null;
      if (f.bytes!.length > 5 * 1024 * 1024) return null;
      final mime = _mimeOfAudio(f.name);
      return 'data:$mime;base64,${base64Encode(f.bytes!)}';
    } catch (e) {
      debugPrint('pickAudio failed: $e');
      return null;
    }
  }

  static String _mimeOf(String name) {
    final l = name.toLowerCase();
    if (l.endsWith('.png')) return 'image/png';
    if (l.endsWith('.gif')) return 'image/gif';
    if (l.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static String _mimeOfVideo(String name) {
    final l = name.toLowerCase();
    if (l.endsWith('.mov')) return 'video/quicktime';
    if (l.endsWith('.webm')) return 'video/webm';
    if (l.endsWith('.m4v')) return 'video/x-m4v';
    return 'video/mp4';
  }

  static String _mimeOfAudio(String name) {
    final l = name.toLowerCase();
    if (l.endsWith('.mp3')) return 'audio/mpeg';
    if (l.endsWith('.wav')) return 'audio/wav';
    if (l.endsWith('.m4a')) return 'audio/mp4';
    if (l.endsWith('.ogg')) return 'audio/ogg';
    return 'audio/mpeg';
  }
}
