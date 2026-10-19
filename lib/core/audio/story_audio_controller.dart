// صوتِ آپلودیِ کاربر برای یک داستان — معادلِ useStoryUserAudio.js + storyAudioDb.js در Hope.
//
//  • فایلِ صوتی (هر حجمی) داخلِ پوشه‌ی برنامه روی خودِ گوشی کپی می‌شود؛ جایی ارسال نمی‌شود.
//  • پخش/توقف، پرش، سرعتِ 0.5×–2× (سراسری)، تکرارِ A-B، جمله‌ی قبل/بعد.
//  • همگام‌سازیِ متن با صدا: زمانِ شروعِ هر جمله ذخیره می‌شود و هایلایت هنگامِ پخش جلو می‌رود.
//    زمان‌ها یا با «علامت‌گذاریِ دستی» (هنگامِ گوش دادن) ساخته می‌شوند یا با «تخمینِ خودکار»
//    یا با «همگام‌سازیِ خودکار» (Whisper روی گوشی؛ تدریجی — هر بخش که آماده شد همان لحظه اجرا می‌شود).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bridge/linlearn_bridge.dart';
import 'audio_sync_service.dart';

enum AbState { idle, waitingB, looping }

const String _kMetaPrefix = 'zflut-story-audio::';
const String _kTimesPrefix = 'zflut-sync-times::';
const String _kRateKey = 'zflut-user-audio-rate';
const String _kFollowKey = 'zflut-sync-follow';
const String _kSyncModelKey = 'syncModelSize'; // همان کلیدِ تنظیمات (fast | balanced)

class StoryAudioController extends ChangeNotifier {
  StoryAudioController({
    required this.storyKey,
    required List<String> sentences,
    required this.prefs,
    this.langCode = 'en',
  }) : _sentences = sentences {
    _rate = (prefs.getDouble(_kRateKey) ?? 1).clamp(0.5, 2.0).toDouble();
    _syncOn = prefs.getBool(_kFollowKey) ?? true;
    _loadTimes();
    unawaited(_restore());
  }

  final String storyKey;
  final SharedPreferences prefs;
  List<String> _sentences;

  /// زبانِ داستان (برای Whisper)
  String langCode;
  String _audioPath = '';

  AudioPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;
  bool _disposed = false;

  // ───── وضعیت ─────
  bool hasAudio = false;
  String fileName = '';
  bool saving = false;
  String error = '';
  bool isPlaying = false;
  Duration duration = Duration.zero;
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  double _rate = 1;
  double get rate => _rate;
  int activeIndex = 0;

  bool _syncOn = true;
  bool get syncOn => _syncOn;
  List<double?>? syncTimes; // ثانیه؛ null = هنوز همگام نشده

  // ───── همگام‌سازیِ خودکار (Whisper) ─────
  bool syncBuilding = false;
  double syncFrac = 0;

  /// '' | 'need_pack' | 'failed' | 'coverage:<درصد>'
  String syncError = '';
  AudioSyncJob? _syncJob;

  AbState abState = AbState.idle;
  double? abA;
  double? abB;

  int get sentenceCount => _sentences.length;

  /// وقتی متنِ داستان (تعدادِ جمله‌ها) عوض شد (مثلاً OCRِ تدریجی).
  void updateSentences(List<String> s) {
    if (s.length == _sentences.length) {
      _sentences = s;
      return;
    }
    _sentences = s;
    if (syncBuilding) unawaited(cancelSyncBuild(restore: false, notify: false));
    _loadTimes();
    if (activeIndex >= s.length) activeIndex = s.isEmpty ? 0 : s.length - 1;
    // عمداً notify نمی‌کنیم: این تابع از داخلِ build صدا زده می‌شه.
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ───── ذخیره/بازیابی ─────
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/story_audio');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<void> _restore() async {
    if (kIsWeb) return;
    try {
      final raw = prefs.getString('$_kMetaPrefix$storyKey');
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final path = (m['path'] ?? '').toString();
      if (path.isEmpty || !await File(path).exists()) {
        await prefs.remove('$_kMetaPrefix$storyKey');
        return;
      }
      await _load(path, (m['name'] ?? '').toString());
    } catch (_) {}
  }

