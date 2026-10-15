import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'models/neural_container.dart';
import 'services/app_prefs.dart';
import 'services/media_db.dart';
import 'services/storage.dart';
import 'state/abundance_store.dart';
import 'state/angels_store.dart';
import 'state/background_store.dart';
import 'state/beliefs_store.dart';
import 'state/emotion_store.dart';
import 'state/gratitude_store.dart';
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

  // IndexedDB (وب) باز و داده‌های قدیمیِ localStorage منتقل می‌شن
  try {
    await AppPrefs.getInstance();
  } catch (e) {
    debugPrint('AppPrefs init failed: $e');
  }

  final store = MapStore(StorageService());
  final theme = ThemeStore();
  final bg = BackgroundStore();
  final motivation = MotivationStore();
  final gratitude = GratitudeStore();
  final beliefs = BeliefsStore();
  final emotions = EmotionStore();
  final abundance = AbundanceStore();
  final angels = AngelsStore();

  try {
    await store.load();
  } catch (e, st) {
    debugPrint('load failed: $e\n$st');
  }
  await theme.load();
  await bg.load();
  await motivation.load();
  await gratitude.load();
  await beliefs.load();
  await abundance.load();
  await angels.load();

  // «ثبت حس» با بستن ادمک (echw:commit در وب): همه‌ی تمرین‌های امروز که
  // انجام شده‌ن رنگ حس می‌گیرن؛ اگه هیچ تمرینی نبود انتخاب نگه داشته می‌شه.
  emotions.onCommitClose = (ids) async {
    final g = await gratitude.applyCommittedFeeling(ids);
    final b = await beliefs.applyCommittedFeeling(ids);
    final done =
        g != FeelingApply.skipped || b != FeelingApply.skipped;
    if (done) {
      kMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('حس ثبت شد و رشته‌ی عصبی ساخته شد 🧠'),
          duration: Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
        ));
    }
    return done;
  };

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider.value(value: theme),
      ChangeNotifierProvider.value(value: bg),
      ChangeNotifierProvider.value(value: motivation),
      ChangeNotifierProvider.value(value: gratitude),
      ChangeNotifierProvider.value(value: beliefs),
      ChangeNotifierProvider.value(value: emotions),
      ChangeNotifierProvider.value(value: abundance),
      ChangeNotifierProvider.value(value: angels),
    ],
    child: const MaghzApp(),
  ));

  // پاک‌سازی فایل‌های رسانه‌ای یتیم (با تأخیر تا شروع برنامه کند نشه)
  Future<void>.delayed(const Duration(seconds: 20), _collectMediaGarbage);
}

Future<void> _collectMediaGarbage() async {
  try {
    final prefs = await AppPrefs.getInstance();
    final texts = <String>[...prefs.stringValues()];
    final map = await StorageService().read();
    if (map != null) texts.add(map);
    await MediaDb.collectGarbage(texts);
  } catch (_) {}
}
