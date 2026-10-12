import 'dart:math' as math;

import 'package:flutter/material.dart';

/// دوربین بوم: جابجایی + زوم (بازه‌ی زوم مثل وب: ۵٪ تا ۴۰۰٪)
class CameraController extends ChangeNotifier {
  double x = 0, y = 0, scale = 1;
  Size view = Size.zero;
  bool _inited = false;

  /// اولین بار «من» وسط صفحه قرار می‌گیره (مثل وب)
  void initCenter(Size s) {
    view = s;
    if (!_inited && s.width > 0) {
      x = s.width / 2;
      y = s.height / 2;
      _inited = true;
    }
  }

  Offset screenToWorld(Offset s) => Offset((s.dx - x) / scale, (s.dy - y) / scale);

  void setView(double nx, double ny, double ns) {
    x = nx;
    y = ny;
    scale = ns.clamp(0.05, 4.0).toDouble();
    notifyListeners();
  }

  void panBy(Offset d) {
    x += d.dx;
    y += d.dy;
    notifyListeners();
  }

  void zoomAt(Offset focal, double factor) {
    final ns = (scale * factor).clamp(0.05, 4.0).toDouble();
    final k = ns / scale;
    x = focal.dx - (focal.dx - x) * k;
    y = focal.dy - (focal.dy - y) * k;
    scale = ns;
    notifyListeners();
  }

  /// نقطه‌ی p (مختصات نقشه) رو وسط صفحه میاره؛ زوم خیلی کم رو به حداقل ۶۰٪ می‌رسونه
  void centerOn(Offset p, {double? minScale}) {
    if (view.isEmpty) return;
    final s = math.max(scale, minScale ?? 0.6).clamp(0.05, 4.0).toDouble();
    scale = s;
    x = view.width / 2 - p.dx * s;
    y = view.height / 2 - p.dy * s;
    notifyListeners();
  }

  void fitRect(Rect r) {
    if (view.isEmpty) return;
    const pad = 60.0;
    final rw = math.max(r.width, 1.0), rh = math.max(r.height, 1.0);
    final s = math.min((view.width - pad * 2) / rw, (view.height - pad * 2) / rh).clamp(0.05, 1.5).toDouble();
    scale = s;
    x = view.width / 2 - r.center.dx * s;
    y = view.height / 2 - r.center.dy * s;
    notifyListeners();
  }
}

/// painter محدوده‌ی همه‌ی چیزهای کشیده‌شده رو اینجا می‌ذاره تا دکمه‌ی «نمایش همه» ازش استفاده کنه
class MapBoundsBox {
  Rect? rect;
}
