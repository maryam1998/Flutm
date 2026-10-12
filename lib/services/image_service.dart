import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  static final _picker = ImagePicker();

  /// چند عکس از گالری/دوربین می‌گیرد و به data URL تبدیل می‌کند.
  /// ابعاد حداکثر ۸۰۰ پیکسل، کیفیت ۸۵٪ — تا حجم JSON سبک بمونه.
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

  static String _mimeOf(String name) {
    final l = name.toLowerCase();
    if (l.endsWith('.png')) return 'image/png';
    if (l.endsWith('.gif')) return 'image/gif';
    if (l.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
