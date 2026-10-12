import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/storage.dart';
import 'state/map_store.dart';
import 'state/motivation_store.dart';
import 'state/theme_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // فونت وزیرمتن را از پیش بارگذاری کن. اگه شبکه نبود یا کند بود، برنامه منتظر نمی‌مونه
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.vazirmatn(fontWeight: FontWeight.w400),
      GoogleFonts.vazirmatn(fontWeight: FontWeight.w500),
      GoogleFonts.vazirmatn(fontWeight: FontWeight.w600),
      GoogleFonts.vazirmatn(fontWeight: FontWeight.w700),
      GoogleFonts.vazirmatn(fontWeight: FontWeight.w800),
    ]).timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('font preload skipped: $e');
  }

  final store = MapStore(StorageService());
  final theme = ThemeStore();
  final motivation = MotivationStore();

  try {
    await store.load();
  } catch (e, st) {
    // اگه خوندن ذخیره‌شده خراب شد هم برنامه با نقشه‌ی خالی بالا بیاد، نه صفحه‌ی سفید
    debugPrint('load failed: $e\n$st');
  }
  await theme.load();
  await motivation.load();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider.value(value: theme),
      ChangeNotifierProvider.value(value: motivation),
    ],
    child: const MaghzApp(),
  ));
}
