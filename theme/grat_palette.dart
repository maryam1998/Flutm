import 'package:flutter/material.dart';

/// متغیرهای CSS دقیقِ `#grat-root` نسخه‌ی وب
/// (css/tamrin-and-beliefs.css برای روشن، css/base-and-map.css برای تاریک)
/// به‌علاوه‌ی متغیرهای سراسری html (--accent / --input-bg / --text-dim / --panel-border)
class GratPalette {
  const GratPalette({
    required this.paper,
    required this.card,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.line,
    required this.emerald900,
    required this.emerald700,
    required this.emerald500,
    required this.emerald300,
    required this.gold600,
    required this.gold500,
    required this.gold300,
    required this.tint,
    required this.danger,
    required this.accent,
    required this.inputBg,
    required this.textDim,
    required this.panelBorder,
    required this.isDark,
  });

  final Color paper, card, surface, surface2;
  final Color ink, inkSoft, muted, line;
  final Color emerald900, emerald700, emerald500, emerald300;
  final Color gold600, gold500, gold300;
  final Color tint, danger;

  /// --accent / --input-bg / --text-dim / --panel-border (سطح html)
  final Color accent, inputBg, textDim, panelBorder;
  final bool isDark;

  static const light = GratPalette(
    paper: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFF7F6F1),
    surface2: Color(0xFFF0EFE8),
    ink: Color(0xFF000000),
    inkSoft: Color(0xFF3D5551),
    muted: Color(0xFF7C8B87),
    line: Color(0xFFE7E5DB),
    emerald900: Color(0xFF0A3D38),
    emerald700: Color(0xFF0F5B53),
    emerald500: Color(0xFF178A7C),
    emerald300: Color(0xFF54B3A4),
    gold600: Color(0xFFA9812F),
    gold500: Color(0xFFC9A24B),
    gold300: Color(0xFFE6CD8E),
    tint: Color(0xFFFBF7EA),
    danger: Color(0xFFB3452F),
    accent: Color(0xFFC9962B),
    inputBg: Color(0xFFF1F2F8),
    textDim: Color(0xFF5B5F77),
    panelBorder: Color.fromRGBO(20, 24, 50, 0.10),
    isDark: false,
  );

  static const dark = GratPalette(
    paper: Color(0xFF161925),
    card: Color(0xFF20232F),
    surface: Color(0xFF20232F),
    surface2: Color(0xFF282C3B),
    ink: Color(0xFFFFFFFF),
    inkSoft: Color(0xFFC7CADF),
    muted: Color(0xFF8B8FA8),
    line: Color(0xFF333750),
    emerald900: Color(0xFF123A34),
    emerald700: Color(0xFF1F9384),
    emerald500: Color(0xFF2BBFAB),
    emerald300: Color(0xFF54C9B8),
    gold600: Color(0xFFE0B64A),
    gold500: Color(0xFFD3AC52),
    gold300: Color(0xFF8A6F33),
    tint: Color(0xFF2A2716),
    danger: Color(0xFFB3452F),
    accent: Color(0xFFF4C542),
    inputBg: Color(0xFF0E1022),
    textDim: Color(0xFF8F93B3),
    panelBorder: Color.fromRGBO(255, 255, 255, 0.08),
    isDark: true,
  );

  static GratPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
