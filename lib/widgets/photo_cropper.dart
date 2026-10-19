import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// کلید ناوبری ریشه — برای باز کردن صفحه‌ی برش از جاهایی که context ندارن (نقشه)
final GlobalKey<NavigatorState> kRootNavKey = GlobalKey<NavigatorState>();

class CropResult {
  final Uint8List bytes;
  final String mime;
  const CropResult(this.bytes, this.mime);
}

/// صفحه‌ی «برش عکس» — نسبت‌های آزاد/۱:۱/۴:۳/۳:۴/۱۶:۹/۹:۱۶، دستگیره‌های گوشه و لبه.
/// null = انصراف، وگرنه عکس برش‌خورده (PNG) یا عکس اصلی (دکمه‌ی «بدون برش»).
Future<CropResult?> showPhotoCropper(
  BuildContext? context,
  Uint8List bytes, {
  String mime = 'image/jpeg',
  double? initialRatio,
  int maxSide = 1000,
  String? progress,
}) {
  final nav = (context != null && context.mounted)
      ? Navigator.of(context)
      : kRootNavKey.currentState;
  if (nav == null) return Future.value(CropResult(bytes, mime));
  return nav.push<CropResult>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _CropPage(
      bytes: bytes,
      mime: mime,
      initialRatio: initialRatio,
      maxSide: maxSide,
      progress: progress,
    ),
  ));
}

enum _H { tl, tr, bl, br, l, r, t, b, move }

class _CropPage extends StatefulWidget {
  final Uint8List bytes;
  final String mime;
  final double? initialRatio;
  final int maxSide;
  final String? progress;
  const _CropPage({
    required this.bytes,
    required this.mime,
    required this.initialRatio,
    required this.maxSide,
    required this.progress,
  });

  @override
  State<_CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<_CropPage> {
  static const _bg = Color(0xFF0B0F1A);
  static const _gold = Color(0xFFC9972B);
  static const _chipBg = Color(0xFF151B2B);
  static const _chipBorder = Color(0xFF2A3247);

  static const List<(String, double?)> _ratios = [
    ('آزاد', null),
    ('۱:۱', 1),
    ('۴:۳', 4 / 3),
    ('۳:۴', 3 / 4),
    ('۱۶:۹', 16 / 9),
    ('۹:۱۶', 9 / 16),
  ];

  ui.Image? _img;
  Rect _crop = Rect.zero; // به پیکسل تصویر
  double? _ratio;
  _H? _h;
  Offset _grab = Offset.zero;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
    decodeImageFromList(widget.bytes).then((im) {
      if (!mounted) return;
      setState(() {
        _img = im;
        _crop = _fit(_ratio);
      });
    }).catchError((_) {
      if (mounted) Navigator.pop(context, CropResult(widget.bytes, widget.mime));
    });
  }

  @override
  void dispose() {
    _img?.dispose();
    super.dispose();
  }

  double get _iw => _img!.width.toDouble();
  double get _ih => _img!.height.toDouble();

  Rect _fit(double? r) {
    final w = _iw, h = _ih;
    if (r == null) return Rect.fromLTWH(w * .05, h * .05, w * .9, h * .9);
    var cw = w * .9, ch = cw / r;
    if (ch > h * .9) {
      ch = h * .9;
      cw = ch * r;
    }
    return Rect.fromCenter(center: Offset(w / 2, h / 2), width: cw, height: ch);
  }

  // ───────── gestures ─────────

  _H? _hit(Offset p, Rect fitted, double s) {
    final c = Rect.fromLTRB(
      fitted.left + _crop.left * s,
      fitted.top + _crop.top * s,
      fitted.left + _crop.right * s,
      fitted.top + _crop.bottom * s,
    );
    const tol = 34.0;
    bool near(Offset a) => (p - a).distance < tol;
    if (near(c.topLeft)) return _H.tl;
    if (near(c.topRight)) return _H.tr;
    if (near(c.bottomLeft)) return _H.bl;
    if (near(c.bottomRight)) return _H.br;
    final inX = p.dx > c.left - tol && p.dx < c.right + tol;
    final inY = p.dy > c.top - tol && p.dy < c.bottom + tol;
    if (inX && (p.dy - c.top).abs() < tol) return _H.t;
    if (inX && (p.dy - c.bottom).abs() < tol) return _H.b;
    if (inY && (p.dx - c.left).abs() < tol) return _H.l;
    if (inY && (p.dx - c.right).abs() < tol) return _H.r;
    if (c.contains(p)) return _H.move;
    return null;
  }

