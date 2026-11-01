import 'widgets/photo_cropper.dart' show kRootNavKey;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/vazir_font.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/map_tab.dart';
import 'screens/practice_tab.dart';
import 'screens/shenakht/shenakht_tab.dart';
import 'models/map_models.dart';
import 'services/reminder_notify.dart';
import 'state/abundance_store.dart';
import 'state/beliefs_store.dart';
import 'state/gratitude_store.dart';
import 'state/linked_goals.dart';
import 'state/map_store.dart';
import 'state/main_tab.dart';
import 'state/reminder_store.dart';
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
      navigatorKey: kRootNavKey,
      scaffoldMessengerKey: kMessengerKey,
      title: 'نقشه راه',
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
      // «اندازه‌ی نوشته‌های برنامه» (تنظیمات) روی کل برنامه اعمال می‌شود:
      // همه‌ی صفحه‌ها، کادرها، دیالوگ‌ها و دکمه‌ها (چون بالای Navigator است).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(theme.textScale)),
        child: Stack(
          textDirection: TextDirection.rtl,
          children: [
            child ?? const SizedBox.shrink(),
            const AngelsLayer(),
            const EmotionWidgetLayer(),
          ],
        ),
      ),
      home: const AuthGate(),
    );
  }
}

final _light = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFC9962B),
    brightness: Brightness.light,
  ),
  useMaterial3: true,
  textTheme: GoogleFonts.vazirmatnTextTheme(),
  scaffoldBackgroundColor: Colors.transparent,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: const Color(0xFF000000),
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.vazirmatn(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF000000),
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
    backgroundColor: Color(0xFF000000),
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
  late final LinkedGoalsWatcher _linked;
  late final ReminderStore _rem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // یادآورِ هدف‌گذاری/تمرین (فاصله‌ها در تنظیمات)
    _rem = context.read<ReminderStore>()
      ..onDue = _onReminder
      ..start();
    // تب‌های وصل‌شده به نقشه (شکرگذاری / بازی فراوانی / بازنویسی)
    _linked = LinkedGoalsWatcher(
      context.read<MapStore>(),
      context.read<GratitudeStore>(),
      context.read<AbundanceStore>(),
      context.read<BeliefsStore>(),
    )..attach();
  }

  @override
  void dispose() {
    _rem
      ..onDue = null
      ..stop();
    _linked.detach();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// نوارِ یادآور بالای صفحه؛ «برو» کاربر را به تبِ مربوط می‌برد
  void _onReminder(ReminderKind kind, String message) {
    final m = kMessengerKey.currentState;
    if (m == null || !mounted) return;
    final goals = kind == ReminderKind.goals;
    final tab = goals ? 1 : 2;
    m.hideCurrentMaterialBanner();
    m.showMaterialBanner(MaterialBanner(
      backgroundColor: const Color(0xFFF1FAF8),
      leading: Icon(goals ? Icons.flag_outlined : Icons.favorite_border,
          color: const Color(0xFF178A7C)),
      content: Text(message,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: Color(0xFF000000))),
      actions: [
        TextButton(
          onPressed: () => m.hideCurrentMaterialBanner(),
          child: const Text('بعداً'),
        ),
        TextButton(
          onPressed: () {
            m.hideCurrentMaterialBanner();
            kMainTabIndex.value = tab;
            setState(() => _index = tab);
          },
          child: Text(goals ? 'برو به هدف‌ها' : 'برو به تمرین'),
        ),
      ],
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _rem.showPending();
    if (s == AppLifecycleState.paused ||
        s == AppLifecycleState.inactive ||
        s == AppLifecycleState.hidden ||
        s == AppLifecycleState.detached) {
      // ذخیره‌ی فوری (بدون انتظار برای تأخیر ۹۰۰ms) تا با رفرش/بستن چیزی گم نشود
      context.read<MapStore>().flush();
    }
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _notifyRunningTimer();
    }
  }

  /// تایمر روشن است و برنامه به پس‌زمینه رفت: اعلانِ «در حال اجراست».
  /// خودِ تایمر از ساعتِ واقعی حساب می‌شود، پس بیرون بودن از برنامه زمان را کم نمی‌کند.
  void _notifyRunningTimer() {
    try {
      final st = context.read<MapStore>().state;
      String? name;
      void walk(List<ActionNode> list) {
        for (final a in list) {
          if (name != null) return;
          if ((a.timerStart ?? 0) > 0) {
            name = a.text.trim().isEmpty ? 'بدون نام' : a.text.trim();
            return;
          }
          walk(a.children);
        }
      }

      for (final g in st.goals) {
        walk(g.actions);
      }
      if (name == null) return;
      showSystemNotification(
          'تایمر در حال اجراست ⏱', '«$name» ادامه دارد؛ برگرد و توقف را بزن.');
    } catch (_) {}
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
              // تب‌ها تنبل ساخته می‌شن: فقط تبِ اول (نقشه) موقع شروع؛ بقیه
              // اولین باری که بازشون کنی. بعدش زنده می‌مونن (حالت حفظ می‌شه).
              child: _LazyIndexedStack(
                index: _index,
                builders: [
                  (_) => const ShenakhtTab(),
                  (_) => const MapTab(),
                  (_) => const PracticeTab(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: WebMainTabBar(
          index: _index,
          onTap: (i) {
            kMainTabIndex.value = i;
            setState(() => _index = i);
          },
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

/// مثل IndexedStack ولی هر فرزند فقط وقتی اولین بار انتخاب شد ساخته می‌شود.
class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({required this.index, required this.builders});
  final int index;
  final List<WidgetBuilder> builders;
  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<bool> _built =
      List<bool>.generate(widget.builders.length, (i) => i == widget.index);

  @override
  Widget build(BuildContext context) {
    _built[widget.index] = true;
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.builders.length; i++)
          _built[i]
              // تبِ پنهان انیمیشن/تیکرش (مثل بوم نقشه) متوقف می‌شه تا تب فعال روان بمونه
              ? TickerMode(
                  enabled: i == widget.index,
                  child: widget.builders[i](context),
                )
              : const SizedBox.shrink(),
      ],
    );
  }
}
