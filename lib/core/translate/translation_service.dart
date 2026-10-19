import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import '../storage/translation_cache_db.dart';

// ═══════════════════════════════════════════════════════════════════
// Translation Service — پورتِ دقیقِ translateService.js + callAI.js وب‌اپ
//
// زنجیره (دقیقاً مثل وب):
//   1. کش محلی (با چکِ looksLikelyMistranslated موقع خواندن)
//   2. صفِ سراسری (۱۰ کار هم‌زمان) + سقفِ زمانیِ ۱۵ ثانیه از لحظه‌ی «اجرا»
//   3. ۴ سرویس رایگان به‌صورت موازی (Google → MyMemory → Lingva → Libre)
//      با circuit breaker (۴ شکست پشت‌سرهم = ۴۵ ثانیه کنار)
//   4. کنترل کیفیت رایگان؛ فقط اگر مشکوک بود (یا forceVerify) → تأیید با AI
//   5. آخرین چاره: ترجمه با بک‌اند AI (Cloudflare Worker /api/generate)
// ═══════════════════════════════════════════════════════════════════

/// همان DEFAULT_BACKEND_URL وب‌اپ (app/ai/callAI.js)
const String kDefaultBackendUrl =
    'https://phrasebook-api.maryam-s-sharifiyan.workers.dev';

const int _kProviderFailThreshold = 4;
const int _kProviderBlockMs = 45 * 1000;
const int kGlobalTranslateConcurrency = 10;
const int _kHardTimeoutMs = 15000;
const int _kProviderTimeoutMs = 6000;
const int _kAiTimeoutMs = 10000;

/// نام انگلیسی زبان — برای پرامپت AI (همان englishLangName وب)
const Map<String, String> _englishNames = {
  'fa': 'Persian', 'en': 'English', 'it': 'Italian', 'hi': 'Hindi',
  'tr': 'Turkish', 'ar': 'Arabic', 'es': 'Spanish', 'de': 'German',
  'fr': 'French', 'zh': 'Chinese', 'ko': 'Korean', 'ru': 'Russian',
  'ja': 'Japanese',
};

String englishLangName(String code) => _englishNames[code] ?? code;

/// بازه‌ی یونیکد رسم‌الخط هر زبان — برای تشخیص «اصلاً ترجمه نشده»
final Map<String, RegExp> _scriptRegex = {
  'fa': RegExp(r'[\u0600-\u06FF]'),
  'ar': RegExp(r'[\u0600-\u06FF]'),
  'ru': RegExp(r'[\u0400-\u04FF]'),
  'zh': RegExp(r'[\u4E00-\u9FFF]'),
  'ja': RegExp(r'[\u3040-\u30FF\u4E00-\u9FFF]'),
  'ko': RegExp(r'[\uAC00-\uD7AF]'),
};

/// آیا متن به رسم‌الخطِ زبانِ [lang] است؟ (برای زبان‌های لاتین همیشه true —
/// تشخیصِ اسپانیایی از انگلیسی ممکن نیست). مثلاً معنیِ اسپانیاییِ یک لغتِ
/// شخصی نباید به‌عنوان ترجمه‌ی فارسی نشان داده شود.
bool textMatchesScript(String text, String lang) {
  final re = _scriptRegex[lang];
  if (re == null) return true;
  return re.hasMatch(text);
}

/// AI به‌جای ترجمه «فکر کردنش» را برگردانده؟
final RegExp aiReasoningRe = RegExp(
  r"(thinking process|here'?s a thinking|analy[sz]e the (request|text|input)|\*\*\s*analy[sz]e|\bconstraint\s*:|the user wants me to|let me (read|think|analy[sz]e|re-?read)|<\/?think(ing)?>|^\s*okay,? (so|let'?s|the user))",
  caseSensitive: false,
  multiLine: true,
);

bool looksLikeAIReasoning(String text) {
  if (text.isEmpty) return false;
  if (aiReasoningRe.hasMatch(text)) return true;
  final boldCount = RegExp(r'\*\*').allMatches(text).length;
  return boldCount >= 4 && RegExp(r'(^|\n|\s)\d\.\s').hasMatch(text);
}

