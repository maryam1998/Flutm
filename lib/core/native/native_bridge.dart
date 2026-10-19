import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

/// رویدادی که از جاوا می‌رسه (مثلاً ttsSpeakDone، modelDownloadProgress، wordQueued، authCallback).
class NativeEvent {
  final String name;
  final Map<String, dynamic> data;
  const NativeEvent(this.name, this.data);
  @override
  String toString() => 'NativeEvent($name, $data)';
}

/// پلِ دارت ⟷ کدِ native اندروید (BubblePlugin).
/// هر متد دقیقاً هم‌نامِ متدِ @PluginMethod در جاواست.
/// روی وب/iOS هیچ کاری نمی‌کنه و یک Map خالی برمی‌گردونه.
class NativeBridge {
  NativeBridge._();
  static final NativeBridge instance = NativeBridge._();

  static const _method = MethodChannel('com.linglearn.app/bubble');
  static const _events = EventChannel('com.linglearn.app/bubble_events');

  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<NativeEvent>? _stream;

  /// همه‌ی رویدادها (broadcast). با `.where((e) => e.name == 'ttsSpeakDone')` فیلتر کن.
  Stream<NativeEvent> get events {
    if (!isSupported) return const Stream.empty();
    return _stream ??= _events.receiveBroadcastStream().map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final d = m['data'];
      return NativeEvent(
        m['event'] as String,
        d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{},
      );
    }).asBroadcastStream();
  }

  /// فقط یک نوع رویداد.
  Stream<Map<String, dynamic>> on(String name) =>
      events.where((e) => e.name == name).map((e) => e.data);

  Future<Map<String, dynamic>> _call(String method,
      [Map<String, dynamic>? args]) async {
    if (!isSupported) return <String, dynamic>{};
    final r = await _method.invokeMethod<dynamic>(method, args);
    if (r is Map) return Map<String, dynamic>.from(r);
    return <String, dynamic>{};
  }

  // ═══════════ متدها (هم‌نامِ BubblePlugin.java) ═══════════
  Future<Map<String, dynamic>> openExternal({String? url}) =>
      _call('openExternal', {if (url != null) 'url': url});

  Future<Map<String, dynamic>> openApp({String? pkg}) =>
      _call('openApp', {if (pkg != null) 'pkg': pkg});

  Future<Map<String, dynamic>> checkPermission() => _call('checkPermission');

  Future<Map<String, dynamic>> requestPermission() => _call('requestPermission');

  Future<Map<String, dynamic>> showBubble({String? targetLang, String? sourceLang, String? translationTone, List<dynamic>? targetLangs}) =>
      _call('showBubble', {if (targetLang != null) 'targetLang': targetLang, if (sourceLang != null) 'sourceLang': sourceLang, if (translationTone != null) 'translationTone': translationTone, if (targetLangs != null) 'targetLangs': targetLangs});

  Future<Map<String, dynamic>> hideBubble() => _call('hideBubble');

  Future<Map<String, dynamic>> setLanguages({String? targetLang, String? sourceLang, String? translationTone, List<dynamic>? targetLangs}) =>
      _call('setLanguages', {if (targetLang != null) 'targetLang': targetLang, if (sourceLang != null) 'sourceLang': sourceLang, if (translationTone != null) 'translationTone': translationTone, if (targetLangs != null) 'targetLangs': targetLangs});

  Future<Map<String, dynamic>> setPanelFont({String? font}) =>
      _call('setPanelFont', {if (font != null) 'font': font});

  Future<Map<String, dynamic>> setUiLang({String? lang}) =>
      _call('setUiLang', {if (lang != null) 'lang': lang});

  Future<Map<String, dynamic>> setDisplayMode({String? mode}) =>
      _call('setDisplayMode', {if (mode != null) 'mode': mode});

  Future<Map<String, dynamic>> setPanelColor({String? color}) =>
      _call('setPanelColor', {if (color != null) 'color': color});

  Future<Map<String, dynamic>> magnifierStart({String? targetLang, String? sourceLang, List<dynamic>? targetLangs}) =>
      _call('magnifierStart', {if (targetLang != null) 'targetLang': targetLang, if (sourceLang != null) 'sourceLang': sourceLang, if (targetLangs != null) 'targetLangs': targetLangs});

  Future<Map<String, dynamic>> magnifierStop() => _call('magnifierStop');

  Future<Map<String, dynamic>> magnifierIsRunning() => _call('magnifierIsRunning');

  Future<Map<String, dynamic>> isRunning() => _call('isRunning');

  Future<Map<String, dynamic>> ytCheckAccess() => _call('ytCheckAccess');

  Future<Map<String, dynamic>> ytRequestAccess() => _call('ytRequestAccess');

  Future<Map<String, dynamic>> ytLoginOpen() => _call('ytLoginOpen');

  Future<Map<String, dynamic>> ytLoginStatus() => _call('ytLoginStatus');

  Future<Map<String, dynamic>> ytSetEnabled({bool? enabled, num? offsetMs}) =>
      _call('ytSetEnabled', {if (enabled != null) 'enabled': enabled, if (offsetMs != null) 'offsetMs': offsetMs});

  Future<Map<String, dynamic>> ytIsActive() => _call('ytIsActive');

  Future<Map<String, dynamic>> ytSavedList() => _call('ytSavedList');

  Future<Map<String, dynamic>> ytSavedAck({List<dynamic>? items}) =>
      _call('ytSavedAck', {if (items != null) 'items': items});

  Future<Map<String, dynamic>> wordQueueList() => _call('wordQueueList');

  Future<Map<String, dynamic>> wordQueueAck({List<dynamic>? items}) =>
      _call('wordQueueAck', {if (items != null) 'items': items});

  Future<Map<String, dynamic>> ytSeek({num? ms}) =>
      _call('ytSeek', {if (ms != null) 'ms': ms});

  Future<Map<String, dynamic>> checkModelStatus({String? lang}) =>
      _call('checkModelStatus', {if (lang != null) 'lang': lang});

  Future<Map<String, dynamic>> cancelModelDownload() => _call('cancelModelDownload');

  Future<Map<String, dynamic>> downloadModel({String? lang}) =>
      _call('downloadModel', {if (lang != null) 'lang': lang});

  Future<Map<String, dynamic>> deleteModel({String? lang}) =>
      _call('deleteModel', {if (lang != null) 'lang': lang});

  Future<Map<String, dynamic>> setSttEngine({String? engine, String? model}) =>
      _call('setSttEngine', {if (engine != null) 'engine': engine, if (model != null) 'model': model});

  Future<Map<String, dynamic>> getWhisperStatus() => _call('getWhisperStatus');

  Future<Map<String, dynamic>> downloadWhisperModel({String? model}) =>
      _call('downloadWhisperModel', {if (model != null) 'model': model});

  Future<Map<String, dynamic>> cancelWhisperDownload() => _call('cancelWhisperDownload');

  Future<Map<String, dynamic>> deleteWhisperModel({String? model}) =>
      _call('deleteWhisperModel', {if (model != null) 'model': model});

  /// همگام‌سازیِ صوتِ آپلودی: فایل را پنجره‌پنجره با Whisper رونویسی می‌کند.
  /// رویدادها: syncChunk {job,text,start,end,frac} / syncDone {job} / syncError {job,code,error}
  Future<Map<String, dynamic>> syncTranscribe(
          {required String job, required String path, String? lang, String? model}) =>
      _call('syncTranscribe', {
        'job': job,
        'path': path,
        if (lang != null) 'lang': lang,
        if (model != null) 'model': model,
      });

  Future<Map<String, dynamic>> syncTranscribeCancel() => _call('syncTranscribeCancel');

  Future<Map<String, dynamic>> setTtsEnabled({bool? enabled}) =>
      _call('setTtsEnabled', {if (enabled != null) 'enabled': enabled});

  Future<Map<String, dynamic>> checkTtsStatus({String? lang}) =>
      _call('checkTtsStatus', {if (lang != null) 'lang': lang});

  Future<Map<String, dynamic>> getTtsCatalog() => _call('getTtsCatalog');

  Future<Map<String, dynamic>> downloadTtsModel({String? lang}) =>
      _call('downloadTtsModel', {if (lang != null) 'lang': lang});

  Future<Map<String, dynamic>> cancelTtsDownload({String? lang}) =>
      _call('cancelTtsDownload', {if (lang != null) 'lang': lang});

  Future<Map<String, dynamic>> cancelAllTtsDownloads() => _call('cancelAllTtsDownloads');

  Future<Map<String, dynamic>> deleteTtsModel({String? lang}) =>
      _call('deleteTtsModel', {if (lang != null) 'lang': lang});

  Future<Map<String, dynamic>> speak({String? text, String? lang, String? id, num? speed}) =>
      _call('speak', {if (text != null) 'text': text, if (lang != null) 'lang': lang, if (id != null) 'id': id, if (speed != null) 'speed': speed});

  Future<Map<String, dynamic>> preloadTts({String? lang}) =>
      _call('preloadTts', {if (lang != null) 'lang': lang});

  Future<Map<String, dynamic>> prefetchTts({String? text, String? lang, num? speed}) =>
      _call('prefetchTts', {if (text != null) 'text': text, if (lang != null) 'lang': lang, if (speed != null) 'speed': speed});

  Future<Map<String, dynamic>> checkSystemTts({String? lang}) =>
      _call('checkSystemTts', {if (lang != null) 'lang': lang});

  Future<Map<String, dynamic>> speakSystem({String? text, String? lang, String? id, num? speed}) =>
      _call('speakSystem', {if (text != null) 'text': text, if (lang != null) 'lang': lang, if (id != null) 'id': id, if (speed != null) 'speed': speed});

  Future<Map<String, dynamic>> stopSpeaking() => _call('stopSpeaking');

  Future<Map<String, dynamic>> releaseTts() => _call('releaseTts');

  Future<Map<String, dynamic>> mlkitStatus({String? src, String? tgt}) =>
      _call('mlkitStatus', {if (src != null) 'src': src, if (tgt != null) 'tgt': tgt});

  Future<Map<String, dynamic>> mlkitDownload({String? src, String? tgt, bool? wifiOnly}) =>
      _call('mlkitDownload', {if (src != null) 'src': src, if (tgt != null) 'tgt': tgt, if (wifiOnly != null) 'wifiOnly': wifiOnly});

  Future<Map<String, dynamic>> mlkitTranslate({String? text, String? src, String? tgt}) =>
      _call('mlkitTranslate', {if (text != null) 'text': text, if (src != null) 'src': src, if (tgt != null) 'tgt': tgt});

  Future<Map<String, dynamic>> mlkitDelete({String? lang}) =>
      _call('mlkitDelete', {if (lang != null) 'lang': lang});

  Future<Map<String, dynamic>> mlkitSetEnabled({bool? enabled}) =>
      _call('mlkitSetEnabled', {if (enabled != null) 'enabled': enabled});
}
