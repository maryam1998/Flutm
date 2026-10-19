import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// لایه‌ی نازک روی Supabase Auth — معادلِ LoginScreen + supabaseClient.
class AuthRepository {
  final SupabaseClient _client;
  AuthRepository(this._client);

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {if (name != null) 'name': name},
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// ارسال لینک بازیابی رمز عبور به ایمیل.
  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email);

  /// ورود گوگل — در وب به همین صفحه (بدون hash/query) برمی‌گردد؛
  /// در اندروید با deep-link com.linglearn.app://login-callback.
  Future<bool> signInWithGoogle() async {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? _webRedirectUrl() : 'com.linglearn.app://login-callback',
    );
  }

  static String _webRedirectUrl() {
    final b = Uri.base;
    final path = b.path.endsWith('/') ? b.path : '${b.path}/';
    return Uri(
      scheme: b.scheme,
      host: b.host,
      port: b.hasPort ? b.port : null,
      path: path,
    ).toString();
  }
}
