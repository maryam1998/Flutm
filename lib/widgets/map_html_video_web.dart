import 'dart:async';
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

/// علت اصلی باگ: `<html dir="rtl">`. اسلات platform-view فلاتر `position:absolute`
/// بدون `left` است و در صفحه‌ی راست‌به‌چپ مبدأ آن لبه‌ی «راست» می‌شود؛ یعنی
/// ویدیو به اندازه‌ی (عرض صفحه − عرض کارت) به راست پرت می‌شد. جهت زنجیره‌ی
/// والدهای همین اسلات را ltr می‌کنیم (فقط برای همین ویدیو؛ متن‌ها دست‌نخورده).
void _forceLtrChain(web.Element? start) {
  var e = start;
  var n = 0;
  while (e != null && n < 16) {
    try {
      (e as web.HTMLElement).style.setProperty('direction', 'ltr');
    } catch (_) {}
    e = e.parentElement;
    n++;
  }
}

Widget buildMapHtmlVideo({
  Key? key,
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
      // جعبه‌ی خودنگهدار: ویدیو absolute داخل یک div با overflow:hidden و
      // direction:ltr (صفحه rtl است) تا هر جا که اسلات فلاتر برود، ویدیو
      // دقیقاً داخل همان کادر بماند و از آن بیرون نزند.
      final box = web.document.createElement('div') as web.HTMLDivElement;
      box.style
        ..position = 'relative'
        ..width = '100%'
        ..height = '100%'
        ..overflow = 'hidden'
        ..pointerEvents = 'none'
        ..backgroundColor = '#000'
        ..setProperty('direction', 'ltr');
      final v = web.document.createElement('video') as web.HTMLVideoElement;
      v.src = url;
      v.controls = false;
      v.autoplay = true;
      v.loop = loop;
      v.setAttribute('playsinline', 'true');
      v.style
        ..position = 'absolute'
        ..left = '0'
        ..top = '0'
        ..pointerEvents = 'none'
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'contain'
        ..backgroundColor = '#000';
      box.append(v);
      // بعد از اینکه فلاتر عنصر را داخل اسلات گذاشت، جهت والدها را ltr کن
      for (final ms in const [0, 60, 300]) {
        Timer(Duration(milliseconds: ms), () => _forceLtrChain(box));
      }
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
      return box;
    });
  }

  final v = _videos[viewType];
  if (v != null && v.loop != loop) v.loop = loop;

  return HtmlElementView(key: key, viewType: viewType);
}

/// نسبت واقعی ویدیو را قبل از ساختن کارت می‌خواند تا کارت از همان اول با اندازه‌ی
/// درست ساخته شود (تغییر اندازه‌ی کارت بعد از لود باعث بیرون‌افتادن ویدیو می‌شد).
Future<double?> probeMapVideoRatio(String url) {
  final c = Completer<double?>();
  final v = web.document.createElement('video') as web.HTMLVideoElement;
  void finish(double? r) {
    if (c.isCompleted) return;
    try {
      v.removeAttribute('src');
      v.load();
    } catch (_) {}
    c.complete(r);
  }

  v.preload = 'metadata';
  v.muted = true;
  v.addEventListener(
      'loadedmetadata',
      ((web.Event _) {
        finish(v.videoWidth > 0 && v.videoHeight > 0
            ? v.videoWidth / v.videoHeight
            : null);
      }).toJS);
  v.addEventListener('error', ((web.Event _) => finish(null)).toJS);
  Timer(const Duration(seconds: 6), () => finish(null));
  v.src = url;
  return c.future;
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
