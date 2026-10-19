import 'package:flutter/material.dart';

/// یک پریست کامل رنگ — معادلِ یک entry از APP_THEMES در theme.js.
@immutable
class AppThemePreset {
  final String key;
  final Map<String, String> label; // {"fa": "...", "en": "..."}
  final Color swatch;
  final AppThemeColors colors;

  const AppThemePreset({
    required this.key,
    required this.label,
    required this.swatch,
    required this.colors,
  });
}

@immutable
class AppThemeColors {
  final Color paper;
  final Color paperDark;
  final Color ink;
  final Color inkSoft;
  final Color gold;
  final Color goldSoft;
  final Color teal;
  final Color rose;
  final Color cardBorder;
  final Color headerFrom;
  final Color headerTo;
  final Color headerText;

  const AppThemeColors({
    required this.paper,
    required this.paperDark,
    required this.ink,
    required this.inkSoft,
    required this.gold,
    required this.goldSoft,
    required this.teal,
    required this.rose,
    required this.cardBorder,
    required this.headerFrom,
    required this.headerTo,
    required this.headerText,
  });
}

/// رنگ‌های ثابت مستقل از تم (مطابقِ theme.js).
class AppFixedColors {
  static const Color mainText = Color(0xFF0B1220);
  static const Color translation = Color(0xFF0F5C34);
  static const Color readMarker = Color(0xFFFFD54F);
  static const Color readDone = Color(0xFF7FA396);
  static const Color readDoneBg = Color(0xFFFBF2DF);
  static const Color readDoneBorder = Color(0xFFE3D2A2);
  static const Color readDoneCheck1 = Color(0xFF3F9B72);
  static const Color readDoneCheck2 = Color(0xFF276E4F);
  static const Color starFavorite = Color(0xFFF5C518);
}

const List<Color> kHighlightPalette = [
  Color(0xFFF7E98E), // زرد کم‌رنگ
  Color(0xFFFBD9AE), // هلویی
  Color(0xFFF7C48C), // نارنجی ملایم
  Color(0xFFF1968E), // صورتی‌مرجانی
  Color(0xFFDCE07E), // زیتونی روشن
  Color(0xFF9AD98A), // سبز کم‌رنگ
  Color(0xFF8DE0BE), // نعنایی
  Color(0xFFA6DEE9), // آبی خیلی روشن
  Color(0xFFA9C7F0), // آبی کم‌رنگ
  Color(0xFFC7B6EC), // بنفش کم‌رنگ
  Color(0xFFF0AEEC), // بنفشی صورتی
  Color(0xFFF4AAC0), // صورتی
];

