// همگام‌سازیِ متنِ داستان با صوتِ آپلودی — معادلِ audioSync.js در Hope.
//
//  • رونویسی روی گوشی (Whisper، همان بسته‌های دانلودشده) توسطِ جاوا انجام می‌شود و تکه‌تکه می‌رسد:
//    هر تکه = {متن، شروع، پایان}.
//  • اینجا هر تکه بلافاصله با جمله‌های داستان تطبیق داده می‌شود (IncrementalAligner)،
//    پس هر مقدار که همگام شد همان لحظه قابل‌استفاده است — کاربر منتظرِ پایانِ کلِ فایل نمی‌ماند.
//  • الگوریتمِ تطبیق (LCS وزن‌دار + لنگر + درون‌یابی) همان الگوریتمِ Hope است.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;

import '../native/native_bridge.dart';

// ───────────────────────── مدل‌ها ─────────────────────────

class SyncWord {
  final String w;
  final double s;
  final double e;
  const SyncWord(this.w, this.s, this.e);
}

class AlignOutcome {
  final bool ok;
  final double coverage; // ۰..۱
  final List<double> times; // ثانیه‌ی شروعِ هر جمله
  const AlignOutcome(this.ok, this.coverage, this.times);
}

class PartialOutcome {
  /// هم‌اندازه‌ی جمله‌ها؛ null = هنوز همگام نشده
  final List<double?> times;
  final int upto; // آخرین جمله‌ی همگام‌شده
  const PartialOutcome(this.times, this.upto);
}

// ───────────────────────── نرمال‌سازی ─────────────────────────

final RegExp _kDiacritics = RegExp('[\u064B-\u065F\u0670\u0640]');
final RegExp _kNonWord = RegExp(r"[^\p{L}\p{N}']+", unicode: true);
final RegExp _kCjk = RegExp('[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af\u0e00-\u0e7f]');

String _norm(String s) {
  var x = s.toLowerCase();
  x = x
      .replaceAll(_kDiacritics, '')
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('`', "'")
      .replaceAll(_kNonWord, '');
  while (x.startsWith("'")) {
    x = x.substring(1);
  }
  while (x.endsWith("'")) {
    x = x.substring(0, x.length - 1);
  }
  return x;
}

/// متن → توکن‌های نرمال‌شده (زبان‌های بدونِ فاصله مثل چینی/ژاپنی: هر نویسه یک توکن).
List<String> _tokens(String text) {
  final out = <String>[];
  for (final piece in text.split(RegExp(r'\s+'))) {
    if (piece.isEmpty) continue;
    if (_kCjk.hasMatch(piece)) {
      for (final r in piece.runes) {
        final n = _norm(String.fromCharCode(r));
        if (n.isNotEmpty) out.add(n);
      }
    } else {
      final n = _norm(piece);
      if (n.isNotEmpty) out.add(n);
    }
  }
  return out;
}

bool _lev1(String a, String b) {
  if (a == b) return true;
  final la = a.length, lb = b.length;
  if ((la - lb).abs() > 1 || (la < lb ? la : lb) < 4) return false;
  var i = 0;
  while (i < la && i < lb && a[i] == b[i]) {
    i++;
  }
  if (la == lb) return a.substring(i + 1) == b.substring(i + 1);
  if (la > lb) return a.substring(i + 1) == b.substring(i);
  return a.substring(i) == b.substring(i + 1);
}

int _wgt(String a, String b) {
  final base = a.length < 8 ? a.length : 8;
  if (a == b) return 2 + base;
  if (_lev1(a, b)) return 1 + (base >> 1);
  return 0;
}

// ───────────────────────── تکه‌ی رونویسی → کلمه‌ها با زمان ─────────────────────────

final RegExp _kPauseEnd = RegExp(r'[.!?…؟۔。！？;:؛]$');
final RegExp _kSoftEnd = RegExp(r'[,،、]$');

