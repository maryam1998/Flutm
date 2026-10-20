import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:image_picker/image_picker.dart';

import '../map/draw_utils.dart' show NodeImageCache;
import '../widgets/photo_cropper.dart';
import 'data_url_cache.dart';
import 'fast_image.dart';
import 'media_blob.dart';
import 'media_kind.dart';

/// عکس‌ها در ذخیره‌سازی به‌صورت base64 نگه‌داری می‌شن و با هر ذخیره کل لیست دوباره نوشته
/// می‌شه؛ پس هرچه عکس سبک‌تر، همه‌چیز (افزودن، ذخیره، بالا اومدن برنامه) سریع‌تره.
/// ۱۲۸۰px با کیفیت ۸۰ روی گوشی از ۱۶۰۰px/۸۵ تقریباً هم‌کیفیته ولی حدود نصف حجم داره.
const int _kMaxSide = 1280;
const int _kQuality = 80;

/// رمزگذاری base64 (برای عکس‌های بزرگ سنگینه؛ روی موبایل تو isolate جدا انجام می‌شه تا UI قفل نکنه)
String _toDataUrl(List<Object> args) =>
    'data:${args[0]};base64,${base64Encode(args[1] as Uint8List)}';

Future<String> _encodeDataUrl(String mime, Uint8List bytes) async {
  if (kIsWeb || bytes.length < 200 * 1024) {
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
  try {
    return await compute(_toDataUrl, <Object>[mime, bytes]);
  } catch (_) {
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
}

/// همه‌ی فایل‌ها هم‌زمان خونده و رمزگذاری می‌شن. بایت‌ها همون لحظه در کش گذاشته می‌شن
/// (بدون دیکُدِ دوباره‌ی base64) و تصویر برای نقشه در پس‌زمینه آماده می‌شه.
Future<List<String>> _filesToDataUrls(List<XFile> files, String Function(String) mimeOf) async {
  final out = await Future.wait(files.map((f) async {
    final bytes = await f.readAsBytes();
    final url = await _encodeDataUrl(mimeOf(f.name), bytes);
    DataUrlCache.seed(url, bytes); // بدون دیکُد دوباره
    NodeImageCache.shared.warm(url); // دیکُد تصویر برای نقشه (بدون انتظار)
    return url;
  }));
  return out;
}

/// نوع واقعی عکس از روی محتوا (بعد از کوچک‌سازی ممکنه با پسوند فرق کنه)
String _sniffMime(Uint8List b, String name, String Function(String) mimeOf) {
  if (b.length > 12) {
    if (b[0] == 0x89 && b[1] == 0x50) return 'image/png';
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return 'image/gif';
    if (b[0] == 0xFF && b[1] == 0xD8) return 'image/jpeg';
    if (b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57 && b[9] == 0x45) {
      return 'image/webp';
    }
  }
  return mimeOf(name);
}

/// روی وب، image_picker با maxWidth/imageQuality عکس را روی canvas می‌کشد و GIF متحرک
/// تبدیل به عکس ثابت می‌شود. پس اینجا بدون محدودیت انتخاب می‌کنیم؛ عکس متحرک (GIF/WebP/APNG)
/// دست‌نخورده می‌ماند و فقط عکس‌های ثابت کوچک می‌شوند.
Future<List<String>> _webFilesToDataUrls(
    List<XFile> files, int maxSide, String Function(String) mimeOf) async {
  final out = <String>[];
  for (final f in files) {
    var bytes = await f.readAsBytes();
    if (!MediaKind.isAnimatedImage(bytes)) {
      bytes = await fastDownscale(bytes, name: f.name, maxSide: maxSide);
    }
    final url = await _encodeDataUrl(_sniffMime(bytes, f.name, mimeOf), bytes);
    DataUrlCache.seed(url, bytes);
    NodeImageCache.shared.warm(url);
    out.add(url);
  }
  return out;
}

class ImageService {
  static final _picker = ImagePicker();

  static Future<List<String>> pickImages() async {
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
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
      if (kIsWeb) {
        final wf = await _picker.pickMultiImage();
        if (wf.isEmpty) return const [];
        return await _webFilesToDataUrls(wf, _kMaxSide, _mimeOf);
      }
      final files = await _picker.pickMultiImage(
        maxWidth: _kMaxSide.toDouble(),
        maxHeight: _kMaxSide.toDouble(),
        imageQuality: _kQuality,
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
      if (kIsWeb) {
        final wf = await _picker.pickImage(source: ImageSource.gallery);
        if (wf == null) return null;
        return (await _webFilesToDataUrls([wf], _kMaxSide, _mimeOf)).first;
      }
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _kMaxSide.toDouble(),
        maxHeight: _kMaxSide.toDouble(),
        imageQuality: _kQuality,
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
      // برش، انیمیشن را به یک فریم تبدیل می‌کرد؛ عکس متحرک بدون تغییر می‌ماند
      if (MediaKind.isAnimatedImage(bytes)) return null;
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
      if (kIsWeb) {
        final wf = await _picker.pickImage(source: ImageSource.gallery);
        if (wf == null) return null;
        return (await _webFilesToDataUrls([wf], 480, _mimeOf)).first;
      }
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 85,
      );
      if (f == null) return null;
      return (await _filesToDataUrls([f], _mimeOf)).first;
    } catch (e) {
      debugPrint('pickSingleImage failed: $e');
      return null;
    }
  }

  /// ویدیو: بیرون از JSON ذخیره می‌شه و مرجع کوتاه `mblob:...` برمی‌گرده
  /// (قبلاً کل ویدیو base64 و داخل JSON می‌رفت و خیلی کند بود).
  static Future<String?> pickVideo() async {
    try {
      final f = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      if (f == null) return null;
      return await MediaBlob.saveXFile(f, mime: _mimeOfVideo(f.name));
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
