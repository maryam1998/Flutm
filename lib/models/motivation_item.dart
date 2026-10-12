import 'dart:math';

String _uid() =>
    DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
    Random().nextInt(1 << 30).toRadixString(36).padLeft(5, '0').substring(0, 5);

class MotivationItem {
  String id;
  String text;
  bool archived;
  int createdAt;
  int? archivedAt;

  MotivationItem({
    String? id,
    required this.text,
    this.archived = false,
    int? createdAt,
    this.archivedAt,
  })  : id = id ?? _uid(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  factory MotivationItem.fromJson(dynamic raw) {
    if (raw is! Map) return MotivationItem(text: '');
    return MotivationItem(
      id: raw['id'] is String ? raw['id'] as String : null,
      text: raw['text'] is String ? raw['text'] as String : '',
      archived: raw['archived'] == true,
      createdAt: raw['createdAt'] is num
          ? (raw['createdAt'] as num).toInt()
          : null,
      archivedAt: raw['archivedAt'] is num
          ? (raw['archivedAt'] as num).toInt()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'archived': archived,
        'createdAt': createdAt,
        if (archivedAt != null) 'archivedAt': archivedAt,
      };
}
