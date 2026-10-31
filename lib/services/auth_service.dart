import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_prefs.dart';
import 'supabase_config.dart';

enum AuthStatus { loading, signedOut, guest, signedIn }

/// ورود با Google یا مهمان. وضعیت ورود ذخیره می‌شود و دفعه‌ی بعد صفحه‌ی ورود نمی‌آید.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _kGuest = 'auth_guest';

  AuthStatus state = AuthStatus.loading;
  bool busy = false;
  String? error;
  StreamSubscription<dynamic>? _sub;

  SupabaseClient? get _client {
    if (!supabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  User? get user => _client?.auth.currentUser;
  String get displayName {
    final u = user;
    final m = u?.userMetadata;
    final n = (m?['full_name'] ?? m?['name'] ?? '') as String;
    if (n.isNotEmpty) return n;
    return u?.email ?? '';
  }

  Future<void> load() async {
    final c = _client;
    if (c != null) {
      _sub ??= c.auth.onAuthStateChange.listen((data) {
        final s = data.session;
        if (s != null && !(s.user.isAnonymous)) {
          state = AuthStatus.signedIn;
          notifyListeners();
        } else if (data.event == AuthChangeEvent.signedOut &&
            state == AuthStatus.signedIn) {
          state = AuthStatus.signedOut;
          notifyListeners();
        }
      });
      final s = c.auth.currentSession;
      if (s != null && !s.user.isAnonymous) {
        state = AuthStatus.signedIn;
        notifyListeners();
        return;
      }
    }
    final p = await AppPrefs.getInstance();
    state = (p.getBool(_kGuest) ?? false) ? AuthStatus.guest : AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    final c = _client;
    if (c == null) {
      error = 'اتصال به Supabase هنوز تنظیم نشده.';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await c.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : kAuthRedirect,
      );
      // نتیجه از onAuthStateChange می‌آید (بعد از برگشت از مرورگر)
    } catch (e) {
      error = 'ورود با Google انجام نشد. دوباره تلاش کن.';
      debugPrint('google sign-in failed: $e');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// مهمان: روی همین دستگاه ذخیره می‌شود (و اگر Supabase وصل باشد، ورودِ ناشناس هم ساخته می‌شود).
  Future<void> continueAsGuest() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final c = _client;
      if (c != null && c.auth.currentSession == null) {
        try {
          await c.auth.signInAnonymously();
        } catch (e) {
          debugPrint('anonymous sign-in skipped: $e');
        }
      }
      final p = await AppPrefs.getInstance();
      await p.setBool(_kGuest, true);
      state = AuthStatus.guest;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (_) {}
    final p = await AppPrefs.getInstance();
    await p.remove(_kGuest);
    state = AuthStatus.signedOut;
    notifyListeners();
  }
}
