import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_font_sizes.dart';
import 'core/constants/app_fonts.dart';
import 'core/constants/app_themes.dart';
import 'core/providers/app_prefs_provider.dart';
import 'core/providers/native_sync_provider.dart';
import 'core/providers/preload.dart';
import 'core/router/app_router.dart';
import 'core/sync/cloud_sync.dart';
import 'core/theme/theme_builder.dart';
import 'l10n/app_localizations.dart';

// فایل‌های دیگر (login_screen, header_tabs, ...) فقط app.dart را import می‌کنند
// و نوع AppLocalizations را از همین‌جا می‌گیرند.
export 'l10n/app_localizations.dart';

class LingoLearnApp extends ConsumerWidget {
  const LingoLearnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 📦 داده‌ی همه‌ی تب‌ها از همین اول بارگذاری شود (نه با باز شدنِ تب)
    startDataPreload(ProviderScope.containerOf(context, listen: false));
    // 🔗 هماهنگی با بخش اندروید (لغات حباب، زیرنویس‌های ذخیره‌شده، وضعیت حباب)
    ref.watch(nativeSyncProvider);
    // ☁️ همگام‌سازی داده‌ها و فهرست مدل‌های دانلودشده با حساب کاربر (فقط وقتی وارد شده)
    ref.watch(cloudSyncProvider);
    final prefs = ref.watch(appPrefsProvider);
    final router = ref.watch(appRouterProvider);
    final themePreset = kAppThemes[prefs.theme]!;
    final fontPreset = kAppFonts[prefs.font]!;
    final sizePreset = kAppFontSizes[prefs.fontSize]!;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).app_title,
      theme: buildAppTheme(themePreset, fontPreset),
      locale: Locale(prefs.uiLang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // ═══════════════════════════════════════════════════════════
        // UI اپ همیشه راست‌چین است — مستقل از زبان رابط.
        //
        // تغییر زبان رابط (uiLang) فقط ترجمه‌ی متن‌ها را عوض می‌کند،
        // ولی چیدمان و جهت هیچ‌وقت تغییر نمی‌کند. این باعث می‌شود:
        //   • تب‌ها همیشه در جای خودشان بمانند
        //   • آواتار همیشه سمت راست، منو همیشه سمت چپ
        //   • انیمیشن‌ها و اسلایدها در جهت درست اجرا شوند
        //   • حتی وقتی زبان مقصد کاربر انگلیسی است، UI به‌هم نریزد
        // ═══════════════════════════════════════════════════════════
        const dir = TextDirection.rtl;

        return Directionality(
          textDirection: dir,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(sizePreset.scale),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routerConfig: router,
    );
  }
}

extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
