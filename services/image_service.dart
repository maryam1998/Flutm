import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:image_picker/image_picker.dart';

import '../map/draw_utils.dart' show NodeImageCache;
import '../widgets/photo_cropper.dart';
import 'data_url_cache.dart';

/// رمزگذاری base64 (برای عکس‌های بزرگ سنگینه؛ روی موبایل تو isolate جدا انجام می‌شه تا UI قفل نکنه)
String _toDataUrl(List<Object> args) =>
    'data:${args[0]};base64,${base64Encode(args[1] as Uint8List)}';

Future<String> _encodeDataUrl(String mime, Uint8List bytes) async {
  if (kIsWeb || bytes.length < 1500 * 1024) {
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
  try {
    return await compute(_toDataUrl, <Object>[mime, bytes]);
  } catch (_) {
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
}

/// همه‌ی فایل‌ها هم‌زمان خونده و رمزگذاری می‌شن (قبلاً یکی‌یکی بود و برای چند عکس خیلی کند بود)،
/// و بلافاصله برای نقشه/بندانگشتی آماده (decode) می‌شن تا عکس دیر ظاهر نشه.
Future<List<String>> _filesToDataUrls(List<XFile> files, String Function(String) mimeOf) async {
  final out = await Future.wait(files.map((f) async {
    final bytes = await f.readAsBytes();
    final url = await _encodeDataUrl(mimeOf(f.name), bytes);
    DataUrlCache.put(url, bytes); // بایت‌ها همین الان موجودن؛ base64 دوباره دیکُد نمی‌شه
    NodeImageCache.shared.warm(url); // دیکُد تصویر برای نقشه (موازی)
    return url;
  }));
  return out;
}

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
      return await _filesToDataUrls(files, _mimeOf);
    } catch (e) {
      debugPrint('pickImages failed: $e');
      return const [];
    }
  }

  /// انتخاب چندتایی عکس — **بدون برش اجباری**: همه‌ی عکس‌ها همون لحظه، دست‌نخورده
  /// اضافه می‌شن؛ هر وقت خواستی با دکمه‌ی ✂ روی خود عکس برشش بزن ([cropDataUrl]).
  /// (اسم قدیمی حفظ شده تا بقیه‌ی فایل‌ها نیازی به تغییر نداشته باشن.)
  static Future<List<String>> pickImagesCropped({BuildContext? context}) async {
    try {
      // ۱۲۸۰px و کیفیت ۸۰: برای نمایش روی نقشه کاملاً کافیه و پردازشش خیلی سریع‌تره
      final files = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (files.isEmpty) return const [];
      return await _filesToDataUrls(files, _mimeOf);
    } catch (e) {
      debugPrint('pickImagesCropped failed: $e');
      return const [];
    }
  }

  /// یک عکس — بدون برش اجباری (برش بعداً با دکمه‌ی ✂ و حالت «آزاد» انجام می‌شه).
  static Future<String?> pickSingleCropped({
    BuildContext? context,
    double? ratio,
    int maxSide = 640,
  }) async {
    try {
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (f == null) return null;
      return (await _filesToDataUrls([f], _mimeOf)).first;
    } catch (e) {
      debugPrint('pickSingleCropped failed: $e');
      return null;
    }
  }

  /// برش یک عکسِ از قبل اضافه‌شده (data-URL). پیش‌فرض: برش **آزاد**.
  /// null = انصراف/خطا؛ وگرنه data-URL جدید (یا همون قبلی اگه «بدون برش» بزنه).
  static Future<String?> cropDataUrl(
    BuildContext? context,
    String src, {
    double? ratio,
    int maxSide = 2400,
    String? progress,
  }) async {
    try {
      if (!src.startsWith('data:')) return null;
      final i = src.indexOf(',');
      if (i < 0) return null;
      final header = src.substring(5, i);
      final mime = header.split(';').first.isEmpty
          ? 'image/jpeg'
          : header.split(';').first;
      final bytes = base64Decode(src.substring(i + 1));
      final res = await showPhotoCropper(
        context,
        bytes,
        mime: mime,
        initialRatio: ratio,
        maxSide: maxSide,
        progress: progress,
      );
      if (res == null) return null;
      return 'data:${res.mime};base64,${base64Encode(res.bytes)}';
    } catch (e) {
      debugPrint('cropDataUrl failed: $e');
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
