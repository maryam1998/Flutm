import 'dart:typed_data';

/// روی موبایل/دسکتاپ کاری نمی‌کنه (آنجا انتخابگر خودش عکس رو کوچک می‌کنه).
Future<Uint8List> fastDownscale(
  Uint8List bytes, {
  required String name,
  int maxSide = 1280,
  double quality = 0.92,
}) async =>
    bytes;
