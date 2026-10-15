import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'media_db.dart';

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
        out.add(await MediaDb.putBytes(bytes, mime));
      }
      return out;
    } catch (e) {
      debugPrint('pickImages failed: $e');
      return const [];
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
      if (bytes.length > 100 * 1024 * 1024) return null;
      final mime = _mimeOfVideo(f.name);
      return MediaDb.putBytes(bytes, mime);
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
      if (f.bytes!.length > 100 * 1024 * 1024) return null;
      final mime = _mimeOfAudio(f.name);
      return MediaDb.putBytes(f.bytes!, mime);
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
