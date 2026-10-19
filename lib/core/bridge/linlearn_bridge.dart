// 📁 مسیر: lib/core/bridge/linlearn_bridge.dart
//
// آداپتور: همان API قبلیِ LinLearnBridge (بدون هیچ تغییر در صفحه‌های UI)،
// ولی حالا روی NativeBridge → BubblePlugin.java کار می‌کند.
// روی وب/iOS همه‌چیز بی‌صدا مقدار پیش‌فرض (false / null) برمی‌گرداند.

import 'dart:async';

import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;

import '../native/native_bridge.dart';

class LinLearnBridge {
  static final NativeBridge _n = NativeBridge.instance;

  // ───────────────────────────────────────────────────────────
  // زبان‌ها (اختیاری): اگر جایی صدا بزنی، به حباب هم داده می‌شود.
  // ───────────────────────────────────────────────────────────
  static String? _uiLang;
  static String? _sourceLang;
  static List<String>? _targetLangs;

  static void configure({
    String? uiLang,
    String? sourceLang,
    List<String>? targetLangs,
  }) {
    if (uiLang != null) _uiLang = uiLang;
    if (sourceLang != null) _sourceLang = sourceLang;
    if (targetLangs != null) _targetLangs = targetLangs;
  }

  // ───────────────────────────────────────────────────────────
  // پیگیری پیشرفت دانلودها (از رویدادهای جاوا)
  // کلید: 'tts:fa' | 'speech:en' | 'song:base'
  // ───────────────────────────────────────────────────────────
  static final Map<String, Map<String, num>> _progress = {};
  static StreamSubscription<NativeEvent>? _sub;

  static void _listen() {
    if (_sub != null || !_n.isSupported) return;
    _sub = _n.events.listen(_onEvent, onError: (Object _) {});
  }

  static void _setProg(String kind, dynamic id, Map<String, dynamic> d) {
    if (id == null) return;
    _progress['$kind:$id'] = <String, num>{
      'bytes': (d['bytes'] as num?) ?? 0,
      'total': (d['total'] as num?) ?? 0,
    };
  }

  static void _onEvent(NativeEvent e) {
    final d = e.data;
    switch (e.name) {
      case 'ttsModelDownloadProgress':
        _setProg('tts', d['lang'], d);
        break;
      case 'modelDownloadProgress':
        _setProg('speech', d['lang'], d);
        break;
      case 'whisperDownloadProgress':
        _setProg('song', d['model'], d);
        break;
      case 'ttsModelDownloadDone':
      case 'ttsModelDownloadError':
      case 'ttsModelDownloadCancelled':
        _progress.remove('tts:${d['lang']}');
        break;
      case 'modelDownloadDone':
      case 'modelDownloadError':
        _progress.remove('speech:${d['lang']}');
        break;
      case 'whisperDownloadDone':
      case 'whisperDownloadError':
        _progress.remove('song:${d['model']}');
        break;
    }
  }

  /// اندازه‌ی «همگام‌سازی» (fast/balanced) → نامِ بسته‌ی Whisper روی گوشی.
  static String syncModelFor(String size) {
    switch (size) {
      case 'fast':
      case 'tiny':
        return 'tiny';
      case 'small':
        return 'small';
      default:
        return 'base';
    }
  }

  /// آیا بسته‌ی همگام‌سازیِ این اندازه دانلود شده؟
  static Future<bool> syncPackReady(String size) async {
    final st = await packStatus('sync', size);
    return st?['downloaded'] == true;
  }

