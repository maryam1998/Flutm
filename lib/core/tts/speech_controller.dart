import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import 'native_tts_bridge.dart';
import 'sentence_splitter.dart';
import 'speech_state.dart';
import 'tts_config.dart';

enum _WebResult { done, cancelled, noVoice, failed }

/// هر بار که یک جمله/لغت «کامل خوانده شد» (خوانش اول و هر تکرار) این رویداد
/// فرستاده می‌شود — پایه‌ی اتصالِ پلیر به «مسیر عصبی» و تقویم.
class ChunkPlayedEvent {
  /// کلیدِ پخشِ کل (locale::fullText) — با PlayerTrack.key قابل‌مقایسه است
  final String? key;
  final String code;

  /// متنِ همین جمله/لغت
  final String text;

  /// آفستِ شروعِ این جمله در متنِ کامل
  final int charOffset;
  final int chunkIndex;
  const ChunkPlayedEvent({
    required this.key,
    required this.code,
    required this.text,
    required this.charOffset,
    required this.chunkIndex,
  });
}

/// نتیجه‌ی یک بار خوانش با Web Speech
enum _Once { ok, silent, noStart, cancelled, failed }

class SpeechController extends StateNotifier<SpeechState> {
  /// [voicePref]: صدای ذخیره‌شده‌ی کاربر برای یک زبان (نام صدا) — اختیاری
  SpeechController({
    String? Function(String lang)? voicePref,
    void Function(ChunkPlayedEvent e)? onChunkPlayed,
    bool Function()? preferPhoneVoice,
  })  : _voicePref = voicePref,
        _onChunkPlayed = onChunkPlayed,
        _preferPhoneVoice = preferPhoneVoice,
        super(const SpeechState()) {
    _initLocalTts();
    // فهرست صداها پیش از اولین تپ در پس‌زمینه گرم شود (خوانشِ ترجمه‌ها تأخیر نداشته باشد)
    unawaited(_warmVoices());
    // ⚡ مدل‌های دانلودیِ Piper همان اولِ کار لود و گرم شوند (اولین خوانش بی‌تأخیر)
    unawaited(NativeTtsBridge.preload());
  }

  final String? Function(String lang)? _voicePref;
  final void Function(ChunkPlayedEvent e)? _onChunkPlayed;
  /// تنظیمات ← «صدای خوانش»: true = همیشه TTS خودِ گوشی (نه بسته‌ی Piper)
  final bool Function()? _preferPhoneVoice;
  List<Map<String, String>> _voices = [];

  // صدایی که برای هر زبان واقعاً شنیده شد (اولویتِ اول دفعه‌ی بعد) و صداهایی
  // که اخیراً بی‌صدا خواندند (چند دقیقه کنار گذاشته می‌شوند).
  final Map<String, String> _goodVoice = {};
  final Map<String, DateTime> _deadVoices = {};
  static const _deadVoiceTtl = Duration(minutes: 3);
  final DateTime _createdAt = DateTime.now();
  DateTime _lastStopAt = DateTime.fromMillisecondsSinceEpoch(0);

  final FlutterTts _localTts = FlutterTts();
  final AudioPlayer _onlinePlayer = AudioPlayer();

  String _fullText = '';
  List<TextChunk> _chunks = [];
  int _chunkIndex = 0;
  String? _currentKey;
  String? _currentCode;

  /// پخشِ «کل متن» با loop (مثل options.loop در Hope) و مرزهای آیتم‌ها
  bool _loop = false;
  List<int>? _boundaries;
  int _generation = 0;
  bool _disposed = false;

  // منتظرهای «پایان خوانش» — هر کدوم مخصوص یک خوانش‌اند و با stop/pause
  // کنسل می‌شن تا هیچ زنجیره‌ی قدیمی‌ای بعداً ناخواسته چیزی پخش نکنه.
  Completer<bool>? _nativeWaiter;
  Completer<bool>? _webWaiter;
  Completer<bool>? _onlineWaiter;
  int _utteranceSeq = 0;

  /// ttsDone ای که id نداره و زودتر از این مدت بعد از شروع برسه، مال
  /// خوانشِ قبلی (متوقف‌شده) حساب می‌شه، نه خوانش فعلی.
  static const _staleDoneGuard = Duration(milliseconds: 150);

  // صف: لیست متن‌های هم‌زبان (مثلاً خطوط یک مکالمه) تا «قبلی/بعدی» در لبه‌ی
  // جمله‌ها به آیتم قبلی/بعدی برود.
  List<String> _queue = [];
  int _queueIndex = -1;

  // A-B
  String _abState = 'idle';
  int? _abChunkA;
  int? _abChunkB;

  // شمارنده‌ی «چندبار این جمله تا الان خونده شده» (شامل خوانش اول)
  final Map<int, int> _chunkRepeatsDone = {};

