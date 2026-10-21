import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'audio_mime.dart';
import 'data_url_cache.dart';

/// پخش صدای ضبط‌شده‌ی هر گره روی نقشه (من، هدف، شاخه، زیرشاخه، حلقه، انیمیشن).
/// فقط یک صدا هم‌زمان پخش می‌شود؛ لمس بعدی صدای قبلی را قطع می‌کند.
class MapVoicePlayer {
  MapVoicePlayer._();
  static final MapVoicePlayer instance = MapVoicePlayer._();

  AudioPlayer? _p;

  static Source _sourceOf(String src) {
    if (!src.startsWith('data:')) return UrlSource(src);
    final Uint8List? bytes = DataUrlCache.bytes(src);
    if (bytes == null) return UrlSource(src);
    if (kIsWeb) return UrlSource(fixAudioDataUrl(src, bytes));
    return BytesSource(bytes, mimeType: sniffAudioMime(bytes));
  }

  /// [extra] = نقشه‌ی extra گره، [key] = 'voice' یا 'walkerVoice'
  Future<void> playFrom(Map<String, dynamic>? extra, String key) async {
    final v = extra?[key];
    if (v is! String || v.isEmpty) return;
    await play(v);
  }

  Future<void> play(String src) async {
    try {
      final p = _p ??= AudioPlayer();
      await p.stop();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(_sourceOf(src));
      await p.resume();
    } catch (_) {
      // صدای خراب یا پشتیبانی‌نشده: بی‌صدا نادیده گرفته می‌شود
    }
  }

  Future<void> stop() async {
    try {
      await _p?.stop();
    } catch (_) {}
  }
}
