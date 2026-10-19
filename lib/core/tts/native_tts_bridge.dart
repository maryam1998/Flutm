import 'dart:async';

import 'package:flutter/foundation.dart';

import '../native/native_bridge.dart';

/// پل به TTS نیتیو اندروید (Piper/Sherpa + TTS خودِ گوشی).
///
/// ⚠️ باگِ قبلی: این کلاس روی کانالِ `lingolearn/tts` صدا می‌زد، ولی سمتِ
/// اندروید هیچ‌وقت چنین کانالی ثبت نشده بود (فقط `com.linglearn.app/bubble`
/// وجود دارد). نتیجه: همه‌ی صدا زدن‌ها بی‌صدا شکست می‌خوردند و TTS گوشی
/// هیچ صدایی نداشت. حالا همه‌چیز از همان [NativeBridge] می‌گذرد:
///   • speak / speakSystem / stopSpeaking  ← متدهای BubblePlugin
///   • پایانِ خوانش ← رویداد `ttsSpeakDone` با { id, ok }
///
/// مثل Hope (nativeTtsFast.js) هر خوانش یک `id` یکتا دارد تا رویدادِ «تمام شد»
/// یک خوانشِ قدیمی (بعد از stop/pause) خوانشِ جدید را تمام‌شده حساب نکند.
class NativeTtsBridge {
  NativeTtsBridge._();

  static final NativeBridge _b = NativeBridge.instance;

  static bool get isAvailable => !kIsWeb && _b.isSupported;

  static void Function(String? id, bool ok)? _doneHandler;
  static StreamSubscription<Map<String, dynamic>>? _sub;

  static void _ensureListening() {
    _sub ??= _b.on('ttsSpeakDone').listen((d) {
      final h = _doneHandler;
      if (h == null) return;
      final rawId = d['id']?.toString();
      h((rawId == null || rawId.isEmpty) ? null : rawId, d['ok'] != false);
    }, onError: (Object e) => debugPrint('ttsSpeakDone stream error: $e'));
  }

  /// آیا بسته‌ی آفلاینِ (Piper) این زبان نصب شده؟
  static final Map<String, DateTime> _readyAt = {};

  static Future<bool> isModelReady(String lang) async {
    if (!isAvailable) return false;
    // ⚡ بدون رفت‌وبرگشتِ اضافه به نیتیو برای هر جمله: جوابِ «آماده» ۳۰ ثانیه کش می‌شود
    final t = _readyAt[lang];
    if (t != null && DateTime.now().difference(t) < const Duration(seconds: 30)) {
      return true;
    }
    try {
      final r = await _b.checkTtsStatus(lang: lang);
      final ok = r['downloaded'] == true;
      if (ok) {
        _readyAt[lang] = DateTime.now();
      } else {
        _readyAt.remove(lang);
      }
      return ok;
    } catch (e) {
      debugPrint('checkTtsStatus error: $e');
      return false;
    }
  }

  /// موتورِ Piper را از قبل (پس‌زمینه) لود و گرم می‌کند تا اولین خوانش تأخیر نداشته باشد.
  static Future<void> preload({String? lang}) async {
    if (!isAvailable) return;
    try {
      await _b.preloadTts(lang: lang);
    } catch (_) {}
  }

  /// صدای جمله‌ی بعدی را پیش‌پیش می‌سازد (موقعِ نوبتش بدون تأخیر پخش می‌شود).
  static Future<void> prefetch(String text, String lang, double rate) async {
    if (!isAvailable) return;
    try {
      await _b.prefetchTts(text: text, lang: lang, speed: rate);
    } catch (_) {}
  }

  /// TTS نیتیو (Piper) — true یعنی خوانش شروع شد (پایانش با [onDone] می‌رسد).
  static Future<bool> speak(
    String text,
    String lang,
    double rate, {
    String? id,
  }) async {
    if (!isAvailable) return false;
    _ensureListening();
    try {
      await _b.speak(text: text, lang: lang, speed: rate, id: id);
      return true;
    } catch (e) {
      debugPrint('native speak error: $e');
      return false;
    }
  }

  /// TTS خودِ گوشی (android.speech.tts).
  static Future<bool> speakSystem(
    String text,
    String lang,
    double rate, {
    String? id,
  }) async {
    if (!isAvailable) return false;
    _ensureListening();
    try {
      await _b.speakSystem(text: text, lang: lang, speed: rate, id: id);
      return true;
    } catch (e) {
      debugPrint('speakSystem error: $e');
      return false;
    }
  }

  /// توقف
  static Future<void> stop() async {
    if (!isAvailable) return;
    try {
      await _b.stopSpeaking();
    } catch (_) {}
  }

  /// منتظر پایانِ خوانش. handler پارامترهای (id, ok) می‌گیرد؛
  /// اگر سمتِ نیتیو id نفرستد، id == null می‌آید.
  static void onDone(void Function(String? id, bool ok) handler) {
    if (!isAvailable) return;
    _doneHandler = handler;
    _ensureListening();
  }
}
