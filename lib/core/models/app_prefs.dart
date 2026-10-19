import 'package:flutter/foundation.dart';

import '../constants/app_languages.dart';
import '../constants/app_themes.dart';

@immutable
class AppPrefs {
  final String theme;
  final String font;
  final String fontSize;
  final String uiLang;               // 'fa', 'en', ...
  final CalendarSystem calendarSystem;
  final String highlightColor;       // '#RRGGBB' یا 'none'
  final String mascotOutfit;
  final bool mascotEnabled;
  final String mascotCharacter;
  final bool customBgEnabled;
  final int customBgOpacity;         // 15..90
  final TabOrder tabOrder;

  const AppPrefs({
    required this.theme,
    required this.font,
    required this.fontSize,
    required this.uiLang,
    required this.calendarSystem,
    required this.highlightColor,
    required this.mascotOutfit,
    required this.mascotEnabled,
    required this.mascotCharacter,
    required this.customBgEnabled,
    required this.customBgOpacity,
    required this.tabOrder,
  });

  static const AppPrefs defaults = AppPrefs(
    theme: 'vintage',
    font: 'default',
    fontSize: 'medium',
    uiLang: 'fa',
    calendarSystem: CalendarSystem.jalali,
    highlightColor: '#F7E98E',
    mascotOutfit: 'classic',
    mascotEnabled: true,
    mascotCharacter: 'classic',
    customBgEnabled: false,
    customBgOpacity: 55,
    tabOrder: TabOrder.defaults,
  );

  AppPrefs copyWith({
    String? theme,
    String? font,
    String? fontSize,
    String? uiLang,
    CalendarSystem? calendarSystem,
    String? highlightColor,
    String? mascotOutfit,
    bool? mascotEnabled,
    String? mascotCharacter,
    bool? customBgEnabled,
    int? customBgOpacity,
    TabOrder? tabOrder,
  }) {
    return AppPrefs(
      theme: theme ?? this.theme,
      font: font ?? this.font,
      fontSize: fontSize ?? this.fontSize,
      uiLang: uiLang ?? this.uiLang,
      calendarSystem: calendarSystem ?? this.calendarSystem,
      highlightColor: highlightColor ?? this.highlightColor,
      mascotOutfit: mascotOutfit ?? this.mascotOutfit,
      mascotEnabled: mascotEnabled ?? this.mascotEnabled,
      mascotCharacter: mascotCharacter ?? this.mascotCharacter,
      customBgEnabled: customBgEnabled ?? this.customBgEnabled,
      customBgOpacity: customBgOpacity ?? this.customBgOpacity,
      tabOrder: tabOrder ?? this.tabOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'font': font,
        'fontSize': fontSize,
        'uiLang': uiLang,
        'calendarSystem': calendarSystem.name,
        'highlightColor': highlightColor,
        'mascotOutfit': mascotOutfit,
        'mascotEnabled': mascotEnabled,
        'mascotCharacter': mascotCharacter,
        'customBgEnabled': customBgEnabled,
        'customBgOpacity': customBgOpacity,
        'tabOrder': tabOrder.toJson(),
      };

  /// Parsing امن — همان کاری که loadAppPrefs انجام می‌داد (fallback به پیش‌فرض).
  factory AppPrefs.fromJson(Map<String, dynamic> json) {
    final theme = kAppThemes.containsKey(json['theme']) ? json['theme'] as String : 'vintage';

    CalendarSystem cal = CalendarSystem.jalali;
    final calName = json['calendarSystem'] as String?;
    if (calName != null) {
      cal = CalendarSystem.values.firstWhere(
        (c) => c.name == calName,
        orElse: () => CalendarSystem.jalali,
      );
    }

    return AppPrefs(
      theme: theme,
      font: (json['font'] as String?) ?? 'default',
      fontSize: (json['fontSize'] as String?) ?? 'medium',
      uiLang: kAppLanguages.containsKey(json['uiLang']) ? json['uiLang'] as String : 'fa',
      calendarSystem: cal,
      highlightColor: (json['highlightColor'] as String?) ?? '#F7E98E',
      mascotOutfit: (json['mascotOutfit'] as String?) ?? 'classic',
      mascotEnabled: json['mascotEnabled'] != false,
      mascotCharacter: (json['mascotCharacter'] as String?) ?? 'classic',
      customBgEnabled: json['customBgEnabled'] == true,
      customBgOpacity: (json['customBgOpacity'] is num)
          ? (json['customBgOpacity'] as num).clamp(15, 90).toInt()
          : 55,
      tabOrder: TabOrder.fromJson(json['tabOrder'] as Map<String, dynamic>?),
    );
  }
}

@immutable
class TabOrder {
  final List<String> primary;
  final List<String> secondary;

  const TabOrder({required this.primary, required this.secondary});

  static const TabOrder defaults = TabOrder(
    primary: ['conversations', 'story', 'saved'],
    secondary: [
      'grammar',
      'speaking',
      'words',
      'favorites',
      'review',
    ],
  );

  Map<String, dynamic> toJson() => {'primary': primary, 'secondary': secondary};

  factory TabOrder.fromJson(Map<String, dynamic>? json) {
    return TabOrder(
      primary: _normalize(json?['primary'], defaults.primary),
      secondary: _normalize(json?['secondary'], defaults.secondary),
    );
  }

  static List<String> _normalize(dynamic saved, List<String> defaults) {
    final out = <String>[];
    if (saved is List) {
      for (final k in saved) {
        if (k is String && defaults.contains(k) && !out.contains(k)) out.add(k);
      }
    }
    for (final k in defaults) {
      if (!out.contains(k)) out.add(k);
    }
    return out;
  }
}
