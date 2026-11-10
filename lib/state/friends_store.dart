import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friends_models.dart';
import '../services/app_prefs.dart';
import '../services/auth_service.dart';
import '../services/supabase_config.dart';

enum FriendSort { newest, unanswered, hot }

/// استورِ «دوستان هم‌فرکانسی» — روی Supabase (جدول‌ها: `supabase/friends.sql`).
///
/// خواندن برای همه آزاد است؛ نوشتن/پاسخ/«حس خوبی داد»/گزارش فقط با ورودِ Google.
/// تغییرها اول روی صفحه اعمال می‌شوند و بعد به سرور می‌روند؛ اگر سرور قبول نکرد
/// برمی‌گردند و پیام خطا نشان داده می‌شود.
class FriendsStore extends ChangeNotifier {
  FriendsStore._();
  static final FriendsStore instance = FriendsStore._();

  static const _kNick = 'friends_nick_v1';
  static const _select =
      '*, friend_answers(*, friend_answer_good(user_id)), friend_post_good(user_id)';

  final List<FriendPost> _posts = [];
  bool loading = false;
  bool loaded = false;

  /// آخرین خطا (برای نوار هشدار بالای صفحه)؛ با یک بارگذاریِ موفق پاک می‌شود
  String? error;

  String _nick = '';