  Future<void> _load(String path, String name) async {
    final p = _player ?? AudioPlayer();
    _player = p;
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _stateSub?.cancel();
    final d = await p.setFilePath(path);
    _audioPath = path;
    await p.setSpeed(_rate);
    duration = d ?? Duration.zero;
    fileName = name;
    hasAudio = true;
    _posSub = p.positionStream.listen(_onTime);
    _durSub = p.durationStream.listen((d) {
      if (d != null && d != duration) {
        duration = d;
        _notify();
      }
    });
    _stateSub = p.playerStateStream.listen((st) {
      final playing = st.playing && st.processingState != ProcessingState.completed;
      if (st.processingState == ProcessingState.completed) {
        p.pause();
        p.seek(Duration.zero);
      }
      if (playing != isPlaying) {
        isPlaying = playing;
        _notify();
      }
    });
    _notify();
  }

  /// انتخابِ فایلِ صوتی از گوشی و وصل کردن به این داستان.
  Future<void> pickAndAttach() async {
    if (kIsWeb) {
      error = 'آپلودِ صوت فقط در اپِ موبایل کار می‌کنه';
      _notify();
      return;
    }
    if (saving) return;
    error = '';
    await cancelSyncBuild(restore: false);
    FilePickerResult? res;
    try {
      res = await FilePicker.platform
          .pickFiles(type: FileType.audio, allowMultiple: false, withData: false);
    } catch (_) {
      error = 'انتخابِ فایل انجام نشد';
      _notify();
      return;
    }
    final f = res?.files.isNotEmpty == true ? res!.files.first : null;
    if (f == null || f.path == null) return;
    saving = true;
    _notify();
    try {
      final dir = await _dir();
      final ext = f.name.contains('.') ? f.name.split('.').last : 'audio';
      final dest = '${dir.path}/${_safe(storyKey)}.$ext';
      // اگه قبلاً فایلِ دیگه‌ای بود پاکش کن
      await _deleteFiles();
      await File(f.path!).copy(dest);
      await prefs.setString(
          '$_kMetaPrefix$storyKey', jsonEncode({'path': dest, 'name': f.name}));
      await clearSync(notify: false);
      await _load(dest, f.name);
    } catch (_) {
      error = 'ذخیره‌ی فایل روی گوشی انجام نشد (شاید جا کم باشه)';
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<void> _deleteFiles() async {
    try {
      final raw = prefs.getString('$_kMetaPrefix$storyKey');
      if (raw != null) {
        final path = (jsonDecode(raw) as Map)['path']?.toString() ?? '';
        if (path.isNotEmpty && await File(path).exists()) {
          await File(path).delete();
        }
      }
    } catch (_) {}
  }

  Future<void> removeAudio() async {
    await cancelSyncBuild(restore: false);
    try {
      await _player?.stop();
    } catch (_) {}
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _stateSub?.cancel();
    await _player?.dispose();
    _player = null;
    await _deleteFiles();
    await prefs.remove('$_kMetaPrefix$storyKey');
    await clearSync(notify: false);
    hasAudio = false;
    _audioPath = '';
    isPlaying = false;
    fileName = '';
    duration = Duration.zero;
    position.value = Duration.zero;
    clearAB();
    _notify();
  }

  // ───── پخش ─────
  Future<void> play() async {
    if (!hasAudio) return;
    await _player?.play();
  }

  Future<void> pause() async => _player?.pause();

  Future<void> toggle() async => isPlaying ? pause() : play();

  Future<void> seek(Duration t) async {
    var x = t;
    if (x < Duration.zero) x = Duration.zero;
    if (duration > Duration.zero && x > duration) x = duration;
    await _player?.seek(x);
    position.value = x;
  }

  Future<void> skip(int seconds) => seek(position.value + Duration(seconds: seconds));

  Future<void> setRate(double r) async {
    _rate = r.clamp(0.5, 2.0).toDouble();
    await prefs.setDouble(_kRateKey, _rate);
    await _player?.setSpeed(_rate);
    _notify();
  }

  // ───── هر تیکِ پخش ─────
  void _onTime(Duration p) {
    position.value = p;
    final s = p.inMilliseconds / 1000.0;
    if (abState == AbState.looping && abA != null && abB != null && s >= abB!) {
      _player?.seek(Duration(milliseconds: (abA! * 1000).round()));
      return;
    }
    final ts = syncTimes;
    if (_syncOn && ts != null) {
      final idx = sentenceIndexAt(ts, s);
      if (idx != activeIndex) {
        activeIndex = idx;
        _notify();
      }
    }
  }

  // ───── جمله‌ی قبل/بعد ─────
  Future<void> setActiveLine(int i, {bool seekAudio = true}) async {
    if (_sentences.isEmpty) return;
    activeIndex = i.clamp(0, _sentences.length - 1);
    _notify();
    if (seekAudio) await _syncSeek(activeIndex);
  }

  Future<void> nextLine() => setActiveLine(activeIndex + 1);
  Future<void> prevLine() => setActiveLine(activeIndex - 1);

  Future<void> _syncSeek(int idx) async {
    final ts = syncTimes;
    if (!_syncOn || ts == null || idx >= ts.length || ts[idx] == null) return;
    await seek(Duration(milliseconds: (ts[idx]! * 1000).round()));
  }

  // ───── A-B ─────
  void markAB() {
    final t = position.value.inMilliseconds / 1000.0;
    if (abState == AbState.idle) {
      abA = t;
      abState = AbState.waitingB;
    } else if (abState == AbState.waitingB) {
      var a = abA!, b = t;
      if (b <= a) {
        b = a;
        a = t;
      }
      abA = a;
      abB = b;
      abState = AbState.looping;
    } else {
      clearAB();
      return;
    }
    _notify();
  }

  void clearAB() {
    abA = null;
    abB = null;
    abState = AbState.idle;
    _notify();
  }

  // ───── همگام‌سازی ─────
  void _loadTimes() {
    final raw = prefs.getString('$_kTimesPrefix$storyKey');
    if (raw == null) {
      syncTimes = null;
      return;
    }
    try {
      final l = (jsonDecode(raw) as List).map((e) {
        final v = (e as num).toDouble();
        return v < 0 ? null : v;
      }).toList();
      syncTimes = l.length == _sentences.length ? l : null;
    } catch (_) {
      syncTimes = null;
    }
  }

  Future<void> _saveTimes() async {
    final ts = syncTimes;
    if (ts == null) {
      await prefs.remove('$_kTimesPrefix$storyKey');
    } else {
      await prefs.setString(
          '$_kTimesPrefix$storyKey', jsonEncode([for (final v in ts) v ?? -1]));
    }
  }

  int get syncedCount => syncTimes?.where((e) => e != null).length ?? 0;

  /// «علامت‌گذاریِ دستی»: همین لحظه = شروعِ جمله‌ی فعال؛ بعد خط می‌رود جمله‌ی بعد.
  Future<void> markCurrentLine() async {
    if (_sentences.isEmpty || !hasAudio || syncBuilding) return;
    final ts = syncTimes ?? List<double?>.filled(_sentences.length, null);
    ts[activeIndex] = position.value.inMilliseconds / 1000.0;
    syncTimes = ts;
    await _saveTimes();
    if (activeIndex < _sentences.length - 1) activeIndex++;
    _notify();
  }

  /// «تخمینِ خودکار»: زمانِ هر جمله متناسب با طولِ متنش بینِ کلِ مدتِ صدا پخش می‌شود
  /// (دقیق نیست؛ برای شروعِ سریع. بعدش می‌شود با علامت‌گذاریِ دستی دقیقش کرد).
  Future<void> estimateSync() async {
    if (_sentences.isEmpty || duration == Duration.zero || syncBuilding) return;
    final lens = [for (final s in _sentences) s.trim().length.clamp(1, 100000)];
    final total = lens.fold<int>(0, (a, b) => a + b);
    final totalSec = duration.inMilliseconds / 1000.0;
    var acc = 0;
    final ts = <double?>[];
    for (final l in lens) {
      ts.add(totalSec * acc / total);
      acc += l;
    }
    syncTimes = ts;
    await _saveTimes();
    _notify();
  }

  Future<void> clearSync({bool notify = true}) async {
    if (syncBuilding) await cancelSyncBuild(restore: false);
    syncError = '';
    syncTimes = null;
    await prefs.remove('$_kTimesPrefix$storyKey');
    if (notify) _notify();
  }

  // ───── همگام‌سازیِ خودکار با Whisper (تدریجی) ─────
  /// جمله‌ی فعال را از روی زمانِ فعلیِ صدا تنظیم می‌کند (وقتی «دنبال کن» روشن است).
  void _applyAt(double sec) {
    final ts = syncTimes;
    if (!_syncOn || ts == null) return;
    final idx = sentenceIndexAt(ts, sec);
    if (idx != activeIndex) activeIndex = idx;
  }

  /// فایلِ صوتی روی خودِ گوشی رونویسی می‌شود؛ هر بخش که آماده شد همان لحظه
  /// هایلایت/پرش با آن کار می‌کند و لازم نیست کاربر تا پایانِ کار صبر کند.
  Future<void> buildSync() async {
    if (syncBuilding || !hasAudio || _sentences.isEmpty || _audioPath.isEmpty) return;
    syncError = '';
    if (kIsWeb) {
      syncError = 'failed';
      _notify();
      return;
    }
    final saved = prefs.getString(_kSyncModelKey);
    final size = (saved == 'fast' || saved == 'balanced') ? saved! : 'balanced';

    // از همین لحظه «در حال کار» حساب می‌شود (تا دوبارزدن دو کار را همزمان شروع نکند)
    final prevTimes = syncTimes;
    syncBuilding = true;
    syncFrac = 0;
    _notify();

    final ready = await LinLearnBridge.syncPackReady(size);
    if (_disposed) return;
    if (!syncBuilding) return; // وسطِ بررسی لغو شد
    if (!ready) {
      syncBuilding = false;
      syncError = 'need_pack';
      _notify();
      return;
    }

    final job = AudioSyncJob(
      sentences: List<String>.from(_sentences),
      durationSec: () => duration.inMilliseconds / 1000.0,
      onPartial: (part) {
        if (_disposed || _syncJob == null) return;
        // بخشِ همگام‌شده همین الان قابل‌استفاده است
        syncTimes = part.times;
        _syncOn = true;
        _applyAt(position.value.inMilliseconds / 1000.0);
        _notify();
      },
      onProgress: (f) {
        if (_disposed || _syncJob == null) return;
        syncFrac = f.clamp(0.0, 1.0).toDouble();
        _notify();
      },
      onDone: (res) async {
        _syncJob = null;
        syncBuilding = false;
        if (_disposed) return;
        if (!res.ok) {
          syncTimes = prevTimes;
          syncError = 'coverage:${(res.coverage * 100).round()}';
        } else {
          syncTimes = [for (final t in res.times) t];
          _syncOn = true;
          await _saveTimes();
          _applyAt(position.value.inMilliseconds / 1000.0);
        }
        _notify();
      },
      onError: (code) {
        _syncJob = null;
        syncBuilding = false;
        if (_disposed) return;
        syncTimes = prevTimes;
        syncError = code == 'NO_MODEL' ? 'need_pack' : 'failed';
        _notify();
      },
    );
    _syncJob = job;
    await job.start(
      path: _audioPath,
      lang: langCode,
      model: LinLearnBridge.syncModelFor(size),
    );
  }

  /// لغوِ همگام‌سازیِ در حال اجرا. restore=true → زمان‌های نیمه‌کاره دور ریخته و حالتِ قبل برمی‌گردد.
  Future<void> cancelSyncBuild({bool restore = true, bool notify = true}) async {
    if (!syncBuilding && _syncJob == null) return;
    final job = _syncJob;
    _syncJob = null;
    syncBuilding = false;
    syncFrac = 0;
    if (restore) _loadTimes();
    if (notify) _notify();
    await job?.cancel();
  }

  Future<void> setSyncOn(bool v) async {
    _syncOn = v;
    await prefs.setBool(_kFollowKey, v);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    final j = _syncJob;
    _syncJob = null;
    if (j != null) unawaited(j.cancel());
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
    position.dispose();
    super.dispose();
  }
}

/// ایندکسِ جمله‌ای که در ثانیه‌ی [t] پخش می‌شود (آخرین جمله‌ی همگام‌شده با زمانِ ≤ t).
int sentenceIndexAt(List<double?> times, double t) {
  var best = 0;
  for (var i = 0; i < times.length; i++) {
    final v = times[i];
    if (v != null && v <= t + 0.05) best = i;
  }
  return best;
}
