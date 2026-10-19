import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

/// موبایل/دسکتاپ: فایلِ دیتابیس در پوشه‌ی داده‌های برنامه.
Future<Database> openCacheDatabase(String name) async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return databaseFactoryIo.openDatabase('${dir.path}/$name');
}
