import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../services/app_prefs.dart';
import '../services/reminder_notify.dart';

enum ReminderKind { goals, practice }

/// یادآورِ «هدف‌گذاری» و «تمرین»: هر چند دقیقه یک‌بار (قابل‌تنظیم) پیام می‌دهد.
///
/// • وقتی برنامه جلوی چشمِ کاربر است: نوارِ پیام داخل برنامه ([onDue]).
/// • وقتی صفحه در پس‌زمینه است: اعلانِ سیستمی (فقط وب و با اجازه‌ی کاربر).
///   اگر اعلان ممکن نبود، همان پیام برای وقتی که کاربر برگشت نگه داشته می‌شود.
///
/// توجه: مرورگر برنامه‌ی بسته را بیدار نمی‌کند؛ یادآور تا وقتی برنامه باز است
/// (حتی در پس‌زمینه) کار می‌کند.
class ReminderStore extends ChangeNotifier {
  static const _kGoalOn = 'rem_goal_on';
  static const _kGoalMin = 'rem_goal_min';
  static const _kPracOn = 'rem_prac_on';
  static const _kPracMin = 'rem_prac_min';

  /// گزینه‌های فاصله‌ی یادآوری (دقیقه)
  static const List<int> kIntervals = [15, 30, 60, 90, 120, 180];

  static const _goalMsgs = [
    'یه قدم کوچیک برای هدفت بردار 🌱',
    'نقشه‌ات منتظرته؛ امروز چه قدمی برمی‌داری؟',
    'هدفت رو یادت هست؟ یک اقدام کوچیک کافیه.',
  ];
  static const _pracMsgs = [
    'وقتِ تمرینه 💛 چند لحظه برای خودت.',
    'یه تمرین کوتاه انجام بده؛ شکرگذاری یا بازنویسی.',
    'تمرینِ امروزت رو فراموش نکن.',
  ];

  bool goalOn = false;
  int goalMin = 120;
  bool pracOn = false;
  int pracMin = 60;

  /// 'granted' | 'denied' | 'default' | 'unsupported'
  String perm = 'unsupported';

  /// شل برنامه این را می‌گذارد تا نوارِ پیام نشان دهد
  void Function(ReminderKind kind, String message)? onDue;

  Timer? _timer;
  final Map<ReminderKind, DateTime> _last = {};
  final List<(ReminderKind, String)> _pending = [];
  int _msgIdx = 0;

  Future<void> load() async {
    try {
      final p = await AppPrefs.getInstance();
      goalOn = p.getBool(_kGoalOn) ?? false;
      goalMin = _okMin(p.getInt(_kGoalMin), 120);
      pracOn = p.getBool(_kPracOn) ?? false;
      pracMin = _okMin(p.getInt(_kPracMin), 60);
    } catch (e) {
      debugPrint('reminder load: $e');
    }
    perm = notifyPermission();
  }

  static int _okMin(int? v, int def) =>
      (v != null && v >= 5 && v <= 1440) ? v : def;

  // ───────── تنظیمات ─────────
  Future<void> setGoalOn(bool v) async {
    goalOn = v;
    _last[ReminderKind.goals] = DateTime.now();
    await _save(_kGoalOn, v);
    if (v) await _askPerm();
    notifyListeners();
  }

  Future<void> setPracOn(bool v) async {
    pracOn = v;
    _last[ReminderKind.practice] = DateTime.now();
    await _save(_kPracOn, v);
    if (v) await _askPerm();
    notifyListeners();
  }

  Future<void> setGoalMin(int m) async {
    goalMin = m;
    _last[ReminderKind.goals] = DateTime.now();
    await _save(_kGoalMin, m);
    notifyListeners();
  }

  Future<void> setPracMin(int m) async {
    pracMin = m;
    _last[ReminderKind.practice] = DateTime.now();
    await _save(_kPracMin, m);
    notifyListeners();
  }

  /// دکمه‌ی «اجازه‌ی اعلان» در تنظیمات
  Future<void> requestPermission() async {
    await _askPerm(force: true);
    notifyListeners();
  }

  Future<void> _askPerm({bool force = false}) async {
    if (!notifySupported()) return;
    final cur = notifyPermission();
    if (cur == 'default' || (force && cur != 'granted')) {
      perm = await requestNotifyPermission();
    } else {
      perm = cur;
    }
  }

  Future<void> _save(String key, Object v) async {
    try {
      final p = await AppPrefs.getInstance();
      if (v is bool) await p.setBool(key, v);
      if (v is int) await p.setInt(key, v);
    } catch (e) {
      debugPrint('reminder save: $e');
    }
  }

  // ───────── زمان‌بندی ─────────
  void start() {
    final now = DateTime.now();
    _last[ReminderKind.goals] = now;
    _last[ReminderKind.practice] = now;
    _timer?.cancel();
    // هر ۳۰ ثانیه چک می‌شود (مرورگر تایمرِ پس‌زمینه را کند می‌کند؛ برای دقیقه‌ای کافی است)
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    final now = DateTime.now();
    _check(ReminderKind.goals, goalOn, goalMin, now);
    _check(ReminderKind.practice, pracOn, pracMin, now);
  }

  void _check(ReminderKind k, bool on, int min, DateTime now) {
    if (!on) return;
    final last = _last[k] ?? now;
    if (now.difference(last).inMinutes < min) return;
    _last[k] = now;
    _fire(k);
  }

  void _fire(ReminderKind k) {
    final list = k == ReminderKind.goals ? _goalMsgs : _pracMsgs;
    final msg = list[_msgIdx++ % list.length];
    final state = WidgetsBinding.instance.lifecycleState;
    final visible = state == null || state == AppLifecycleState.resumed;
    if (visible) {
      onDue?.call(k, msg);
      return;
    }
    final title = k == ReminderKind.goals ? 'هدف‌گذاری' : 'تمرین';
    showSystemNotification(title, msg).then((ok) {
      // اعلان ممکن نبود: وقتی کاربر برگشت نشان داده شود
      if (!ok && _pending.length < 2) _pending.add((k, msg));
    });
  }

  /// وقتی کاربر به برنامه برگشت صدا زده می‌شود
  void showPending() {
    if (_pending.isEmpty) return;
    final (k, m) = _pending.last;
    _pending.clear();
    onDue?.call(k, m);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
