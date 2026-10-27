import 'package:flutter/foundation.dart';

/// تبِ اصلیِ فعال: ۰ = شناخت، ۱ = هدف گذاری، ۲ = تمرین.
/// ویجت شناورِ «آدم و احساسات» بالای کل برنامه است و از این مقدار می‌فهمد
/// کاربر الان کدام تب است تا در تب‌های انتخاب‌شده پنهان شود.
final ValueNotifier<int> kMainTabIndex = ValueNotifier<int>(1);

/// نام تب‌های اصلی (برای تنظیمات)
const List<String> kMainTabNames = ['شناخت', 'هدف گذاری', 'تمرین'];

/// کلیدِ ذخیره در `MapState.extra`: فهرست ایندکسِ تب‌هایی که ویجت در آن‌ها پنهان است
const String kEmotionHiddenTabsKey = 'emotionHiddenTabs';

List<int> emotionHiddenTabs(Map<String, dynamic> extra) {
  final v = extra[kEmotionHiddenTabsKey];
  if (v is! List) return const [];
  return [for (final e in v) if (e is num) e.toInt()];
}
