import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_prefs.dart';
import 'auth_service.dart';
import 'supabase_config.dart';

/// ─── تنظیمِ اشتراک (اینجا را ویرایش کن) ───
/// قیمتی که در صفحه‌ی اشتراک نشان داده می‌شود
const String kPremiumPriceText = 'ماهانه ۱۴۹٬۰۰۰ تومان';

/// لینکِ پرداخت (درگاه/پیج پرداخت). خالی = فقط «کد فعال‌سازی» نشان داده می‌شود.
const String kPremiumPayUrl = '';

/// راهِ ارتباطی برای خرید/دریافتِ کد (مثلاً آیدیِ تلگرام)
const String kPremiumContact = '';

/// تعدادِ رایگانِ شکرگذاری (ثبتِ دستی) و بازی فراوانی (خرید)
const int kFreeGratitudeLimit = 3;
const int kFreeAbundanceLimit = 3;

/// وضعیتِ اشتراکِ کاربر. منبعِ حقیقت: جدولِ `premium_users` در Supabase
/// (supabase/premium.sql). آخرین وضعیت روی گوشی هم نگه داشته می‌شود تا
/// بدون اینترنت هم کار کند.
class PremiumService extends ChangeNotifier {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const _kCache = 'premium_cache_v1'; // «uid|expiresMs»

  DateTime? _expires;
  bool _inited = false;
  bool loading = false;

  bool get isPremium => _expires != null && _expires!.isAfter(DateTime.now());
  DateTime? get expires => _expires;

  SupabaseClient? get _c {
    if (!supabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _uid {
    final u = _c?.auth.currentUser;
    return (u == null || u.isAnonymous) ? null : u.id;
  }

  bool get signedIn => _uid != null;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    AuthService.instance.addListener(() => refresh());
    await _readCache();
    unawaited(refresh());
  }

  Future<void> _readCache() async {
    try {
      final p = await AppPrefs.getInstance();
      final raw = p.getString(_kCache) ?? '';
      final i = raw.indexOf('|');
      if (i > 0 && raw.substring(0, i) == _uid) {
        final ms = int.tryParse(raw.substring(i + 1));
        if (ms != null) _expires = DateTime.fromMillisecondsSinceEpoch(ms);
      } else {
        _expires = null;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _writeCache() async {
    try {
      final p = await AppPrefs.getInstance();
      final id = _uid;
      if (id == null || _expires == null) {
        await p.remove(_kCache);
      } else {
        await p.setString(
            _kCache, '$id|${_expires!.millisecondsSinceEpoch}');
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    final c = _c;
    final id = _uid;
    if (c == null || id == null) {
      _expires = null;
      await _writeCache();
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final row = await c
          .from('premium_users')
          .select('expires_at')
          .eq('user_id', id)
          .maybeSingle();
      _expires = row == null
          ? null
          : DateTime.tryParse(row['expires_at'].toString())?.toLocal();
      await _writeCache();
    } catch (_) {
      // اینترنت/سرور نبود: همان وضعیتِ ذخیره‌شده می‌ماند
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// null = موفق؛ وگرنه پیامِ خطا
  Future<String?> redeem(String code) async {
    final c = _c;
    if (c == null) return 'اتصال به سرور تنظیم نشده.';
    if (_uid == null) return 'اول با حساب Google وارد شو.';
    final t = code.trim();
    if (t.length < 4) return 'کد را کامل وارد کن.';
    try {
      await c.rpc('redeem_premium_code', params: {'p_code': t});
      await refresh();
      return null;
    } on PostgrestException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid code')) return 'این کد معتبر نیست یا قبلاً استفاده شده.';
      if (m.contains('login')) return 'اول با حساب Google وارد شو.';
      if (m.contains('does not exist') || m.contains('schema cache')) {
        return 'سیستم اشتراک هنوز روی سرور ساخته نشده (supabase/premium.sql).';
      }
      return 'خطای سرور: ${e.message}';
    } catch (_) {
      return 'اینترنت وصل نیست یا سرور در دسترس نیست.';
    }
  }
}