const Map<String, AppThemePreset> kAppThemes = {
  'vintage': AppThemePreset(
    key: 'vintage',
    label: {'fa': 'کلاسیک (پیش‌فرض)', 'en': 'Classic (default)'},
    swatch: Color(0xFFC99A2E),
    colors: AppThemeColors(
      paper: Color(0xFFEFE6C9),
      paperDark: Color(0xFFE6DAB2),
      ink: Color(0xFF1E2A26),
      inkSoft: Color(0xFF4B5551),
      gold: Color(0xFFC99A2E),
      goldSoft: Color(0xFFE3C77E),
      teal: Color(0xFF1B4640),
      rose: Color(0xFF9E3B3B),
      cardBorder: Color(0xFFE7DEC1),
      headerFrom: Color(0xFF1B4640),
      headerTo: Color(0xFF1E2A26),
      headerText: Color(0xFFEFE6C9),
    ),
  ),
  'ocean': AppThemePreset(
    key: 'ocean',
    label: {'fa': 'اقیانوسی', 'en': 'Ocean'},
    swatch: Color(0xFF2E86DE),
    colors: AppThemeColors(
      paper: Color(0xFFEAF4F4),
      paperDark: Color(0xFFD7E9EA),
      ink: Color(0xFF0F2A38),
      inkSoft: Color(0xFF2A4E5C),
      gold: Color(0xFF1C7C93),
      goldSoft: Color(0xFF8FCBD8),
      teal: Color(0xFF1C7C93),
      rose: Color(0xFFB4533F),
      cardBorder: Color(0xFFBBD6D8),
      headerFrom: Color(0xFF3AA0F2),
      headerTo: Color(0xFF1C7C93),
      headerText: Color(0xFFF4FBFD),
    ),
  ),
  'forest': AppThemePreset(
    key: 'forest',
    label: {'fa': 'جنگلی', 'en': 'Forest'},
    swatch: Color(0xFF2FA84F),
    colors: AppThemeColors(
      paper: Color(0xFFF1F0E4),
      paperDark: Color(0xFFE2E0CC),
      ink: Color(0xFF26321D),
      inkSoft: Color(0xFF41522C),
      gold: Color(0xFF8A6D2F),
      goldSoft: Color(0xFFC9B77E),
      teal: Color(0xFF5C7A3A),
      rose: Color(0xFF9C4A3A),
      cardBorder: Color(0xFFCBCBA8),
      headerFrom: Color(0xFF3FAE5C),
      headerTo: Color(0xFF2C6B3D),
      headerText: Color(0xFFF5F8EC),
    ),
  ),
  'rosewine': AppThemePreset(
    key: 'rosewine',
    label: {'fa': 'گلبهی', 'en': 'Rosewine'},
    swatch: Color(0xFFC2185B),
    colors: AppThemeColors(
      paper: Color(0xFFF7EAEA),
      paperDark: Color(0xFFEBD6D8),
      ink: Color(0xFF3A1F26),
      inkSoft: Color(0xFF5C3540),
      gold: Color(0xFFA34960),
      goldSoft: Color(0xFFE3AFBC),
      teal: Color(0xFF6E5A78),
      rose: Color(0xFFA34960),
      cardBorder: Color(0xFFDDBFC4),
      headerFrom: Color(0xFFD45079),
      headerTo: Color(0xFF9C2E56),
      headerText: Color(0xFFFDF1F2),
    ),
  ),
  'midnight': AppThemePreset(
    key: 'midnight',
    label: {'fa': 'تیره (شب)', 'en': 'Midnight'},
    swatch: Color(0xFF3F51B5),
    colors: AppThemeColors(
      paper: Color(0xFF1B1F2A),
      paperDark: Color(0xFF262C3B),
      ink: Color(0xFFF1E8D6),
      inkSoft: Color(0xFFC9C2AE),
      gold: Color(0xFFD9A441),
      goldSoft: Color(0xFF8A6A2C),
      teal: Color(0xFF5FA997),
      rose: Color(0xFFD9776A),
      cardBorder: Color(0xFF3A4258),
      headerFrom: Color(0xFF4A5AC4),
      headerTo: Color(0xFF232A3D),
      headerText: Color(0xFFF1E8D6),
    ),
  ),
  'sunset': AppThemePreset(
    key: 'sunset',
    label: {'fa': 'غروب', 'en': 'Sunset'},
    swatch: Color(0xFFE8622C),
    colors: AppThemeColors(
      paper: Color(0xFFFCEFE2),
      paperDark: Color(0xFFF5DFC6),
      ink: Color(0xFF3A2313),
      inkSoft: Color(0xFF6B4A2C),
      gold: Color(0xFFD9752E),
      goldSoft: Color(0xFFF0B784),
      teal: Color(0xFF4E7A6E),
      rose: Color(0xFFB23A3A),
      cardBorder: Color(0xFFE6C79E),
      headerFrom: Color(0xFFF0793D),
      headerTo: Color(0xFFC24A34),
      headerText: Color(0xFFFDF3E7),
    ),
  ),
  'lavender': AppThemePreset(
    key: 'lavender',
    label: {'fa': 'بنفش (اسطوخودوس)', 'en': 'Lavender'},
    swatch: Color(0xFF8E44AD),
    colors: AppThemeColors(
      paper: Color(0xFFF1EEF8),
      paperDark: Color(0xFFE1DAF0),
      ink: Color(0xFF2C2140),
      inkSoft: Color(0xFF4C3E68),
      gold: Color(0xFF7A5FA8),
      goldSoft: Color(0xFFC5B3E3),
      teal: Color(0xFF4C7A8A),
      rose: Color(0xFFA8517F),
      cardBorder: Color(0xFFD2C5EA),
      headerFrom: Color(0xFF9C5FC4),
      headerTo: Color(0xFF6A3F92),
      headerText: Color(0xFFF8F3FC),
    ),
  ),
  'mint': AppThemePreset(
    key: 'mint',
    label: {'fa': 'نعنایی', 'en': 'Mint'},
    swatch: Color(0xFF1AAE8C),
    colors: AppThemeColors(
      paper: Color(0xFFEAF7F1),
      paperDark: Color(0xFFD6EEE2),
      ink: Color(0xFF12332A),
      inkSoft: Color(0xFF2E5548),
      gold: Color(0xFF2E9E7B),
      goldSoft: Color(0xFF9BDCC3),
      teal: Color(0xFF2E9E7B),
      rose: Color(0xFFB25353),
      cardBorder: Color(0xFFBEE0D0),
      headerFrom: Color(0xFF2BC49E),
      headerTo: Color(0xFF1B8F71),
      headerText: Color(0xFFF2FBF7),
    ),
  ),
  'amber': AppThemePreset(
    key: 'amber',
    label: {'fa': 'کهربایی', 'en': 'Amber'},
    swatch: Color(0xFFF0A202),
    colors: AppThemeColors(
      paper: Color(0xFFFDF4E3),
      paperDark: Color(0xFFF7E7C4),
      ink: Color(0xFF3D2B0E),
      inkSoft: Color(0xFF6B4F22),
      gold: Color(0xFFD98E04),
      goldSoft: Color(0xFFF3C567),
      teal: Color(0xFF4E7A3A),
      rose: Color(0xFFB23A3A),
      cardBorder: Color(0xFFEEDBA6),
      headerFrom: Color(0xFFF5A623),
      headerTo: Color(0xFFC77800),
      headerText: Color(0xFFFFF8EC),
    ),
  ),
  'coral': AppThemePreset(
    key: 'coral',
    label: {'fa': 'مرجانی', 'en': 'Coral'},
    swatch: Color(0xFFFF6F61),
    colors: AppThemeColors(
      paper: Color(0xFFFDECE9),
      paperDark: Color(0xFFF8D7D0),
      ink: Color(0xFF3A1B15),
      inkSoft: Color(0xFF6B3A2E),
      gold: Color(0xFFE0644F),
      goldSoft: Color(0xFFF5AFA0),
      teal: Color(0xFF3F8E85),
      rose: Color(0xFFE0644F),
      cardBorder: Color(0xFFF0C4B8),
      headerFrom: Color(0xFFFF7A62),
      headerTo: Color(0xFFD9432E),
      headerText: Color(0xFFFFF3EF),
    ),
  ),
  'sky': AppThemePreset(
    key: 'sky',
    label: {'fa': 'آسمانی', 'en': 'Sky'},
    swatch: Color(0xFF4FC3F7),
    colors: AppThemeColors(
      paper: Color(0xFFEAF7FD),
      paperDark: Color(0xFFD5EEFA),
      ink: Color(0xFF123244),
      inkSoft: Color(0xFF2E5568),
      gold: Color(0xFF2B93C4),
      goldSoft: Color(0xFF9BD8EF),
      teal: Color(0xFF2B93C4),
      rose: Color(0xFFC0504F),
      cardBorder: Color(0xFFBFE3F3),
      headerFrom: Color(0xFF63C8F5),
      headerTo: Color(0xFF1E86B8),
      headerText: Color(0xFFF2FBFE),
    ),
  ),
  'berry': AppThemePreset(
    key: 'berry',
    label: {'fa': 'توتی', 'en': 'Berry'},
    swatch: Color(0xFF9C1F5C),
    colors: AppThemeColors(
      paper: Color(0xFFF8ECF1),
      paperDark: Color(0xFFEED8E2),
      ink: Color(0xFF350F22),
      inkSoft: Color(0xFF5E2C42),
      gold: Color(0xFFA8356E),
      goldSoft: Color(0xFFDE9AB9),
      teal: Color(0xFF6C3B57),
      rose: Color(0xFFA8356E),
      cardBorder: Color(0xFFE0C0D0),
      headerFrom: Color(0xFFB93A79),
      headerTo: Color(0xFF7A1E4C),
      headerText: Color(0xFFFCF0F5),
    ),
  ),
  'olive': AppThemePreset(
    key: 'olive',
    label: {'fa': 'زیتونی', 'en': 'Olive'},
    swatch: Color(0xFF6B8E23),
    colors: AppThemeColors(
      paper: Color(0xFFF3F2E6),
      paperDark: Color(0xFFE6E4CC),
      ink: Color(0xFF2B2E17),
      inkSoft: Color(0xFF4C512C),
      gold: Color(0xFF8A7A2F),
      goldSoft: Color(0xFFC9BE7E),
      teal: Color(0xFF6B8E23),
      rose: Color(0xFFA15A3A),
      cardBorder: Color(0xFFD8D6B0),
      headerFrom: Color(0xFF7FA02E),
      headerTo: Color(0xFF556B1B),
      headerText: Color(0xFFF6F8EA),
    ),
  ),
  'slate': AppThemePreset(
    key: 'slate',
    label: {'fa': 'دودی', 'en': 'Slate'},
    swatch: Color(0xFF5B7C99),
    colors: AppThemeColors(
      paper: Color(0xFFEEF2F5),
      paperDark: Color(0xFFDFE6EB),
      ink: Color(0xFF1D2C38),
      inkSoft: Color(0xFF3D5566),
      gold: Color(0xFF4E7B99),
      goldSoft: Color(0xFFA9C6D6),
      teal: Color(0xFF4E7B99),
      rose: Color(0xFFB0524A),
      cardBorder: Color(0xFFCBD8E0),
      headerFrom: Color(0xFF6E93B0),
      headerTo: Color(0xFF3E5F78),
      headerText: Color(0xFFF3F7FA),
    ),
  ),
};
