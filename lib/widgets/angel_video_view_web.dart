import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final Set<String> _registered = <String>{};

/// یک `<video>` واقعی HTML با CSS mask برای لبه‌های محو.
/// این تنها راهی است که روی وب می‌شود ویدیو را با لبه‌های نرم نشان داد.
Widget buildAngelVideo({
  required String id,
  required String url,
  required bool soft,
  required double size,
  required double opacity,
}) {
  final viewType = 'angel-video-$id';

  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final video =
            web.document.createElement('video') as web.HTMLVideoElement;
        video.src = url;
        video.autoplay = true;
        video.loop = true;
        video.muted = true;
        video.setAttribute('playsinline', 'true');
        video.style.objectFit = 'contain';
        video.style.width = '100%';
        video.style.height = '100%';
        video.style.pointerEvents = 'none';
        video.style.opacity = opacity.toString();
        if (soft) {
          const mask =
              'radial-gradient(ellipse at center, #000 52%, transparent 72%)';
          video.style.setProperty('-webkit-mask-image', mask);
          video.style.setProperty('mask-image', mask);
        }
        return video;
      },
    );
  }

  return SizedBox(
    width: size,
    height: size,
    child: HtmlElementView(viewType: viewType),
  );
}
