String toFaDigits(String s) {
  return s.replaceAllMapped(
    RegExp(r'\d'),
    (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
  );
}

/// واحد پولِ بازی فراوانی (از تنظیمات بازی ست می‌شود)
String gMoneyUnit = 'تومان';

/// واحدهای قابل انتخاب در تنظیم بازی فراوانی
const List<String> kMoneyUnits = ['تومان', 'دلار', 'یورو', 'ریال'];

String formatMoney(double amount, {String? unit}) {
  final rounded = amount.round();
  final neg = rounded < 0;
  final abs = rounded.abs();
  final s = abs.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${neg ? '−' : ''}${toFaDigits(buf.toString())} ${unit ?? gMoneyUnit}';
}

String formatMoneyShort(double amount) {
  final rounded = amount.round();
  if (rounded >= 1000000) {
    final m = rounded / 1000000;
    return '${toFaDigits(m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1))} میلیون $gMoneyUnit';
  }
  return formatMoney(amount);
}
