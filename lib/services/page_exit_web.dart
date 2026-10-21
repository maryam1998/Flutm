import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// وقتی صفحه رفرش/بسته می‌شود یا به پس‌زمینه می‌رود، [callback] را صدا می‌زند
/// (برای ذخیره‌ی فوریِ تغییراتِ ذخیره‌نشده).
void onPageExit(void Function() callback) {
  try {
    final onExit = ((web.Event _) {
      callback();
    }).toJS;
    web.window.addEventListener('pagehide', onExit);
    web.window.addEventListener('beforeunload', onExit);
    web.document.addEventListener(
      'visibilitychange',
      ((web.Event _) {
        if (web.document.visibilityState == 'hidden') callback();
      }).toJS,
    );
  } catch (_) {
    // مرورگر پشتیبانی نکرد: مهم نیست
  }
}
