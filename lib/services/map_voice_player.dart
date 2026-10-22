import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;

import 'audio_mime.dart';
import 'data_url_cache.dart';

/// پخش صدای ضبط‌شده‌ی هر گره روی نقشه (من، هدف، شاخه، زیرشاخه، حلقه، انیمیشن).
/// فقط یک صدا هم‌زمان پخش می‌شود. تعداد تکرار: ۱، ۲، ۳ یا بی‌نهایت
/// (در extra با کلیدِ «<voiceKey>Repeat» ذخیره می‌شود؛ ۰ = بی‌نهایت).
class MapVoicePlayer {
  MapVoicePlayer._();
  static final MapVoicePlayer instance = MapVoicePlayer._();

  AudioPlayer? _p;
  StreamSubscription<void>? _sub;
  String _src = '';
  int _left = 0; // تعداد پخش‌های باقی‌مانده (شامل پخش جاری)؛ -1 = بی‌نهایت

  /// شناسه‌ی صدایی که الان پخش می‌شود (خالی = هیچ‌کدام)
  final ValueNotifier<String> playing = ValueNotifier<String>('');

  static Source _sourceOf(String src) {
    if (!src.startsWith('data:')) return UrlSource(src);
    final Uint8List? bytes = DataUrlCache.bytes(src);
    if (bytes == null) return UrlSource(src);
    if (kIsWeb) return UrlSource(fixAudioDataUrl(src, bytes));
    return BytesSource(bytes, mimeType: sniffAudioMime(bytes));
  }

  /// تعداد تکرارِ ذخیره‌شده: ۱، ۲، ۳ یا ۰ (= بی‌نهایت)
  static int repeatOf(Map<String, dynamic>? extra, String key) {
    final r = extra?['${key}Repeat'];
    if (r is num) {
      final n = r.toInt();
      if (n == 0 || n == 2 || n == 3) return n;
    }
    return 1;
  }

  /// ۱ → ۲ → ۳ → ∞ → ۱
  static int nextRepeat(int cur) => cur == 1 ? 2 : (cur == 2 ? 3 : (cur == 3 ? 0 : 1));

  /// دکمه‌ی پلی روی نقشه: اگر همین صدا در حال پخش است متوقف می‌شود، وگرنه شروع می‌شود
  Future<void> toggle(String id, Map<String, dynamic>? extra, String key) async {
    if (playing.value == id) {
      await stop();
      return;
    }
    final v = extra?[key];
    if (v is! String || v.isEmpty) return;
    final rep = repeatOf(extra, key);
    await _start(id, v, rep == 0 ? -1 : rep);
  }

  /// تغییر تعداد تکرار در حین پخش
  void setRepeat(String id, int rep) {
    if (playing.value == id) _left = rep == 0 ? -1 : rep;
  }

  Future<void> _start(String id, String src, int count) async {
    try {
      final p = _p ??= AudioPlayer();
      _sub ??= p.onPlayerComplete.listen((_) => _onComplete());
      _left = 0;
      playing.value = '';
      await p.stop();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(_sourceOf(src));
      _src = src;
      _left = count;
      playing.value = id;
      await p.resume();
    } catch (_) {
      // صدای خراب یا پشتیبانی‌نشده: بی‌صدا نادیده گرفته می‌شود
      playing.value = '';
    }
  }

  Future<void> _onComplete() async {
    if (playing.value.isEmpty) return;
    if (_left > 0) _left--;
    if (_left == 0) {
      playing.value = '';
      return;
    }
    try {
      final p = _p!;
      await p.setSource(_sourceOf(_src));
      await p.resume();
    } catch (_) {
      playing.value = '';
    }
  }

  Future<void> stop() async {
    _left = 0;
    playing.value = '';
    try {
      await _p?.stop();
    } catch (_) {}
  }
}
