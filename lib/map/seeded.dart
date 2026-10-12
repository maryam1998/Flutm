/// پورت دقیق تابع seeded() نسخه‌ی وب (Math.imul روی ۳۲ بیت)
/// تا تنه‌ها و شاخه‌ها دقیقاً همون شکل قبلی رو بگیرن.
const _m = 0xFFFFFFFF;
int _imul(int a, int b) => ((a & _m) * (b & _m)) & _m;

double Function() seeded(String s) {
  var h = (1779033703 ^ s.length) & _m;
  for (final c in s.codeUnits) {
    h = _imul(h ^ c, 3432918353);
    h = ((h << 13) | (h >> 19)) & _m;
  }
  return () {
    h = _imul(h ^ (h >> 16), 2246822507);
    h = _imul(h ^ (h >> 13), 3266489909);
    h = (h ^ (h >> 16)) & _m;
    return h / 4294967296.0;
  };
}