/// متنِ یک پنجره (با زمانِ شروع/پایانِ کلِ پنجره) → کلمه‌هایی با زمانِ تخمینی.
/// زمان به نسبتِ طولِ کلمه پخش می‌شود و بعدِ نقطه/ویرگول کمی «مکث» حساب می‌شود.
List<SyncWord> expandChunk(String text, double start, double end) {
  final toks = text.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (toks.isEmpty) return const [];
  final span = (end - start) < 0.2 ? 0.2 : (end - start);
  final weights = <double>[
    for (final t in toks)
      (t.length < 1 ? 1 : t.length).toDouble() +
          (_kPauseEnd.hasMatch(t) ? 3.0 : (_kSoftEnd.hasMatch(t) ? 1.2 : 0.0))
  ];
  final total = weights.fold<double>(0, (a, b) => a + b);
  final out = <SyncWord>[];
  var cur = start;
  for (var i = 0; i < toks.length; i++) {
    final d = span * weights[i] / total;
    out.add(SyncWord(toks[i], cur, cur + d));
    cur += d;
  }
  return out;
}

// ───────────────────────── تطبیقِ تدریجی ─────────────────────────

class IncrementalAligner {
  IncrementalAligner(List<String> sentences) : _sentences = sentences {
    for (var si = 0; si < sentences.length; si++) {
      _firstTok.add(_t.length);
      for (final tk in _tokens(sentences[si])) {
        _t.add(tk);
      }
    }
    _matchTime = List<double?>.filled(_t.length, null);
    _matchEnd = List<double?>.filled(_t.length, null);
  }

  final List<String> _sentences;
  final List<String> _t = [];
  final List<int> _firstTok = [];
  late final List<double?> _matchTime;
  late final List<double?> _matchEnd;
  int _cursor = 0; // اولین توکنِ متن که هنوز رد نشده
  int _fails = 0;
  int matched = 0;
  int _wordsSeen = 0;

  int get tokenCount => _t.length;
  double get coverage =>
      _t.isEmpty ? 0 : matched / _t.length;

  /// یک تکه (کلمه‌های پنجره) را با متن تطبیق می‌دهد. true = چیزی جدید جور شد.
  bool addChunk(List<SyncWord> words) {
    final R = <String>[];
    final Rs = <double>[];
    final Re = <double>[];
    for (final w in words) {
      for (final tk in _tokens(w.w)) {
        R.add(tk);
        Rs.add(w.s);
        Re.add(w.e);
      }
    }
    final m = R.length;
    final N = _t.length;
    if (m == 0 || N == 0) return false;
    _wordsSeen += m;

    // پنجره‌ی جستجو در متن: از کمی عقبِ مکانِ فعلی تا چند برابرِ طولِ تکه؛ با شکست‌های پشت‌سرهم بازتر می‌شود
    final int from = (_cursor - 30).clamp(0, N).toInt();
    int span = 2 * m + 60;
    if (_fails > 0) span = span * (1 + _fails * 2);
    int to = from + span;
    if (_fails >= 4 || to > N) to = N;
    if ((to - from) * m > 36000000) to = from + (36000000 ~/ m);
    if (to <= from) return false;

    final r = _lcs(_t, from, to, R, Rs, Re);
    final pairs = r.pairs; // (ایندکسِ توکنِ متن، ایندکسِ کلمه)
    if (pairs.isEmpty || pairs.length / m < 0.25) {
      _fails++;
      return false;
    }
    var fresh = 0;
    var last = -1;
    for (final p in pairs) {
      final ti = p[0], rj = p[1];
      if (_matchTime[ti] == null) {
        _matchTime[ti] = Rs[rj];
        _matchEnd[ti] = Re[rj];
        matched++;
        fresh++;
      }
      if (ti > last) last = ti;
    }
    _fails = 0;
    if (last + 1 > _cursor) _cursor = last + 1;
    return fresh > 0;
  }

  /// نتیجه‌ی نیمه‌کاره: فقط جمله‌هایی که تا الان واقعاً با صدا جور شدن زمان دارن.
  PartialOutcome? partial(double duration) {
    if (matched < 4) return null;
    final r = _times(duration);
    if (r.anchored < 0) return null;
    final ts = <double?>[
      for (var i = 0; i < r.times.length; i++) i <= r.anchored ? r.times[i] : null
    ];
    return PartialOutcome(ts, r.anchored);
  }

