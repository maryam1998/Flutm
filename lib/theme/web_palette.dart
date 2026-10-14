import 'package:flutter/material.dart';

/// پالت دقیقِ وب‌اپ Maghz (متغیرهای CSS در css/base-and-map.css و tamrin-and-beliefs.css)
class WebPalette {
  const WebPalette({
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.panelBg,
    required this.panelBorder,
    required this.textMain,
    required this.textDim,
    required this.accent,
    required this.paper,
    required this.navBg,
    required this.line,
    required this.muted,
    required this.subActive,
  });

  /// --bg-1 / --bg-2 / رنگ پایانی گرادیان بدنه
  final Color bg1, bg2, bg3;

  /// --panel-bg / --panel-border
  final Color panelBg, panelBorder;

  /// --text-main / --text-dim / --accent
  final Color textMain, textDim, accent;

  /// تب «تمرین»: --paper / --nav-bg / --line / --muted / --emerald-700
  final Color paper, navBg, line, muted, subActive;

  static const light = WebPalette(
    bg1: Color(0xFFEEF1F8),
    bg2: Color(0xFFDBE1F0),
    bg3: Color(0xFFEEF1F8),
    panelBg: Color.fromRGBO(255, 255, 255, 0.92),
    panelBorder: Color.fromRGBO(20, 24, 50, 0.10),
    textMain: Color(0xFF000000),
    textDim: Color(0xFF5B5F77),
    accent: Color(0xFFC9962B),
    paper: Color(0xFFFFFFFF),
    navBg: Color.fromRGBO(255, 255, 255, 0.94),
    line: Color(0xFFE7E5DB),
    muted: Color(0xFF7C8B87),
    subActive: Color(0xFF0F5B53),
  );

  static const dark = WebPalette(
    bg1: Color(0xFF0A0C18),
    bg2: Color(0xFF150F28),
    bg3: Color(0xFF0C0A1C),
    panelBg: Color.fromRGBO(18, 20, 38, 0.92),
    panelBorder: Color.fromRGBO(255, 255, 255, 0.08),
    textMain: Color(0xFFFFFFFF),
    textDim: Color(0xFF8F93B3),
    accent: Color(0xFFF4C542),
    paper: Color(0xFF161925),
    navBg: Color.fromRGBO(22, 25, 37, 0.94),
    line: Color(0xFF333750),
    muted: Color(0xFF8B8FA8),
    subActive: Color(0xFF1F9384),
  );

  static WebPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
