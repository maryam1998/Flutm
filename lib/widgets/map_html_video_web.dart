import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// ویدیوی کارت شناور نقشه روی وب با `<video>` واقعی HTML.
/// ویجت VideoPlayer فلاتر روی وب در این کارت سیاه/نامرئی می‌ماند (مثل پس‌زمینه‌ی
/// ویدیویی)، پس خود مرورگر ویدیو را نشان می‌دهد و کنترل‌های پخش/جلو-عقب هم از
/// خود مرورگر است.
final Map<String, web.HTMLVideoElement> _videos =
    <String, web.HTMLVideoElement>{};
final Map<String, ({ValueChanged<double> onRatio, VoidCallback onError})> _cb =
    <String, ({ValueChanged<double> onRatio, VoidCallback onError})>{};
final Set<String> _registered = <String>{};

Widget buildMapHtmlVideo({
  required String id,
  required String url,
  required bool loop,
  required ValueChanged<double> onRatio,
  required VoidCallback onError,
}) {
  final viewType = 'map-video-$id';
  _cb[viewType] = (onRatio: onRatio, onError: onError);

  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final v = web.document.createElement('video') as web.HTMLVideoElement;
      v.src = url;
      v.controls = true;
      v.autoplay = true;
      v.loop = loop;
      v.setAttribute('playsinline', 'true');
      v.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'contain'
        ..backgroundColor = '#000'
        ..borderRadius = '0 0 14px 14px';
      v.addEventListener(
          'loadedmetadata',
          ((web.Event _) {
            if (v.videoWidth > 0 && v.videoHeight > 0) {
              _cb[viewType]?.onRatio(v.videoWidth / v.videoHeight);
            }
          }).toJS);
      v.addEventListener(
          'error',
          ((web.Event _) {
            _cb[viewType]?.onError();
          }).toJS);
      _videos[viewType] = v;
      try {
        v.play().toDart.catchError((Object _) => null);
      } catch (_) {}
      return v;
    });
  }

  final v = _videos[viewType];
  if (v != null && v.loop != loop) v.loop = loop;

  return HtmlElementView(viewType: viewType);
}

/// بستن کارت: پخش را کامل قطع کن (وگرنه صدا می‌ماند)
void disposeMapHtmlVideo(String id) {
  final k = 'map-video-$id';
  _cb.remove(k);
  final v = _videos.remove(k);
  if (v == null) return;
  try {
    v.pause();
    v.removeAttribute('src');
    v.load();
  } catch (_) {}
}
