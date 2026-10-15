import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/media_db.dart';

Color withOp(Color c, double o) => c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

enum LabelAlign { center, left, right }

class TextCache {
  final _m = <String, TextPainter>{};

  /// رنگ دور متن؛ توی تم روشن کرمی و توی تم تاریک تیره‌ست
  Color outlineColor = const Color(0xFF0A0C18);
  void setOutline(Color c) {
    if (c == outlineColor) return;
    outlineColor = c;
    _m.clear();
  }

  TextPainter get(String text, double size, Color color, FontWeight w, {double? strokeW}) {
    final key = '$text|${size.toStringAsFixed(1)}|${color.hashCode}|${w.index}|${strokeW ?? 0}';
    final hit = _m[key];
    if (hit != null) return hit;
    if (_m.length > 500) _m.clear();
    final style = GoogleFonts.vazirmatn().copyWith(
      fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Noto Sans', 'Noto Color Emoji', 'Segoe UI Emoji', 'Apple Color Emoji'],
      fontSize: size,
      fontWeight: w,
      color: strokeW == null ? color : null,
      foreground: strokeW == null
          ? null
          : (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeJoin = StrokeJoin.round
            ..color = outlineColor),
    );
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.rtl)..layout();
    return _m[key] = tp;
  }
}

final textCache = TextCache();

/// y = خط مبنا (مثل SVG). outline = دور مشکی مثل paint-order:stroke
Rect drawText(
  Canvas c, String text, double x, double y, {
  required double size, required Color color, FontWeight weight = FontWeight.w600,
  LabelAlign align = LabelAlign.center, double? outline, bool vCenter = false,
}) {
  if (text.isEmpty) return Rect.zero;
  final fill = textCache.get(text, size, color, weight);
  final w = fill.width;
  final left = switch (align) { LabelAlign.center => x - w / 2, LabelAlign.left => x, LabelAlign.right => x - w };
  final top = vCenter ? y - fill.height / 2 : y - fill.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  if (outline != null) {
    textCache.get(text, size, color, weight, strokeW: outline).paint(c, Offset(left, top));
  }
  fill.paint(c, Offset(left, top));
  return Rect.fromLTWH(left, top, w, fill.height);
}

/// اعداد انگلیسی -> فارسی
String toFa(Object n) {
  const d = '۰۱۲۳۴۵۶۷۸۹';
  return n.toString().split('').map((ch) {
    final i = int.tryParse(ch);
    return i == null ? ch : d[i];
  }).join();
}

List<String> wrapText(String str, int maxChars) {
  final words = str.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  var lines = <String>[];
  var cur = '';
  for (final w in words) {
    if ('$cur $w'.trim().length > maxChars && cur.isNotEmpty) {
      lines.add(cur.trim());
      cur = w;
    } else {
      cur = '$cur $w'.trim();
    }
  }
  if (cur.isNotEmpty) lines.add(cur);
  if (lines.isEmpty) lines.add('');
  if (lines.length > 4) {
    lines = lines.sublist(0, 4);
    final l = lines[3];
    lines[3] = '${l.substring(0, math.min(l.length, maxChars - 1))}…';
  }
  return lines;
}

/// خط‌چین روی مسیر. dashes به‌صورت [خط، فاصله، خط، فاصله...]
void drawDashed(Canvas c, Path path, Paint p, List<double> dashes) {
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    var i = 0;
    while (d < m.length) {
      final len = dashes[i % dashes.length];
      if (i.isEven) c.drawPath(m.extractPath(d, math.min(d + len, m.length)), p);
      d += len;
      i++;
    }
  }
}

/// کش تصاویر data: URI برای رسم روی بوم
class NodeImageCache extends ChangeNotifier {
  final _cache = <String, ui.Image>{};
  final _pending = <String>{};

  ui.Image? get(String src) {
    if (src.isEmpty || !(src.startsWith('data:') || MediaDb.isRef(src))) return null;
    final k = '${src.length}:${src.hashCode}';
    final hit = _cache[k];
    if (hit != null) return hit;
    if (_pending.add(k)) _load(k, src);
    return null;
  }

  Future<void> _load(String key, String src) async {
    try {
      final bytes = MediaDb.bytes(src);
      if (bytes == null) return;
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 320);
      final frame = await codec.getNextFrame();
      _cache[key] = frame.image;
      notifyListeners();
    } catch (_) {
      // تصویر نامعتبر یا فرمت پشتیبانی‌نشده (مثل SVG): نادیده گرفته میشه
    }
  }
}
