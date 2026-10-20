import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import 'app.dart';
import 'models/neural_container.dart';
import 'services/boot_status.dart';
import 'services/storage.dart';
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

/// صفحه‌ی اولِ سبک: همون لحظه نشون داده می‌شه تا کاربر منتظر صفحه‌ی خالی نمونه
/// (بارگذاری داده‌ها بعدش انجام می‌شه).
class _BootSplash extends StatelessWidget {
  const _BootSplash();
  @override
  Widget build(BuildContext context) => const Directionality(
        textDirection: TextDirection.rtl,
        child: ColoredBox(
          color: Color(0xFFFFFFFF),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology_outlined, size: 56, color: Color(0xFFC9962B)),
                SizedBox(height: 16),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFFC9962B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bootStage('data');

  // وب: صفحه‌ی بارگذاریِ index.html تا اولین فریمِ خودِ برنامه می‌مونه، پس
  // splash فلاتر لازم نیست (قبلاً دو صفحه‌ی بارگذاری پشت‌سرهم دیده می‌شد).
  // موبایل: یک صفحه‌ی سبک بالا بیاد تا کاربر صفحه‌ی سفید نبینه.
  if (!kIsWeb) runApp(const _BootSplash());

  // فونت وزیرمتن داخل خود برنامه است (pubspec) و دانلود/انتظاری ندارد.
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

  bootStage('ui');
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
