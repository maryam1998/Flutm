import 'package:flutter/material.dart';

/// رنگ ثابت هر سطح CEFR — در تمام تب‌ها یکسان
Color levelColor(String level) {
  switch (level) {
    case 'A1': return const Color(0xFF2E9E7B); // سبز زمردی
    case 'A2': return const Color(0xFF4A9EAF); // فیروزه‌ای
    case 'B1': return const Color(0xFF7A5FA8); // بنفش
    case 'B2': return const Color(0xFFB85A72); // رز
    case 'C1': return const Color(0xFFD9752E); // نارنجی
    case 'C2': return const Color(0xFFA0354B); // قرمز تیره
    default:   return const Color(0xFF4B5551);
  }
}

/// پس‌زمینه‌ی ملایم (۱۴٪ شفافیت)
Color levelBgColor(String level) => levelColor(level).withOpacity(0.14);
