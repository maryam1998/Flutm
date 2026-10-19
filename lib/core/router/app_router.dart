import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../config/app_config.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/tabs/conversations_tab.dart';
import '../../features/tabs/favorites_tab.dart';
import '../../features/tabs/grammar_tab.dart';
import '../../features/review/review_tab.dart';
import '../../features/tabs/speaking_tab.dart';
import '../../features/tabs/story_tab.dart';
import '../../features/tabs/words_tab.dart';

/// روتر — معادلِ تصمیم App.jsx بین LoginScreen و PhrasebookMain.
/// redirect بر اساس سشن Supabase.
final appRouterProvider = Provider<GoRouter>((ref) {
  // حالت توسعه: بدون ورود. هیچ‌چیز از Supabase خوانده نمی‌شود.
  if (kSkipLogin) {
    return GoRouter(
      initialLocation: '/story',
      redirect: (context, state) =>
          state.matchedLocation == '/login' ? '/story' : null,
      routes: _routes,
      errorBuilder: _errorBuilder,
    );
  }

  // GoRouter فقط یک‌بار ساخته می‌شود؛ تغییر سشن از طریق refreshListenable
  // redirect را دوباره اجرا می‌کند.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, next) {
    // با ورودِ واقعی، حالت مهمان تمام می‌شود (تا بعد از خروج مستقیم وارد اپ نشود).
    final session = next.valueOrNull?.session;
    if (session != null && ref.read(guestModeProvider)) {
      ref.read(guestModeProvider.notifier).leave();
    }
    refresh.value++;
  });
  ref.listen(guestModeProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/story',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authRepositoryProvider).currentSession != null ||
          ref.read(guestModeProvider);
      final goingToLogin = state.matchedLocation == '/login';
      if (!loggedIn) return goingToLogin ? null : '/login';
      if (goingToLogin) return '/story';
      return null;
    },
    routes: _routes,
    errorBuilder: _errorBuilder,
  );
});

Widget _errorBuilder(BuildContext _, GoRouterState state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    );

/// تب‌ها بدون انیمیشنِ صفحه (هر تب هدرِ خودش را داخل لیست اسکرول می‌کند).
GoRoute _tab(String path, Widget Function() build) => GoRoute(
      path: path,
      pageBuilder: (_, state) =>
          NoTransitionPage<void>(key: state.pageKey, child: build()),
    );

final List<RouteBase> _routes = [
  GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
  ShellRoute(
    builder: (context, state, child) => AppShell(child: child),
    routes: [
      _tab('/conversations', () => const ConversationsTab()),
      _tab('/story', () => const StoryTab()),
      GoRoute(path: '/saved', redirect: (_, __) => '/story'),
      _tab('/grammar', () => const GrammarTab()),
      _tab('/speaking', () => const SpeakingTab()),
      _tab('/words', () => const WordsTab()),
      _tab('/favorites', () => const FavoritesTab()),
      _tab('/review', () => const ReviewTab()),
    ],
  ),
];