  AlignOutcome finish(double duration) {
    if (_t.isEmpty || matched == 0) {
      return const AlignOutcome(false, 0, []);
    }
    final r = _times(duration);
    return AlignOutcome(coverage >= 0.3, coverage, r.times);
  }

  // لنگرها → زمانِ شروعِ جمله‌ها (پورتِ مستقیمِ alignSentences در Hope)
  _TimesResult _times(double duration) {
    final S = _sentences.length;
    final N = _t.length;
    const avgWord = 0.35;
    final anchor = List<double?>.filled(S, null);
    for (var si = 0; si < S; si++) {
      final from = _firstTok[si];
      final to = si + 1 < S ? _firstTok[si + 1] : N;
      for (var k = from; k < to; k++) {
        final mt = _matchTime[k];
        if (mt != null) {
          anchor[si] = mt - (k - from) * avgWord;
          break;
        }
      }
    }
    int cnt(int si) {
      final c = (si + 1 < S ? _firstTok[si + 1] : N) - _firstTok[si];
      return c < 1 ? 1 : c;
    }

    final times = List<double>.filled(S, 0);
    var a = -1;
    for (var si = 0; si < S; si++) {
      final an = anchor[si];
      if (an == null) continue;
      final t1 = an < 0 ? 0.0 : an;
      final t0 = a >= 0 ? (anchor[a]! < 0 ? 0.0 : anchor[a]!) : 0.0;
      final gapStart = a + 1;
      if (si - gapStart > 0) {
        var total = 0;
        for (var k = a < 0 ? 0 : a; k < si; k++) {
          total += cnt(k);
        }
        var acc = a < 0 ? 0 : cnt(a);
        for (var k = gapStart; k < si; k++) {
          times[k] = t0 + ((t1 - t0) * acc) / total;
          acc += cnt(k);
        }
      }
      times[si] = t1;
      a = si;
    }
    if (a < 0) {
      for (var si = 0; si < S; si++) {
        times[si] = N == 0 ? 0 : (duration * _firstTok[si]) / N;
      }
    } else if (a < S - 1) {
      final tl = anchor[a]! < 0 ? 0.0 : anchor[a]!;
      double lastEnd = tl;
      for (var k = N - 1; k >= 0; k--) {
        if (_matchEnd[k] != null) {
          lastEnd = _matchEnd[k]!;
          break;
        }
      }
      var endT = (duration > 0 ? (duration < lastEnd + 2 ? duration : lastEnd + 2) : lastEnd + 2);
      if (endT < tl + 1) endT = tl + 1;
      var total = 0;
      for (var k = a; k < S; k++) {
        total += cnt(k);
      }
      var acc = cnt(a);
      for (var k = a + 1; k < S; k++) {
        times[k] = tl + ((endT - tl) * acc) / total;
        acc += cnt(k);
      }
    }
    // یکنواخت، کمی زودتر از شروعِ واقعی، حداقل ۰٫۱۵ ثانیه فاصله
    const lead = 0.2;
    var run = 0.0;
    for (var si = 0; si < S; si++) {
      var t = times[si] - (si == 0 ? 0 : lead);
      if (t < 0) t = 0;
      if (duration > 0 && t > duration) t = duration;
      run = si == 0 ? 0 : (t > run + 0.15 ? t : run + 0.15);
      times[si] = (run * 100).round() / 100;
    }
    if (S > 0) times[0] = 0;
    return _TimesResult(times, a);
  }
}

class _TimesResult {
  final List<double> times;
  final int anchored;
  _TimesResult(this.times, this.anchored);
}

class _LcsResult {
  final List<List<int>> pairs;
  _LcsResult(this.pairs);
}