  SupabaseClient? get _c {
    if (!supabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get myId => _c?.auth.currentUser?.id;

  /// فقط کاربرِ واردشده با Google می‌تواند بنویسد (مهمان/ناشناس فقط می‌خواند)
  bool get canWrite {
    final u = _c?.auth.currentUser;
    return u != null && !u.isAnonymous;
  }

  /// نامِ پیش‌فرض: نامِ مستعارِ قبلی، وگرنه اسمِ کوچکِ حسابِ Google، وگرنه «همسفر»
  String get myName {
    if (_nick.isNotEmpty) return _nick;
    final dn = AuthService.instance.displayName.trim();
    if (dn.isNotEmpty && !dn.contains('@')) {
      final first = dn.split(RegExp(r'\s+')).first;
      return first.length > 20 ? first.substring(0, 20) : first;
    }
    return 'همسفر';
  }

  /// نامِ نمایشیِ ذخیره‌شده را (بدون نیاز به باز شدنِ تب دوستان) از حافظه می‌خواند
  Future<void> loadNick() async {
    try {
      final p = await AppPrefs.getInstance();
      _nick = p.getString(_kNick) ?? _nick;
      notifyListeners();
    } catch (_) {}
  }

  /// تغییرِ نامِ نمایشی در «دوستان» (از تنظیمات). خالی = برگشت به نامِ پیش‌فرض.
  /// فقط روی پست‌ها و پاسخ‌های بعدی اثر می‌گذارد.
  Future<void> setNick(String name) async {
    var n = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.length > 20) n = n.substring(0, 20);
    _nick = n;
    try {
      final p = await AppPrefs.getInstance();
      if (n.isEmpty) {
        await p.remove(_kNick);
      } else {
        await p.setString(_kNick, n);
      }
    } catch (_) {}
    notifyListeners();
  }

  // ───────── بارگذاری ─────────
  bool _again = false;

  Future<void> load({bool force = false}) async {
    if (loading) {
      if (force) _again = true;
      return;
    }
    if (loaded && !force) return;
    final c = _c;
    if (c == null) {
      error = 'اتصال به سرور تنظیم نشده.';
      loaded = true;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final p = await AppPrefs.getInstance();
      _nick = p.getString(_kNick) ?? _nick;

      List<dynamic> rows;
      try {
        rows = await c
            .from('friend_posts')
            .select(_select)
            .order('created_at', ascending: false)
            .limit(100);
      } catch (_) {
        // اگر خواندنِ یکجای پست+پاسخ+«حس خوبی» جواب نداد، جدا‌جدا بخوان
        // تا حداقل خودِ پست‌ها دیده شوند.
        rows = await _loadSplit(c);
      }

      // چیزهایی که خودم گزارش کرده‌ام برای من پنهان بماند
      final hiddenPosts = <String>{};
      final hiddenAnswers = <String>{};
      if (canWrite) {
        try {
          final reps = await c.from('friend_reports').select('post_id, answer_id');
          for (final r in reps) {
            final pid = r['post_id'];
            final aid = r['answer_id'];
            if (pid != null) hiddenPosts.add(pid.toString());
            if (aid != null) hiddenAnswers.add(aid.toString());
          }
        } catch (_) {}
      }

      _posts
        ..clear()
        ..addAll(rows
            .map((r) => _postFrom(Map<String, dynamic>.from(r as Map),
                hiddenPosts, hiddenAnswers))
            .whereType<FriendPost>());
      error = null;
      loaded = true;
    } catch (e) {
      error = _msg(e);
      loaded = true;
    } finally {
      loading = false;
      notifyListeners();
      if (_again) {
        _again = false;
        unawaited(load(force: true));
      }
    }
  }

  Future<void> refresh() => load(force: true);

  Future<List<dynamic>> _loadSplit(SupabaseClient c) async {
    final posts = await c
        .from('friend_posts')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    final out = <Map<String, dynamic>>[
      for (final r in posts) Map<String, dynamic>.from(r as Map)
    ];
    try {
      final ans = await c.from('friend_answers').select();
      final ansGood = <String, List<dynamic>>{};
      try {
        final ag = await c.from('friend_answer_good').select();
        for (final g in ag) {
          final m = Map<String, dynamic>.from(g as Map);
          ansGood.putIfAbsent(m['answer_id'].toString(), () => []).add(m);
        }
      } catch (_) {}
      for (final a in ans) {
        final m = Map<String, dynamic>.from(a as Map);
        m['friend_answer_good'] = ansGood[m['id'].toString()] ?? [];
        for (final r in out) {
          if (r['id'].toString() == m['post_id'].toString()) {
            (r['friend_answers'] ??= <dynamic>[]).add(m);
          }
        }
      }
    } catch (_) {}
    try {
      final pg = await c.from('friend_post_good').select();
      for (final g in pg) {
        final m = Map<String, dynamic>.from(g as Map);
        for (final r in out) {
          if (r['id'].toString() == m['post_id'].toString()) {
            (r['friend_post_good'] ??= <dynamic>[]).add(m);
          }
        }
      }
    } catch (_) {}
    return out;
  }

  // ───────── اشتراکِ شکرگذاری از تب شکرگذاری ─────────
  static const _kSharedGrat = 'friends_shared_grat_v1';

  /// شکرگذاریِ «اشتراک‌گذاری با بقیه» را به‌صورت پستِ «شکرگذاری» در تب دوستان
  /// می‌گذارد. null = موفق (یا قبلاً گذاشته شده)؛ وگرنه پیامِ خطا.
  Future<String?> shareGratitude({
    required String entryKey,
    required String text,
    String? emotionId,
  }) async {
    final c = _c;
    if (c == null) return 'اتصال به سرور تنظیم نشده.';
    if (!canWrite) {
      return 'برای دیده‌شدن در تب دوستان باید با حساب Google وارد شوی.';
    }
    var t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length < 6) {
      return 'برای اشتراک در دوستان، شکرگذاری باید متنِ کامل‌تری داشته باشد.';
    }
    try {
      final p = await AppPrefs.getInstance();
      final done = (p.getString(_kSharedGrat) ?? '')
          .split(',')
          .where((e) => e.isNotEmpty)
          .toSet();
      if (done.contains(entryKey)) return null;

      var title = t;
      var body = '';
      if (t.length > 140) {
        title = '${t.substring(0, 137)}…';
        body = t.substring(137);
        if (body.length > 1200) body = body.substring(0, 1200);
      }
      await c.from('friend_posts').insert({
        'kind': FriendKind.gratitude.name,
        'title': title,
        'body': body,
        'category': '',
        'author_name': myName,
        if (emotionId != null && emotionId.isNotEmpty) 'emotion_id': emotionId,
      });
      done.add(entryKey);
      await p.setString(_kSharedGrat, done.join(','));
      // لیست را تازه کن تا همین الان در تب دوستان دیده شود
      loaded = false;
      unawaited(load(force: true));
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  static String _msg(Object e) {
    if (e is PostgrestException) {
      final m = '${e.message} ${e.code ?? ''}'.toLowerCase();
      if (m.contains('pgrst205') ||
          m.contains('does not exist') ||
          m.contains('schema cache') ||
          m.contains('42p01')) {
        return 'جدول‌های دوستان هنوز در Supabase ساخته نشده‌اند. فایل supabase/friends.sql را در SQL Editor اجرا کن.';
      }
      if (m.contains('row-level security') || m.contains('42501')) {
        return 'اجازه‌ی این کار را نداری. با حساب Google وارد شو.';
      }
      return 'خطای سرور: ${e.message}';
    }
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('ClientException') ||
        s.contains('XMLHttpRequest')) {
      return 'اینترنت وصل نیست یا سرور در دسترس نیست.';
    }
    return 'مشکلی پیش آمد. دوباره تلاش کن.';
  }

  DateTime _time(dynamic v) {
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  FriendPost? _postFrom(Map<String, dynamic> r, Set<String> hiddenPosts,
      Set<String> hiddenAnswers) {
    final id = r['id']?.toString();
    if (id == null || hiddenPosts.contains(id)) return null;
    final me = myId;
    final goods = (r['friend_post_good'] as List? ?? const []);
    final kindName = r['kind']?.toString() ?? 'question';
    final kind = FriendKind.values.firstWhere((k) => k.name == kindName,
        orElse: () => FriendKind.question);
    final answers = <FriendAnswer>[];
    for (final a in (r['friend_answers'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(a as Map);
      final aid = m['id']?.toString();
      if (aid == null || hiddenAnswers.contains(aid)) continue;
      answers.add(_answerFrom(m, me));
    }
    answers.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return FriendPost(
      id: id,
      kind: kind,
      title: r['title']?.toString() ?? '',
      body: r['body']?.toString() ?? '',
      category: r['category']?.toString() ?? '',
      author: r['author_name']?.toString() ?? 'همسفر',
      createdAt: _time(r['created_at']),
      emotionId: (r['emotion_id'] as String?)?.isEmpty == true
          ? null
          : r['emotion_id'] as String?,
      goodCount: goods.length,
      goodByMe:
          me != null && goods.any((g) => (g as Map)['user_id']?.toString() == me),
      mine: me != null && r['user_id']?.toString() == me,
      answers: answers,
    );
  }

  FriendAnswer _answerFrom(Map<String, dynamic> m, String? me) {
    final goods = (m['friend_answer_good'] as List? ?? const []);
    return FriendAnswer(
      id: m['id'].toString(),
      author: m['author_name']?.toString() ?? 'همسفر',
      body: m['body']?.toString() ?? '',
      createdAt: _time(m['created_at']),
      goodCount: goods.length,
      goodByMe:
          me != null && goods.any((g) => (g as Map)['user_id']?.toString() == me),
      helpful: m['helpful'] == true,
      mine: me != null && m['user_id']?.toString() == me,
    );
  }

  // ───────── خواندن ─────────
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

  // ───────── «حس خوبی داد» ─────────
  Future<void> toggleGood(FriendPost p) async {
    final c = _c;
    final me = myId;
    if (c == null || me == null || !canWrite) return;
    final was = p.goodByMe;
    p.goodByMe = !was;
    p.goodCount += was ? -1 : 1;
    notifyListeners();
    try {
      if (was) {
        await c
            .from('friend_post_good')
            .delete()
            .eq('post_id', p.id)
            .eq('user_id', me);
      } else {
        await c.from('friend_post_good').insert({'post_id': p.id});
      }
    } catch (e) {
      if (!(e is PostgrestException && e.code == '23505')) {
        p.goodByMe = was;
        p.goodCount += was ? 1 : -1;
        error = _msg(e);
      }
      notifyListeners();
    }
  }

  Future<void> toggleAnswerGood(FriendAnswer a) async {
    final c = _c;
    final me = myId;
    if (c == null || me == null || !canWrite) return;
    final was = a.goodByMe;
    a.goodByMe = !was;
    a.goodCount += was ? -1 : 1;
    notifyListeners();
    try {
      if (was) {
        await c
            .from('friend_answer_good')
            .delete()
            .eq('answer_id', a.id)
            .eq('user_id', me);
      } else {
        await c.from('friend_answer_good').insert({'answer_id': a.id});
      }
    } catch (e) {
      if (!(e is PostgrestException && e.code == '23505')) {
        a.goodByMe = was;
        a.goodCount += was ? 1 : -1;
        error = _msg(e);
      }
      notifyListeners();
    }
  }

  // ───────── نوشتن ─────────
  /// null = موفق؛ وگرنه پیامِ خطا برای نشان‌دادن به کاربر
  Future<String?> addPost({
    required FriendKind kind,
    required String title,
    String body = '',
    String category = '',
    String? emotionId,
    required String author,
  }) async {
    final c = _c;
    if (c == null) return 'اتصال به سرور تنظیم نشده.';
    if (!canWrite) return 'برای نوشتن باید با حساب Google وارد شوی.';
    try {
      final row = await c
          .from('friend_posts')
          .insert({
            'kind': kind.name,
            'title': title,
            'body': body,
            'category': category,
            'author_name': author,
            if (emotionId != null) 'emotion_id': emotionId,
          })
          .select()
          .single();
      final p = _postFrom(Map<String, dynamic>.from(row), {}, {});
      if (p != null) _posts.insert(0, p);
      _nick = author;
      final prefs = await AppPrefs.getInstance();
      await prefs.setString(_kNick, author);
      notifyListeners();
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  Future<String?> addAnswer(FriendPost p, String body) async {
    final c = _c;
    if (c == null) return 'اتصال به سرور تنظیم نشده.';
    if (!canWrite) return 'برای پاسخ دادن باید با حساب Google وارد شوی.';
    try {
      final row = await c
          .from('friend_answers')
          .insert({
            'post_id': p.id,
            'author_name': myName,
            'body': body,
          })
          .select()
          .single();
      p.answers.add(_answerFrom(Map<String, dynamic>.from(row), myId));
      notifyListeners();
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  /// پرسنده فقط یک پاسخ را «کمکم کرد» می‌کند؛ دوباره زدن برش می‌دارد
  Future<void> markHelpful(FriendPost p, FriendAnswer a) async {
    final c = _c;
    if (c == null || !canWrite) return;
    final was = a.helpful;
    final before = {for (final x in p.answers) x.id: x.helpful};
    for (final x in p.answers) {
      x.helpful = false;
    }
    a.helpful = !was;
    notifyListeners();
    try {
      await c.rpc('friend_mark_helpful', params: {'p_answer': a.id});
    } catch (e) {
      for (final x in p.answers) {
        x.helpful = before[x.id] ?? false;
      }
      error = _msg(e);
      notifyListeners();
    }
  }

  /// پستِ خودم را پاک می‌کنم
  Future<String?> deletePost(FriendPost p) async {
    final c = _c;
    if (c == null || !canWrite) return 'برای این کار باید وارد شوی.';
    try {
      await c.from('friend_posts').delete().eq('id', p.id);
      _posts.removeWhere((x) => x.id == p.id);
      notifyListeners();
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  // ───────── گزارش ─────────
  /// گزارش ثبت می‌شود و برای خودِ گزارش‌دهنده بلافاصله پنهان؛ با ۳ گزارش از
  /// آدم‌های مختلف برای همه پنهان می‌شود.
  Future<void> hidePost(FriendPost p, {String reason = ''}) async {
    p.hiddenByMe = true;
    notifyListeners();
    final c = _c;
    if (c == null || !canWrite) return;
    try {
      await c.from('friend_reports').insert({'post_id': p.id, 'reason': reason});
    } catch (e) {
      if (!(e is PostgrestException && e.code == '23505')) error = _msg(e);
      notifyListeners();
    }
  }

  Future<void> hideAnswer(FriendAnswer a, {String reason = ''}) async {
    a.hidden = true;
    notifyListeners();
    final c = _c;
    if (c == null || !canWrite) return;
    try {
      await c
          .from('friend_reports')
          .insert({'answer_id': a.id, 'reason': reason});
    } catch (e) {
      if (!(e is PostgrestException && e.code == '23505')) error = _msg(e);
      notifyListeners();
    }
  }
}
