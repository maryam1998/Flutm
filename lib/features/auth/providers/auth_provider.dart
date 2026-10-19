import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/local_storage.dart' show sharedPrefsProvider;
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

/// State سشن فعلی — قالبِ AsyncValue برای استفاده در روتر.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.onAuthStateChange;
});

/// کلیدِ حالت مهمان (با پیشوند zflut-auth- از همگام‌سازی ابری مستثنی است).
const String kGuestPrefKey = 'zflut-auth-guest-v1';

/// حالت «ورود به‌عنوان مهمان»: بدون حساب، داده فقط روی همین دستگاه می‌ماند.
class GuestModeNotifier extends StateNotifier<bool> {
  final SharedPreferences _sp;
  GuestModeNotifier(this._sp) : super(_sp.getBool(kGuestPrefKey) ?? false);

  Future<void> enter() async {
    state = true;
    await _sp.setBool(kGuestPrefKey, true);
  }

  Future<void> leave() async {
    state = false;
    await _sp.remove(kGuestPrefKey);
  }
}

final guestModeProvider =
    StateNotifierProvider<GuestModeNotifier, bool>((ref) {
  return GuestModeNotifier(ref.watch(sharedPrefsProvider));
});