/// خروجیِ مدل‌های «گارد/ایمنی» یا امتناع (مثلاً «User Safety: safe») که به‌جای
/// ترجمه برمی‌گردند — ترجمه حساب نمی‌شوند.
final RegExp _guardOutputRe = RegExp(
  r"^\s*(user\s+|assistant\s+)?safety\s*:|^\s*(safe|unsafe)\s*$|^\s*(i'?m sorry,? (but )?i (can'?t|cannot)|as an ai\b|sorry, i can'?t (help|assist|translate))",
  caseSensitive: false,
  multiLine: true,
);

bool looksLikeGuardOutput(String text) {
  final t = text.trim();
  return t.isNotEmpty && _guardOutputRe.hasMatch(t);
}

/// برچسبِ مدل‌های گارد («User Safety: unsafe» / «Safety Categories: …») — جواب نیست.
/// اگر Workerِ قدیمی این خروجی را فیلتر نکند، اینجا جلوی نمایشش گرفته می‌شود.
final RegExp _aiGuardRe = RegExp(
  r'^\s*((user|assistant)\s+)?safety(\s+categories)?\s*:|^\s*(safe|unsafe)\s*$',
  caseSensitive: false,
  multiLine: true,
);

/// <think>…</think> و مانندش را برمی‌دارد
String stripAIReasoning(String text) {
  return text
      .replaceAll(
          RegExp(r'<think(ing)?>[\s\S]*?<\/think(ing)?>', caseSensitive: false),
          '')
      .replaceAll(RegExp(r'<think(ing)?>[\s\S]*$', caseSensitive: false), '')
      .trim();
}

/// کنترل کیفیتِ سبک — همان looksLikelyMistranslated وب
bool looksLikelyMistranslated(
  String sourceText,
  String draft,
  String targetLang, {
  String sourceLang = 'auto',
}) {
  final src = sourceText.trim();
  final out = draft.trim();
  if (out.isEmpty) return true;
  if (looksLikeAIReasoning(out)) return true;
  if (looksLikeGuardOutput(out)) return true;

  // خروجی عیناً همان متن مبدأ است
  if (sourceLang.isNotEmpty &&
      sourceLang != 'auto' &&
      sourceLang != targetLang &&
      out.toLowerCase() == src.toLowerCase()) {
    return true;
  }

  // رسم‌الخط زبان مقصد در خروجی نیست
  final re = _scriptRegex[targetLang];
  if (re != null && src.length > 1 && !re.hasMatch(out)) return true;

  // منبع یک «کلمه‌ی تکی» است ولی خروجی یک جمله‌ی بلند (مثلاً MyMemory برای
  // «put» یک جمله‌ی بی‌ربط برمی‌گرداند) → مشکوک
  if (src.isNotEmpty && !RegExp(r'\s').hasMatch(src)) {
    final outWords = out.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (outWords > 4) return true;
  }

  // نسبت طولِ غیرعادی
  final ratio = out.length / (src.isEmpty ? 1 : src.length);
  if (src.length > 3 && (ratio < 0.25 || ratio > 3.5)) return true;

  return false;
}

String _stripQuotes(String s) =>
    s.replaceAll(RegExp("^[\"'«»]+|[\"'«».\\s]+\$"), '').trim();

// ═══════════════════════════════════════════════════════════════════
// Circuit breaker (سراسری)
// ═══════════════════════════════════════════════════════════════════
final Map<String, int> _providerFailCounts = {};
final Map<String, int> _providerBlockedUntil = {};

bool _isProviderBlocked(String name) {
  final until = _providerBlockedUntil[name];
  if (until == null) return false;
  if (DateTime.now().millisecondsSinceEpoch < until) return true;
  _providerBlockedUntil.remove(name);
  _providerFailCounts[name] = 0;
  return false;
}

