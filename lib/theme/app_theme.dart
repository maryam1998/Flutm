import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kLightBg = Color(0xFFF5EFE0);
const kLightBg2 = Color(0xFFEDE5D5);
const kLightInk = Color(0xFF2A2218);
const kDarkBg = Color(0xFF0B0D1E);
const kDarkBg2 = Color(0xFF151933);

// ---------- پالت صفحه‌ی «اهداف» (هم‌رنگ وب) ----------
const kGoalsBg = Color(0xFFFBF6EA); // کرم
const kGoalsGold = Color(0xFFC9972B); // طلایی
const kGoalsInk = Color(0xFF2A2218); // متن
const kGoalsMuted = Color(0xFF7A6B57); // متن کم‌رنگ
const kGoalsBorder = Color(0xFFE0D5C0); // حاشیه

// ---------- تم روشن (پیش‌فرض — شبیه وب) ----------
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: kLightBg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFC9972B),
    brightness: Brightness.light,
  ),
  useMaterial3: true,
  textTheme: GoogleFonts.vazirmatnTextTheme(),
  appBarTheme: AppBarTheme(
    backgroundColor: kLightBg,
    foregroundColor: kLightInk,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.vazirmatn(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: kLightInk,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: kLightBg,
    indicatorColor: const Color(0xFFC9972B).withAlpha(60),
    labelTextStyle: WidgetStatePropertyAll(
      GoogleFonts.vazirmatn(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: kLightInk,
    contentTextStyle: TextStyle(color: Colors.white),
  ),
);

// ---------- تم تاریک ----------
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kDarkBg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF5EC8F0),
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.dark().textTheme),
  appBarTheme: AppBarTheme(
    backgroundColor: kDarkBg,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.vazirmatn(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: kDarkBg,
    indicatorColor: const Color(0xFF5EC8F0).withAlpha(60),
    labelTextStyle: WidgetStatePropertyAll(
      GoogleFonts.vazirmatn(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  ),
);

/// تم روشنِ کرم/طلایی مخصوص صفحه‌ی اهداف و دیالوگ‌های داخل آن
final ThemeData goalsLightTheme = () {
  final base = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: kGoalsBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kGoalsGold,
      brightness: Brightness.light,
    ).copyWith(
      primary: kGoalsGold,
      onPrimary: Colors.white,
      surface: kGoalsBg,
      onSurface: kGoalsInk,
      outline: kGoalsBorder,
      outlineVariant: kGoalsBorder,
      secondaryContainer: kGoalsGold.withAlpha(48),
      onSecondaryContainer: kGoalsInk,
    ),
    dividerColor: kGoalsBorder,
    dividerTheme: const DividerThemeData(color: kGoalsBorder, thickness: 1),
    dialogTheme: const DialogThemeData(backgroundColor: kGoalsBg),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: kGoalsBg),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: kGoalsGold,
      selectionColor: kGoalsGold.withAlpha(70),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: const TextStyle(color: kGoalsMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kGoalsBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kGoalsBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kGoalsGold, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: kGoalsGold,
      side: const BorderSide(color: kGoalsBorder),
      labelStyle: const TextStyle(color: kGoalsInk),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      checkmarkColor: Colors.white,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kLightInk,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.vazirmatnTextTheme(base.textTheme)
        .apply(bodyColor: kGoalsInk, displayColor: kGoalsInk),
  );
}();

Widget goalsLightSheet(Widget child) =>
    Theme(data: goalsLightTheme, child: child);
