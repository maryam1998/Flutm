import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// پس‌زمینه‌ی ویدیویی روی وب — دقیقاً مثل `#ambient-bg-video` در Maghz:
///   position:absolute; left:-8%; top:-8%; width:116%; height:116%;
///   object-fit:cover; filter:blur(var(--amb-blur));
/// و شفافیتِ کل لایه با transition ‌ی ۰٫۷ ثانیه.
///
/// چرا `<video>` واقعی؟ ویجت VideoPlayer فلاتر روی وب با FittedBox/Transform/
/// Opacity درست ترکیب نمی‌شود (ویدیو فقط در یک نوار باریک دیده می‌شد). عنصر HTML
/// خودش با CSS کل صفحه را می‌پوشاند و Opacity/Blur را مرورگر انجام می‌دهد.
class _Els {
  _Els(this.box, this.video);
  final web.HTMLDivElement box;
  final web.HTMLVideoElement video;
}

final Map<String, _Els> _els = <String, _Els>{};
final Map<String, (double, double)> _latest = <String, (double, double)>{};
final Set<String> _registered = <String>{};

void _apply(_Els e, double opacity, double blur) {
  e.box.style.opacity = opacity.clamp(0.0, 1.0).toString();
  e.video.style.setProperty('filter', blur > 0 ? 'blur(${blur}px)' : 'none');
}

Widget buildBackgroundVideo({
  required String url,
  required double opacity,
  required double blur,
}) {
  final viewType = 'bg-video-${url.hashCode}';
  _latest[viewType] = (opacity, blur);

  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final box = web.document.createElement('div') as web.HTMLDivElement;
      box.style
        ..position = 'relative'
        ..width = '100%'
        ..height = '100%'
        ..overflow = 'hidden'
        ..pointerEvents = 'none'
        ..opacity = '0'
        ..setProperty('transition', 'opacity .7s ease');

      final video = web.document.createElement('video') as web.HTMLVideoElement;
      video.src = url;
      video.autoplay = true;
      video.loop = true;
      video.muted = true;
      video.defaultMuted = true;
      video.setAttribute('playsinline', 'true');
      video.setAttribute('muted', '');
      video.style
        ..position = 'absolute'
        ..left = '-8%'
        ..top = '-8%'
        ..width = '116%'
        ..height = '116%'
        ..objectFit = 'cover'
        ..pointerEvents = 'none';
      box.append(video);

      final els = _Els(box, video);
      _els[viewType] = els;

      // ظاهر شدن نرم: اول شفافیت ۰، کمی بعد مقدار انتخابی
      Timer(const Duration(milliseconds: 60), () {
        final l = _latest[viewType];
        if (l != null) _apply(els, l.$1, l.$2);
      });
      try {
        video.play().toDart.catchError((Object _) => null);
      } catch (_) {}
      return box;
    });
  }

  // تغییر Blur/شفافیت از تنظیمات: مستقیم روی عنصر
  final els = _els[viewType];
  if (els != null) _apply(els, opacity, blur);

  return SizedBox.expand(child: HtmlElementView(viewType: viewType));
}
