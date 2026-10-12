import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/map_tab.dart';
import 'screens/placeholder_tab.dart';
import 'state/map_store.dart';
import 'state/motivation_store.dart';
import 'state/theme_store.dart';
import 'theme/app_theme.dart';
import 'widgets/motivation_bar.dart';

class MaghzApp extends StatelessWidget {
  const MaghzApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeStore>();
    return MaterialApp(
      title: 'مغز',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: theme.mode,
      home: const Shell(),
    );
  }
}

/// سه تب اصلی؛ ترتیب مثل نسخه‌ی وب: شناخت، نقشه، شکرگزاری. پیش‌فرض: نقشه
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

  /// معادل pagehide / visibilitychange در وب: موقع رفتن به پس‌زمینه فوراً ذخیره کن
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive || s == AppLifecycleState.detached) {
      context.read<MapStore>().flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    // وقتی نوار انگیزشی بالای صفحه است، خودش فضای status bar را می‌گیرد؛ تب‌ها دوباره آن را اضافه نکنند
    final barVisible = context.select<MotivationStore, bool>((m) => m.showBar && m.current != null);
    return Scaffold(
      body: Column(
        children: [
          const MotivationBar(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: barVisible,
              child: IndexedStack(
                index: _index,
                children: const [
                  PlaceholderTab(title: 'شناخت', note: 'بعد از تب نقشه منتقل میشه'),
                  MapTab(),
                  PlaceholderTab(title: 'شکرگزاری', note: 'بعد از تب نقشه منتقل میشه'),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.psychology_outlined), selectedIcon: Icon(Icons.psychology), label: 'شناخت'),
          NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'نقشه'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'شکرگزاری'),
        ],
      ),
    );
  }
}