void _reportProviderOutcome(String name, bool succeeded) {
  if (succeeded) {
    _providerFailCounts[name] = 0;
    _providerBlockedUntil.remove(name);
    return;
  }
  final count = (_providerFailCounts[name] ?? 0) + 1;
  _providerFailCounts[name] = count;
  if (count >= _kProviderFailThreshold) {
    _providerBlockedUntil[name] =
        DateTime.now().millisecondsSinceEpoch + _kProviderBlockMs;
  }
}

// ═══════════════════════════════════════════════════════════════════
// صفِ سراسریِ هم‌زمانی
// ═══════════════════════════════════════════════════════════════════
int _activeJobs = 0;
final List<_Job> _queue = [];

class _Job {
  final Future<dynamic> Function() fn;
  final Completer<dynamic> completer = Completer<dynamic>();
  _Job(this.fn);
}

void _runNextJob() {
  if (_activeJobs >= kGlobalTranslateConcurrency) return;
  if (_queue.isEmpty) return;
  final job = _queue.removeAt(0);
  _activeJobs++;
  () async {
    try {
      final v = await job.fn();
      if (!job.completer.isCompleted) job.completer.complete(v);
    } catch (e, st) {
      if (!job.completer.isCompleted) job.completer.completeError(e, st);
    } finally {
      _activeJobs--;
      _runNextJob();
    }
  }();
}

Future<String> _queueJob(Future<String> Function() fn) {
  final job = _Job(fn);
  _queue.add(job);
  _runNextJob();
  return job.completer.future.then((v) => v as String);
}

/// اجرای تسک‌های async با سقفِ هم‌زمانی (همان runWithConcurrencyLimit وب)
Future<List<R>> runWithConcurrencyLimit<T, R>(
  List<T> items,
  int limit,
  Future<R> Function(T item, int index) worker,
) async {
  final results = List<R?>.filled(items.length, null);
  var nextIndex = 0;
  Future<void> runNext() async {
    while (nextIndex < items.length) {
      final i = nextIndex++;
      results[i] = await worker(items[i], i);
    }
  }

  final n = items.isEmpty ? 0 : (limit < 1 ? 1 : (limit > items.length ? items.length : limit));
  await Future.wait(List.generate(n, (_) => runNext()));
  return results.cast<R>();
}

// ═══════════════════════════════════════════════════════════════════
// تنظیمات AI
// ═══════════════════════════════════════════════════════════════════
class AiSettings {
  final String backendUrl;
  const AiSettings({required this.backendUrl});

  /// دقیقاً مثل callAI وب: اگر خالی بود از DEFAULT_BACKEND_URL استفاده کن.
  String get baseUrl {
    final clean = backendUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return clean.isEmpty ? kDefaultBackendUrl : clean;
  }
}

/// آخرین دلیلِ فنیِ خطای AI (برای نمایش زیرِ پیامِ خطا و عیب‌یابی).
String kLastAiError = '';

class _AiBackendError implements Exception {
  final String message;
  _AiBackendError(this.message);
  @override
  String toString() => 'ai-backend-error: $message';
}