/// LCSِ وزن‌دار بینِ T[from..to) و R. خروجی: جفت‌های [ایندکسِ سراسریِ توکنِ متن، ایندکسِ کلمه].
_LcsResult _lcs(List<String> T, int from, int to, List<String> R,
    List<double> Rs, List<double> Re) {
  final n = to - from;
  final m = R.length;
  final w = m + 1;
  final dir = Uint8List((n + 1) * w); // 1=مچ، 2=بالا، 3=چپ
  var prev = Int32List(w);
  var cur = Int32List(w);
  for (var i = 1; i <= n; i++) {
    cur[0] = 0;
    final ti = T[from + i - 1];
    for (var j = 1; j <= m; j++) {
      var best = prev[j];
      var dd = 2;
      if (cur[j - 1] > best) {
        best = cur[j - 1];
        dd = 3;
      }
      final sc = _wgt(ti, R[j - 1]);
      if (sc > 0 && prev[j - 1] + sc >= best) {
        best = prev[j - 1] + sc;
        dd = 1;
      }
      cur[j] = best;
      dir[i * w + j] = dd;
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  final pairs = <List<int>>[];
  var i = n, j = m;
  while (i > 0 && j > 0) {
    final dd = dir[i * w + j];
    if (dd == 1) {
      pairs.add([from + i - 1, j - 1]);
      i--;
      j--;
    } else if (dd == 2) {
      i--;
    } else {
      j--;
    }
  }
  return _LcsResult(pairs.reversed.toList());
}

// ───────────────────────── اجرای کارِ نیتیو ─────────────────────────

class AudioSyncJob {
  AudioSyncJob({
    required this.sentences,
    required this.durationSec,
    required this.onPartial,
    required this.onProgress,
    required this.onDone,
    required this.onError,
  }) : _aligner = IncrementalAligner(sentences);

  final List<String> sentences;

  /// مدتِ صوت (ثانیه) — لحظه‌ای خوانده می‌شود.
  final double Function() durationSec;
  final void Function(PartialOutcome part) onPartial;
  final void Function(double frac) onProgress;
  final void Function(AlignOutcome result) onDone;

  /// code: NO_MODEL | NO_AUDIO | ENGINE | FAILED
  final void Function(String code) onError;

  final IncrementalAligner _aligner;
  StreamSubscription<NativeEvent>? _sub;
  String _job = '';
  bool _closed = false;

  Future<void> start({
    required String path,
    required String lang,
    required String model,
  }) async {
    final n = NativeBridge.instance;
    if (!n.isSupported) {
      _fail('FAILED');
      return;
    }
    _job = 'sync-${DateTime.now().microsecondsSinceEpoch}';
    _sub = n.events.listen(_onEvent, onError: (Object _) {});
    try {
      await n.syncTranscribe(job: _job, path: path, lang: lang, model: model);
    } on PlatformException catch (e) {
      final m = '${e.message}';
      _fail(m.contains('NO_MODEL')
          ? 'NO_MODEL'
          : m.contains('NO_AUDIO')
              ? 'NO_AUDIO'
              : 'FAILED');
    } catch (_) {
      _fail('FAILED');
    }
  }

  void _onEvent(NativeEvent e) {
    if (_closed) return;
    final d = e.data;
    if (d['job'] != _job) return;
    switch (e.name) {
      case 'syncChunk':
        final text = (d['text'] ?? '').toString();
        final s = (d['start'] as num?)?.toDouble() ?? 0;
        final en = (d['end'] as num?)?.toDouble() ?? s + 1;
        final frac = (d['frac'] as num?)?.toDouble() ?? 0;
        final changed = _aligner.addChunk(expandChunk(text, s, en));
        onProgress(frac);
        if (changed) {
          final p = _aligner.partial(durationSec());
          if (p != null) onPartial(p);
        }
        break;
      case 'syncDone':
        _close();
        onDone(_aligner.finish(durationSec()));
        break;
      case 'syncError':
        _fail((d['code'] ?? 'FAILED').toString());
        break;
    }
  }

  void _fail(String code) {
    if (_closed) return;
    _close();
    onError(code);
  }

  void _close() {
    _closed = true;
    _sub?.cancel();
    _sub = null;
  }

  /// لغوِ کاربر (بدونِ فراخوانیِ onError).
  Future<void> cancel() async {
    if (_closed) return;
    _close();
    try {
      await NativeBridge.instance.syncTranscribeCancel();
    } catch (_) {}
  }
}
