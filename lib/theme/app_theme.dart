import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kLightBg = Color(0xFFF5EFE0);
const kLightBg2 = Color(0xFFEDE5D5);
const kLightInk = Color(0xFF2A2218);
const kDarkBg = Color(0xFF0B0D1E);
const kDarkBg2 = Color(0xFF151933);

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

/// پنل‌های پایین‌روی اپ پس‌زمینه‌ی تیره‌ی ثابت دارن و متن‌هاشون برای زمینه‌ی تیره نوشته شده؛
/// این wrapper باعث می‌شه توی تم روشن هم متن‌ها روشن بمونن و خوانا باشن.
Widget darkSheet(Widget child) => Theme(data: darkTheme, child: child);
