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

// ─────────────────────────────────────────────────────────────
// انیمیشن‌های جدا: هر عکس/GIF یا ایموجی = یک قدم‌زنِ مستقل با پاهای خودش
// ─────────────────────────────────────────────────────────────

/// یک انیمیشنِ مستقل روی نقشه: یا عکس/GIF (`photo`) یا ایموجی (`emoji`).
class WalkerItem {
  const WalkerItem.photo(String src)
      : photo = src,
        emoji = '';
  const WalkerItem.emoji(String e)
      : emoji = e,
        photo = '';

  final String photo;
  final String emoji;

  bool get isEmoji => emoji.isNotEmpty;
  String get value => isEmoji ? emoji : photo;

  Map<String, dynamic> toJson() =>
      isEmoji ? {'t': 'e', 'v': emoji} : {'t': 'p', 'v': photo};
}

/// فهرست انیمیشن‌ها. اگر هنوز فهرست جدید ذخیره نشده، از داده‌ی قدیمی
/// (ایموجی + عکس‌ها) ساخته می‌شود تا چیزی از دست نرود.
List<WalkerItem> walkerItemsOf(Map<String, dynamic> extra) {
  final raw = extra['walkerItems'];
  if (raw is List) {
    final out = <WalkerItem>[];
    for (final e in raw) {
      if (e is Map) {
        final v = e['v'];
        if (v is! String || v.isEmpty) continue;
        out.add(e['t'] == 'e' ? WalkerItem.emoji(v) : WalkerItem.photo(v));
      }
    }
    return out;
  }
  final out = <WalkerItem>[];
  final em = walkerEmojiOf(extra);
  if (em.isNotEmpty) out.add(WalkerItem.emoji(em));
  for (final p in walkerPhotosOf(extra)) {
    out.add(WalkerItem.photo(p));
  }
  return out;
}

void setWalkerItems(Map<String, dynamic> extra, List<WalkerItem> items) {
  // کلیدهای قدیمی حذف می‌شوند تا دوباره به‌هم وصل نشوند
  extra.remove('walkerPhotos');
  extra.remove('walkerPhoto');
  extra.remove('walkerEmoji');
  if (items.isEmpty) {
    // فهرستِ خالی = دایره‌ی پیش‌فرض (نه برگشت به داده‌ی قدیمی)
    extra['walkerItems'] = <Map<String, dynamic>>[];
  } else {
    extra['walkerItems'] = [for (final i in items) i.toJson()];
  }
}
