import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'screens/map_tab.dart';
import 'screens/placeholder_tab.dart';
import 'screens/practice_tab.dart';
import 'state/theme_store.dart';
import 'widgets/angels_layer.dart';
import 'widgets/background_layer.dart';
import 'widgets/emotion_widget_layer.dart';
import 'widgets/motivation_bar.dart';
import 'widgets/web_tab_bars.dart';

/// برای نمایش پیام (SnackBar) از بیرون از درخت ویجت‌ها
final GlobalKey<ScaffoldMessengerState> kMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class MaghzApp extends StatelessWidget {
  const MaghzApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeStore>();
    return MaterialApp(
      scaffoldMessengerKey: kMessengerKey,
      title: 'بی‌نهایت راه',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _light,
      darkTheme: _dark,
      themeMode: theme.mode,
      builder: (context, child) => Stack(
        textDirection: TextDirection.rtl,
        children: [
          child ?? const SizedBox.shrink(),
          const AngelsLayer(),
          const EmotionWidgetLayer(),
        ],
      ),
      home: const Shell(),
    );
  }
}

final _light = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFC9972B),
    brightness: Brightness.light,
  ),
  useMaterial3: true,
  textTheme: GoogleFonts.vazirmatnTextTheme(),
  scaffoldBackgroundColor: Colors.transparent,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: const Color(0xFF2A2218),
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.vazirmatn(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF2A2218),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: const Color.fromRGBO(255, 255, 255, 0.92),
    indicatorColor: const Color.fromRGBO(244, 197, 66, 0.12),
    labelTextStyle: WidgetStatePropertyAll(
      GoogleFonts.vazirmatn(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: Color(0xFF2A2218),
    contentTextStyle: TextStyle(color: Colors.white),
  ),
);

final _dark = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF5EC8F0),
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.dark().textTheme),
  scaffoldBackgroundColor: Colors.transparent,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.vazirmatn(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: const Color.fromRGBO(18, 20, 38, 0.92),
    indicatorColor: const Color.fromRGBO(244, 197, 66, 0.12),
    labelTextStyle: WidgetStatePropertyAll(
      GoogleFonts.vazirmatn(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  ),
);

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _index = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused ||
        s == AppLifecycleState.inactive ||
        s == AppLifecycleState.detached) {
      context.read<ThemeStore>();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundLayer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const MotivationBar(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: const [
                  PlaceholderTab(
                      title: 'شناخت', note: 'بعد از تب نقشه منتقل می‌شه'),
                  MapTab(),
                  PracticeTab(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: WebMainTabBar(
          index: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            WebTabItem(
              icon: Icons.psychology_outlined,
              selectedIcon: Icons.psychology,
              label: 'شناخت',
            ),
            WebTabItem(
              icon: Icons.hub_outlined,
              selectedIcon: Icons.hub,
              label: 'هدف گذاری',
            ),
            WebTabItem(
              icon: Icons.favorite_border,
              selectedIcon: Icons.favorite,
              label: 'تمرین',
            ),
          ],
        ),
      ),
    );
  }
}
