/// عکس‌های قدم‌زن (دایره‌ی جلوی پاها).
/// چند عکس در `extra['walkerPhotos']` نگه داشته می‌شه؛ کلید قدیمی `walkerPhoto`
/// (عکس اول) هم برای سازگاری با داده‌های قبلی هم‌زمان نگه داشته می‌شه.
List<String> walkerPhotosOf(Map<String, dynamic> extra) {
  final out = <String>[];
  final raw = extra['walkerPhotos'];
  if (raw is List) {
    for (final e in raw) {
      if (e is String && e.isNotEmpty) out.add(e);
    }
  }
  if (out.isEmpty) {
    final one = extra['walkerPhoto'];
    if (one is String && one.isNotEmpty) out.add(one);
  }
  return out;
}

void setWalkerPhotos(Map<String, dynamic> extra, List<String> photos) {
  if (photos.isEmpty) {
    extra.remove('walkerPhotos');
    extra.remove('walkerPhoto');
  } else {
    extra['walkerPhotos'] = List<String>.of(photos);
    extra['walkerPhoto'] = photos.first;
  }
}

/// ایموجیِ قدم‌زن (به‌جای دایره‌ی جلوی پاها). اگر پر باشد، به‌جای عکس/GIF نشان داده می‌شود.
String walkerEmojiOf(Map<String, dynamic> extra) {
  final e = extra['walkerEmoji'];
  return e is String ? e.trim() : '';
}

void setWalkerEmoji(Map<String, dynamic> extra, String emoji) {
  final e = emoji.trim();
  if (e.isEmpty) {
    extra.remove('walkerEmoji');
  } else {
    extra['walkerEmoji'] = e;
  }
}
