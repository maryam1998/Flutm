import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// مقیاس‌دهی نسبت به عرض اسکرین‌شات مرجع (۹۰۰ پیکسل).
///
/// `context.px(108)` یعنی «۱۰۸ پیکسلِ اسکرین‌شات» — روی هر گوشی با همان
/// نسبتِ عرض صفحه نمایش داده می‌شود. روی تبلت/وب عرض تا ۴۸۰ محدود می‌شود
/// تا همه‌چیز بادکنکی نشود.
extension ScreenScaleX on BuildContext {
  double px(double v) {
    final w = MediaQuery.sizeOf(this).width;
    return v * math.min(w, 480.0) / 900.0;
  }
}
