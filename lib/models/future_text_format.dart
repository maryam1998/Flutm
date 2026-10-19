import 'package:flutter/material.dart';

/// یک گزینه‌ی فونت برای متن آینده
class FutureFont {
  final String id;
  final String label;
  final String? family; // null = پیش‌فرض

  const FutureFont({required this.id, required this.label, this.family});
}

const List<FutureFont> kFutureFonts = [
  FutureFont(id: '',         label: 'پیش‌فرض'),
  FutureFont(id: 'nazanin',  label: 'بی نازنین',    family: 'B Nazanin'),
  FutureFont(id: 'titr',     label: 'بی تیتر',       family: 'B Titr'),
  FutureFont(id: 'nastaliq', label: 'نستعلیق',       family: 'IranNastaliq'),
  FutureFont(id: 'zar',      label: 'بی زر',          family: 'B Zar'),
  FutureFont(id: 'arial',    label: 'Arial',          family: 'Arial'),
  FutureFont(id: 'times',    label: 'Times New Roman',family: 'Times New Roman'),
];

String? futureFontFamily(String id) {
  for (final f in kFutureFonts) {
    if (f.id == id) return f.family;
  }
  return null;
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
      font: j['font'] as String? ?? '',
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
