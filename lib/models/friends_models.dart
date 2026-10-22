import '../map/draw_utils.dart' show toFa;

/// نوع پست در «دوستان هم‌فرکانسی»
enum FriendKind { question, experience, gratitude }

extension FriendKindX on FriendKind {
  String get label {
    switch (this) {
      case FriendKind.question:
        return 'پرسش';
      case FriendKind.experience:
        return 'تجربه';
      case FriendKind.gratitude:
        return 'شکرگذاری';
    }
  }
}

const List<String> kFriendCategories = [
  'قانون جذب',
  'باورها',
  'حس و فرکانس',
  'پول و فراوانی',
  'روابط',
  'عادت و تمرین',
];

class FriendAnswer {
  FriendAnswer({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    this.goodCount = 0,
    this.goodByMe = false,
    this.helpful = false,
    this.mine = false,
    this.hidden = false,
  });
  final String id;
  final String author;
  final String body;
  final DateTime createdAt;
  int goodCount;
  bool goodByMe;

  /// پرسنده زده «کمکم کرد»
  bool helpful;
  final bool mine;

  /// گزارش‌شده توسط خودِ کاربر → برایش پنهان می‌شود
  bool hidden;
}

class FriendPost {
  FriendPost({
    required this.id,
    required this.kind,
    required this.title,
    this.body = '',
    this.category = '',
    required this.author,
    required this.createdAt,
    this.emotionId,
    this.goodCount = 0,
    this.goodByMe = false,
    this.mine = false,
    List<FriendAnswer>? answers,
  }) : answers = answers ?? [];

  final String id;
  final FriendKind kind;
  final String title;
  final String body;
  final String category;
  final String author;
  final DateTime createdAt;
  final String? emotionId;
  int goodCount;
  bool goodByMe;
  final bool mine;
  bool hiddenByMe = false;
  final List<FriendAnswer> answers;

  List<FriendAnswer> get visibleAnswers =>
      answers.where((a) => !a.hidden).toList();

  bool get solved => answers.any((a) => a.helpful);
}

String faTimeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'همین الان';
  if (d.inMinutes < 60) return '${toFa(d.inMinutes)} دقیقه پیش';
  if (d.inHours < 24) return '${toFa(d.inHours)} ساعت پیش';
  if (d.inDays < 30) return '${toFa(d.inDays)} روز پیش';
  if (d.inDays < 365) return '${toFa(d.inDays ~/ 30)} ماه پیش';
  return '${toFa(d.inDays ~/ 365)} سال پیش';
}
