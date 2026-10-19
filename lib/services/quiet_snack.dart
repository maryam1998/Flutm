import 'package:flutter/material.dart';

/// پیام‌های خودکار برنامه (SnackBar) حذف شدن؛ همه‌ی نقطه‌هایی که قبلاً
/// showSnackBar صدا می‌زدن حالا این تابع رو صدا می‌زنن که هیچ‌کاری نمی‌کنه.
extension QuietSnack on ScaffoldMessengerState {
  void quietSnack(SnackBar snackBar) {}
}
