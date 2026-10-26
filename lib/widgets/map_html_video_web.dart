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
typedef _Cb = ({
  ValueChanged<double> onRatio,
  VoidCallback onError,
  void Function(double frac, bool playing) onState
});
final Map<String, _Cb> _cb = <String, _Cb>{};
final Set<String> _registered = <String>{};

Widget buildMapHtmlVideo({
  required String id,
  required String url,
  required bool loop,
  required ValueChanged<double> onRatio,
  required VoidCallback onError,
  required void Function(double frac, bool playing) onState,
}) {
  final viewType = 'map-video-$id';
  _cb[viewType] = (onRatio: onRatio, onError: onError, onState: onState);

  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final v = web.document.createElement('video') as web.HTMLVideoElement;
      v.src = url;
      v.controls = false;
      v.autoplay = true;
      v.loop = loop;
      v.setAttribute('playsinline', 'true');
      v.style
        ..pointerEvents = 'none'
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
      void report() {
        final d = v.duration;
        final f = (d.isFinite && d > 0) ? (v.currentTime / d).clamp(0.0, 1.0) : 0.0;
        _cb[viewType]?.onState(f.toDouble(), !v.paused && !v.ended);
      }
      for (final ev in const ['timeupdate', 'play', 'pause', 'ended']) {
        v.addEventListener(ev, ((web.Event _) => report()).toJS);
      }
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

/// پخش/توقف (لمس روی ویدیو)
void toggleMapHtmlVideo(String id) {
  final v = _videos['map-video-$id'];
  if (v == null) return;
  try {
    if (v.paused || v.ended) {
      v.play().toDart.catchError((Object _) => null);
    } else {
      v.pause();
    }
  } catch (_) {}
}

/// جلو/عقب بردن (0..1)
void seekMapHtmlVideo(String id, double frac) {
  final v = _videos['map-video-$id'];
  if (v == null) return;
  final d = v.duration;
  if (d.isFinite && d > 0) v.currentTime = d * frac.clamp(0.0, 1.0);
}
