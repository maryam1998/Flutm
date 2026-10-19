import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';

enum SortMode {
  defaultOrder,   // پیش‌فرض
  alphabetical,   // الفبایی
  byLevel,        // بر اساس سطح
  recent,         // اخیراً
}

extension SortModeX on SortMode {
  String get faLabel {
    switch (this) {
      case SortMode.defaultOrder: return 'پیش‌فرض';
      case SortMode.alphabetical: return 'الفبایی';
      case SortMode.byLevel:      return 'سطح (A→C)';
      case SortMode.recent:       return 'اخیراً اضافه‌شده';
    }
  }
}

extension SortModeL10n on SortMode {
  /// برچسبِ محلی‌شده (فارسی/انگلیسی/...) بر اساس زبانِ رابط
  String label(AppLocalizations L) {
    switch (this) {
      case SortMode.defaultOrder: return L.sort_default;
      case SortMode.alphabetical: return L.sort_name_asc;
      case SortMode.byLevel:      return L.sort_level_asc;
      case SortMode.recent:       return L.sort_recent;
    }
  }
}

@immutable
class WordsFilterState {
  /// سطح انتخاب‌شده — 'all' یا 'A1'..'C2'
  final String level;

  /// متن جستجو (خالی = بدون فیلتر)
  final String query;

  /// حالت مرتب‌سازی
  final SortMode sort;

  const WordsFilterState({
    this.level = 'all',
    this.query = '',
    this.sort = SortMode.defaultOrder,
  });

  WordsFilterState copyWith({
    String? level,
    String? query,
    SortMode? sort,
  }) {
    return WordsFilterState(
      level: level ?? this.level,
      query: query ?? this.query,
      sort: sort ?? this.sort,
    );
  }
}
