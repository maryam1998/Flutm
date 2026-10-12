/// تبدیل میلادی ↔ جلالی (پورت دقیق calG2d / calD2j نسخه‌ی وب)
/// کلید روزها در لاگ‌ها «سال-ماه-روز جلالی» بدون صفر پیشوند است؛ مثل 1405-7-20

const kJalaliMonths = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

int _div(int a, int b) => a ~/ b;
int _mod(int a, int b) => a - (a ~/ b) * b;

class _JalCal {
  _JalCal(this.leap, this.gy, this.march);
  final int leap, gy, march;
}

_JalCal _jalCal(int jy) {
  const breaks = [-61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178];
  final gy = jy + 621;
  var leapJ = -14, jp = breaks[0], jump = 0;
  for (var i = 1; i < breaks.length; i++) {
    final jm = breaks[i];
    jump = jm - jp;
    if (jy < jm) break;
    leapJ = leapJ + _div(jump, 33) * 8 + _div(_mod(jump, 33), 4);
    jp = jm;
  }
  var n = jy - jp;
  leapJ = leapJ + _div(n, 33) * 8 + _div(_mod(n, 33) + 3, 4);
  if (_mod(jump, 33) == 4 && jump - n == 4) leapJ += 1;
  final leapG = _div(gy, 4) - _div((_div(gy, 100) + 1) * 3, 4) - 150;
  final march = 20 + leapJ - leapG;
  if (jump - n < 6) n = n - jump + _div(jump, 33) * 33;
  var leap = _mod(_mod(n + 1, 33) - 1, 4);
  if (leap == -1) leap = 4;
  return _JalCal(leap, gy, march);
}

int _g2d(int gy, int gm, int gd) {
  var d = _div((gy + _div(gm - 8, 6) + 100100) * 1461, 4) + _div(153 * _mod(gm + 9, 12) + 2, 5) + gd - 34840408;
  d = d - _div(_div(gy + 100100 + _div(gm - 8, 6), 100) * 3, 4) + 752;
  return d;
}

int _d2gYear(int jdn) {
  var j = 4 * jdn + 139361631;
  j = j + _div(_div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908;
  final i = _div(_mod(j, 1461), 4) * 5 + 308;
  final gm = _mod(_div(i, 153), 12) + 1;
  return _div(j, 1461) - 100100 + _div(8 - gm, 6);
}

class Jalali {
  const Jalali(this.jy, this.jm, this.jd);
  final int jy, jm, jd;
}

Jalali toJalaali(int gy, int gm, int gd) {
  final jdn = _g2d(gy, gm, gd);
  final gyy = _d2gYear(jdn);
  var jy = gyy - 621;
  final r = _jalCal(jy);
  final jdn1f = _g2d(gyy, 3, r.march);
  var k = jdn - jdn1f;
  if (k >= 0) {
    if (k <= 185) return Jalali(jy, 1 + _div(k, 31), _mod(k, 31) + 1);
    k -= 186;
  } else {
    jy -= 1;
    k += 179;
    if (r.leap == 1) k += 1;
  }
  return Jalali(jy, 7 + _div(k, 30), _mod(k, 30) + 1);
}

/// کلید روز جلالی برای لاگ‌ها (مثل pcJKey)
String jKey(DateTime d) {
  final j = toJalaali(d.year, d.month, d.day);
  return '${j.jy}-${j.jm}-${j.jd}';
}

/// کلید روز میلادی محلی (YYYY-MM-DD) برای startDate دوره‌ها
String localKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseLocalKey(String k) {
  final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
  if (p.length != 3) return DateTime.now();
  return DateTime(p[0], p[1], p[2]);
}

/// کلیدهای جلالی ۷ روز هفته‌ی جاری (شنبه تا جمعه)
List<String> jalaaliCurrentWeekDates() {
  final now = DateTime.now();
  final wd = now.weekday; // Mon=1 ... Sat=6, Sun=7
  // شنبه = 0، یکشنبه = 1، ...، جمعه = 6
  int jalaliWeekday;
  if (wd == 6) {
    jalaliWeekday = 0; // Sat
  } else if (wd == 7) {
    jalaliWeekday = 1; // Sun
  } else {
    jalaliWeekday = wd + 1; // Mon=2 ... Fri=6
  }
  final start = now.subtract(Duration(days: jalaliWeekday));
  final keys = <String>[];
  for (var i = 0; i < 7; i++) {
    keys.add(jKey(start.add(Duration(days: i))));
  }
  return keys;
}

/// کلید جلالی امروز
String todayJK() => jKey(DateTime.now());
