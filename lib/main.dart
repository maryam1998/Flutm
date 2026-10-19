import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/storage/durable_store.dart';
import 'core/storage/local_storage.dart' show sharedPrefsProvider;
import 'core/sync/app_restarter.dart';
import 'core/storage/translation_cache_db.dart';

// مقادیر واقعی از --dart-define (در GitHub Actions از Secrets) می‌آیند.
const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  // همه‌چیز (binding + runApp) در یک zone اجرا می‌شود تا هر خطای راه‌اندازی
  // به‌جای صفحه‌ی خالی، روی صفحه نمایش داده شود.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    // در حالت release خطای ساخت ویجت به‌جای کادر خاکستری/خالی، متن خطا را نشان بده.
    ErrorWidget.builder = (details) => Material(
          color: const Color(0xFFFFF3F3),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SingleChildScrollView(
                child: Text(
                  details.exceptionAsString(),
                  style: const TextStyle(color: Color(0xFF9E3B3B), fontSize: 12),
                ),
              ),
            ),
          ),
        );

    // portrait فقط روی موبایل معنی دارد.
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // Supabase: در حالت kSkipLogin شکست آن مانع اجرای اپ نمی‌شود.
    String? supabaseError;
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      supabaseError =
          'SUPABASE_URL و SUPABASE_ANON_KEY هنگام build تنظیم نشده‌اند.\n'
          'در GitHub: Settings ← Secrets and variables ← Actions ← New repository secret\n'
          'دو secret با همین نام‌ها بساز و workflow را دوباره اجرا کن.';
    } else {
      try {
        await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
      } catch (e) {
        supabaseError = '$e';
      }
    }
    if (supabaseError != null && !kSkipLogin) {
      runApp(StartupErrorApp(
        title: 'تنظیمات/اتصال Supabase مشکل دارد',
        details: supabaseError,
      ));
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // نسخه‌ی دائمیِ داده‌های کاربر (IndexedDB روی وب / فایل روی موبایل):
    // اگر prefs خالی/پاک شده باشد، لغات و داستان‌ها و ... از این‌جا برمی‌گردند.
    await DurableStore.instance.init(prefs);

    // کشِ دائمیِ ترجمه‌ها (IndexedDB / فایل) — در پس‌زمینه باز و پر می‌شود؛
    // تا آماده شود کش فقط در حافظه کار می‌کند و اپ منتظر نمی‌ماند.
    unawaited(TranslationCacheDb.instance.init(prefs));

    // AppRestarter: بعد از بازیابیِ داده‌ی ابری درخت providerها دوباره ساخته می‌شود.
    runApp(
      AppRestarter(
        builder: () => ProviderScope(
          overrides: [
            // SharedPreferences را از قبل می‌سازیم تا خواندن prefs سنکرون باشد.
            sharedPrefsProvider.overrideWithValue(prefs),
          ],
          child: const LingoLearnApp(),
        ),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
  });
}

/// صفحه‌ی خطای راه‌اندازی — مستقل از تم/ترجمه/Supabase تا همیشه نمایش داده شود.
class StartupErrorApp extends StatelessWidget {
  final String title;
  final String details;
  const StartupErrorApp({super.key, required this.title, required this.details});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFEFE6C9),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Color(0xFF9E3B3B)),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2A26),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      details,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Color(0xFF4B5551),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
