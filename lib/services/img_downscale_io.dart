import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// موبایل/دسکتاپ: کوچک‌سازی با پکیج image (در isolate جدا).
/// (روی وب این پکیج اصلاً داخل برنامه نیست تا فایل برنامه سبک‌تر و شروع سریع‌تر باشد.)
Future<Uint8List?> downscaleToJpeg(
        Uint8List bytes, int maxSide, int quality) =>
    compute(_downscale, <Object>[bytes, maxSide, quality]);

Uint8List? _downscale(List<Object> a) {
  try {
    final bytes = a[0] as Uint8List;
    final maxSide = a[1] as int;
    final quality = a[2] as int;
    var im = img.decodeImage(bytes);
    if (im == null) return null;
    im = img.bakeOrientation(im);
    if (math.max(im.width, im.height) > maxSide) {
      im = im.width >= im.height
          ? img.copyResize(im, width: maxSide)
          : img.copyResize(im, height: maxSide);
    }
    return Uint8List.fromList(img.encodeJpg(im, quality: quality));
  } catch (_) {
    return null;
  }
}
