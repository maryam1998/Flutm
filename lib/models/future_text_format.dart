import 'package:flutter/material.dart';

import '../services/note_fonts.dart';

/// یک گزینه‌ی فونت برای متن آینده.
/// فونت‌ها همان فهرستِ «یادداشت روی نقشه» ([kNoteFonts]) هستند و با اولین
/// انتخاب دانلود می‌شوند (فونت‌های سیستمی مثل B Nazanin روی گوشی/وب وجود ندارند).
class FutureFont {
  final String id;
  final String label;

  const FutureFont({required this.id, required this.label});

  /// null = پیش‌فرض یا هنوز دانلود نشده
  String? get family => id.isEmpty ? null : NoteFonts.familyOf(id);
}

final List<FutureFont> kFutureFonts = [
  const FutureFont(id: '', label: 'پیش‌فرض'),
  for (final f in kNoteFonts) FutureFont(id: f.id, label: f.label),
];

/// شناسه‌های قدیمیِ ذخیره‌شده ← فونت معادل در فهرست جدید
const Map<String, String> _legacyFontIds = {
  'nazanin': 'amiri',
  'titr': 'lalezar',
  'nastaliq': 'arefruqaa',
  'zar': 'scheherazade',
  'arial': 'tajawal',
  'times': 'amiri',
};

/// شناسه‌ی معتبر (قدیمی‌ها تبدیل می‌شوند؛ ناشناخته = پیش‌فرض)
String futureFontId(String id) {
  final m = _legacyFontIds[id] ?? id;
  return NoteFonts.byId(m) == null ? '' : m;
}

String? futureFontFamily(String id) {
  final fid = futureFontId(id);
  if (fid.isEmpty) return null;
  NoteFonts.ensure(fid); // اگر دانلود نشده، همین حالا شروع می‌شود
  return NoteFonts.familyOf(fid);
}

/// فرمت متن آینده — فونت، اندازه، تراز، بولد، ایتالیک
class FutureTextFormat {
  String font;    // id از kFutureFonts
  int size;       // 10..40
  String align;   // 'right' | 'center' | 'left'
  bool bold;
  bool italic;

  FutureTextFormat({
    this.font = '',
    this.size = 14,
    this.align = 'right',
    this.bold = false,
    this.italic = true,
  });

  static const int minSize = 10;
  static const int maxSize = 40;

  FutureTextFormat copyWith({
    String? font,
    int? size,
    String? align,
    bool? bold,
    bool? italic,
  }) {
    return FutureTextFormat(
      font: font ?? this.font,
      size: size ?? this.size,
      align: align ?? this.align,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
    );
  }

  TextAlign get textAlign => align == 'center'
      ? TextAlign.center
      : (align == 'left' ? TextAlign.left : TextAlign.right);

  TextStyle buildStyle({Color? color}) {
    return TextStyle(
      fontFamily: futureFontFamily(font),
      fontFamilyFallback: const ['Vazirmatn'],
      fontSize: size.toDouble(),
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      color: color,
      height: 1.9,
    );
  }

  factory FutureTextFormat.fromJson(Map<String, dynamic>? j) {
    if (j == null) return FutureTextFormat();
    final size = (j['size'] as num?)?.toInt() ?? 14;
    final align = j['align'] as String? ?? 'right';
    return FutureTextFormat(
      font: futureFontId(j['font'] as String? ?? ''),
      size: size.clamp(minSize, maxSize),
      align: ['right', 'center', 'left'].contains(align) ? align : 'right',
      bold: j['bold'] == true,
      italic: j['italic'] != false, // پیش‌فرض true
    );
  }

  Map<String, dynamic> toJson() => {
        'font': font,
        'size': size,
        'align': align,
        'bold': bold,
        'italic': italic,
      };
}
