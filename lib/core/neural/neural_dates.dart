// ═══════════════════════════════════════════════════════════════════
// ابزار تاریخ برای «مسیر عصبی» — تبدیل شمسی/میلادی و کلیدِ روز.
// (پورتِ مستقیمِ همان توابعِ NeuralPath.jsx در Hope؛ بدون پکیج اضافه.)
// ═══════════════════════════════════════════════════════════════════

const List<String> kPersianMonths = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];
const List<String> kEnMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _p2(int n) => n.toString().padLeft(2, '0');

/// کلیدِ روز: yyyy-MM-dd (به وقتِ محلی)
String dayKeyOf(DateTime d) => '${d.year}-${_p2(d.month)}-${_p2(d.day)}';

DateTime parseDayKey(String k) {
  final p = k.split('-');
  if (p.length == 3) {
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y != null && m != null && d != null) return DateTime(y, m, d);
  }
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// فاصله‌ی دو روز به‌صورت «روزِ تقویمی» (DST-safe)
int daysBetween(DateTime a, DateTime b) {
  final ua = DateTime.utc(a.year, a.month, a.day);
  final ub = DateTime.utc(b.year, b.month, b.day);
  return ub.difference(ua).inDays;
}

/// [jy, jm, jd]
List<int> gregorianToJalali(int gy, int gm, int gd) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  int jy;
  if (gy > 1600) {
    jy = 979;
    gy -= 1600;
  } else {
    jy = 0;
    gy -= 621;
  }
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 365 * gy +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) -
      80 +
      gd +
      gdm[gm - 1];
  jy += 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  int jm, jd;
  if (days < 186) {
    jm = 1 + (days ~/ 31);
    jd = 1 + (days % 31);
  } else {
    jm = 7 + ((days - 186) ~/ 30);
    jd = 1 + ((days - 186) % 30);
  }
  return [jy, jm, jd];
}

String faDigits(Object n) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  return n.toString().replaceAllMapped(
      RegExp(r'[0-9]'), (m) => fa[int.parse(m.group(0)!)]);
}

/// ارقام فارسی/عربی → انگلیسی (برای خواندنِ ورودیِ کاربر)
String enDigits(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = fa.indexOf(ch);
    final j = ar.indexOf(ch);
    b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : ch));
  }
  return b.toString();
}
