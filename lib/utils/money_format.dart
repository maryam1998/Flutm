String toFaDigits(String s) {
  return s.replaceAllMapped(
    RegExp(r'\d'),
    (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
  );
}

String formatMoney(double amount) {
  final rounded = amount.round();
  final neg = rounded < 0;
  final abs = rounded.abs();
  final s = abs.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${neg ? '−' : ''}${toFaDigits(buf.toString())} تومان';
}

String formatMoneyShort(double amount) {
  final rounded = amount.round();
  if (rounded >= 1000000) {
    final m = rounded / 1000000;
    return '${toFaDigits(m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1))} میلیون تومان';
  }
  return formatMoney(amount);
}
