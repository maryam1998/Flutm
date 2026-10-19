import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// کوچک‌کردن عکس با موتور خودِ مرورگر (سریع و بدون قفل‌کردن رابط).
/// GIF و WebP کوچک (احتمالاً متحرک) دست‌نخورده می‌مونن؛ اگه کوچک‌سازی نشد یا
/// حجم کم نشد، همون بایت‌های اصلی برمی‌گرده.
Future<Uint8List> fastDownscale(
  Uint8List bytes, {
  required String name,
  int maxSide = 1280,
  double quality = 0.92,
}) async {
  final lower = name.toLowerCase();
  if (lower.endsWith('.gif')) return bytes;
  if (lower.endsWith('.webp') && bytes.length < 400 * 1024) return bytes;
  web.ImageBitmap? bmp;
  try {
    final parts = <JSAny>[bytes.toJS].toJS;
    final blob = web.Blob(parts);
    bmp = await web.window.createImageBitmap(blob).toDart;
    final w = bmp.width;
    final h = bmp.height;
    final longest = w > h ? w : h;
    if (longest <= maxSide && bytes.length < 300 * 1024) return bytes;
    final scale = longest > maxSide ? maxSide / longest : 1.0;
    final tw = (w * scale).round().clamp(1, 16384);
    final th = (h * scale).round().clamp(1, 16384);
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = tw;
    canvas.height = th;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(bmp, 0, 0, tw, th);
    // PNG/WebP شفافیت دارند → حتماً PNG بماند (JPEG پس‌زمینه‌ی سیاه/سفید و «کادر» می‌ساخت)
    final keepAlpha = lower.endsWith('.png') || lower.endsWith('.webp');
    final mime = keepAlpha ? 'image/png' : 'image/jpeg';
    final done = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? b) {
        done.complete(b);
      }).toJS,
      mime,
      quality.toJS,
    );
    final out = await done.future;
    if (out == null) return bytes;
    final buf = await out.arrayBuffer().toDart;
    final res = buf.toDart.asUint8List();
    return res.length < bytes.length ? res : bytes;
  } catch (_) {
    return bytes;
  } finally {
    try {
      bmp?.close();
    } catch (_) {}
  }
}
