// پیاده‌سازیِ وب: انتخابِ فایل، خواندن/رندرِ PDF با pdf.js و OCR با tesseract.js
// (اسکریپت‌ها اولین بار که لازم شدند از CDN بارگذاری می‌شوند).
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as jsu;
import 'dart:typed_data';
import 'dart:math' as math;

class PickedFile {
  final String name;
  final Uint8List bytes;
  const PickedFile(this.name, this.bytes);
  int get size => bytes.length;
}

const String _pdfJsUrl =
    'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js';
const String _pdfWorkerUrl =
    'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
const String _tesseractUrl =
    'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';

final Map<String, Future<void>> _scriptLoads = {};

Future<void> _loadScript(String url, String globalName) {
  if (jsu.hasProperty(html.window, globalName)) return Future.value();
  return _scriptLoads.putIfAbsent(url, () {
    final c = Completer<void>();
    final s = html.ScriptElement()
      ..src = url
      ..async = true;
    s.onLoad.first.then((_) => c.complete());
    s.onError.first.then((_) {
      _scriptLoads.remove(url);
      c.completeError(StateError('script load failed: $url'));
    });
    html.document.head!.append(s);
    return c.future;
  });
}

Future<List<PickedFile>> pickFiles({
  required String accept,
  bool multiple = false,
}) {
  final c = Completer<List<PickedFile>>();
  final input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = multiple;
  input.onChange.first.then((_) async {
    final out = <PickedFile>[];
    try {
      for (final f in input.files ?? <html.File>[]) {
        final r = html.FileReader();
        r.readAsArrayBuffer(f);
        await r.onLoadEnd.first;
        final res = r.result;
        final bytes = res is Uint8List
            ? res
            : Uint8List.view(res as ByteBuffer);
        out.add(PickedFile(f.name, bytes));
      }
      if (!c.isCompleted) c.complete(out);
    } catch (e) {
      if (!c.isCompleted) c.completeError(e);
    }
  });
  input.addEventListener('cancel', (_) {
    if (!c.isCompleted) c.complete(const []);
  });
  input.click();
  return c.future;
}

// ───────────────────────── OCR ─────────────────────────
const Map<String, String> _tessLang = {
  'en': 'eng',
  'es': 'spa',
  'de': 'deu',
  'fr': 'fra',
  'fa': 'fas',
  'it': 'ita',
  'ar': 'ara',
  'tr': 'tur',
  'ru': 'rus',
  'hi': 'hin',
  'zh': 'chi_sim',
  'ja': 'jpn',
  'ko': 'kor',
};

/// حداقلِ اطمینانِ هر کلمه و حداقلِ نسبتِ حروف (مثلِ Hope) تا آشغال‌های
/// تزئینیِ عکس وارد متن نشن.
const int _minWordConfidence = 62;
const double _minLetterRatio = 0.5;

bool _wordLooksLikeText(String w) {
  if (w.isEmpty) return false;
  final letters = RegExp(r'\p{L}', unicode: true).allMatches(w).length;
  return letters / w.length >= _minLetterRatio;
}

/// یک نشستِ OCR (یک worker که برای چند عکس استفاده می‌شه) — مثلِ Hope:
/// PSM = SINGLE_COLUMN، پیش‌پردازشِ عکس، فیلترِ اطمینان.
class OcrSession {
  final dynamic _worker;
  OcrSession._(this._worker);

  static Future<OcrSession> open(String langCode) async {
    await _loadScript(_tesseractUrl, 'Tesseract');
    final tess = jsu.getProperty(html.window, 'Tesseract');
    final worker = await jsu.promiseToFuture(
        jsu.callMethod(tess, 'createWorker', [_tessLang[langCode] ?? 'eng']));
    try {
      final psm = jsu.getProperty(jsu.getProperty(tess, 'PSM'), 'SINGLE_COLUMN');
      final params = jsu.newObject();
      jsu.setProperty(params, 'tessedit_pageseg_mode', psm);
      await jsu.promiseToFuture(
          jsu.callMethod(worker, 'setParameters', [params]));
    } catch (_) {}
    return OcrSession._(worker);
  }

