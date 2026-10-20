import 'dart:typed_data';

/// تشخیص نوع فایل (عکس / ویدیو / عکس متحرک) — هم از روی پسوند، هم از روی محتوا.
/// برای پس‌زمینه: gif، webp و apng متحرک، و هر ویدیویی را بدون دست‌زدن نگه می‌دارد.
class MediaKind {
  MediaKind._();

  static const imageExts = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'apng', 'bmp', 'avif', 'heic', 'heif',
  };
  static const videoExts = {
    'mp4', 'mov', 'webm', 'm4v', 'mkv', '3gp', 'avi', 'ogv',
  };

  static String extOf(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  static bool _at(Uint8List b, int o, String t) {
    if (b.length < o + t.length) return false;
    for (var i = 0; i < t.length; i++) {
      if (b[o + i] != t.codeUnitAt(i)) return false;
    }
    return true;
  }

  /// 'image' | 'video' | null
  static String? kindOf(String name, Uint8List b) {
    final e = extOf(name);
    if (imageExts.contains(e)) return 'image';
    if (videoExts.contains(e)) return 'video';
    if (b.length < 12) return null;
    if (_at(b, 0, 'GIF8') ||
        _at(b, 1, 'PNG') ||
        (b[0] == 0xFF && b[1] == 0xD8)) {
      return 'image';
    }
    if (_at(b, 0, 'RIFF') && _at(b, 8, 'WEBP')) return 'image';
    if (_at(b, 4, 'ftyp')) {
      return (_at(b, 8, 'avif') || _at(b, 8, 'avis')) ? 'image' : 'video';
    }
    if (b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) {
      return 'video';
    }
    return null;
  }

  static int _indexOf(Uint8List b, List<int> pat, [int from = 0, int? to]) {
    final end = (to ?? b.length) - pat.length;
    for (var i = from; i <= end; i++) {
      var ok = true;
      for (var j = 0; j < pat.length; j++) {
        if (b[i + j] != pat[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  /// آیا این عکس چند فریمی (متحرک) است؟  GIF با بیش از یک فریم، WebP با تکه‌ی ANIM،
  /// PNG با تکه‌ی acTL (APNG) و AVIF با برند avis.
  static bool isAnimatedImage(Uint8List b) {
    if (b.length < 16) return false;
    if (_at(b, 0, 'GIF8')) {
      // هر فریم یک «Graphic Control Extension» (21 F9 04) دارد
      var n = 0, from = 0;
      while (n < 2) {
        final i = _indexOf(b, const [0x21, 0xF9, 0x04], from);
        if (i < 0) break;
        n++;
        from = i + 3;
      }
      return n > 1;
    }
    if (_at(b, 0, 'RIFF') && _at(b, 8, 'WEBP')) {
      return _indexOf(b, 'ANIM'.codeUnits, 12, b.length < 4096 ? b.length : 4096) >=
          0;
    }
    if (_at(b, 1, 'PNG')) {
      final idat = _indexOf(b, 'IDAT'.codeUnits);
      return _indexOf(b, 'acTL'.codeUnits, 8, idat < 0 ? b.length : idat) >= 0;
    }
    if (_at(b, 4, 'ftyp') && _at(b, 8, 'avis')) return true;
    return false;
  }

  static String mimeOfImage(String name) {
    switch (extOf(name)) {
      case 'png':
      case 'apng':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'avif':
        return 'image/avif';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }

  static String mimeOfVideo(String name) {
    switch (extOf(name)) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      case 'mkv':
        return 'video/x-matroska';
      case '3gp':
        return 'video/3gpp';
      case 'avi':
        return 'video/x-msvideo';
      case 'ogv':
        return 'video/ogg';
      default:
        return 'video/mp4';
    }
  }
}
