import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// با هر نسخه‌ی جدید این عدد رو عوض کن؛ یک‌بار کش قدیمی پاک و صفحه خودکار تازه می‌شه.
const String kWebBuildStamp = '2026-10-19-v6';

/// سرویس‌ورکر و کش‌های قدیمی مرورگر رو پاک می‌کنه تا نسخه‌ی جدید سایت بالا بیاد.
/// فقط وقتی stamp عوض شده باشه یک‌بار صفحه رو تازه می‌کنه (حلقه‌ی بی‌پایان نداریم).
Future<void> cleanOldWebCaches() async {
  try {
    final regs =
        (await web.window.navigator.serviceWorker.getRegistrations().toDart)
            .toDart;
    for (final r in regs) {
      await r.unregister().toDart;
    }
    final keys = (await web.window.caches.keys().toDart).toDart;
    for (final k in keys) {
      await web.window.caches.delete(k.toDart).toDart;
    }
    final seen = web.window.localStorage.getItem('maghz_build_stamp');
    if (seen != kWebBuildStamp) {
      web.window.localStorage.setItem('maghz_build_stamp', kWebBuildStamp);
      if (seen != null || regs.isNotEmpty || keys.isNotEmpty) {
        web.window.location.reload();
      }
    }
  } catch (_) {
    // مرورگر پشتیبانی نکنه یا خطا بده: مهم نیست
  }
}