  Offset _toImg(Offset p, Rect fitted, double s) => Offset(
        ((p.dx - fitted.left) / s).clamp(0.0, _iw).toDouble(),
        ((p.dy - fitted.top) / s).clamp(0.0, _ih).toDouble(),
      );

  void _start(Offset p, Rect fitted, double s) {
    _h = _hit(p, fitted, s);
    if (_h == _H.move) _grab = _toImg(p, fitted, s) - _crop.topLeft;
  }

  void _update(Offset pw, Rect fitted, double s) {
    final h = _h;
    if (h == null || _img == null) return;
    final p = _toImg(pw, fitted, s);
    final minPx = math.min(48 / s, math.min(_iw, _ih) / 2);
    final r = _ratio;
    var c = _crop;

    if (h == _H.move) {
      var l = p.dx - _grab.dx, t = p.dy - _grab.dy;
      l = l.clamp(0.0, _iw - c.width).toDouble();
      t = t.clamp(0.0, _ih - c.height).toDouble();
      setState(() => _crop = Rect.fromLTWH(l, t, c.width, c.height));
      return;
    }

    if (r == null) {
      var l = c.left, t = c.top, rr = c.right, b = c.bottom;
      if (h == _H.l || h == _H.tl || h == _H.bl) l = p.dx.clamp(0.0, rr - minPx).toDouble();
      if (h == _H.r || h == _H.tr || h == _H.br) rr = p.dx.clamp(l + minPx, _iw).toDouble();
      if (h == _H.t || h == _H.tl || h == _H.tr) t = p.dy.clamp(0.0, b - minPx).toDouble();
      if (h == _H.b || h == _H.bl || h == _H.br) b = p.dy.clamp(t + minPx, _ih).toDouble();
      setState(() => _crop = Rect.fromLTRB(l, t, rr, b));
      return;
    }

    // نسبت قفل
    final isCorner = h == _H.tl || h == _H.tr || h == _H.bl || h == _H.br;
    if (isCorner) {
      final right = h == _H.tr || h == _H.br;
      final bottom = h == _H.bl || h == _H.br;
      final anchor = Offset(right ? c.left : c.right, bottom ? c.top : c.bottom);
      final sx = right ? 1.0 : -1.0, sy = bottom ? 1.0 : -1.0;
      final maxW = sx > 0 ? _iw - anchor.dx : anchor.dx;
      final maxH = sy > 0 ? _ih - anchor.dy : anchor.dy;
      var w = (sx * (p.dx - anchor.dx));
      var hh = (sy * (p.dy - anchor.dy));
      w = math.max(w, hh * r);
      w = math.max(w, minPx);
      var nh = w / r;
      if (nh > maxH) {
        nh = maxH;
        w = nh * r;
      }
      if (w > maxW) {
        w = maxW;
        nh = w / r;
      }
      c = Rect.fromPoints(anchor, Offset(anchor.dx + sx * w, anchor.dy + sy * nh));
    } else if (h == _H.l || h == _H.r) {
      final ax = h == _H.r ? c.left : c.right;
      final sx = h == _H.r ? 1.0 : -1.0;
      final maxW = sx > 0 ? _iw - ax : ax;
      var w = (sx * (p.dx - ax)).clamp(minPx, maxW).toDouble();
      var nh = w / r;
      if (nh > _ih) {
        nh = _ih;
        w = nh * r;
      }
      final cy = c.center.dy.clamp(nh / 2, _ih - nh / 2).toDouble();
      c = Rect.fromPoints(Offset(ax, cy - nh / 2), Offset(ax + sx * w, cy + nh / 2));
    } else {
      final ay = h == _H.b ? c.top : c.bottom;
      final sy = h == _H.b ? 1.0 : -1.0;
      final maxH = sy > 0 ? _ih - ay : ay;
      var nh = (sy * (p.dy - ay)).clamp(minPx, maxH).toDouble();
      var w = nh * r;
      if (w > _iw) {
        w = _iw;
        nh = w / r;
      }
      final cx = c.center.dx.clamp(w / 2, _iw - w / 2).toDouble();
      c = Rect.fromPoints(Offset(cx - w / 2, ay), Offset(cx + w / 2, ay + sy * nh));
    }
    setState(() => _crop = c);
  }

  // ───────── output ─────────

