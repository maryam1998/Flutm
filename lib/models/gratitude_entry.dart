import 'dart:math';

String _uid() =>
    DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
    Random().nextInt(1 << 30).toRadixString(36).padLeft(5, '0').substring(0, 5);

// ───────────── عکس ─────────────
class GratitudeImage {
  String id;
  String src; // data:image/... یا file path
  GratitudeImage({String? id, required this.src}) : id = id ?? _uid();

  factory GratitudeImage.fromJson(dynamic raw) {
    if (raw is String) return GratitudeImage(src: raw);
    if (raw is Map) {
      return GratitudeImage(
        id: raw['id'] is String ? raw['id'] as String : null,
        src: raw['src'] is String ? raw['src'] as String : '',
      );
    }
    return GratitudeImage(src: '');
  }
  Map<String, dynamic> toJson() => {'id': id, 'src': src};
}

// ───────────── صدا ─────────────
class GratitudeAudio {
  String src;
  String name;
  GratitudeAudio({required this.src, this.name = ''});

  factory GratitudeAudio.fromJson(dynamic raw) {
    if (raw is String) return GratitudeAudio(src: raw);
    if (raw is Map) {
      return GratitudeAudio(
        src: raw['src'] is String ? raw['src'] as String : '',
        name: raw['name'] is String ? raw['name'] as String : '',
      );
    }
    return GratitudeAudio(src: '');
  }
  Map<String, dynamic> toJson() => {'src': src, 'name': name};
}

// ───────────── ویدیو (جدید) ─────────────
class GratitudeVideo {
  String id;
  String path; // file path یا data URL
  String name;
  int size;
  GratitudeVideo({
    String? id,
    required this.path,
    this.name = '',
    this.size = 0,
  }) : id = id ?? _uid();

  factory GratitudeVideo.fromJson(dynamic raw) {
    if (raw is String) return GratitudeVideo(path: raw);
    if (raw is Map) {
      return GratitudeVideo(
        id: raw['id'] is String ? raw['id'] as String : null,
        path: raw['path'] is String ? raw['path'] as String : '',
        name: raw['name'] is String ? raw['name'] as String : '',
        size: raw['size'] is int ? raw['size'] as int : 0,
      );
    }
    return GratitudeVideo(path: '');
  }
  Map<String, dynamic> toJson() =>
      {'id': id, 'path': path, 'name': name, 'size': size};
}

// ───────────── یک ثبت شکرگذاری ─────────────
class GratitudeEntry {
  String id;
  String text;
  String icon;
  String? image; // legacy: اولین عکس
  double? amount;
  List<GratitudeImage> images;
  List<GratitudeAudio> audios;
  List<GratitudeVideo> videos;
  String date, day, time, iso;
  String source; // 'manual' | 'purchase'
  bool shared;
  int? editedAt;
  double? txId;
  List<String> emotionIds;
  Map<String, dynamic> extra;

  GratitudeEntry({
    String? id,
    this.text = '',
    this.icon = '🙏',
    this.image,
    this.amount,
    List<GratitudeImage>? images,
    List<GratitudeAudio>? audios,
    List<GratitudeVideo>? videos,
    this.date = '',
    this.day = '',
    this.time = '',
    this.iso = '',
    this.source = 'manual',
    this.shared = false,
    this.editedAt,
    this.txId,
    List<String>? emotionIds,
    Map<String, dynamic>? extra,
  })  : id = id ?? _uid(),
        images = images ?? [],
        audios = audios ?? [],
        videos = videos ?? [],
        emotionIds = emotionIds ?? [],
        extra = extra ?? {};

  static const _known = {
    'id', 'text', 'icon', 'image', 'amount', 'images', 'audios', 'videos',
    'date', 'day', 'time', 'iso', 'source', 'shared', 'editedAt', 'txId',
    'emotionIds',
  };

  factory GratitudeEntry.fromJson(dynamic raw) {
    if (raw is! Map) return GratitudeEntry();
    final j = Map<String, dynamic>.from(raw);
    final extra = <String, dynamic>{};
    for (final e in j.entries) {
      if (!_known.contains(e.key)) extra[e.key] = e.value;
    }
    return GratitudeEntry(
      id: j['id'] is String
          ? j['id'] as String
          : (j['id'] is num ? (j['id'] as num).toString() : null),
      text: j['text'] is String ? j['text'] as String : '',
      icon: j['icon'] is String ? j['icon'] as String : '🙏',
      image: j['image'] is String ? j['image'] as String : null,
      amount: j['amount'] is num ? (j['amount'] as num).toDouble() : null,
      images: j['images'] is List
          ? (j['images'] as List).map(GratitudeImage.fromJson).toList()
          : [],
      audios: j['audios'] is List
          ? (j['audios'] as List).map(GratitudeAudio.fromJson).toList()
          : [],
      videos: j['videos'] is List
          ? (j['videos'] as List).map(GratitudeVideo.fromJson).toList()
          : [],
      date: j['date'] is String ? j['date'] as String : '',
      day: j['day'] is String ? j['day'] as String : '',
      time: j['time'] is String ? j['time'] as String : '',
      iso: j['iso'] is String ? j['iso'] as String : '',
      source: j['source'] is String ? j['source'] as String : 'manual',
      shared: j['shared'] == true,
      editedAt: j['editedAt'] is num ? (j['editedAt'] as num).toInt() : null,
      txId: j['txId'] is num ? (j['txId'] as num).toDouble() : null,
      emotionIds: j['emotionIds'] is List
          ? (j['emotionIds'] as List).map((e) => e.toString()).toList()
          : [],
      extra: extra,
    );
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'text': text,
        'icon': icon,
        'image': image,
        'amount': amount,
        'images': images.map((i) => i.toJson()).toList(),
        'audios': audios.map((a) => a.toJson()).toList(),
        'videos': videos.map((v) => v.toJson()).toList(),
        'date': date,
        'day': day,
        'time': time,
        'iso': iso,
        'source': source,
        'shared': shared,
        'editedAt': editedAt,
        'txId': txId,
        'emotionIds': emotionIds,
      };

  /// متن با پیشوند «خدایا شکرت که:» مثل gratDisplayText وب
  String displayText() {
    if (source == 'purchase') {
      final nm = text.trim();
      if (nm.isEmpty) return '🛍 خرید';
      return nm;
    }
    if (text.isEmpty) return '🙏 شکرگذاری';
    if (text.startsWith('خدایا شکرت که')) return text;
    return 'خدایا شکرت که: $text';
  }
}
