import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/storage.dart';
import 'state/map_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = MapStore(StorageService());
  try {
    await store.load();
  } catch (e, st) {
    // اگه خوندن ذخیره‌شده خراب شد هم برنامه با نقشه‌ی خالی بالا بیاد، نه صفحه‌ی سفید
    debugPrint('load failed: $e\n$st');
  }
  runApp(ChangeNotifierProvider.value(value: store, child: const MaghzApp()));
}