  Future<void> _confirm() async {
    if (_img == null || _busy) return;
    setState(() => _busy = true);
    try {
      final src = _crop;
      var ow = src.width, oh = src.height;
      final k = math.min(1.0, widget.maxSide / math.max(ow, oh));
      ow = math.max(1, ow * k);
      oh = math.max(1, oh * k);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawImageRect(_img!, src, Rect.fromLTWH(0, 0, ow, oh),
          Paint()..filterQuality = FilterQuality.high);
      final out = await rec.endRecording().toImage(ow.round(), oh.round());
      final bd = await out.toByteData(format: ui.ImageByteFormat.png);
      out.dispose();
      if (!mounted) return;
      if (bd == null) {
        Navigator.pop(context, CropResult(widget.bytes, widget.mime));
      } else {
        Navigator.pop(context, CropResult(bd.buffer.asUint8List(), 'image/png'));
      }
    } catch (_) {
      if (mounted) Navigator.pop(context, CropResult(widget.bytes, widget.mime));
    }
  }

  // ───────── UI ─────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 14),
              Text(
                widget.progress == null ? 'برش عکس' : 'برش عکس (${widget.progress})',
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    for (final it in _ratios) ...[
                      _chip(it.$1, it.$2),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: _area()),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _btn('انصراف', () => Navigator.pop(context)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _btn(
                        'بدون برش',
                        () => Navigator.pop(
                            context, CropResult(widget.bytes, widget.mime)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _btn('تأیید', _confirm, primary: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, double? r) {
    final sel = _ratio == r;
    return GestureDetector(
      onTap: _img == null
          ? null
          : () => setState(() {
                _ratio = r;
                _crop = _fit(r);
              }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: sel ? _gold : _chipBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? _gold : _chipBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? const Color(0xFF1A1305) : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap, {bool primary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? _gold : _chipBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary ? _gold : _chipBorder),
        ),
        child: _busy && primary
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : Text(
                label,
                style: TextStyle(
                  color: primary ? const Color(0xFF1A1305) : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  Widget _area() {
    if (_img == null) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    return LayoutBuilder(builder: (ctx, box) {
      const pad = 14.0;
      final aw = box.maxWidth - pad * 2, ah = box.maxHeight - pad * 2;
      final s = math.min(aw / _iw, ah / _ih);
      final fitted = Rect.fromLTWH(
        pad + (aw - _iw * s) / 2,
        pad + (ah - _ih * s) / 2,
        _iw * s,
        _ih * s,
      );
      final cw = Rect.fromLTRB(
        fitted.left + _crop.left * s,
        fitted.top + _crop.top * s,
        fitted.left + _crop.right * s,
        fitted.top + _crop.bottom * s,
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _start(d.localPosition, fitted, s),
        onPanUpdate: (d) => _update(d.localPosition, fitted, s),
        onPanEnd: (_) => _h = null,
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: fitted,
              child: RawImage(image: _img, fit: BoxFit.fill),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _CropPainter(fitted, cw)),
            ),
          ],
        ),
      );
    });
  }
}

class _CropPainter extends CustomPainter {
  final Rect fitted, crop;
  _CropPainter(this.fitted, this.crop);

  @override
  void paint(Canvas canvas, Size size) {
    // تیره کردن بیرون کادر
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(fitted)
      ..addRect(crop);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.55));

    // شبکه‌ی ثلث‌ها
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final x = crop.left + crop.width * i / 3;
      final y = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), grid);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), grid);
    }

    // کادر
    canvas.drawRect(
      crop,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // دستگیره‌ها
    final hp = Paint()..color = Colors.white;
    final sh = Paint()..color = Colors.black.withValues(alpha: 0.35);
    void rr(Offset c, double w, double h) {
      final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: w, height: h), const Radius.circular(6));
      canvas.drawRRect(rect.shift(const Offset(0, 1)), sh);
      canvas.drawRRect(rect, hp);
    }

    rr(crop.topLeft, 26, 26);
    rr(crop.topRight, 26, 26);
    rr(crop.bottomLeft, 26, 26);
    rr(crop.bottomRight, 26, 26);
    if (crop.width > 120) {
      rr(Offset(crop.center.dx, crop.top), 60, 12);
      rr(Offset(crop.center.dx, crop.bottom), 60, 12);
    }
    if (crop.height > 120) {
      rr(Offset(crop.left, crop.center.dy), 12, 60);
      rr(Offset(crop.right, crop.center.dy), 12, 60);
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) =>
      old.crop != crop || old.fitted != fitted;
}
