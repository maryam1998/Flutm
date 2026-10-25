import 'dart:ui';

const kPalette = ['#f4c542', '#5ec8f0', '#f0708a', '#8f7bf0', '#63d6a8', '#f0a15e', '#e06bd6', '#7bd0f0'];
const kRingColor = '#2dd4bf';
const kDefaultTextColor = '#eef0fa';
const kNodeFill = '#12142a';
const kDefaultImgSize = 50.0;
const kIconScaleMin = 0.5;
const kIconScaleMax = 3.0;

// ─── پیش‌فرض‌های خوانا برای نقشه‌ی هدف‌گذاری ───
const kDefaultFontSize = 18.0; // اندازه‌ی نوشته‌ها
const kMeRadiusDefault = 46.0; // دایره‌ی «من»
const kGoalRadiusDefault = 28.0; // دایره‌ی هدف
const kRingRadiusDefault = 36.0; // «نزدیک شدن به هدف»
const kDefaultTrunkStyle = 'glow'; // خط پیش‌فرض: درخشان
/// وقتی خیلی زوم‌اوت است، نوشته‌ی هدف/من/حلقه حداقل تا این اندازه‌ی روی صفحه (پیکسل) بزرگ می‌شود
const kLabelMinScreenPx = 9.0;
const kLabelBoostMax = 2.5; // سقف بزرگ‌شدنِ خودکار (ضریب)
const kEmojiSizeMin = 0.1; // کمترین اندازه‌ی نوشته/ایکونِ انیمیشن (۱۰٪)

/// دکمه/برچسب «زیرشاخه» فعلاً مخفی است (نام نهایی هنوز انتخاب نشده).
/// برای برگرداندن، فقط این مقدار را true کنید.
const kShowSubActions = false;

/// سقف اندازه‌ی انیمیشن روی مسیر (ضریب؛ ۱.۰ = ۱۰۰٪)
const kWalkerSizeMin = 0.1; // ۱۰٪
const kWalkerSizeMax = 2.0; // هدف / قدم‌زن اصلی (تا ۲۰۰٪)
const kWalkerSizeDivisions = 38; // گام ۵٪ (۰.۱ تا ۲)
const kFootSizeMax = 2.0; // قدم شاخه / زیرشاخه (تا ۲۰۰٪)
const kFootScaleMin = 0.1; // کمترین مقیاس کلی قدم‌ها (۱۰٪)
const kFootScaleDefault = 0.35; // پیش‌فرض اندازه‌ی قدم‌ها (۳۵٪)
const kFootScaleMax = 5.0; // مقیاس کلی قدم‌ها در تنظیمات (تا ۵۰۰٪)

class FreqBand {
  final String label, hz, desc;
  final String color;
  final double speed;
  const FreqBand(this.label, this.hz, this.color, this.speed, this.desc);
}

const kFreqBands = <String, FreqBand>{
  'delta': FreqBand('دلتا', '۰.۵–۴', '#7c4dff', 7.0, 'بازسازی و درمان عمیق'),
  'theta': FreqBand('تتا', '۴–۸', '#9c6bff', 4.8, 'مدیتیشن و خلاقیت'),
  'alpha': FreqBand('آلفا', '۸–۱۲', '#5ec8f0', 3.4, 'آرامش هوشیار'),
  'beta': FreqBand('بتا', '۱۲–۳۰', '#63d6a8', 2.2, 'تمرکز فعال'),
  'gamma': FreqBand('گاما', '۳۰+', '#f4c542', 1.5, 'اوج تمرکز و بینش'),
};

const kBranchStyles = <String, String>{
  'organic': 'طبیعی', 'straight': 'مستقیم', 'curve': 'قوسی', 'wave': 'موجی',
  'elbow': 'زاویه‌دار', 'step': 'پله‌ای', 'zigzag': 'زیگزاگ',
};

const kTrunkStyles = <String, String>{
  'solid': 'خط راست', 'dashed': 'خط‌چین', 'dotted': 'نقطه‌چین', 'dashdot': 'خط‌نقطه',
  'long': 'خط‌چین بلند', 'double': 'دو خطی', 'glow': 'درخشان', 'taper': 'باریک‌شونده',
};

/// "#rrggbb" or "#rgb" -> Color
Color hexColor(String? hex, [Color fallback = const Color(0xFFFFFFFF)]) {
  if (hex == null) return fallback;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length != 6) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}
