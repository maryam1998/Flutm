import 'dart:typed_data';

/// فقط روی وب کار می‌کند؛ روی موبایل/دسکتاپ از FilePicker استفاده می‌شود.
Future<void> downloadBytesWeb(
  Uint8List bytes,
  String fileName, {
  String mime = 'application/json',
}) async {}
