import 'dart:convert';
import 'dart:typed_data';

/// تشخیص فرمت واقعی صدا از روی بایت‌ها (نه از روی اسم/پسوند).
/// ویس‌هایی که مرورگر ضبط می‌کنه معمولاً webm/opus هستن ولی قبلاً با برچسب
/// اشتباه `audio/m4a` ذخیره می‌شدن و پخش نمی‌شدن.
String sniffAudioMime(Uint8List b, {String fallback = 'audio/mpeg'}) {
  bool at(int off, String s) {
    if (b.length < off + s.length) return false;
    for (var i = 0; i < s.length; i++) {
      if (b[off + i] != s.codeUnitAt(i)) return false;
    }
    return true;
  }

  if (b.length >= 4 && b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) {
    return 'audio/webm';
  }
  if (at(0, 'OggS')) return 'audio/ogg';
  if (at(0, 'RIFF') && at(8, 'WAVE')) return 'audio/wav';
  if (at(0, 'fLaC')) return 'audio/flac';
  if (at(4, 'ftyp')) return 'audio/mp4';
  if (at(0, 'ID3')) return 'audio/mpeg';
  if (b.length >= 2 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) {
    return (b[1] & 0x06) == 0 ? 'audio/aac' : 'audio/mpeg';
  }
  if (at(0, '#!AMR')) return 'audio/amr';
  if (at(0, 'FORM')) return 'audio/aiff';
  return fallback;
}

/// نوع صدا از روی پسوند (برای وقتی که بایت‌ها قابل تشخیص نیستن)
String audioMimeFromName(String name) {
  final l = name.toLowerCase();
  const map = {
    '.mp3': 'audio/mpeg',
    '.mpga': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.wave': 'audio/wav',
    '.m4a': 'audio/mp4',
    '.mp4': 'audio/mp4',
    '.m4b': 'audio/mp4',
    '.aac': 'audio/aac',
    '.ogg': 'audio/ogg',
    '.oga': 'audio/ogg',
    '.opus': 'audio/ogg',
    '.webm': 'audio/webm',
    '.mka': 'audio/webm',
    '.flac': 'audio/flac',
    '.amr': 'audio/amr',
    '.3gp': 'audio/3gpp',
    '.3ga': 'audio/3gpp',
    '.aif': 'audio/aiff',
    '.aiff': 'audio/aiff',
    '.wma': 'audio/x-ms-wma',
  };
  for (final e in map.entries) {
    if (l.endsWith(e.key)) return e.value;
  }
  return 'audio/mpeg';
}

/// ساخت data-URL صدا با برچسب درست
String audioDataUrl(Uint8List bytes, {String? name}) {
  final mime = sniffAudioMime(bytes,
      fallback: name == null ? 'audio/mpeg' : audioMimeFromName(name));
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

/// data-URLهای قدیمی (مثلاً `audio/m4a` اشتباه) را با برچسب درست دوباره می‌سازد.
String fixAudioDataUrl(String src, Uint8List? bytes) {
  if (!src.startsWith('data:') || bytes == null || bytes.isEmpty) return src;
  final comma = src.indexOf(',');
  if (comma < 0) return src;
  final real = sniffAudioMime(bytes, fallback: '');
  if (real.isEmpty) return src;
  final header = src.substring(5, comma);
  final cur = header.split(';').first.toLowerCase();
  if (cur == real) return src;
  return 'data:$real;base64,${src.substring(comma + 1)}';
}
