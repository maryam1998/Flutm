import 'package:flutter/foundation.dart';

import '../models/friends_models.dart';

enum FriendSort { newest, unanswered, hot }

/// استورِ «دوستان هم‌فرکانسی».
/// فعلاً فقط در حافظه (داده‌ی نمایشی)؛ بعد از طراحی بک‌اند با Supabase جایگزین می‌شه.
class FriendsStore extends ChangeNotifier {
  FriendsStore._() {
    _seed();
  }
  static final FriendsStore instance = FriendsStore._();

  /// تا وقتی به سرور وصل نشده، برچسب «نمایشی» نشون داده می‌شه
  static const bool demo = true;

  String myName = 'همسفر';
  final List<FriendPost> _posts = [];
  int _seq = 100;

  String _id() => 'p${_seq++}';

  List<FriendPost> view({FriendKind? kind, FriendSort sort = FriendSort.newest}) {
    var l = _posts.where((p) => !p.hiddenByMe).toList();
    if (kind != null) l = l.where((p) => p.kind == kind).toList();
    switch (sort) {
      case FriendSort.newest:
        l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case FriendSort.unanswered:
        l = l.where((p) => p.kind == FriendKind.question && p.answers.isEmpty)
            .toList();
        l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case FriendSort.hot:
        int score(FriendPost p) => p.visibleAnswers.length * 2 + p.goodCount;
        l.sort((a, b) => score(b).compareTo(score(a)));
    }
    return l;
  }

  FriendPost? byId(String id) {
    for (final p in _posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  void toggleGood(FriendPost p) {
    p.goodByMe = !p.goodByMe;
    p.goodCount += p.goodByMe ? 1 : -1;
    notifyListeners();
  }

  void toggleAnswerGood(FriendAnswer a) {
    a.goodByMe = !a.goodByMe;
    a.goodCount += a.goodByMe ? 1 : -1;
    notifyListeners();
  }

  FriendPost addPost({
    required FriendKind kind,
    required String title,
    String body = '',
    String category = '',
    String? emotionId,
    required String author,
  }) {
    myName = author;
    final p = FriendPost(
      id: _id(),
      kind: kind,
      title: title,
      body: body,
      category: category,
      author: author,
      createdAt: DateTime.now(),
      emotionId: emotionId,
      mine: true,
    );
    _posts.insert(0, p);
    notifyListeners();
    return p;
  }

  void addAnswer(FriendPost p, String body) {
    p.answers.add(FriendAnswer(
      id: _id(),
      author: myName,
      body: body,
      createdAt: DateTime.now(),
      mine: true,
    ));
    notifyListeners();
  }

  /// پرسنده فقط یک پاسخ را «کمکم کرد» می‌کند؛ دوباره زدن برش می‌دارد
  void markHelpful(FriendPost p, FriendAnswer a) {
    final was = a.helpful;
    for (final x in p.answers) {
      x.helpful = false;
    }
    a.helpful = !was;
    notifyListeners();
  }

  void hidePost(FriendPost p) {
    p.hiddenByMe = true;
    notifyListeners();
  }

  void hideAnswer(FriendAnswer a) {
    a.hidden = true;
    notifyListeners();
  }

  // ───────── داده‌ی نمایشی ─────────
  void _seed() {
    DateTime ago(int minutes) =>
        DateTime.now().subtract(Duration(minutes: minutes));
    _posts.addAll([
      FriendPost(
        id: 'p1',
        kind: FriendKind.question,
        title: 'چرا با وجود تمرین شکرگذاری هنوز حس کمبود دارم؟',
        body:
            'یک ماهه هر شب شکرگذاری می‌نویسم ولی وقتی خرج‌هام رو می‌بینم دوباره حس کمبود میاد سراغم. کسی این تجربه رو داشته؟',
        category: 'حس و فرکانس',
        author: 'مهتاب',
        createdAt: ago(18),
        emotionId: 'lack',
        goodCount: 6,
        answers: [
          FriendAnswer(
            id: 'a1',
            author: 'آرمان',
            body:
                'برای من وقتی جواب داد که شکرگذاری رو از «چیزهایی که دارم» به «حسی که الان دارم» تغییر دادم؛ فقط لیست‌نویسی کافی نبود.',
            createdAt: ago(9),
            goodCount: 4,
          ),
          FriendAnswer(
            id: 'a2',
            author: 'نسیم',
            body:
                'سعی کن بعد از نوشتن، یک دقیقه چشم‌ها رو ببندی و همون حس رو توی بدنت پیدا کنی.',
            createdAt: ago(5),
            goodCount: 2,
          ),
        ],
      ),
      FriendPost(
        id: 'p2',
        kind: FriendKind.experience,
        title: 'سی روز با یک جمله‌ی تاکیدی',
        body:
            'هر صبح فقط یک جمله می‌گفتم و حسش رو ثبت می‌کردم. روز ۲۰ام اولین بار حس کردم جمله دیگه برام «تکرار» نیست، باور شده. رشته‌ی عصبی‌ام هم سبز شده بود 😊',
        category: 'عادت و تمرین',
        author: 'سارا',
        createdAt: ago(95),
        emotionId: 'joy',
        goodCount: 14,
        answers: [
          FriendAnswer(
            id: 'a3',
            author: 'همسفر',
            body: 'چقدر قشنگ! کدوم جمله بود؟',
            createdAt: ago(60),
            mine: true,
          ),
        ],
      ),
      FriendPost(
        id: 'p3',
        kind: FriendKind.gratitude,
        title: 'خدایا شکرت که امروز صبح بوی نون تازه رو حس کردم',
        category: 'شکرگذاری',
        author: 'رضا',
        createdAt: ago(140),
        emotionId: 'love',
        goodCount: 9,
      ),
      FriendPost(
        id: 'p4',
        kind: FriendKind.question,
        title: 'چطور باور قدیمی «پول درآوردن سخته» رو بازنویسی کنم؟',
        body: '',
        category: 'باورها',
        author: 'همسفر',
        createdAt: ago(300),
        goodCount: 3,
        mine: true,
        answers: [
          FriendAnswer(
            id: 'a4',
            author: 'پگاه',
            body:
                'اول ببین این باور از کجا اومده. وقتی منبعش رو دیدم، جمله‌ی جایگزین طبیعی‌تر شد.',
            createdAt: ago(250),
            goodCount: 5,
          ),
        ],
      ),
      FriendPost(
        id: 'p5',
        kind: FriendKind.question,
        title: 'فرق «خواستن» و «انتظار داشتن» تو قانون جذب چیه؟',
        body: '',
        category: 'قانون جذب',
        author: 'کیان',
        createdAt: ago(1500),
        goodCount: 1,
      ),
    ]);
  }
}
