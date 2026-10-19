import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// مرحله‌ی فعلیِ شروع را به صفحه‌ی بارگذاری (index.html) خبر می‌دهد تا
/// کاربر ببیند چه مرحله‌ای است و زمانِ هر مرحله ثبت شود.
void bootStage(String stage) {
  try {
    web.window.dispatchEvent(
      web.CustomEvent('maghz-boot', web.CustomEventInit(detail: stage.toJS)),
    );
  } catch (_) {}
}
