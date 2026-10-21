import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../theme/vazir_font.dart';

import '../services/data_url_cache.dart';
import '../services/media_kind.dart';

Color withOp(Color c, double o) => c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

enum LabelAlign { center, left, right }

class TextCache {
  final _m = <String, TextPainter>{};

  /// رنگ دور متنِ گره/شاخه (`.node-label` / `.branch-label`): تم روشن #F4F6FB، تم تاریک #0A0C18
  Color outlineColor = const Color(0xFF0A0C18);
  void setOutline(Color c) {
    if (c == outlineColor) return;
    outlineColor = c;
    _m.clear();
  }

  TextPainter get(String text, double size, Color color, FontWeight w, {double? strokeW, Color? outlineOverride}) {
    final key = '$text|${size.toStringAsFixed(1)}|${color.hashCode}|${w.index}|${strokeW ?? 0}|${outlineOverride?.hashCode ?? 0}';
    final hit = _m[key];
    if (hit != null) return hit;
    if (_m.length > 500) _m.clear();
    final style = GoogleFonts.vazirmatn().copyWith(
      fontFamilyFallback: [...GoogleFonts.emojiFallback, 'Segoe UI', 'Tahoma', 'Noto Sans', 'Noto Color Emoji', 'Segoe UI Emoji', 'Apple Color Emoji'],
      fontSize: size,
      fontWeight: w,
      color: strokeW == null ? color : null,
      foreground: strokeW == null
          ? null
          : (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeJoin = StrokeJoin.round
            ..color = outlineOverride ?? outlineColor),
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
  Color? outlineColor,
}) {
  if (text.isEmpty) return Rect.zero;
  final fill = textCache.get(text, size, color, weight);
  final w = fill.width;
  final left = switch (align) { LabelAlign.center => x - w / 2, LabelAlign.left => x, LabelAlign.right => x - w };
  final top = vCenter ? y - fill.height / 2 : y - fill.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  if (outline != null) {
    textCache.get(text, size, color, weight, strokeW: outline, outlineOverride: outlineColor).paint(c, Offset(left, top));
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

/// کش تصاویر data: URI برای رسم روی بوم.
/// یک نمونه‌ی مشترک ([shared]) هست تا عکسِ تازه‌انتخاب‌شده همون لحظه‌ی انتخاب، پیش‌دیکُد (warm)
/// بشه و موقع نشون دادن روی نقشه منتظر دیکُد نمونه.
class _AnimFrames {
  _AnimFrames(this.frames, this.ends, this.total);
  final List<ui.Image> frames;
  final List<int> ends; // زمان پایان هر فریم (میلی‌ثانیه، تجمعی)
  final int total;

  ui.Image at(double sec) {
    if (frames.length == 1 || total <= 0) return frames.first;
    final ms = ((sec * 1000).floor()) % total;
    var lo = 0, hi = ends.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (ends[mid] > ms) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return frames[lo];
  }
}

class NodeImageCache extends ChangeNotifier {
  static final NodeImageCache shared = NodeImageCache();

  /// سقف حافظه‌ی فریم‌های یک عکس متحرک (بایت)
  static const int _animMaxBytes = 48 * 1024 * 1024;
  static const int _animWidth = 320;

  final _cache = <String, ui.Image>{};
  final _pending = <String>{};
  final _anims = <String, _AnimFrames>{};
  final _animPending = <String>{};
  final _notAnim = <String>{};

  // کلید ارزان (به‌جای hashCode کل رشته‌ی چند مگابایتی که هر فریم محاسبه می‌شد)
  static String _key(String src) {
    final n = src.length;
    final a = src.indexOf(',') + 1;
    final head = src.substring(a, a + 64 > n ? n : a + 64);
    final tail = src.substring(n - 64 < a ? a : n - 64);
    final mid = n > a + 400 ? src.substring(n ~/ 2, n ~/ 2 + 48) : '';
    return '$n:${Object.hash(head, tail, mid)}';
  }

  /// آماده‌سازی بی‌صدا (بدون برگرداندن چیزی)
  void warm(String src) => get(src);

  /// [animate] = true و عکس متحرک (GIF / WebP / APNG) → فریمِ زمان [t] (ثانیه) برمی‌گردد؛
  /// تا آماده‌شدن فریم‌ها (یا برای عکس ثابت) همان فریم اول است.
  ui.Image? get(String src, {bool animate = false, double t = 0}) {
    if (src.isEmpty || !src.startsWith('data:')) return null;
    final k = _key(src);
    if (animate) {
      final an = _anims[k];
      if (an != null) return an.at(t);
      if (!_notAnim.contains(k) && _animPending.add(k)) _loadAnim(k, src);
    }
    final hit = _cache[k];
    if (hit != null) return hit;
    if (_pending.add(k)) _load(k, src);
    return null;
  }

  Future<void> _load(String key, String src) async {
    try {
      final bytes = DataUrlCache.bytes(src);
      if (bytes == null) return;
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 400);
      final frame = await codec.getNextFrame();
      _cache[key] = frame.image;
      _pending.remove(key);
      notifyListeners();
    } catch (_) {
      // تصویر نامعتبر یا فرمت پشتیبانی‌نشده (مثل SVG): در pending می‌مونه تا هر فریم دوباره تلاش نشه
    }
  }

  /// همه‌ی فریم‌های عکس متحرک را (با عرض کم و سقف حافظه) دیکُد می‌کند.
  Future<void> _loadAnim(String key, String src) async {
    try {
      final bytes = DataUrlCache.bytes(src);
      if (bytes == null || !MediaKind.isAnimatedImage(bytes)) {
        _notAnim.add(key);
        return;
      }
      var codec = await ui.instantiateImageCodec(bytes, targetWidth: _animWidth);
      final n = codec.frameCount;
      if (n <= 1) {
        codec.dispose();
        _notAnim.add(key);
        return;
      }
      final first = await codec.getNextFrame();
      final perFrame = first.image.width * first.image.height * 4;
      if (perFrame * n > _animMaxBytes) {
        // کوچک‌تر دیکُد کن تا در سقف حافظه جا شود
        final k = math.sqrt(_animMaxBytes / (perFrame * n));
        final w = math.max(48, (_animWidth * k).floor());
        first.image.dispose();
        codec.dispose();
        codec = await ui.instantiateImageCodec(bytes, targetWidth: w);
        final f0 = await codec.getNextFrame();
        return _finishAnim(key, codec, f0, n);
      }
      return _finishAnim(key, codec, first, n);
    } catch (_) {
      _notAnim.add(key);
    } finally {
      _animPending.remove(key);
    }
  }

  Future<void> _finishAnim(
      String key, ui.Codec codec, ui.FrameInfo first, int n) async {
    final frames = <ui.Image>[first.image];
    final ends = <int>[];
    var acc = 0;
    int dur(ui.FrameInfo f) {
      final ms = f.duration.inMilliseconds;
      return ms < 20 ? 100 : ms; // GIFهای بدون زمان‌بندی: ۱۰۰ms
    }

    acc += dur(first);
    ends.add(acc);
    for (var i = 1; i < n; i++) {
      final f = await codec.getNextFrame();
      frames.add(f.image);
      acc += dur(f);
      ends.add(acc);
    }
    codec.dispose();
    _anims[key] = _AnimFrames(frames, ends, acc);
    notifyListeners();
  }
}
