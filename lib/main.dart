import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'models/neural_container.dart';
import 'services/storage.dart';
import 'services/web_cache_clean.dart';
import 'state/abundance_store.dart';
import 'state/angels_store.dart';
import 'state/background_store.dart';
import 'state/beliefs_store.dart';
import 'state/emotion_store.dart';
import 'state/gratitude_store.dart';
import 'state/map_store.dart';
import 'state/motivation_store.dart';
import 'state/shenakht_store.dart';
import 'state/theme_store.dart';
import 'services/quiet_snack.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // کش و سرویس‌ورکر قدیمیِ وب پاک می‌شه تا همیشه آخرین نسخه بالا بیاد
  await cleanOldWebCaches();

  // فونت از اینترنت (fonts.gstatic.com) دانلود می‌شه؛ اگه کند/فیلتر بود نباید صفحه‌ی اول
  // دقیقه‌ها سفید بمونه. حداکثر ۳ ثانیه صبر می‌کنیم؛ بعدش برنامه بالا میاد و فونت وقتی
  // رسید جایگزین می‌شه.
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.vazirmatn(fontWeight: FontWeight.w400),
      GoogleFonts.vazirmatn(fontWeight: FontWeight.w700),
    ]).timeout(const Duration(seconds: 3), onTimeout: () => []);
  } catch (_) {}

  final store = MapStore(StorageService());
  final theme = ThemeStore();
  final bg = BackgroundStore();
  final motivation = MotivationStore();
  final gratitude = GratitudeStore();
  final beliefs = BeliefsStore();
  final emotions = EmotionStore();
  final abundance = AbundanceStore();
  final angels = AngelsStore();
  final shenakht = ShenakhtStore(StorageService());

  // بارگذاری هم‌زمان (قبلاً پشت‌سرهم بود و جمعِ زمان‌ها حساب می‌شد)
  await Future.wait<void>([
    store.load().catchError((Object e, StackTrace st) {
      debugPrint('load failed: $e\n$st');
    }),
    theme.load(),
    bg.load(),
    motivation.load(),
    gratitude.load(),
    beliefs.load(),
    abundance.load(),
    angels.load(),
    shenakht.load(),
  ]);

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
        ..quietSnack(const SnackBar(
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
      ChangeNotifierProvider.value(value: shenakht),
    ],
    child: const MaghzApp(),
  ));
}
