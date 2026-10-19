import 'package:flutter/widgets.dart';

import '../../app.dart' show AppL10nX;
import '../../core/neural/neural_dates.dart' show faDigits;
import 'providers/review_provider.dart';

export '../../app.dart' show AppL10nX;
export '../tabs/_hope_panel.dart' show uiContentDirection;

/// کمک‌های ترجمه‌ی تب «مرور».
extension ReviewI18n on BuildContext {
  /// عدد بر اساس زبان رابط: فارسی → ارقام فارسی، بقیه → لاتین.
  String rvNum(Object n) =>
      Localizations.localeOf(this).languageCode == 'fa' ? faDigits(n) : '$n';

  /// برچسب‌های ۷ روز هفته (دوشنبه … یکشنبه) از ARB.
  List<String> get rvWeekdayLetters {
    final parts = l10n.rv_weekday_letters.split(',');
    return parts.length == 7 ? parts : List.filled(7, '');
  }

  String rvFilterLabel(ReviewFilter f) {
    final L = l10n;
    switch (f) {
      case ReviewFilter.today:
        return L.rv_f_today;
      case ReviewFilter.week:
        return L.rv_f_week;
      case ReviewFilter.learned:
        return L.rv_learned;
      case ReviewFilter.all:
        return L.review_filter_all;
      case ReviewFilter.hard:
        return L.rv_f_hard;
      case ReviewFilter.fresh:
        return L.rv_f_new;
    }
  }
}
