import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/storage.dart';
import 'state/background_store.dart';
import 'state/map_store.dart';
import 'state/motivation_store.dart';
import 'state/theme_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GoogleFonts.pendingFonts([
    GoogleFonts.vazirmatn(fontWeight: FontWeight.w400),
    GoogleFonts.vazirmatn(fontWeight: FontWeight.w500),
    GoogleFonts.vazirmatn(fontWeight: FontWeight.w600),
    GoogleFonts.vazirmatn(fontWeight: FontWeight.w700),
    GoogleFonts.vazirmatn(fontWeight: FontWeight.w800),
  ]);

  final store = MapStore(StorageService());
  final theme = ThemeStore();
  final bg = BackgroundStore();
  final motivation = MotivationStore();

  try {
    await store.load();
  } catch (e, st) {
    debugPrint('load failed: $e\n$st');
  }
  await theme.load();
  await bg.load();
  await motivation.load();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider.value(value: theme),
      ChangeNotifierProvider.value(value: bg),
      ChangeNotifierProvider.value(value: motivation),
    ],
    child: const MaghzApp(),
  ));
}
