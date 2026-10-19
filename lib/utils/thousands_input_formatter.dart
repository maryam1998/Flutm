import 'package:flutter/services.dart';

const _fa = '۰۱۲۳۴۵۶۷۸۹';
const _ar = '٠١٢٣٤٥٦٧٨٩';

/// ارقام فارسی/عربی → انگلیسی
String normalizeDigits(String s) {
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = _fa.indexOf(c);
    final j = _ar.indexOf(c);
    b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : c));
  }
  return b.toString();
}

/// «300000» → «300,000»
String groupThousands(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// مقدار عددی یک فیلد مبلغ (جداکننده‌ها و ارقام فارسی رو درنظر می‌گیره)
double parseMoneyInput(String s) {
  final d = normalizeDigits(s).replaceAll(RegExp(r'[^0-9]'), '');
  return double.tryParse(d) ?? 0;
}

/// حین تایپ، جداکننده‌ی هزارگان می‌ذاره (300,000) و جای مکان‌نما رو حفظ می‌کنه
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = normalizeDigits(newValue.text);
    final int end = newValue.selection.end < 0
        ? raw.length
        : (newValue.selection.end > raw.length
            ? raw.length
            : newValue.selection.end);
    final digitsBefore =
        RegExp(r'[0-9]').allMatches(raw.substring(0, end)).length;

    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final text = groupThousands(digits);

    var pos = 0, seen = 0;
    while (pos < text.length && seen < digitsBefore) {
      if (text[pos] != ',') seen++;
      pos++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: pos > text.length ? text.length : pos),
    );
  }
}
