import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// وب: کوچک‌سازی با موتور خودِ مرورگر (خیلی سریع‌تر از کدِ Dart روی ترد اصلی،
/// و جهت عکس EXIF را خودش رعایت می‌کند). null = نشد → فایل اصلی استفاده می‌شود.
Future<Uint8List?> downscaleToJpeg(
    Uint8List bytes, int maxSide, int quality) async {
  web.ImageBitmap? bmp;
  try {
    final blob = web.Blob(<JSAny>[bytes.toJS].toJS);
    bmp = await web.window.createImageBitmap(blob).toDart;
    final w = bmp.width;
    final h = bmp.height;
    final longest = w > h ? w : h;
    final scale = longest > maxSide ? maxSide / longest : 1.0;
    final tw = (w * scale).round().clamp(1, 16384);
    final th = (h * scale).round().clamp(1, 16384);
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = tw;
    canvas.height = th;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(bmp, 0, 0, tw, th);
    final done = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? b) {
        done.complete(b);
      }).toJS,
      'image/jpeg',
      (quality / 100).toJS,
    );
    final out = await done.future;
    if (out == null) return null;
    final buf = await out.arrayBuffer().toDart;
    return buf.toDart.asUint8List();
  } catch (_) {
    return null;
  } finally {
    try {
      bmp?.close();
    } catch (_) {}
  }
}
