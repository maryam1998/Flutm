import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'models/emotion.dart';
import 'models/neural_container.dart';
import 'screens/map_tab.dart';
import 'screens/placeholder_tab.dart';
import 'screens/practice_tab.dart';
import 'state/emotion_store.dart';
import 'state/gratitude_store.dart';
import 'state/theme_store.dart';
import 'widgets/background_layer.dart';
import 'widgets/emotion_widget_layer.dart';
import 'widgets/motivation_bar.dart';

class MaghzApp extends StatelessWidget {
  const MaghzApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeStore>();
    return MaterialApp(
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
    backgroundColor: const Color(0xFFF5EFE0).withValues(alpha: 0.96),
    indicatorColor: const Color(0xFFC9972B).withValues(alpha: 0.28),
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
    backgroundColor: const Color(0xFF0B0D1E).withValues(alpha: 0.96),
    indicatorColor: const Color(0xFF5EC8F0).withValues(alpha: 0.28),
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
  bool _wired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    _wireEmotionCommit();
  }

  void _wireEmotionCommit() {
    final em = context.read<EmotionStore>();
    final gr = context.read<GratitudeStore>();

    em.onCommitClose = (ids) {
      if (ids.isEmpty) return;
      final valid = ids.where((id) => emotionById(id) != null).toList();
      if (valid.isEmpty) return;
      final dom = dominantEmotion(valid);
      if (dom == null) return;

      final felt = NeuralFiberEmotion(
        ids: valid,
        color: dom.color,
        freq: dom.freq,
      );

      // اول سعی کن آخرین رشته‌ی بدون‌احساس را رنگ کنی
      final colored = gr.neural.colorLatestUncolored(felt);
      // اگر همه‌ی رشته‌ها رنگی بودند، یک رشته‌ی جدید بساز
      if (!colored) {
        gr.neural.addAutoFiber(emotion: felt);
      }
      gr.saveNeural();
    };
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.psychology_outlined),
              selectedIcon: Icon(Icons.psychology),
              label: 'شناخت',
            ),
            NavigationDestination(
              icon: Icon(Icons.hub_outlined),
              selectedIcon: Icon(Icons.hub),
              label: 'هدف‌گذاری',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'تمرین',
            ),
          ],
        ),
      ),
    );
  }
}
