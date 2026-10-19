import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/constants/app_languages.dart';
import '../../../core/mascot/mascot_pin_provider.dart';
import '../../../core/neural/neural_dates.dart' show faDigits;
import '../../../core/providers/app_prefs_provider.dart';
import '../../../core/providers/linlearn_provider.dart';
import '../../../core/providers/reader_providers.dart';
import '../../../core/providers/speech_provider.dart';
import '../../../core/providers/story_library_provider.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/tts/speech_state.dart';
import '../../review/providers/review_provider.dart';
import '../../review/providers/review_session_provider.dart';

// ─────────────────────────────────────────────────────────────────────────
// آدمکِ ساده‌ی Lingova (کلاسیک) — پورتِ LingovaMascot.jsx + useLingovaMascot.js
// از Hope. فقط همان آدمکِ سادهٔ SVG؛ کاراکترها/لباس‌های دیگر پورت نشده‌اند.
//
//  • رویِ یک نوارِ ثابتِ بالای صفحه رفت‌وبرگشت قدم می‌زند.
//  • اگر کاربر بی‌تعامل شود، دو پیامِ تصادفی از چهار پیامِ یادآوری نشان می‌دهد.
//  • تپِ ساده = توقف/ادامه، کشیدن و رها کردن = سنجاق شدن همان‌جا.
//  • پیام‌های رویدادی: لغت‌های جدید، داستان جدید، پایان مرور، یادگرفتنِ لغت، streak.
// ─────────────────────────────────────────────────────────────────────────
const double _kW = 30; // LINGOVA_MASCOT_WIDTH
const double _kH = 38; // LINGOVA_MASCOT_HEIGHT
const double _kStripH = 40; // ارتفاع نوار بالا (بدون نوار وضعیت)
const double _kStripPad = 16; // px-4
const int _kIdleMs = 6000; // LINGOVA_IDLE_MS
const int _kLegMsgCount = 2; // LINGOVA_LEG_MSG_COUNT
const int _kLegMsgPauseMs = 2000; // LINGOVA_LEG_MSG_PAUSE_MS
const int _kLegMsgMinDelayMs = 500;
const int _kLegMsgMaxDelayMs = 7000;
const int _kTurnPauseMs = 400; // LINGOVA_TURN_PAUSE_MS
const double _kTapMove = 10; // LINGOVA_TAP_MOVE_TOLERANCE
const int _kEventShowMs = 3200;
const String _kDailyKey = 'zflut-mascot-daily-v1';

enum _Mode { walk, read, alert }

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

class LingovaMascotLayer extends ConsumerStatefulWidget {
  const LingovaMascotLayer({super.key});

  @override
  ConsumerState<LingovaMascotLayer> createState() => _LingovaMascotLayerState();
}