// ═══════════════════════════════════════════════════════════════════
// Main service
// ═══════════════════════════════════════════════════════════════════
class TranslationService {
  TranslationService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(milliseconds: _kProviderTimeoutMs),
          receiveTimeout: const Duration(milliseconds: _kProviderTimeoutMs),
        )),
        _aiDio = Dio(BaseOptions(
          // پاسخ‌های غیر 2xx را خودمان بررسی می‌کنیم (برای 429 و ...)
          validateStatus: (_) => true,
        ));

  final Dio _dio;
  final Dio _aiDio;

  // ─── کش دائمی (حافظه + دیتابیس: IndexedDB روی وب / فایل روی موبایل) ───
  // کلید دقیقاً مثل وب: source::target::text — نگاه کن به TranslationCacheDb
  final TranslationCacheDb _db = TranslationCacheDb.instance;

  String _cacheKey(String text, String from, String to) =>
      '${from.isEmpty ? 'auto' : from}::$to::$text';

  Future<String?> _cacheGet(String text, String from, String to) {
    final v = _db.get(_cacheKey(text, from, to));
    return v.then((s) => (s != null && s.isNotEmpty) ? s : null);
  }

  /// خواندنِ سریع و همگام از کش (برای اسکرولِ روان: بدون await و بدون فلیکر).
  /// فقط اگر مقدارِ کش‌شده از کنترل کیفیت رد شود برمی‌گرداند؛ وگرنه null.
  String? peekCached(String text, String from, String to) {
    if (text.trim().isEmpty || to.isEmpty) return null;
    final v = _db.peek(_cacheKey(text, from, to));
    if (v == null || v.isEmpty) return null;
    return looksLikelyMistranslated(text, v, to, sourceLang: from) ? null : v;
  }

  /// ذخیره در کشِ دائمی
  Future<void> cachePut(
      String text, String from, String to, String value) {
    return _db.put(_cacheKey(text, from, to), value);
  }

  /// تعدادِ ترجمه‌های ذخیره‌شده روی دستگاه
  int get cachedCount => _db.count;

  // ═══════════════════════════════════════════════════════════════
  // API اصلی — معادلِ translateFree وب
  // ═══════════════════════════════════════════════════════════════
  Future<String> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
    AiSettings? aiSettings,
    bool forceVerify = false,
  }) async {
    if (text.trim().isEmpty || targetLang.isEmpty) return text;
    if (sourceLang.isNotEmpty &&
        sourceLang != 'auto' &&
        sourceLang == targetLang) {
      return text;
    }

    // ۱. کش — با چکِ کیفیت؛ کشِ مشکوک نادیده گرفته می‌شود
    final cached = await _cacheGet(text, sourceLang, targetLang);
    if (cached != null &&
        !looksLikelyMistranslated(text, cached, targetLang,
            sourceLang: sourceLang)) {
      return cached;
    }

    // ۲. صفِ سراسری؛ تایمر ۱۵ثانیه‌ای فقط از لحظه‌ی «اجرا» شروع می‌شود
    return _queueJob(() {
      final done = Completer<String>();
      final timer = Timer(const Duration(milliseconds: _kHardTimeoutMs), () {
        if (!done.isCompleted) done.complete(text);
      });
      translateNetwork(
        text: text,
        targetLang: targetLang,
        sourceLang: sourceLang,
        aiSettings: aiSettings,
        forceVerify: forceVerify,
      ).then((v) {
        if (!done.isCompleted) done.complete(v);
      }).catchError((_) {
        if (!done.isCompleted) done.complete(text);
      }).whenComplete(timer.cancel);
      return done.future;
    });
  }

  /// ترجمه‌ی دوباره (رفرش): بدون کش → دوباره سراغ مترجم‌های رایگان؛ اگر نتیجه
  /// مشکوک بود (یا عیناً همان ترجمه‌ی قبلی بود) یک AI به‌عنوان ناظر بررسی/اصلاح
  /// می‌کند؛ اگر باز هم نشد، آخرین چاره ترجمه‌ی مستقیم با AI. سقفِ زمانیِ کل
  /// ۲۵ ثانیه است تا دکمه هیچ‌وقت گیر نکند.
  Future<String> retranslate({
    required String text,
    required String targetLang,
    String sourceLang = 'en',
    AiSettings? aiSettings,
    String? previous,
  }) async {
    if (text.trim().isEmpty) return text;
    final ai = aiSettings;
    final prev = previous?.trim();

    bool bad(String r) =>
        r.trim().isEmpty ||
        looksLikelyMistranslated(text, r, targetLang, sourceLang: sourceLang);
    bool same(String r) =>
        prev != null && prev.isNotEmpty && r.trim() == prev;

    Future<String> run() async {
      // ۱. مترجم‌های رایگان (بدون کش)
      final providers = <_Provider>[
        _Provider('google', _viaGoogle),
        _Provider('mymemory', _viaMyMemory),
        _Provider('lingva', _viaLingva),
        _Provider('libre', _viaLibre),
      ];
      var result = '';
      try {
        final winner =
            await _raceProviders(providers, text, targetLang, sourceLang);
        result = winner?.result ?? '';
      } catch (_) {}

      // ۲. ناظر AI: فقط اگر مشکوک بود یا همان ترجمه‌ی قبلی تکرار شد
      if (ai != null && result.trim().isNotEmpty &&
          (bad(result) || same(result))) {
        result = await _verifyWithAI(text, targetLang, result, ai);
      }
      if (result.trim().isNotEmpty && !bad(result) && !same(result)) {
        await cachePut(text, sourceLang, targetLang, result);
        return result;
      }

      // ۳. آخرین چاره: ترجمه‌ی مستقیم با AI
      if (ai != null) {
        try {
          final r = await translateViaAI(text, targetLang, sourceLang, ai);
          if (!bad(r)) {
            await cachePut(text, sourceLang, targetLang, r);
            return r;
          }
        } catch (_) {}
      }
      // اگر ترجمه‌ی سالمی هست (حتی تکراری) همان را بده؛ وگرنه متن اصلی
      return (result.trim().isNotEmpty && !bad(result)) ? result : text;
    }

    try {
      return await run().timeout(const Duration(seconds: 25));
    } catch (_) {
      return text;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // زنجیره‌ی شبکه — معادلِ translateFreeNetwork وب
  // ═══════════════════════════════════════════════════════════════
  Future<String> translateNetwork({
    required String text,
    required String targetLang,
    required String sourceLang,
    AiSettings? aiSettings,
    bool forceVerify = false,
  }) async {
    final providers = <_Provider>[
      _Provider('google', _viaGoogle),
      _Provider('mymemory', _viaMyMemory),
      _Provider('lingva', _viaLingva),
      _Provider('libre', _viaLibre),
    ].where((p) => !_isProviderBlocked(p.name)).toList();

    final winner = await _raceProviders(providers, text, targetLang, sourceLang);

    if (winner != null) {
      var result = winner.result;

      // فقط اگر مشکوک بود (یا forceVerify) با AI بررسی/اصلاح کن
      if (aiSettings != null &&
          (forceVerify ||
              looksLikelyMistranslated(text, result, targetLang,
                  sourceLang: sourceLang))) {
        result = await _verifyWithAI(text, targetLang, result, aiSettings);
      }

      // اگر بعد از اصلاح هم مشکوک بود کش نکن — برو سراغ AI
      if (!looksLikelyMistranslated(text, result, targetLang,
          sourceLang: sourceLang)) {
        _reportProviderOutcome(winner.provider.name, true);
        await cachePut(text, sourceLang, targetLang, result);
        return result;
      }
    }

    // آخرین چاره: بک‌اند AI — این نتیجه هم از فیلتر کیفیت رد می‌شود
    if (aiSettings != null) {
      try {
        final result =
            await translateViaAI(text, targetLang, sourceLang, aiSettings);
        if (result.trim().isNotEmpty &&
            !looksLikelyMistranslated(text, result, targetLang,
                sourceLang: sourceLang)) {
          await cachePut(text, sourceLang, targetLang, result);
          return result;
        }
      } catch (_) {}
    }

    return text; // هیچ سرویسی جواب نداد → متن اصلی (تا برنامه نیفتد)
  }

  /// مسابقه‌ی مترجم‌ها: اولین نتیجه‌ی «سالم» برنده است. اگر نتیجه‌ای از کنترل
  /// کیفیت رد شد (مثلاً جوابِ بی‌ربطِ MyMemory برای یک کلمه) فعلاً نگه داشته
  /// می‌شود و منتظرِ بقیه می‌مانیم؛ فقط اگر هیچ‌کدام سالم نبود همان اولی برمی‌گردد.
  Future<_Winner?> _raceProviders(
    List<_Provider> providers,
    String text,
    String targetLang,
    String sourceLang,
  ) {
    if (providers.isEmpty) return Future<_Winner?>.value(null);

    final completer = Completer<_Winner?>();
    var remaining = providers.length;
    var settled = false;
    _Winner? fallback;

    for (final p in providers) {
      Future<String?> f;
      try {
        f = p.call(text, targetLang, sourceLang);
      } catch (e) {
        f = Future.error(e);
      }
      f.then((result) {
        if (result != null && result.trim().isNotEmpty) {
          final good = !looksLikelyMistranslated(text, result, targetLang,
              sourceLang: sourceLang);
          if (good) {
            if (!settled) {
              settled = true;
              completer.complete(_Winner(result, p));
            }
          } else {
            fallback ??= _Winner(result, p);
          }
        } else {
          _reportProviderOutcome(p.name, false);
        }
      }).catchError((_) {
        _reportProviderOutcome(p.name, false);
      }).whenComplete(() {
        remaining--;
        if (remaining == 0 && !settled && !completer.isCompleted) {
          settled = true;
          completer.complete(fallback);
        }
      });
    }
    return completer.future;
  }

  // ═══════════════════════════════════════════════════════════════
  // Providers
  // ═══════════════════════════════════════════════════════════════
  dynamic _json(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return null;
      }
    }
    return data;
  }

  Future<String?> _viaGoogle(String text, String target, String source) async {
    final url =
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=${source.isEmpty ? 'auto' : source}&tl=$target&dt=t&q=${Uri.encodeComponent(text)}';
    final res = await _dio
        .get(url)
        .timeout(const Duration(milliseconds: _kProviderTimeoutMs));
    final data = _json(res.data);
    if (data is! List || data.isEmpty) throw Exception('google-empty-response');
    final chunks = data[0];
    if (chunks is! List || chunks.isEmpty) {
      throw Exception('google-empty-response');
    }
    return chunks
        .whereType<List>()
        .map((c) => (c.isNotEmpty && c[0] != null) ? c[0].toString() : '')
        .join();
  }

  Future<String?> _viaMyMemory(
      String text, String target, String source) async {
    final sl = (source == 'auto' || source.isEmpty) ? 'en' : source;
    final url =
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=$sl|$target';
    final res = await _dio
        .get(url)
        .timeout(const Duration(milliseconds: _kProviderTimeoutMs));
    final data = _json(res.data);
    if (data is! Map) throw Exception('mymemory-shape');
    final rd = data['responseData'];
    final translated =
        (rd is Map ? rd['translatedText']?.toString() : null) ?? '';
    if (translated.isEmpty) throw Exception('mymemory-empty-response');
    if (RegExp(r'^(PLEASE SELECT|INVALID |NO TRANSLATION|AMOUNT OF WORDS)',
            caseSensitive: false)
        .hasMatch(translated.trim())) {
      throw Exception('mymemory-api-error: $translated');
    }
    return translated;
  }

  Future<String?> _viaLingva(String text, String target, String source) async {
    final url =
        'https://lingva.ml/api/v1/${source.isEmpty ? 'auto' : source}/$target/${Uri.encodeComponent(text)}';
    final res = await _dio
        .get(url)
        .timeout(const Duration(milliseconds: _kProviderTimeoutMs));
    final data = _json(res.data);
    if (data is! Map) throw Exception('lingva-shape');
    final t = data['translation']?.toString() ?? '';
    if (t.isEmpty) throw Exception('lingva-empty-response');
    return t;
  }

  Future<String?> _viaLibre(String text, String target, String source) async {
    final res = await _dio
        .post(
          'https://libretranslate.de/translate',
          data: {
            'q': text,
            'source': source.isEmpty ? 'auto' : source,
            'target': target,
            'format': 'text',
          },
          options: Options(contentType: 'application/json'),
        )
        .timeout(const Duration(milliseconds: _kProviderTimeoutMs));
    final data = _json(res.data);
    if (data is! Map) throw Exception('libre-shape');
    final t = data['translatedText']?.toString() ?? '';
    if (t.isEmpty) throw Exception('libre-empty-response');
    return t;
  }

  // ═══════════════════════════════════════════════════════════════
  // callAI — پورتِ دقیقِ app/ai/callAI.js (retry، 429، timeout، کفِ توکن)
  // ═══════════════════════════════════════════════════════════════
  static const String _aiNetMsg =
      "The AI isn't responding. Check your internet connection and try again.";

  Future<String> callAI({
    required String prompt,
    int? maxTokens,
    int retries = 2,
    required AiSettings settings,
    int timeoutMs = _kAiTimeoutMs,
  }) async {
    final url = '${settings.baseUrl}/api/generate';
    final tokens = (maxTokens ?? 300).clamp(64, 8192).toInt();
    final body = {'prompt': prompt, 'maxTokens': tokens};

    for (var attempt = 0;; attempt++) {
      try {
        final res = await _aiDio
            .post(
              url,
              data: body,
              options: Options(
                contentType: 'application/json',
                sendTimeout: Duration(milliseconds: timeoutMs),
                receiveTimeout: Duration(milliseconds: timeoutMs),
              ),
            )
            .timeout(Duration(milliseconds: timeoutMs));

        final status = res.statusCode ?? 0;
        if (status < 200 || status >= 300) {
          var detail = 'HTTP $status';
          final isRateLimited = status == 429;
          final isClientError = status >= 400 && status < 500 && !isRateLimited;
          final errBody = _json(res.data);
          if (errBody is Map && errBody['error'] != null) {
            detail = errBody['error'].toString();
          }
          final maxAttempts = isRateLimited ? (retries > 1 ? retries : 1) : retries;
          if ((!isClientError || isRateLimited) && attempt < maxAttempts) {
            final m = RegExp(r'try again in\s+(\d+(?:\.\d+)?)s',
                    caseSensitive: false)
                .firstMatch(detail);
            final waitMs = isRateLimited
                ? ((m != null ? double.parse(m.group(1)!) : 15) * 1000).ceil() +
                    500
                : 700 * (attempt + 1);
            await Future.delayed(Duration(milliseconds: waitMs));
            continue;
          }
          kLastAiError = 'HTTP $status — ${detail.length > 220 ? detail.substring(0, 220) : detail}';
          throw _AiBackendError(
              (status >= 500 || isRateLimited) ? _aiNetMsg : detail);
        }

        final data = _json(res.data);
        final rawText = (data is Map ? data['text']?.toString() : null) ?? '';
        // خروجیِ گارد/ایمنی جواب نیست → مثل پاسخِ خالی، دوباره امتحان / خطا
        final text = _aiGuardRe.hasMatch(rawText) ? '' : rawText;
        if (text.isEmpty) {
          if (attempt < retries) {
            await Future.delayed(Duration(milliseconds: 700 * (attempt + 1)));
            continue;
          }
          kLastAiError = rawText.isEmpty
              ? 'پاسخ خالی از Worker'
              : 'خروجی گارد/ایمنی از Worker (Worker قدیمی؟)';
          throw _AiBackendError(_aiNetMsg);
        }
        return text;
      } on _AiBackendError {
        rethrow;
      } catch (e) {
        if (attempt < retries) {
          await Future.delayed(Duration(milliseconds: 700 * (attempt + 1)));
          continue;
        }
        final es = e.toString();
        kLastAiError = es.length > 220 ? es.substring(0, 220) : es;
        throw _AiBackendError(_aiNetMsg);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ترجمه با AI — معادلِ translateViaAI وب
  // ═══════════════════════════════════════════════════════════════
  Future<String> translateViaAI(
    String text,
    String target,
    String source,
    AiSettings? settings,
  ) async {
    if (settings == null) throw Exception('translate-ai-no-settings');
    final targetLabel = englishLangName(target);
    final prompt =
        'Translate the following text into $targetLabel. '
        'Respond with ONLY the translation itself — no quotes, no explanation, no original text, nothing else.\n\n'
        'Text: $text';

    String clean(String r) => _stripQuotes(stripAIReasoning(r));

    // سقفِ توکن متناسب با طولِ متن (قبلاً همیشه ۲۰۰)
    final tr = (text.length ~/ 2 + 96).clamp(128, 400).toInt();
    var cleaned = clean(await callAI(
        prompt: prompt, maxTokens: tr, retries: 1, settings: settings));

    if (cleaned.isEmpty ||
        looksLikeAIReasoning(cleaned) ||
        looksLikeGuardOutput(cleaned)) {
      final strict =
          'Output ONLY the $targetLabel translation of the text below, as a single line. '
          'Do not think aloud, do not analyze, do not explain, do not use lists or markdown.\n\n'
          'Text: $text\n\n$targetLabel translation:';
      cleaned = clean(await callAI(
          prompt: strict, maxTokens: tr, retries: 0, settings: settings));
    }

    if (cleaned.isEmpty) throw Exception('translate-ai-empty-response');
    if (looksLikeAIReasoning(cleaned)) {
      throw Exception('translate-ai-reasoning-leak');
    }
    if (looksLikeGuardOutput(cleaned)) {
      throw Exception('translate-ai-guard-output');
    }
    return cleaned;
  }

  Future<String> _verifyWithAI(
    String source,
    String target,
    String draft,
    AiSettings settings,
  ) async {
    try {
      final targetLabel = englishLangName(target);
      final prompt =
          'Source text: "$source"\n'
          'Draft translation into $targetLabel: "$draft"\n\n'
          'Is the draft an accurate, complete translation? If yes, reply with EXACTLY: OK\n'
          'If no, reply with ONLY the corrected translation — no quotes, no explanation, nothing else.';
      final result = await callAI(
          prompt: prompt, maxTokens: 80, retries: 0, settings: settings);
      final cleaned = stripAIReasoning(result);
      if (cleaned.isEmpty ||
          RegExp(r'^OK\.?$', caseSensitive: false).hasMatch(cleaned) ||
          looksLikeAIReasoning(cleaned)) {
        return draft;
      }
      if (looksLikeGuardOutput(cleaned)) return draft;
      final fixed = _stripQuotes(cleaned);
      if (fixed.isEmpty) return draft;
      // «اصلاح»ی که چند برابرِ پیش‌نویس است ترجمه نیست
      if (draft.isNotEmpty && fixed.length > draft.length * 3 + 20) return draft;
      return fixed;
    } catch (_) {
      return draft;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ترجمه‌ی «داخل جمله»ی یک کلمه — معادلِ translateWordInContext وب
  // ═══════════════════════════════════════════════════════════════
  static const String _alignL = '⟦';
  static const String _alignR = '⟧';

  Future<String?> translateWordInContext({
    required String sentenceText,
    required String word,
    required String sourceLang,
    required String targetLang,
    AiSettings? aiSettings,
  }) async {
    if (sentenceText.isEmpty || word.isEmpty) return null;
    var idx = findWholeWordIndex(sentenceText, word);
    if (idx == -1) {
      idx = sentenceText.toLowerCase().indexOf(word.toLowerCase());
    }
    if (idx == -1) return null;
    final wrapped = sentenceText.substring(0, idx) +
        _alignL +
        sentenceText.substring(idx, idx + word.length) +
        _alignR +
        sentenceText.substring(idx + word.length);
    try {
      final translated = await translate(
        text: wrapped,
        targetLang: targetLang,
        sourceLang: sourceLang,
        aiSettings: aiSettings,
      );
      final m = RegExp('$_alignL([^$_alignR]*)$_alignR').firstMatch(translated);
      if (m != null && (m.group(1) ?? '').trim().isNotEmpty) {
        return m.group(1)!.trim();
      }
    } catch (_) {}
    return null;
  }
}

/// جستجوی «کلمه‌ی کامل» — معادلِ findWholeWordIndex وب
int findWholeWordIndex(String haystack, String needle) {
  if (haystack.isEmpty || needle.isEmpty) return -1;
  final h = haystack.toLowerCase();
  final n = needle.toLowerCase();
  final wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
  bool isWordChar(String ch) => ch.isNotEmpty && wordChar.hasMatch(ch);
  var from = 0;
  while (true) {
    final idx = h.indexOf(n, from);
    if (idx == -1) return -1;
    final before = idx > 0 ? h[idx - 1] : '';
    final after = idx + n.length < h.length ? h[idx + n.length] : '';
    if (!isWordChar(before) && !isWordChar(after)) return idx;
    from = idx + 1;
  }
}

class _Provider {
  final String name;
  final Future<String?> Function(String text, String target, String source) call;
  _Provider(this.name, this.call);
}

class _Winner {
  final String result;
  final _Provider provider;
  _Winner(this.result, this.provider);
}
