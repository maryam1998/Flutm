import 'dart:math';

String _uid() =>
    DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
    Random().nextInt(1 << 30).toRadixString(36).padLeft(5, '0').substring(0, 5);

class GratitudeImage {
  String id;
  String src;
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

class GratitudeEntry {
  String id;
  String text;
  String icon;
  String? image; // legacy: first image src
  double? amount;
  List<GratitudeImage> images;
  List<GratitudeAudio> audios;
  String date, day, time, iso;
  String source; // 'manual' | 'purchase'
  bool shared;
  int? editedAt;
  double? txId;

  /// شناسه‌های احساسی که کاربر روی این شکرگذاری انتخاب کرده
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
        emotionIds = emotionIds ?? [],
        extra = extra ?? {};

  static const _known = {
    'id', 'text', 'icon', 'image', 'amount', 'images', 'audios',
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