  /// خاکستری + کشیدنِ کنتراست + بزرگ‌کردن تا ۱۶۰۰ پیکسل (مثلِ preprocessImageForOcr).
  Future<dynamic> _preprocess(Uint8List bytes) async {
    final blob = html.Blob([bytes]);
    final bitmap = await jsu.promiseToFuture(
        jsu.callMethod(html.window, 'createImageBitmap', [blob]));
    final bw = (jsu.getProperty(bitmap, 'width') as num).toInt();
    final bh = (jsu.getProperty(bitmap, 'height') as num).toInt();
    const minLong = 1600;
    final longSide = math.max(bw, bh);
    final scale = longSide < minLong ? minLong / longSide : 1.0;
    final w = math.max(1, (bw * scale).round());
    final h = math.max(1, (bh * scale).round());
    final canvas = html.CanvasElement(width: w, height: h);
    final ctx = canvas.context2D;
    ctx.imageSmoothingQuality = 'high';
    jsu.callMethod(ctx, 'drawImage', [bitmap, 0, 0, w, h]);
    final img = ctx.getImageData(0, 0, w, h);
    final px = img.data;
    final lum = Float32List(w * h);
    var minL = 255.0, maxL = 0.0;
    for (var i = 0, p = 0; i < px.length; i += 4, p++) {
      final g = 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2];
      lum[p] = g;
      if (g < minL) minL = g;
      if (g > maxL) maxL = g;
    }
    final range = math.max(maxL - minL, 1.0);
    for (var i = 0, p = 0; i < px.length; i += 4, p++) {
      final v = (((lum[p] - minL) / range) * 255).clamp(0, 255).toInt();
      px[i] = v;
      px[i + 1] = v;
      px[i + 2] = v;
    }
    ctx.putImageData(img, 0, 0);
    return canvas;
  }

  Future<String> recognize(Uint8List bytes) async {
    dynamic source;
    try {
      source = await _preprocess(bytes);
    } catch (_) {
      source = html.Blob([bytes]);
    }
    final res = await jsu
        .promiseToFuture(jsu.callMethod(_worker, 'recognize', [source]));
    final data = jsu.getProperty(res, 'data');
    final words = jsu.getProperty(data, 'words');
    if (words is List && words.isNotEmpty) {
      final out = <String>[];
      for (final w in words) {
        final conf = jsu.getProperty(w, 'confidence');
        final text = (jsu.getProperty(w, 'text') ?? '').toString();
        if ((conf is num ? conf : 100) >= _minWordConfidence &&
            _wordLooksLikeText(text)) {
          out.add(text);
        }
      }
      return out.join(' ').trim();
    }
    return (jsu.getProperty(data, 'text') ?? '').toString().trim();
  }

  Future<void> close() async {
    try {
      await jsu.promiseToFuture(jsu.callMethod(_worker, 'terminate', []));
    } catch (_) {}
  }
}

// ───────────────────────── PDF ─────────────────────────
class PdfDocHandle {
  final dynamic _doc;
  final int pageCount;
  PdfDocHandle._(this._doc, this.pageCount);

  static Future<PdfDocHandle> open(Uint8List bytes) async {
    await _loadScript(_pdfJsUrl, 'pdfjsLib');
    final lib = jsu.getProperty(html.window, 'pdfjsLib');
    jsu.setProperty(
        jsu.getProperty(lib, 'GlobalWorkerOptions'), 'workerSrc', _pdfWorkerUrl);
    final params = jsu.newObject();
    jsu.setProperty(params, 'data', bytes);
    final task = jsu.callMethod(lib, 'getDocument', [params]);
    final doc = await jsu.promiseToFuture(jsu.getProperty(task, 'promise'));
    final n = (jsu.getProperty(doc, 'numPages') as num).toInt();
    return PdfDocHandle._(doc, n);
  }

  Future<dynamic> _page(int i) =>
      jsu.promiseToFuture(jsu.callMethod(_doc, 'getPage', [i + 1]));

  Future<String> pageText(int pageIndex) async {
    final page = await _page(pageIndex);
    final content =
        await jsu.promiseToFuture(jsu.callMethod(page, 'getTextContent', []));
    final items = jsu.getProperty(content, 'items') as List;
    final sb = StringBuffer();
    for (final it in items) {
      sb.write((jsu.getProperty(it, 'str') ?? '').toString());
      if (jsu.getProperty(it, 'hasEOL') == true) sb.write(' ');
    }
    return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<Uint8List> renderPage(int pageIndex, {double scale = 1.6}) async {
    final page = await _page(pageIndex);
    final vpParams = jsu.newObject();
    jsu.setProperty(vpParams, 'scale', scale);
    final viewport = jsu.callMethod(page, 'getViewport', [vpParams]);
    final w = (jsu.getProperty(viewport, 'width') as num).ceil();
    final h = (jsu.getProperty(viewport, 'height') as num).ceil();
    final canvas = html.CanvasElement(width: w, height: h);
    final rp = jsu.newObject();
    jsu.setProperty(rp, 'canvasContext', canvas.context2D);
    jsu.setProperty(rp, 'viewport', viewport);
    final task = jsu.callMethod(page, 'render', [rp]);
    await jsu.promiseToFuture(jsu.getProperty(task, 'promise'));
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.88);
    return base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
  }

  void dispose() {
    try {
      jsu.callMethod(_doc, 'destroy', []);
    } catch (_) {}
  }
}