class _LingovaMascotLayerState extends ConsumerState<LingovaMascotLayer>
    with WidgetsBindingObserver {
  final math.Random _rnd = math.Random();
  Timer? _timer;

  // حرکت
  double _x = 0;
  double _target = -1; // -1 = هنوز مسیری شروع نشده
  double _speed = 0.55;
  int _facing = 1;
  _Mode _mode = _Mode.walk;
  int _pauseUntil = 0;
  List<double> _cps = [0, 0];
  int _cpIdx = 0;
  String? _idleBubble;
  bool _paused = false;
  bool _playing = false;
  bool _lastPinned = false;

  // درگ
  bool _pressed = false;
  bool _moved = false;
  Offset _downPos = Offset.zero;
  Offset _grabOff = Offset.zero;
  Offset _dragPos = Offset.zero;

  // پیام‌های رویدادی
  final List<String> _queue = [];
  String? _eventBubble;
  int _eventUntil = 0;

  Size _screen = Size.zero;
  double _topInset = 0;

  @override
  void initState() {
    super.initState();
    _playing =
        ref.read(speechControllerProvider).status == SpeechStatus.playing;
    _timer = Timer.periodic(const Duration(milliseconds: 45), _tick);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // برگشت به اپ (مثلاً بعد از تماشای ویدیو با حباب/زیرنویس) = «تعامل»؛ بلافاصله هشدار نده
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      MascotActivity.mark();
      _idleBubble = null;
      if (_mode == _Mode.alert) _mode = _Mode.walk;
    }
  }

  /// کاربر دارد از حباب/ترجمه‌ی زنده/زیرنویس (بیرون از اپ) استفاده می‌کند؛ بیکار حساب نمی‌شود.
  bool _externalActive() {
    try {
      return ref.read(bubbleProvider).running || ref.read(liveTranslatorProvider);
    } catch (_) {
      return false;
    }
  }

  // ───────────────────────── منطق حرکت (stepLeg) ─────────────────────────
  bool get _dragMoved => _pressed && _moved;

  double _edge1(bool pinned) {
    final track = pinned ? _screen.width : _screen.width - 2 * _kStripPad;
    return math.max(track - _kW, 24);
  }

  void _startLeg(double toX) {
    _target = toX;
    _facing = toX >= _x ? 1 : -1;
    _speed = 0.45 + _rnd.nextDouble() * 0.3;
    double d() =>
        _kLegMsgMinDelayMs +
        _rnd.nextDouble() * (_kLegMsgMaxDelayMs - _kLegMsgMinDelayMs);
    _cps = [d(), d()]..sort();
    _cpIdx = 0;
  }

  String _pickIdleLine() {
    final L = context.l10n;
    final lines = [
      L.lingovaBubbleRead,
      L.lingovaBubbleKeepGoing,
      L.lingovaBubbleStillThere,
      L.lingovaBubbleHeyYou,
    ];
    return lines[_rnd.nextInt(lines.length)];
  }

  void _step(int now, bool pinned) {
    if (_playing || _externalActive()) MascotActivity.mark();
    final last = MascotActivity.last;
    final isIdle = now - last > _kIdleMs;
    final edge1 = _edge1(pinned);

    if (_target < 0) _startLeg(edge1);

    if (_mode == _Mode.alert) {
      if (!isIdle || now >= _pauseUntil) {
        _mode = _Mode.walk;
        _idleBubble = null;
      }
      return;
    }

    if (_mode == _Mode.read) {
      if (now >= _pauseUntil) {
        final next = _target == 0 ? edge1 : 0.0;
        _startLeg(next);
        _mode = _Mode.walk;
      }
      return;
    }

    final dx = _target - _x;
    if (dx.abs() < 1.5) {
      _mode = _Mode.read;
      _pauseUntil = now + _kTurnPauseMs;
      return;
    }

    if (isIdle && _cpIdx < _kLegMsgCount) {
      final dueAt = last + _kIdleMs + _cps[_cpIdx].toInt();
      if (now >= dueAt) {
        _cpIdx += 1;
        _mode = _Mode.alert;
        _idleBubble = _pickIdleLine();
        _pauseUntil = now + _kLegMsgPauseMs;
        return;
      }
    }

    _x += dx.sign * _speed;
  }

  void _tick(Timer _) {
    if (!mounted || _screen == Size.zero) return;
    final now = _nowMs();

    if (_eventBubble != null && now >= _eventUntil) _eventBubble = null;
    if (_eventBubble == null && _queue.isNotEmpty) {
      _eventBubble = _queue.removeAt(0);
      _eventUntil = now + _kEventShowMs;
    }

    final pin = ref.read(mascotPinProvider);
    final pinned = pin != null;
    if (pinned != _lastPinned) {
      _lastPinned = pinned;
      _target = -1;
      _mode = _Mode.walk;
      _idleBubble = null;
      _x = pinned
          ? (pin!.dx * _screen.width)
              .clamp(0.0, math.max(_screen.width - _kW, 0.0))
              .toDouble()
          : 0.0;
    }

    if (!_paused && !_pressed) _step(now, pinned);
    setState(() {});
  }

  // ───────────────────────── پیام‌های رویدادی ─────────────────────────
  void _say(String text) {
    if (_queue.length >= 3) return;
    _queue.add(text);
  }

  void _onNewWords(int n) {
    final storage = ref.read(localStorageProvider);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final j = storage.readJson(_kDailyKey);
    var count = 0;
    var fired = <int>[];
    if (j['day'] == today) {
      count = (j['count'] as num?)?.toInt() ?? 0;
      fired = [
        for (final e in (j['fired'] as List? ?? const []))
          if (e is num) e.toInt()
      ];
    }
    count += n;
    final L = context.l10n;
    String? msg;
    for (final thr in const [5, 10, 20]) {
      if (count >= thr && !fired.contains(thr)) {
        fired.add(thr);
        msg = thr == 5
            ? L.lingovaBubbleGreatStart
            : thr == 10
                ? L.lingovaBubbleGoodProgress
                : L.lingovaBubbleExcellent;
      }
    }
    unawaited(storage
        .writeJson(_kDailyKey, {'day': today, 'count': count, 'fired': fired}));
    if (msg != null) _say(msg);
  }

  void _onReviewSession(ReviewSessionState? p, ReviewSessionState n) {
    if (p == null || p.startedAt != n.startedAt) return;
    final L = context.l10n;
    if (n.learned > p.learned) _say(L.lingovaBubbleMastered);
    if (!p.finished && n.finished) {
      _say(L.lingovaBubbleReviewDone);
      final streak = ref.read(reviewStatsProvider).streak(DateTime.now());
      if (streak >= 2) {
        final lang = ref.read(appPrefsProvider).uiLang;
        _say(L.lingovaBubbleStreak(lang == 'fa' ? faDigits(streak) : '$streak'));
      }
    }
  }

  // ───────────────────────── درگ / تپ ─────────────────────────
  Offset _currentPos(bool pinned, Offset? pin) {
    if (_dragMoved) return _dragPos;
    if (pinned && pin != null) {
      final top = (pin.dy * _screen.height)
          .clamp(0.0, math.max(_screen.height - _kH, 0.0))
          .toDouble();
      return Offset(_x, top);
    }
    return Offset(_kStripPad + _x, _topInset);
  }

  void _onDown(PointerDownEvent e, Offset pos) {
    _pressed = true;
    _moved = false;
    _downPos = e.position;
    _grabOff = e.position - pos;
    _dragPos = pos;
    setState(() {});
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pressed) return;
    if (!_moved && (e.position - _downPos).distance > _kTapMove) _moved = true;
    if (_moved) {
      final p = e.position - _grabOff;
      _dragPos = Offset(
        p.dx.clamp(0.0, math.max(_screen.width - _kW, 0.0)).toDouble(),
        p.dy.clamp(0.0, math.max(_screen.height - _kH, 0.0)).toDouble(),
      );
      setState(() {});
    }
  }

  void _onUp() {
    if (!_pressed) return;
    final moved = _moved;
    _pressed = false;
    _moved = false;
    if (moved) {
      _x = _dragPos.dx;
      _lastPinned = true;
      _target = -1;
      _mode = _Mode.walk;
      ref
          .read(mascotPinProvider.notifier)
          .pin(_dragPos.dx / _screen.width, _dragPos.dy / _screen.height);
    } else {
      _paused = !_paused;
    }
    setState(() {});
  }

  // ───────────────────────── ظاهر ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final prefs = ref.watch(appPrefsProvider);
    final pin = ref.watch(mascotPinProvider);

    ref.listen(
      speechControllerProvider.select((s) => s.status),
      (_, n) => _playing = n == SpeechStatus.playing,
    );
    ref.listen(leitnerProvider, (p, n) {
      if (p != null && n.length > p.length) _onNewWords(n.length - p.length);
    });
    ref.listen(storyLibraryProvider, (p, n) {
      if (p != null && n.length > p.length) _say(context.l10n.lingovaBubbleNewStory);
    });
    ref.listen(reviewSessionProvider, _onReviewSession);

    final mq = MediaQuery.of(context);
    _topInset = mq.padding.top;
    _screen = mq.size;
    final enabled = prefs.mascotEnabled;
    final pinned = pin != null || _dragMoved;
    final pos = _currentPos(pinned, pin);

    final bubbleText = !enabled
        ? null
        : (_eventBubble ?? (_paused ? null : _idleBubble));
    final showBubble = bubbleText != null && !_dragMoved;

    final shown = _paused ? null : _mode;
    final mascot = Positioned(
      left: pos.dx,
      top: pos.dy,
      width: _kW,
      height: _kH,
      child: IgnorePointer(
        ignoring: !enabled,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0,
          duration: const Duration(milliseconds: 600),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _onDown(e, pos),
            onPointerMove: _onMove,
            onPointerUp: (_) => _onUp(),
            onPointerCancel: (_) {
              _pressed = false;
              _moved = false;
              setState(() {});
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(_facing.toDouble(), 1, 1),
                  child: CustomPaint(
                    size: const Size(_kW, _kH),
                    painter: _MascotPainter(
                      mode: shown,
                      ms: _nowMs(),
                      shirt: c.teal,
                      pants: c.ink,
                      head: c.gold,
                      eye: c.ink,
                    ),
                  ),
                ),
                if (_paused)
                  Positioned(
                    top: -16,
                    left: _facing == 1 ? 6 : -6,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: c.ink,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.play_arrow, size: 10, color: c.paper),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // نوار ثابتِ بالای صفحه (هم‌رنگ هدر) — جای راه‌رفتنِ آدمک
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _topInset + _kStripH,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.headerFrom, c.headerTo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        mascot,
        if (showBubble) _bubble(c, prefs.uiLang, bubbleText, pos),
      ],
    );
  }

  Widget _bubble(AppThemeColorsExt c, String uiLang, String text, Offset pos) {
    final dir = kAppLanguages[uiLang]?.dir ?? TextDirection.ltr;
    final style = TextStyle(
      color: c.ink,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.none,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: dir,
      maxLines: 1,
    )..layout();
    final bw = tp.width + 12;
    final desired = pos.dx + (_facing == 1 ? -4 : -34);
    final left =
        desired.clamp(8.0, math.max(_screen.width - 8 - bw, 8.0)).toDouble();
    final above = pos.dy >= 26;
    final top = above ? pos.dy - 22 : pos.dy + _kH + 2;
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Directionality(
          textDirection: dir,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: c.paper,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Text(text, maxLines: 1, softWrap: false, style: style),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── نقاشی آدمک (SVG → Canvas) ───────────────────────────
class _MascotPainter extends CustomPainter {
  /// null = پارک‌شده (بدون انیمیشن)
  final _Mode? mode;
  final int ms;
  final Color shirt, pants, head, eye;

  _MascotPainter({
    required this.mode,
    required this.ms,
    required this.shirt,
    required this.pants,
    required this.head,
    required this.eye,
  });

  static double _tri(double t) => t < 0.5 ? 1 - 4 * t : -3 + 4 * t;

  void _rot(Canvas c, Offset o, double deg, VoidCallback draw) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(deg * math.pi / 180);
    c.translate(-o.dx, -o.dy);
    draw();
    c.restore();
  }

  RRect _r(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  @override
  void paint(Canvas canvas, Size size) {
    final t = (ms % 500) / 500.0;
    final walking = mode == _Mode.walk;

    // چماق
    var armDeg = 0.0;
    var armDy = 0.0;
    if (mode == _Mode.alert) {
      armDeg = -95;
      armDy = -2 * (0.5 - 0.5 * math.cos(2 * math.pi * (ms % 600) / 600));
    } else if (walking) {
      armDeg = -10 * _tri(t);
    }
    canvas.save();
    canvas.translate(0, armDy);
    _rot(canvas, const Offset(18, 15), armDeg, () {
      canvas.drawRRect(_r(17, 3, 2.6, 11, 1.3), Paint()..color = const Color(0xFF8A5A2B));
      canvas.drawCircle(const Offset(18.3, 3), 2.6, Paint()..color = const Color(0xFF6B4423));
    });
    canvas.restore();

    // سر (موقع «خوندن» کمی خم می‌شود)
    _rot(canvas, const Offset(15, 8), mode == _Mode.read ? 18 : 0, () {
      canvas.drawCircle(const Offset(15, 8), 5, Paint()..color = head);
      canvas.drawCircle(const Offset(17, 7.2), 0.8, Paint()..color = eye);
    });

    // تنه
    canvas.drawRRect(_r(12, 13, 6, 12, 3), Paint()..color = shirt);

    // پاها
    final legDeg = walking ? 24 * _tri(t) : 0.0;
    final pp = Paint()..color = pants;
    _rot(canvas, const Offset(13, 25), legDeg, () {
      canvas.drawRRect(_r(11.5, 25, 2.4, 10, 1.2), pp);
    });
    _rot(canvas, const Offset(17, 25), -legDeg, () {
      canvas.drawRRect(_r(16, 25, 2.4, 10, 1.2), pp);
    });
  }

  @override
  bool shouldRepaint(covariant _MascotPainter old) => true;
}