  Future<void> _initLocalTts() async {
    // ⚠️ هر فراخوانی جداگانه try/catch دارد: قبلاً اگر setSharedInstance
    // (فقط iOS) روی وب خطا می‌داد، بقیه‌ی تنظیمات هم نادیده می‌ماند.
    if (!kIsWeb) {
      try {
        await _localTts.setSharedInstance(true);
      } catch (e) {
        debugPrint('setSharedInstance error: $e');
      }
    }
    try {
      // پایان خوانش را با completion handler می‌فهمیم، نه با awaitSpeakCompletion.
      await _localTts.awaitSpeakCompletion(false);
    } catch (e) {
      debugPrint('awaitSpeakCompletion error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // API عمومی
  // ═══════════════════════════════════════════════════════════════

  Future<String> toggle(
    String text,
    String code, {
    int? startCharOffset,
    List<String>? queue,
    int? queueIndex,
    bool loop = false,
    List<int>? sentenceBoundaries,
  }) async {
    if (text.isEmpty) return 'unsupported';

    final newKey = '${TtsConfig.locale[code] ?? 'en-US'}::$text';

    // همان متن، در حال پخش → pause
    if (_currentKey == newKey && state.status == SpeechStatus.playing) {
      await _pause();
      return 'ok';
    }

    // همان متن، paused → resume
    if (_currentKey == newKey && state.status == SpeechStatus.paused) {
      _generation++;
      state = state.copyWith(status: SpeechStatus.playing);
      unawaited(_playFrom(_chunkIndex));
      return 'ok';
    }

    // متن جدید
    await _startText(
      text,
      code,
      startCharOffset: startCharOffset,
      queue: queue,
      queueIndex: queueIndex,
      loop: loop,
      sentenceBoundaries: sentenceBoundaries,
    );
    return 'ok';
  }

  Future<void> _startText(
    String text,
    String code, {
    int? startCharOffset,
    List<String>? queue,
    int? queueIndex,
    bool startAtEnd = false,
    bool loop = false,
    List<int>? sentenceBoundaries,
  }) async {
    final newKey = '${TtsConfig.locale[code] ?? 'en-US'}::$text';
    _generation++;
    await _stopAll();

    _fullText = text;
    _loop = loop;
    _boundaries = sentenceBoundaries;
    _chunks = SentenceSplitter.split(text, boundaries: sentenceBoundaries);
    _chunkRepeatsDone.clear();
    _currentKey = newKey;
    _currentCode = code;
    _queue = queue ?? const [];
    _queueIndex = queue == null ? -1 : (queueIndex ?? -1);

    var startIdx = startCharOffset != null && startCharOffset > 0
        ? _chunkIndexForOffset(startCharOffset)
        : 0;
    if (startAtEnd && _chunks.isNotEmpty) startIdx = _chunks.length - 1;

    _chunkIndex = startIdx;
    _abState = 'idle';
    _abChunkA = null;
    _abChunkB = null;

    state = state.copyWith(
      key: newKey,
      total: _chunks.length,
      chunkIndex: startIdx,
      charOffset: _chunks.isEmpty ? 0 : _chunks[startIdx].start,
      abState: 'idle',
      clearAB: true,
      clearError: true,
      hasPrev: _hasPrev(startIdx),
      hasNext: _hasNext(startIdx),
    );

    unawaited(_playFrom(startIdx));
  }

  bool _hasPrev(int chunkIdx) => chunkIdx > 0 || _queueIndex > 0;

  bool _hasNext(int chunkIdx) =>
      chunkIdx + 1 < _chunks.length ||
      (_queueIndex >= 0 && _queueIndex + 1 < _queue.length);

  /// دکمه‌ی پلی/توقف خودِ پلیر — بدون parse کردن key (که با '::' داخل متن خراب می‌شد)
  Future<void> togglePlayPause() async {
    final key = _currentKey;
    if (key == null || _fullText.isEmpty) return;
    await toggle(
      _fullText,
      _currentCode ?? 'en',
      queue: _queue.isEmpty ? null : _queue,
      queueIndex: _queue.isEmpty ? null : _queueIndex,
      loop: _loop,
      sentenceBoundaries: _boundaries,
    );
  }

  Future<void> stop() async {
    _generation++;
    await _stopAll();
    _fullText = '';
    _chunks = [];
    _chunkIndex = 0;
    _chunkRepeatsDone.clear();
    _currentKey = null;
    _currentCode = null;
    _loop = false;
    _boundaries = null;
    _abState = 'idle';
    _abChunkA = null;
    _abChunkB = null;
    _queue = [];
    _queueIndex = -1;
    state = state.copyWith(
      status: SpeechStatus.idle,
      hasPrev: false,
      hasNext: false,
      clearKey: true,
      chunkIndex: 0,
      charOffset: 0,
      total: 0,
      abState: 'idle',
      clearAB: true,
      clearError: true,
    );
  }

  Future<void> seekToChunk(int idx) async {
    if (_chunks.isEmpty) return;
    final clamped = idx.clamp(0, _chunks.length - 1);
    _generation++;
    await _stopAll();
    // با جابجایی دستی، شمارنده‌ی تکرار از صفر شروع شود
    _chunkRepeatsDone.clear();
    _chunkIndex = clamped;
    state = state.copyWith(
      chunkIndex: clamped,
      charOffset: _chunks[clamped].start,
      status: SpeechStatus.playing,
      hasPrev: _hasPrev(clamped),
      hasNext: _hasNext(clamped),
    );
    unawaited(_playFrom(clamped));
  }

  /// جمله‌ی بعد؛ اگر آخرین جمله بود و صف داریم → آیتم بعدیِ صف
  Future<void> nextChunk() async {
    if (_chunks.isEmpty) return;
    if (_chunkIndex + 1 < _chunks.length) {
      await seekToChunk(_chunkIndex + 1);
      return;
    }
    final code = _currentCode;
    if (code != null && _queueIndex >= 0 && _queueIndex + 1 < _queue.length) {
      final i = _queueIndex + 1;
      await _startText(_queue[i], code, queue: _queue, queueIndex: i);
      return;
    }
    // آخرِ متن: از اول ادامه بده (دکمه‌ی «بعدی» همیشه کار می‌کند)
    await seekToChunk(0);
  }

  /// جمله‌ی قبل؛ اگر اولین جمله بود و صف داریم → آخرین جمله‌ی آیتم قبلی
  Future<void> prevChunk() async {
    if (_chunks.isEmpty) return;
    if (_chunkIndex > 0) {
      await seekToChunk(_chunkIndex - 1);
      return;
    }
    final code = _currentCode;
    if (code != null && _queueIndex > 0) {
      final i = _queueIndex - 1;
      await _startText(_queue[i], code,
          queue: _queue, queueIndex: i, startAtEnd: true);
      return;
    }
    // اولین جمله: همان جمله را از اول بخوان (دکمه‌ی «قبلی» همیشه کار می‌کند)
    await seekToChunk(0);
  }

  Future<void> setRate(double r) async {
    final clamped = r.clamp(0.25, 2.0);
    state = state.copyWith(rate: clamped);
    try {
      await _localTts.setSpeechRate(clamped);
      await _onlinePlayer.setSpeed(clamped);
    } catch (_) {}
  }

  Future<void> toggleMuted() async {
    final muted = !state.muted;
    state = state.copyWith(muted: muted);
    try {
      await _localTts.setVolume(muted ? 0.0 : 1.0);
      await _onlinePlayer.setVolume(muted ? 0.0 : 1.0);
    } catch (_) {}
  }

  /// چرخه تکرار: 0 → 2 → 3 → ∞ → 0
  /// (مثل Hope: «N بار کلاً» روی هر جمله؛ ∞ = همین جمله تا وقتی خودت
  /// «بعدی» را بزنی یا خاموشش کنی)
  void cycleRepeat() {
    final order = [0, 2, 3, -1];
    final i = order.indexOf(state.globalRepeat);
    final next = order[(i + 1) % order.length];
    debugPrint('🔁 cycleRepeat: ${state.globalRepeat} → $next');
    state = state.copyWith(globalRepeat: next);
  }

  void markAB() {
    if (_chunks.isEmpty) return;
    if (_abState == 'idle') {
      _abChunkA = _chunkIndex;
      _abState = 'waitingB';
    } else if (_abState == 'waitingB') {
      if (_chunkIndex < (_abChunkA ?? 0)) {
        _abChunkB = _abChunkA;
        _abChunkA = _chunkIndex;
      } else {
        _abChunkB = _chunkIndex;
      }
      _abState = 'looping';
    } else {
      _abState = 'idle';
      _abChunkA = null;
      _abChunkB = null;
    }
    // ✅ قبلاً state.copyWith() خالی بود و دکمه‌ی A-B هیچ‌وقت تغییر نمی‌کرد
    if (_abState == 'idle') {
      state = state.copyWith(abState: 'idle', clearAB: true);
    } else {
      state = state.copyWith(
        abState: _abState,
        abChunkA: _abChunkA,
        abChunkB: _abChunkB,
      );
    }
  }

  /// ایندکسِ جمله‌ای که این آفستِ کاراکتری داخلِ آن است
  /// (معادل chunkIndexForOffset در Hope).
  int chunkIndexForOffset(int offset) => _chunkIndexForOffset(offset);

  int getChunkCount() => _chunks.length;
  String getChunkText(int idx) =>
      (idx >= 0 && idx < _chunks.length) ? _chunks[idx].text : '';
  String get fullText => _fullText;
  int get currentChunk => _chunkIndex;

  /// مرزِ جمله‌های متنِ در حال پخش + طولِ کلِ متن — برای نوارِ پیشرفتِ پلیر
  /// و پرشِ چندثانیه‌ای (معادل getChunksMeta / getFullTextLength در Hope).
  List<TextChunk> get chunksMeta => _chunks;
  int get fullTextLength => _fullText.length;

  // ═══════════════════════════════════════════════════════════════
  // داخلی
  // ═══════════════════════════════════════════════════════════════

  /// همه‌ی منتظرهای پایان خوانش را با false آزاد می‌کند.
  void _cancelWaiters() {
    for (final c in [_nativeWaiter, _webWaiter, _onlineWaiter]) {
      if (c != null && !c.isCompleted) c.complete(false);
    }
    _nativeWaiter = null;
    _webWaiter = null;
    _onlineWaiter = null;
  }

  Future<void> _pause() async {
    _generation++;
    _cancelWaiters();
    _lastStopAt = DateTime.now();
    try {
      await _localTts.stop();
      await NativeTtsBridge.stop();
      await _onlinePlayer.pause();
    } catch (_) {}
    state = state.copyWith(status: SpeechStatus.paused);
  }

  Future<void> _stopAll() async {
    _cancelWaiters();
    _lastStopAt = DateTime.now();
    try {
      await _localTts.stop();
      await NativeTtsBridge.stop();
      await _onlinePlayer.stop();
    } catch (_) {}
  }

  Future<void> _playFrom(int idx) async {
    if (_disposed) return;
    if (idx >= _chunks.length) {
      // رسیدن به آخرِ متن: با loop (پخشِ کلِ لیست/مکالمه، مثل Hope) یا تکرارِ ∞
      // از اول ادامه می‌دهد.
      if ((state.globalRepeat == -1 || _loop) && _chunks.isNotEmpty) {
        _chunkRepeatsDone.clear();
        unawaited(_playFrom(0));
        return;
      }
      _chunkIndex = 0;
      state = state.copyWith(
          status: SpeechStatus.idle, chunkIndex: 0, charOffset: 0);
      return;
    }

    final myGen = _generation;
    _chunkIndex = idx;
    state = state.copyWith(
      chunkIndex: idx,
      charOffset: _chunks[idx].start,
      status: SpeechStatus.playing,
      total: _chunks.length,
      clearError: true,
      hasPrev: _hasPrev(idx),
      hasNext: _hasNext(idx),
    );

    final chunk = _chunks[idx];
    final cleanText = SentenceSplitter.sanitize(chunk.text);
    // تکه‌ی بدون حرف/عدد (مثلاً فقط «.» یا «؟») صدایی ندارد → بی‌صدا رد شو
    if (cleanText.isEmpty ||
        !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(cleanText)) {
      unawaited(_playFrom(idx + 1));
      return;
    }

    final code = _currentCode ?? 'en';

    if (NativeTtsBridge.isAvailable) {
      // ۱. Piper نیتیو
      final ready = (_preferPhoneVoice?.call() ?? false)
          ? false
          : await NativeTtsBridge.isModelReady(code);
      if (myGen != _generation) return;
      if (ready) {
        final ok = await _playNative(idx, cleanText, code, myGen);
        // ✅ اگر وسط کار pause/stop/seek شد، هرگز سراغ موتور بعدی نرو
        // (قبلاً بعد از pause، موتور بعدی خوانش قدیمی را ناخواسته پخش می‌کرد)
        if (myGen != _generation) return;
        if (ok) return;
      }

      // ۲. TTS خود گوشی
      final okSys = await _playSystemTts(idx, cleanText, code, myGen);
      if (myGen != _generation) return;
      if (okSys) return;
    }

    // ۳. Web Speech / Edge
    if (myGen != _generation) return;
    await _playOnline(idx, cleanText, code, myGen);
  }

  /// خوانش با موتور نیتیو و انتظار برای رویداد پایان.
  /// true = خوانده و به مرحله‌ی «مکث + تکرار» رفت؛ false = شکست یا لغو.
  Future<bool> _speakNativeAndWait({
    required Future<bool> Function(String id) speakFn,
    required int idx,
    required String text,
    required int myGen,
    void Function()? onStarted,
  }) async {
    try {
      final id = 'f${++_utteranceSeq}';
      final waiter = Completer<bool>();
      _nativeWaiter = waiter;
      final startedAt = DateTime.now();

      NativeTtsBridge.onDone((doneId, ok) {
        if (waiter.isCompleted || !identical(_nativeWaiter, waiter)) return;
        if (doneId != null && doneId != id) return; // مال خوانش قبلی
        if (doneId == null &&
            DateTime.now().difference(startedAt) < _staleDoneGuard) {
          return; // احتمالاً مال خوانش قبلیِ متوقف‌شده
        }
        waiter.complete(ok);
      });

      final started = await speakFn(id);
      if (myGen != _generation) return false;
      if (!started) return false;
      if (onStarted != null) {
        try {
          onStarted();
        } catch (_) {}
      }

      final finished = await waiter.future.timeout(
        Duration(seconds: 30 + text.length ~/ 10),
        onTimeout: () => true,
      );
      if (identical(_nativeWaiter, waiter)) _nativeWaiter = null;
      if (myGen != _generation) return false;
      if (!finished) return false;

      await _gapThenNext(idx, text, myGen);
      return true;
    } catch (e) {
      debugPrint('native speak error: $e');
      return false;
    }
  }

  Future<bool> _playNative(int idx, String text, String code, int myGen) {
    return _speakNativeAndWait(
      speakFn: (id) => NativeTtsBridge.speak(text, code, state.rate, id: id),
      idx: idx,
      text: text,
      myGen: myGen,
      // جمله‌ی بعدی را همین حین که این یکی پخش می‌شود آماده کن (بعد از شروعِ پخش، تا خوانشِ فعلی کند نشود)
      onStarted: () => _prefetchNext(idx, code),
    );
  }

  void _prefetchNext(int idx, String code) {
    final n = idx + 1;
    if (n >= _chunks.length) return;
    final t = SentenceSplitter.sanitize(_chunks[n].text);
    if (t.isEmpty || !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(t)) return;
    unawaited(NativeTtsBridge.prefetch(t, code, state.rate));
  }

  Future<bool> _playSystemTts(int idx, String text, String code, int myGen) {
    return _speakNativeAndWait(
      speakFn: (id) =>
          NativeTtsBridge.speakSystem(text, code, state.rate, id: id),
      idx: idx,
      text: text,
      myGen: myGen,
    );
  }

  /// یک‌بار خواندنِ فهرست صداها (بدون هیچ انتظار/تکرار).
  Future<List<Map<String, String>>> _readVoicesOnce() async {
    try {
      final raw = await _localTts.getVoices;
      if (raw is List && raw.isNotEmpty) {
        return raw
            .whereType<Map>()
            .map((m) => {
                  'name': '${m['name'] ?? ''}',
                  'locale': '${m['locale'] ?? m['lang'] ?? ''}',
                })
            .where((m) => m['name']!.isNotEmpty && m['locale']!.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('getVoices error: $e');
    }
    return const [];
  }

  /// فهرست صداهای دستگاه/مرورگر (مثل getCachedVoices در Hope): از کش
  /// می‌خواند؛ فقط با force دوباره از موتور می‌پرسد. هرگز منتظر نمی‌ماند —
  /// پر شدنِ فهرست کارِ [_warmVoices] در پس‌زمینه است.
  Future<List<Map<String, String>>> _loadVoices({bool force = false}) async {
    if (!force && _voices.isNotEmpty) return _voices;
    final list = await _readVoicesOnce();
    if (list.isNotEmpty) _voices = list;
    return _voices;
  }

  /// پیش‌گرم‌کردنِ فهرست صداها همان اولِ کار (معادل refreshVoiceCache +
  /// voiceschanged در Hope). کروم فهرست را دیر و تکه‌تکه کامل می‌کند؛ اگر
  /// اولین خوانشِ ترجمه منتظرش بماند، چند ثانیه تأخیر/سکوت می‌شود. اینجا
  /// پیش از اولین تپِ کاربر، در پس‌زمینه پرش می‌کنیم.
  Future<void> _warmVoices() async {
    for (var i = 0; i < 12 && !_disposed; i++) {
      await _loadVoices(force: true);
      if (_voices.isNotEmpty && i >= 3) break;
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  String _normLocale(String l) => l.toLowerCase().replaceAll('_', '-');

  static String _voiceKey(Map<String, String> v) =>
      '${v['name']}|${v['locale']}';

  bool _isDead(Map<String, String> v) {
    final t = _deadVoices[_voiceKey(v)];
    if (t == null) return false;
    if (DateTime.now().difference(t) > _deadVoiceTtl) {
      _deadVoices.remove(_voiceKey(v));
      return false;
    }
    return true;
  }

  /// صداهای مناسب برای زبان، به ترتیبِ اولویت (مثل getBestVoice در Hope):
  /// صدایی که قبلاً واقعاً شنیده شد > صدای ذخیره‌شده‌ی کاربر > هم‌locale دقیق >
  /// کیفیت (neural/wavenet/...) > Google > بقیه. صدایی که اخیراً «بی‌صدا»
  /// خوانده (مثلاً صدای آنلاینِ Google بدون اینترنت) کنار گذاشته می‌شود.
  /// null = فهرست صداها نامعلوم (هنوز خالی)؛ لیست خالی = مطمئنیم صدایی
  /// برای این زبان نیست.
  Future<List<Map<String, String>>?> _voiceCandidates(
      String locale, String code) async {
    var voices = await _loadVoices();
    // فقط اگر فهرست هنوز کاملاً خالیه (ثانیه‌های اول) کوتاه صبر می‌کنیم
    for (var i = 0; i < 3 && voices.isEmpty; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      voices = await _loadVoices(force: true);
    }
    if (voices.isEmpty) return null;

    final prefix = _normLocale(locale).split('-').first;
    final wanted = _normLocale(locale);
    List<Map<String, String>> findMatching(List<Map<String, String>> all) =>
        all.where((v) {
          final l = _normLocale(v['locale']!);
          return l == prefix || l.startsWith('$prefix-');
        }).toList();

    var matching = findMatching(voices);
    if (matching.isEmpty) {
      // فهرست ممکنه هنوز ناقص باشه؛ فقط در ثانیه‌های اولِ برنامه کمی صبر
      // می‌کنیم، بعدش بی‌درنگ نتیجه می‌گیریم (دیگر تأخیر ندارد).
      final young = DateTime.now().difference(_createdAt) <
          const Duration(seconds: 6);
      for (var i = 0; i < (young ? 2 : 1) && matching.isEmpty; i++) {
        if (young) await Future.delayed(const Duration(milliseconds: 250));
        voices = await _loadVoices(force: true);
        matching = findMatching(voices);
      }
    }
    matching.removeWhere(_isDead);
    if (matching.isEmpty) return const [];

    final saved = _voicePref?.call(code);
    final good = _goodVoice[code];
    const quality = [
      'neural', 'wavenet', 'chirp', 'studio', 'natural', 'premium',
      'enhanced', 'polyglot',
    ];
    final genderRe = RegExp('female|male', caseSensitive: false);

    int score(Map<String, String> v) {
      final name = v['name']!;
      final n = name.toLowerCase();
      var s = 0;
      if (good != null && name == good) s -= 10000;
      if (saved != null && saved.isNotEmpty && name == saved) s -= 9000;
      if (_normLocale(v['locale']!) == wanted) s -= 5;
      final qi = quality.indexWhere((k) => n.contains(k));
      if (qi >= 0) {
        s -= (genderRe.hasMatch(name) ? 100 : 60) - qi;
      } else if (n.contains('google')) {
        s -= 20;
      }
      return s;
    }

    final scored = <MapEntry<int, Map<String, String>>>[
      for (var i = 0; i < matching.length; i++)
        MapEntry(score(matching[i]) * 1000 + i, matching[i]),
    ]..sort((a, b) => a.key.compareTo(b.key));
    return scored.map((e) => e.value).toList();
  }

  /// یک بار خواندنِ [text] با صدای [voice] (null = فقط با زبان) و تشخیصِ
  /// نتیجه: خوانده شد / بی‌صدا تمام شد / اصلاً شروع نشد / لغو / خطا.
  Future<_Once> _speakWebOnce(
    String text,
    String locale,
    Map<String, String>? voice,
    int myGen,
  ) async {
    final waiter = Completer<bool>();
    _webWaiter = waiter;
    var started = false;

    // پایان خوانش را با handler می‌فهمیم (نه awaitSpeakCompletion که روی
    // وب فعال نمی‌شد و تکرار، خوانش‌ها را پشت سر هم داخل صف مرورگر می‌ریخت).
    _localTts.setStartHandler(() {
      started = true;
    });
    _localTts.setCompletionHandler(() {
      if (waiter.isCompleted || !identical(_webWaiter, waiter)) return;
      waiter.complete(true);
    });
    _localTts.setCancelHandler(() {
      // cancel یعنی خودمان stop زدیم؛ _cancelWaiters کارش را کرده.
    });
    _localTts.setErrorHandler((msg) {
      if (waiter.isCompleted || !identical(_webWaiter, waiter)) return;
      final m = '$msg'.toLowerCase();
      if (m.contains('interrupted') || m.contains('cancel')) {
        return; // قطع‌شدن عمدیِ خودمان، خطا نیست
      }
      debugPrint('WebSpeech error event: $msg');
      waiter.complete(false);
    });

    await _localTts.setLanguage(voice?['locale'] ?? locale);
    if (voice != null) {
      await _localTts.setVoice({
        'name': voice['name']!,
        'locale': voice['locale']!,
      });
    }
    await _localTts.setSpeechRate(_engineRate(state.rate));
    await _localTts.setVolume(state.muted ? 0.0 : 1.0);
    await _localTts.setPitch(1.0);
    if (myGen != _generation) return _Once.cancelled;

    // کروم (به‌خصوص اندروید) بعد از cancel() اگر بلافاصله speak() شود،
    // گاهی بی‌صدا خوانش را می‌اندازد؛ فقط وقتی تازه stop زده‌ایم مکث می‌کنیم
    // (بین جمله‌های پشت‌سرهم دیگر هیچ تأخیرِ اضافه‌ای نیست).
    if (kIsWeb &&
        DateTime.now().difference(_lastStopAt) <
            const Duration(milliseconds: 400)) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (myGen != _generation) return _Once.cancelled;
    }

    final t0 = DateTime.now();
    await _localTts.speak(text);
    if (myGen != _generation) return _Once.cancelled;

    // اگر تا ۳ ثانیه هیچ شروعی گزارش نشد، خوانش بی‌صدا افتاده → شکست
    // (تا به‌جای سکوتِ طولانی، صدای بعدی/موتور بعدی امتحان شود).
    final early = await Future.any<bool?>([
      waiter.future,
      Future<bool?>.delayed(
        const Duration(milliseconds: 3000),
        () => (started || waiter.isCompleted) ? null : false,
      ),
    ]);
    if (myGen != _generation) return _Once.cancelled;
    if (early == false && !started) {
      if (identical(_webWaiter, waiter)) _webWaiter = null;
      try {
        await _localTts.stop();
      } catch (_) {}
      return _Once.noStart;
    }

    final finished = early ??
        await waiter.future.timeout(
          Duration(seconds: 20 + text.length ~/ 5),
          onTimeout: () => true,
        );
    if (myGen != _generation) return _Once.cancelled;
    if (identical(_webWaiter, waiter)) _webWaiter = null;
    if (!finished) return _Once.failed;

    // خوانشِ «بی‌صدا»: گاهی موتور (مثلاً صدای آنلاینِ Google وقتی اینترنت
    // نیست) رویداد پایان را تقریباً فوراً می‌فرستد بی‌آنکه چیزی پخش شود.
    // فقط برای متن‌های نه‌چندان کوتاه (لغتِ تک‌کلمه‌ای واقعاً می‌تواند خیلی
    // سریع تمام شود).
    final elapsedMs = DateTime.now().difference(t0).inMilliseconds;
    final minMs = (text.length * 15 / state.rate.clamp(0.25, 3.0))
        .clamp(250, 3000)
        .round();
    if (text.length >= 10 && elapsedMs < minMs) {
      debugPrint('silent utterance detected (${elapsedMs}ms)');
      return _Once.silent;
    }
    return _Once.ok;
  }

  Future<_WebResult> _playWebSpeech(
    int idx,
    String text,
    String code,
    int myGen,
  ) async {
    try {
      final locale = TtsConfig.locale[code] ?? 'en-US';

      // ✅ مثل Hope: صدای مخصوصِ همین زبان از بین صداهای نصب‌شده‌ی دستگاه.
      // اگر صدای اولی بی‌صدا یا بی‌شروع بود (مثلاً صدای آنلاین بدون
      // اینترنت)، همان لحظه صدای بعدیِ همان زبان را امتحان می‌کنیم؛ صدایی که
      // کار کرد برای دفعه‌های بعد حفظ می‌شود تا ترجمه‌ها بدون تأخیر بخوانند.
      final candidates = await _voiceCandidates(locale, code);
      if (myGen != _generation) return _WebResult.cancelled;
      if (candidates != null && candidates.isEmpty) return _WebResult.noVoice;

      // null = فهرست نامعلوم → بدون انتخابِ صدا فقط با زبان می‌خوانیم (مثل Hope)
      final List<Map<String, String>?> tries =
          candidates == null ? [null] : candidates.take(3).toList();

      for (var i = 0; i < tries.length; i++) {
        final voice = tries[i];
        final r = await _speakWebOnce(text, locale, voice, myGen);
        if (myGen != _generation || r == _Once.cancelled) {
          return _WebResult.cancelled;
        }
        if (r == _Once.ok) {
          if (voice != null) _goodVoice[code] = voice['name']!;
          await _gapThenNext(idx, text, myGen);
          return _WebResult.done;
        }
        // «بی‌صدا» همیشه کنار گذاشته می‌شود؛ «شروع‌نشده» فقط اگر صدای دیگری
        // برای امتحان مانده (تا صدای کُندِ لودشونده اشتباهی حذف نشود).
        if (voice != null &&
            (r == _Once.silent ||
                (r == _Once.noStart && i < tries.length - 1))) {
          _deadVoices[_voiceKey(voice)] = DateTime.now();
          if (_goodVoice[code] == voice['name']) _goodVoice.remove(code);
        }
        try {
          await _localTts.stop();
        } catch (_) {}
      }
      return _WebResult.failed;
    } catch (e) {
      debugPrint('WebSpeech error: $e');
      return _WebResult.failed;
    }
  }

  Future<void> _playOnline(
    int idx,
    String text,
    String code,
    int myGen,
  ) async {
    // اول TTS خودِ گوشی/مرورگر (مثل Hope) برای همه‌ی زبان‌ها، از جمله ترجمه‌ها.
    // فارسی/عربی: اگر صدایی روی گوشی هست همان؛ وگرنه (یا اگر شکست خورد)
    // سرویس آنلاین Edge. بقیه‌ی زبان‌ها: اگر صدای گوشی نبود، پیام می‌دهیم.
    final r = await _playWebSpeech(idx, text, code, myGen);
    if (myGen != _generation) return;
    switch (r) {
      case _WebResult.done:
      case _WebResult.cancelled:
        return;
      case _WebResult.noVoice:
        if (!TtsConfig.onlineOnly.contains(code)) {
          state = state.copyWith(
            status: SpeechStatus.idle,
            error: 'برای این زبان صدایی روی دستگاه نصب نیست؛ '
                'صدای آن را از تنظیمات دستگاه/مرورگر نصب کنید.',
          );
          return;
        }
        break; // فارسی/عربی → آنلاین
      case _WebResult.failed:
        // صدای گوشی شکست خورد → به‌جای بن‌بست، Edge آنلاین را امتحان کن
        break;
    }

    // Edge TTS از Worker
    final voice = TtsConfig.edgeVoice[code] ?? 'en-US-AriaNeural';
    final url = '${TtsConfig.backendUrl}/api/tts'
        '?voice=${Uri.encodeComponent(voice)}'
        '&text=${Uri.encodeComponent(text)}';

    StreamSubscription<PlayerState>? sub;
    try {
      await _onlinePlayer.stop();
      await _onlinePlayer.setUrl(url);
      await _onlinePlayer.setSpeed(state.rate);
      await _onlinePlayer.setVolume(state.muted ? 0.0 : 1.0);

      if (myGen != _generation) return;

      final waiter = Completer<bool>();
      _onlineWaiter = waiter;
      sub = _onlinePlayer.playerStateStream.listen((ps) {
        if (ps.processingState == ProcessingState.completed &&
            !waiter.isCompleted) {
          waiter.complete(true);
        }
      });

      unawaited(_onlinePlayer.play());
      final finished = await waiter.future;
      if (identical(_onlineWaiter, waiter)) _onlineWaiter = null;
      if (myGen != _generation) return;
      if (!finished) return;

      await _gapThenNext(idx, text, myGen);
    } catch (e) {
      debugPrint('Online TTS error: $e');
      if (myGen != _generation) return;
      state = state.copyWith(
        status: SpeechStatus.idle,
        error: 'خطا در پخش صدا',
      );
    } finally {
      await sub?.cancel();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // مکث + منطق تکرار (هم‌مفهوم با speechController.js در Hope)
  //   • تکرار روی «هر جمله» اعمال می‌شود، نه کل متن.
  //   • تنظیم N یعنی «کلاً N بار» (خوانش اول هم حساب است).
  //   • ∞ یعنی همین جمله دوباره و دوباره، تا کاربر «بعدی» بزند.
  // ═══════════════════════════════════════════════════════════════
  Future<void> _gapThenNext(int idx, String text, int myGen) async {
    // 🧬 این جمله همین الان کامل خوانده شد (خوانش اول یا یکی از تکرارها) →
    // به «مسیر عصبی» خبر بده. قبل از مکثِ بینِ جمله‌ها، تا اگر کاربر وسطِ
    // مکث pause کرد، تکرار از دست نرود.
    if (myGen == _generation && !_disposed && idx < _chunks.length) {
      try {
        _onChunkPlayed?.call(ChunkPlayedEvent(
          key: _currentKey,
          code: _currentCode ?? 'en',
          text: _chunks[idx].text,
          charOffset: _chunks[idx].start,
          chunkIndex: idx,
        ));
      } catch (e) {
        debugPrint('onChunkPlayed error: $e');
      }
    }
    final gap = _gapMs(chunk: text, rate: state.rate);
    await Future.delayed(Duration(milliseconds: gap));
    if (myGen != _generation || _disposed) return;

    // A-B looping
    if (_abState == 'looping' && _abChunkB != null && idx == _abChunkB) {
      final targetA = _abChunkA ?? 0;
      _chunkRepeatsDone.clear();
      unawaited(_playFrom(targetA));
      return;
    }

    // ═══ تکرار ═══
    final target = state.globalRepeat; // 0 | 2 | 3 | -1
    if (target != 0) {
      final done = _chunkRepeatsDone[idx] ?? 1; // تعداد دفعاتی که تا الان خونده شده
      final needRepeat = target == -1 || done < target;
      debugPrint(
          '🔁 repeat check: idx=$idx, done=$done, target=$target, needRepeat=$needRepeat');
      if (needRepeat) {
        _chunkRepeatsDone[idx] = done + 1;
        unawaited(_playFrom(idx));
        return;
      }
    }

    _chunkRepeatsDone.remove(idx);
    unawaited(_playFrom(idx + 1));
  }

  int _chunkIndexForOffset(int offset) {
    for (int i = _chunks.length - 1; i >= 0; i--) {
      if (offset >= _chunks[i].start) return i;
    }
    return 0;
  }

  /// سرعتِ مناسبِ موتورِ TTS گوشی/مرورگر (مثل engineRate در Hope).
  /// وب: زیر ۱ به بازه‌ی [0.2..1] نگاشت می‌شود. اندروید نیتیو (flutter_tts):
  /// مقیاس ۰..۱ است و ۰٫۵ سرعتِ عادی.
  double _engineRate(double r) {
    if (!kIsWeb) return (r * 0.5).clamp(0.05, 1.0);
    if (r >= 1) return r;
    return 0.2 + ((r - 0.25) / 0.75) * 0.8;
  }

  int _gapMs({required String chunk, required double rate}) {
    final trimmed = chunk.trimRight();
    final last = trimmed.isEmpty ? '' : trimmed[trimmed.length - 1];
    final base = switch (last) {
      '!' || '！' => 220,
      '?' || '؟' || '？' => 220,
      '…' => 260,
      _ => 180,
    };
    // مکثِ طبیعی: با سرعتِ بالا کمی کوتاه‌تر، با سرعتِ پایین حداکثر ۴۰۰ms
    return (base / rate.clamp(0.5, 2.0)).round().clamp(80, 400).toInt();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelWaiters();
    _localTts.stop();
    _onlinePlayer.dispose();
    super.dispose();
  }
}
