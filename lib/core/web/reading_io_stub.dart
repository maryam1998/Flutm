// پیاده‌سازیِ اندروید / iOS / دسکتاپ برای انتخابِ فایل، PDF و OCR
// (نسخه‌ی وب در reading_io_web.dart است؛ انتخابِ بینِ این دو با import مشروط انجام می‌شود).
//
//   • انتخابِ فایل : file_picker
//   • متنِ PDF     : syncfusion_flutter_pdf
//   • عکسِ صفحه    : pdfx
//   • OCR عکس     : google_mlkit_text_recognition (روی خودِ گوشی، بدونِ اینترنت)
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class PickedFile {
  final String name;
  final Uint8List bytes;
  const PickedFile(this.name, this.bytes);
  int get size => bytes.length;
}

/// [accept] همان رشته‌های `accept` در وب: `application/pdf` ، `image/*` ، `audio/*`
Future<List<PickedFile>> pickFiles({
  required String accept,
  bool multiple = false,
}) async {
  FileType type = FileType.any;
  List<String>? exts;
  if (accept.contains('pdf')) {
    type = FileType.custom;
    exts = const ['pdf'];
  } else if (accept.startsWith('image')) {
    type = FileType.image;
  } else if (accept.startsWith('audio')) {
    type = FileType.audio;
  } else if (accept.contains('.srt')) {
    type = FileType.any; // بعضی گوشی‌ها پسوندِ srt را نمی‌شناسند
  }
  final res = await FilePicker.platform.pickFiles(
    type: type,
    allowedExtensions: exts,
    allowMultiple: multiple,
    withData: true,
  );
  if (res == null) return const [];
  final out = <PickedFile>[];
  for (final f in res.files) {
    Uint8List? b = f.bytes;
    if (b == null && f.path != null) b = await File(f.path!).readAsBytes();
    if (b != null) out.add(PickedFile(f.name, b));
  }
  return out;
}

/// نشستِ OCR با ML Kit. ML Kit فقط این خط‌ها را می‌خواند:
/// لاتین (انگلیسی/آلمانی/اسپانیایی/فرانسوی/…)، چینی، ژاپنی، کره‌ای، دوناگری.
/// عربی/فارسی را ML Kit پشتیبانی نمی‌کند — برایشان خطایِ واضح می‌دهیم.
class OcrSession {
  final TextRecognizer _rec;
  OcrSession._(this._rec);

  static TextRecognitionScript _scriptFor(String lang) {
    switch (lang) {
      case 'zh':
        return TextRecognitionScript.chinese;
      case 'ja':
        return TextRecognitionScript.japanese;
      case 'ko':
        return TextRecognitionScript.korean;
      case 'hi':
      case 'mr':
      case 'ne':
        return TextRecognitionScript.devanagiri;
      case 'ar':
      case 'fa':
      case 'ur':
      case 'he':
      case 'ru':
      case 'uk':
      case 'el':
      case 'th':
        throw UnsupportedError('ocr-script:$lang');
      default:
        return TextRecognitionScript.latin;
    }
  }

  static Future<OcrSession> open(String langCode) async =>
      OcrSession._(TextRecognizer(script: _scriptFor(langCode)));

  Future<String> recognize(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File(
        '${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await f.writeAsBytes(bytes, flush: true);
    try {
      final r = await _rec.processImage(InputImage.fromFilePath(f.path));
      return r.text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    } finally {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  Future<void> close() async {
    try {
      await _rec.close();
    } catch (_) {}
  }
}

/// سندِ PDF: متن با Syncfusion، عکسِ صفحه با pdfx.
class PdfDocHandle {
  final sf.PdfDocument _text;
  final pdfx.PdfDocument _img;
  PdfDocHandle._(this._text, this._img);

  int get pageCount => _img.pagesCount;

  static Future<PdfDocHandle> open(Uint8List bytes) async {
    final t = sf.PdfDocument(inputBytes: bytes);
    final i = await pdfx.PdfDocument.openData(bytes);
    return PdfDocHandle._(t, i);
  }

  Future<String> pageText(int pageIndex) async {
    final raw = sf.PdfTextExtractor(_text)
        .extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
    return raw.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  Future<Uint8List> renderPage(int pageIndex, {double scale = 1.6}) async {
    final page = await _img.getPage(pageIndex + 1);
    try {
      final w = page.width * scale;
      final h = page.height * scale;
      final out = await page.render(
        width: w,
        height: h,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      if (out == null) throw StateError('render failed');
      return out.bytes;
    } finally {
      await page.close();
    }
  }

  void dispose() {
    try {
      _text.dispose();
    } catch (_) {}
    try {
      _img.close();
    } catch (_) {}
  }
}
