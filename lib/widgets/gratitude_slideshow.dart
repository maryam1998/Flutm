import 'package:flutter/material.dart';

import '../state/gratitude_store.dart';
import 'media_slideshow.dart';

/// اسلایدشوی تصاویر شکرگذاری‌ها — منطق در [MediaSlideshow] (مشترک با تب باورها).
class GratitudeSlideshow extends StatelessWidget {
  final GratitudeStore store;

  /// کلید اسلاید فعلی را می‌دهد تا آلبوم از همان عکس شروع شود
  final ValueChanged<String?>? onOpenAlbum;

  const GratitudeSlideshow({
    super.key,
    required this.store,
    this.onOpenAlbum,
  });

  List<MediaSlide> _collect() {
    final out = <MediaSlide>[];
    for (final e in store.entries) {
      if (e.source == 'purchase') continue;
      for (final im in e.images) {
        out.add(MediaSlide(
          key: 'g${e.id}_${im.id}',
          isVideo: im.src.startsWith('data:video/'),
          src: im.src,
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return MediaSlideshow(
      listenable: store,
      collect: _collect,
      cfgKey: 'gratSlideshow',
      title: '🖼️ تصاویر شکرگذاری‌ها',
      onOpenAlbum: onOpenAlbum,
    );
  }
}