  static Future<bool> _ok(Future<dynamic> Function() f) async {
    try {
      await f();
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Overlay Permission (اجازه‌ی نمایش حباب شناور)
  // ═══════════════════════════════════════════════════════════
  static Future<bool> canDrawOverlays() async {
    if (!_n.isSupported) return false;
    _listen();
    try {
      final r = await _n.checkPermission();
      return r['granted'] == true;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    if (!_n.isSupported) return;
    await _n.requestPermission();
  }

  // ═══════════════════════════════════════════════════════════
  // Bubble (حباب شناور)
  // mode: 'both' | 'magnifier' | 'translator'
  // ═══════════════════════════════════════════════════════════
  static Future<void> startBubble({String mode = 'both'}) async {
    if (!_n.isSupported) return;
    _listen();
    if (mode != 'magnifier') {
      await _n.showBubble(
        targetLang: _uiLang,
        sourceLang: _sourceLang,
        targetLangs: _targetLangs,
      );
    }
    if (mode == 'magnifier' || mode == 'both') {
      await _n.magnifierStart(
        targetLang: _uiLang,
        sourceLang: _sourceLang,
        targetLangs: _targetLangs,
      );
    }
  }

  static Future<void> stopBubble() async {
    if (!_n.isSupported) return;
    await _ok(() => _n.hideBubble());
    await _ok(() => _n.magnifierStop());
  }

  /// آیا حباب/ذره‌بین الان واقعاً در حال اجراست؟ (برای هماهنگ‌سازی وضعیت بعد از باز شدن اپ)
  static Future<bool> isBubbleRunning() async {
    if (!_n.isSupported) return false;
    try {
      final a = await _n.isRunning();
      final b = await _n.magnifierIsRunning();
      return a['running'] == true || b['running'] == true;
    } on PlatformException {
      return false;
    }
  }

  /// رنگ کادر حباب (#RRGGBB) و حالت نمایش ('both' | 'translation' | 'original').
  static Future<void> setBubbleOptions({
    String? panelColor,
    String? displayMode,
  }) async {
    if (!_n.isSupported) return;
    if (panelColor != null) await _ok(() => _n.setPanelColor(color: panelColor));
    if (displayMode != null) {
      await _ok(() => _n.setDisplayMode(mode: displayMode));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // بسته‌های آفلاین
  // kind: 'tts' | 'speech' | 'song' | 'sync'   —   id: کد زبان یا نام مدل
  // وضعیت: {downloaded, downloading, bytes, total, partialBytes, approxMb, enabled}
  // 'sync' (همگام‌سازی صدا): همان بسته‌های Whisper؛ fast→tiny ، balanced→base
  // ═══════════════════════════════════════════════════════════
  static Map<String, dynamic> _status(
    String key, {
    required bool downloaded,
    required bool downloading,
    num partial = 0,
    num? approxMb,
    bool? enabled,
  }) {
    final p = _progress[key];
    final m = <String, dynamic>{
      'downloaded': downloaded,
      'downloading': downloading,
      'bytes': downloading ? (p?['bytes'] ?? 0) : 0,
      'total': downloading ? (p?['total'] ?? 0) : 0,
      'partialBytes': partial,
    };
    if (approxMb != null) m['approxMb'] = approxMb;
    if (enabled != null) m['enabled'] = enabled;
    return m;
  }

  static Future<Map<String, dynamic>?> packStatus(String kind, String id) async {
    if (!_n.isSupported) return null;
    _listen();
    try {
      if (kind == 'tts') {
        final s = await _n.checkTtsStatus(lang: id);
        num partial = 0;
        final cat = await _n.getTtsCatalog();
        final langs = cat['languages'];
        if (langs is List) {
          for (final l in langs) {
            if (l is Map && l['lang'] == id) {
              partial = (l['partialBytes'] as num?) ?? 0;
            }
          }
        }
        return _status(
          'tts:$id',
          downloaded: s['downloaded'] == true,
          downloading: s['downloading'] == true,
          partial: partial,
        );
      }
      if (kind == 'speech') {
        final s = await _n.checkModelStatus(lang: id);
        return _status(
          'speech:$id',
          downloaded: s['downloaded'] == true,
          downloading: s['downloading'] == true && s['activeLang'] == id,
          partial: (s['partialBytes'] as num?) ?? 0,
        );
      }
      if (kind == 'song' || kind == 'sync') {
        final wid = kind == 'sync' ? syncModelFor(id) : id;
        final s = await _n.getWhisperStatus();
        bool downloaded = false;
        num partial = 0;
        num? approx;
        final models = s['models'];
        if (models is List) {
          for (final m in models) {
            if (m is Map && m['id'] == wid) {
              downloaded = m['downloaded'] == true;
              partial = (m['partialBytes'] as num?) ?? 0;
              approx = m['approxMb'] as num?;
            }
          }
        }
        return _status(
          'song:$wid',
          downloaded: downloaded,
          downloading: s['downloading'] == true && s['activeModel'] == wid,
          partial: partial,
          approxMb: approx,
          enabled: kind == 'song'
              ? (s['engine'] == 'whisper' && s['model'] == id)
              : null,
        );
      }
      return null; // ناشناخته
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> packDownload(String kind, String id) {
    if (!_n.isSupported) return Future.value(false);
    _listen();
    switch (kind) {
      case 'tts':
        return _ok(() => _n.downloadTtsModel(lang: id));
      case 'speech':
        return _ok(() => _n.downloadModel(lang: id));
      case 'song':
        return _ok(() => _n.downloadWhisperModel(model: id));
      case 'sync':
        return _ok(() => _n.downloadWhisperModel(model: syncModelFor(id)));
      default:
        return Future.value(false);
    }
  }

  static Future<bool> packCancel(String kind, String id) {
    if (!_n.isSupported) return Future.value(false);
    switch (kind) {
      case 'tts':
        return _ok(() => _n.cancelTtsDownload(lang: id));
      case 'speech':
        return _ok(() => _n.cancelModelDownload());
      case 'song':
      case 'sync':
        return _ok(() => _n.cancelWhisperDownload());
      default:
        return Future.value(false);
    }
  }

  /// هوکِ همگام‌سازی ابری: وقتی کاربر خودش یک بسته را حذف می‌کند صدا زده می‌شود.
  static void Function(String kind, String id)? onPackDeleted;

  static Future<bool> packDelete(String kind, String id) async {
    if (!_n.isSupported) return false;
    final bool ok;
    switch (kind) {
      case 'tts':
        ok = await _ok(() => _n.deleteTtsModel(lang: id));
        break;
      case 'speech':
        ok = await _ok(() => _n.deleteModel(lang: id));
        break;
      case 'song':
        ok = await _ok(() => _n.deleteWhisperModel(model: id));
        break;
      case 'sync':
        ok = await _ok(() => _n.deleteWhisperModel(model: syncModelFor(id)));
        break;
      default:
        return false;
    }
    // بسته‌ی همگام‌سازی همان مدلِ Whisper است؛ در حساب هم با نامِ 'song' ثبت می‌شود
    if (ok) {
      onPackDeleted?.call(kind == 'sync' ? 'song' : kind,
          kind == 'sync' ? syncModelFor(id) : id);
    }
    return ok;
  }

  static Future<bool> packSetEnabled(String kind, String id, bool enabled) {
    if (!_n.isSupported) return Future.value(false);
    switch (kind) {
      case 'tts':
        return _ok(() => _n.setTtsEnabled(enabled: enabled));
      case 'song':
        return _ok(() => _n.setSttEngine(
              engine: enabled ? 'whisper' : 'sherpa',
              model: id,
            ));
      default:
        return Future.value(false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // زیرنویس زنده‌ی یوتیوب (نیازمند «دسترسی به اعلان‌ها»)
  // ═══════════════════════════════════════════════════════════
  static Future<bool> ytCheckAccess() async {
    if (!_n.isSupported) return false;
    try {
      final r = await _n.ytCheckAccess();
      return r['granted'] == true;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> ytRequestAccess() {
    if (!_n.isSupported) return Future.value(false);
    return _ok(() => _n.ytRequestAccess());
  }

  static Future<bool> ytLoginOpen() {
    if (!_n.isSupported) return Future.value(false);
    return _ok(() => _n.ytLoginOpen());
  }

  static Future<bool> ytLoggedIn() async {
    if (!_n.isSupported) return false;
    try {
      final r = await _n.ytLoginStatus();
      return r['loggedIn'] == true;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> ytSetEnabled(bool enabled) {
    if (!_n.isSupported) return Future.value(false);
    return _ok(() => _n.ytSetEnabled(enabled: enabled));
  }

  // ═══════════════════════════════════════════════════════════
  // Live Translator (ترجمه‌ی زنده‌ی صدا)
  // ═══════════════════════════════════════════════════════════
  static Future<void> startLiveTranslator({
    required String sourceLang,
    required String targetLang,
  }) async {
    if (!_n.isSupported) return;
    _listen();
    _sourceLang = sourceLang;
    _uiLang = targetLang;
    await _n.showBubble(
      targetLang: targetLang,
      sourceLang: sourceLang,
      targetLangs: _targetLangs,
    );
  }

  static Future<void> stopLiveTranslator() async {
    if (!_n.isSupported) return;
    await _ok(() => _n.hideBubble());
  }

  // ═══════════════════════════════════════════════════════════
  // Translation (ترجمه‌ی متن، آفلاین با ML Kit)
  // ═══════════════════════════════════════════════════════════
  static Future<String?> translateText({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    if (!_n.isSupported) return null;
    try {
      final r = await _n.mlkitTranslate(
        text: text,
        src: sourceLang,
        tgt: targetLang,
      );
      final t = r['text'];
      return t is String ? t : null;
    } on PlatformException {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // TTS (خواندن با صدای نیتیو): اول Piper، اگه نبود موتور سیستم
  // ═══════════════════════════════════════════════════════════
  static Future<void> speak({
    required String text,
    required String lang,
  }) async {
    if (!_n.isSupported) return;
    _listen();
    try {
      await _n.speak(text: text, lang: lang);
    } on PlatformException {
      try {
        await _n.speakSystem(text: text, lang: lang);
      } on PlatformException {
        // نادیده
      }
    }
  }

  static Future<void> stopSpeaking() async {
    if (!_n.isSupported) return;
    await _ok(() => _n.stopSpeaking());
  }

  // ═══════════════════════════════════════════════════════════
  // YouTube (زیرنویس) — سمت اندروید به‌صورت متدِ جدا در دسترس نیست
  // (زیرنویس زنده از طریق حباب + ytSetEnabled کار می‌کند)
  // ═══════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>?> fetchYtCaptions(String url) async =>
      null;
}
