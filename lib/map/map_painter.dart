import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show StringCharacters;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/constants.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../services/map_video_player.dart';
import '../services/map_voice_player.dart';
import '../theme/vazir_font.dart';
import '../state/goal_ops.dart';
import 'camera.dart';
import 'draw_utils.dart';
import '../services/note_fonts.dart';
import 'foot_shape.dart';
import 'geometry.dart' as geo;
import 'hit_registry.dart';
import 'map_ops.dart';
import 'plant_painter.dart';
import 'today_focus.dart';
import 'user_state.dart';
import 'walker_photos.dart';
import 'world_painter.dart';
import '../widgets/emoji_stack.dart' show isTextIcon;

const kLabelRtlAnchor = false;

/// پاداشِ دیداری: هدفِ رسیده‌شده / شاخه‌ی انجام‌شده‌ی امروز کم‌رنگ می‌شود
const double _kReachedFade = 0.88; // هدفِ رسیده‌شده پررنگ می‌ماند (قبلاً ۰٫۴۲)
const double _kDoneFade = 0.5;

/// وضعیتِ «انجام شد» برای مُهر و انیمیشنِ پاداش (فقط در حافظه‌ی همین اجرا)
final Map<String, bool> _doneSeen = {};
final Map<String, double> _doneBurstAt = {};

/// شکوفه‌ی شاخه‌های تمام‌شده و جشنِ رسیدن به هدف (فقط در حافظه‌ی همین اجرا)
final Map<String, bool> _bloomSeen = {};
final Map<String, double> _bloomAt = {};
final Map<String, String> _flowerSigCache = {};
final Map<String, Set<String>> _flowerDaysCache = {};

/// روزهایی از یک شاخه که روی نقشه گل شده‌اند (برای نمای راه‌رفتن؛ null = هنوز رسم نشده)
Set<String>? mapFlowerDays(String actionId) => _flowerDaysCache[actionId];

/// همان شاخه‌ی گل/غنچه‌ی نقشه (برای نمای راه‌رفتن)؛ ریشه در (۰،۰)، جهتِ [dir]
void paintMapSprig(Canvas canvas, Offset tip, double dir, double r, String id,
        {bool budOnly = false, bool flower = false}) =>
    MapPainter._sprig(canvas, tip, dir, r, id, 1.0,
        budOnly: budOnly, flower: flower);
/// گیاهِ تمرکز: توقفِ تایمر → شکفتنِ غنچه/گل (فقط در حافظه‌ی همین اجرا)
final Map<String, bool> _plantRunSeen = {};
final Map<String, double> _plantStopAt = {};
final Map<String, bool> _reachSeen = {};
final Map<String, double> _reachAt = {};

/// شفافیتِ قدم‌زنِ (عکس + پاها) بعد از «انجام شد»
const double _kDoneWalkerFade = 0.42;

/// وضعیتِ جمع/بازشدنِ حلزونیِ زیرشاخه‌ها (فقط در حافظه‌ی همین اجرا)
/// p: ۱ = کاملاً باز ، ۰ = کاملاً جمع
class _FoldRt {
  double p = 1.0;
  bool? target;
  double lastT = 0;
  double delayUntil = 0;
  double msgAt = -100;
}

final Map<String, _FoldRt> _foldRt = {};

double _l(double a, double b, double t) => a + (b - a) * t;

/// ease in-out (کند → تند → کند)
double _easeInOut(double t) {
  if (t < 0.5) return 2 * t * t;
  final u = -2 * t + 2;
  return 1 - u * u / 2;
}

/// وضعیتِ زنده‌ی هر قدم‌زن (فقط در حافظه): موقعیتِ لحظه‌ای روی مسیر، تا بعد از
/// توقف (لمس طولانی) دقیقاً از همان‌جا ادامه بدهد و نپرد.
class _WalkerRt {
  double? cyc; // موقعیت در چرخه‌ی رفت‌وبرگشت (کسری از ۰ تا ۱؛ با زوم نمی‌پرد)
  double lastTt = 0;
  bool playing = false;
  double? lastBodyT; // آخرین موقعیتِ کشیده‌شده
  bool lastRet = false; // آخرین جهت (برگشت؟)
  double? frozenT; // موقعیتِ لحظه‌ی توقف (یا جایی که کاربر کشید)
  bool frozenRet = false;
  double? seenManual; // آخرین walkerPos/footPos دیده‌شده؛ برای تشخیص کشیدنِ دستی
}

final Map<String, _WalkerRt> _walkerRt = {};

/// منحنی عمومی برای قدم‌زن: t بین ۰ و ۱
abstract class _Curve {
  Offset at(double t);
  double tangent(double t);
}

class _CubicCurve implements _Curve {
  _CubicCurve(this.c);
  final geo.Cubic c;
  @override
  Offset at(double t) => c.at(t);
  @override
  double tangent(double t) => c.tangent(t);
}

/// مسیر چندپاره (از ابتدای شاخه، روی شاخه‌های پدر، تا تنه و هدف)
class _RouteCurve implements _Curve {
  _RouteCurve(List<Offset> raw) {
    for (final p in raw) {
      if (pts.isEmpty || (p - pts.last).distance > 0.5) pts.add(p);
    }
    if (pts.length < 2) pts.add(pts.first + const Offset(1, 0));
    cum.add(0);
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum.last + (pts[i] - pts[i - 1]).distance);
    }
    length = cum.last;
  }
  final List<Offset> pts = [];
  final List<double> cum = [];
  late final double length;

  @override
  Offset at(double t) {
    final d = length * t.clamp(0.0, 1.0);
    for (var i = 1; i < pts.length; i++) {
      if (d <= cum[i] || i == pts.length - 1) {
        final seg = (cum[i] - cum[i - 1]);
        final f = seg == 0 ? 0.0 : ((d - cum[i - 1]) / seg).clamp(0.0, 1.0);
        return Offset.lerp(pts[i - 1], pts[i], f)!;
      }
    }
    return pts.first;
  }

  /// جهت به سمت هدف؛ با پنجره‌ی کوچک نرم می‌شود تا در پیچ‌ها ناگهانی نچرخد
  @override
  double tangent(double t) {
    final w = math.min(0.25, 14.0 / math.max(length, 1.0));
    final a = at((t - w).clamp(0.0, 1.0));
    final b = at((t + w).clamp(0.0, 1.0));
    final d = b - a;
    return math.atan2(d.dy, d.dx);
  }
}

/// ترتیب زمانی کلید روز جلالی «سال-ماه-روز»
int _jkOrd(String k) {
  final p = k.split('-');
  if (p.length != 3) return 0;
  return (int.tryParse(p[0]) ?? 0) * 10000 +
      (int.tryParse(p[1]) ?? 0) * 100 +
      (int.tryParse(p[2]) ?? 0);
}

class MapPainter extends CustomPainter {
  MapPainter({
    required this.state,
    required this.cam,
    required this.time,
    required this.images,
    required this.boundsBox,
    required this.hits,
    this.isDark = true,
  }) : super(
            repaint: Listenable.merge(
                [
              cam,
              time,
              images,
              MapVoicePlayer.instance.playing,
              MapVideoPlayer.instance.current
            ]));

  final MapState state;
  final CameraController cam;
  final ValueNotifier<double> time;
  final NodeImageCache images;
  final MapBoundsBox boundsBox;
  final HitRegistry hits;
  final bool isDark;
  final List<Offset> _pts = [];

  double get _t => time.value;

  /// موقعیت پاهای قدم‌زن‌های رسم‌شده در این فریم (برای دوری از تداخل)
  final List<Offset> _walkerPts = [];

  /// آخرین موقعیت/شعاع سرِ قدم‌زن رسم‌شده (برای دکمه‌ی تایمر)
  /// لمس‌های گل/غنچه: آخر از همه ثبت می‌شوند تا نوشته‌ی شاخه یا قدم رویشان را نگیرد
  final List<HitEntry> _lateHits = [];
  Offset _lastBodyPos = Offset.zero;
  double _lastBodyR = 0;

  @override
  bool shouldRepaint(covariant MapPainter old) => true;

  // ───────────────────────── رنگ و اندازه ─────────────────────────

  Color get _textColor {
    final c = state.textColor.toLowerCase().trim();
    final auto = isDark ? Colors.white : Colors.black;
    if (c == '#000000' || c == '#000') return Colors.black;
    if (c.isEmpty || c == '#eef0fa' || c == '#ffffff' || c == '#fff') {
      return auto;
    }
    return hexColor(c, auto);
  }

  double _fs() => state.fontSize.clamp(8.0, 60.0).toDouble();

  /// رنگ نوشته‌ی اختصاصی هر گره (extra['labelColor']) یا رنگ کلی
  Color _tcOf(Map<String, dynamic> extra, Color tc) {
    final v = extra['labelColor'];
    if (v is String && v.isNotEmpty) return hexColor(v, tc);
    return tc;
  }

  /// فونت اختصاصیِ نوشته‌ی هر گره (extra[key]؛ پیش‌فرض labelFont). تا دانلود نشده null.
  String? _fontOf(Map<String, dynamic> extra, [String key = 'labelFont']) {
    final id = extra[key];
    if (id is! String || id.isEmpty || id == 'default') return null;
    NoteFonts.ensure(id);
    return NoteFonts.familyOf(id);
  }

  /// ضریب اندازه‌ی دایره‌ی نوک اقدام/زیراقدام (extra['circleScale'])
  double _circleScaleOf(ActionNode a) {
    final v = a.extra['circleScale'];
    return v is num ? v.toDouble().clamp(0.3, 8.0).toDouble() : 1.0;
  }
  /// وقتی نقشه خیلی زوم‌اوت است، نوشته‌ی «من/هدف/حلقه» تا حدی بزرگ می‌شود تا روی صفحه ریز نشود
  double _zoomBoost() {
    final s = cam.scale <= 0 ? 1.0 : cam.scale;
    return (kLabelMinScreenPx / (_fs() * s)).clamp(1.0, kLabelBoostMax).toDouble();
  }

  double _labelSize(String type, [double scale = 1]) {
    switch (type) {
      case 'me':
        return (_fs() + 3) * _zoomBoost();
      case 'goal':
        return _fs() * _zoomBoost();
      case 'ring':
        return (_fs() - 2) * _zoomBoost();
      default:
        return math.max(8, _fs() * math.min(1.0, scale + 0.3));
    }
  }

  /// نمایش تاریخ/ساعتِ هر گره: انتخابِ خودِ گره (extra) یا تنظیم کلی
  bool _showDateOf(Map<String, dynamic> extra) {
    final v = extra['showDate'];
    return v is bool ? v : state.showDateStamps;
  }

  bool _showTimeOf(Map<String, dynamic> extra) {
    final v = extra['showTime'];
    return v is bool ? v : state.showTimeStamps;
  }

  /// هاله‌ی هر گره: انتخابِ خودِ گره (extra['showHalo']) یا تنظیم کلی (پیش‌فرض خاموش)
  bool _haloOn(Map<String, dynamic> extra, bool global) {
    final v = extra['showHalo'];
    return v is bool ? v : global;
  }

  String _formatStamp(int ts, Map<String, dynamic> extra) {
    try {
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      final parts = <String>[];
      if (_showDateOf(extra)) {
        final j = toJalaali(d.year, d.month, d.day);
        parts.add('${toFa(j.jy)}/${toFa(j.jm)}/${toFa(j.jd)}');
      }
      if (_showTimeOf(extra)) {
        parts.add(
            '${toFa(d.hour.toString().padLeft(2, '0'))}:${toFa(d.minute.toString().padLeft(2, '0'))}');
      }
      return parts.join(' — ');
    } catch (_) {
      return '';
    }
  }

  void _ringLink(Canvas canvas, Goal g, Ring r) {
    final dx = r.x - g.x;
    final dy = r.y - g.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 1) return;
    final ux = dx / d;
    final uy = dy / d;
    final x1 = g.x + ux * (g.radius + 6);
    final y1 = g.y + uy * (g.radius + 6);
    final x2 = r.x - ux * (r.radius + 6);
    final y2 = r.y - uy * (r.radius + 6);
    final mx = (x1 + x2) / 2 - uy * d * 0.12;
    final my = (y1 + y2) / 2 + ux * d * 0.12;

    final col = hexColor(r.color, hexColor(kRingColor));
    final path = Path()
      ..moveTo(x1, y1)
      ..quadraticBezierTo(mx, my, x2, y2);

    drawDashed(
      canvas,
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = withOp(col, 0.6),
      const [2, 7],
    );
  }

  // ───────────────────────── paint ─────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    // Maghz: `.node-label` و `.branch-label` در تم روشن stroke:#f4f6fb دارند
    // (نوشته‌ی مشکی ← دورِ سفید)؛ فقط `.feeling-label` (نشانه‌ها) همیشه #0a0c18 است.
    textCache.setOutline(
        isDark ? const Color(0xFF0A0C18) : const Color(0xFFF4F6FB));
    _pts.clear();
    _walkerPts.clear();
    hits.clear();
    _lateHits.clear();
    canvas.save();
    canvas.translate(cam.x, cam.y);
    canvas.scale(cam.scale);
    // دنیای در حال رشد (زمین سرسبز، جاده، خانه، ماشین…) زیرِ همه‌ی نقشه
    WorldLayer.paint(canvas, state, cam, size, _t, isDark);
    final tc = _textColor;

    // حالت «فقط امروز»: هدفِ قدم بعدی پررنگ، بقیه کم‌رنگ (هر گروه یک لایه)
    final fid = TodayFocus.goalId;
    // کم‌رنگ‌کردنِ بقیه‌ی هدف‌ها حذف شد: همه‌چیز همیشه پررنگ است
    // (به‌جایش غنچه و گل: هر روز غنچه، هر ۳ روزِ پشت‌سرهم یک غنچه → گل)
    const only = false;
    final dimPaint = Paint()..color = const Color.fromRGBO(0, 0, 0, 0.22);
    final passes = only ? const [true, false] : const [false];
    bool dimG(Goal g) => only && g.id != fid;
    bool dimR(Ring r) {
      if (!only) return false;
      final lg = _goalOf(r);
      return lg == null || lg.id != fid;
    }

    for (final dimPass in passes) {
      if (dimPass) canvas.saveLayer(null, dimPaint);
      for (final g in state.goals) {
        if (_isHidden(g)) continue;
        if (only && dimG(g) != dimPass) continue;
        // جمع‌کردنِ هدف (دکمه‌ی ۹ یا دکمه‌ی بالا-چپ) در حالت «فقط امروز» هم رعایت می‌شود
        _fade(canvas, g.reached ? _kReachedFade : 1.0, () {
          _branches(canvas, g, tc,
              trunkOnly: g.reached ||
                  (g.collapsed && g.actions.isNotEmpty));
        });
      }
      if (!state.ringsCollapsed) {
        for (final r in state.rings) {
          if (only && dimR(r) != dimPass) continue;
          if (r.actions.isNotEmpty) {
            final lg = _goalOf(r);
            if (lg != null && _isHidden(lg)) continue;
            final lgReached = lg?.reached ?? false;
            _fade(canvas, lgReached ? _kReachedFade : 1.0, () {
              _branches(canvas, r, tc,
                  trunkOnly:
                      r.collapsed || (lg?.collapsed ?? false) || lgReached);
            });
          }
        }
      }
      if (state.showRingLinks && !state.ringsCollapsed) {
        for (final r in state.rings) {
          if (r.goalId.isEmpty) continue;
          if (only && dimR(r) != dimPass) continue;
          Goal? lg;
          for (final gg in state.goals) {
            if (gg.id == r.goalId) {
              lg = gg;
              break;
            }
          }
          if (lg == null || _isHidden(lg)) continue;
          _ringLink(canvas, lg, r);
        }
      }
      if (dimPass) canvas.restore();
    }
    _drawMe(canvas, tc);
    for (final dimPass in passes) {
      if (dimPass) canvas.saveLayer(null, dimPaint);
      for (final g in state.goals) {
        if (only && dimG(g) != dimPass) continue;
        if (!_isHidden(g)) {
          _fade(canvas, 1.0, () => _drawGoal(canvas, g, tc));
        }
        _hideBtn(canvas, g, tc);
      }
      if (!state.ringsCollapsed) {
        for (final r in state.rings) {
          if (only && dimR(r) != dimPass) continue;
          final lg = _goalOf(r);
          if (lg != null && _isHidden(lg)) continue;
          _fade(canvas, (lg?.reached ?? false) ? _kReachedFade : 1.0,
              () => _drawRing(canvas, r, tc));
        }
      }
      if (dimPass) canvas.restore();
    }
    canvas.restore();
    hits.entries.addAll(_lateHits);

    if (_pts.isNotEmpty) {
      var minX = _pts.first.dx, maxX = minX, minY = _pts.first.dy, maxY = minY;
      for (final p in _pts) {
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
      boundsBox.rect = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(30);
    }
  }

  bool _isHidden(Goal g) => g.extra['hidden'] == true;

  /// اجرای [draw] با شفافیتِ [op] (۱ = بدون تغییر)
  void _fade(Canvas canvas, double op, void Function() draw) {
    if (op >= 0.999) {
      draw();
      return;
    }
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, op));
    draw();
    canvas.restore();
  }

  /// پیشبردِ انیمیشنِ جمع/بازشدنِ زیرشاخه‌های [id]؛ بدون زیرشاخه → null
  _FoldRt? _stepFold(String id, bool hasKids, bool wantFold, int n,
      {bool celebrate = false}) {
    if (!hasKids) {
      _foldRt.remove(id);
      return null;
    }
    var fr = _foldRt[id];
    if (fr == null) {
      // اولین دیدن (مثلاً بازکردن اپ): بدون انیمیشن، مستقیم در حالتِ درست
      fr = _FoldRt()
        ..p = wantFold ? 0.0 : 1.0
        ..target = wantFold
        ..lastT = _t;
      _foldRt[id] = fr;
      return fr;
    }
    if (fr.target != wantFold) {
      fr.target = wantFold;
      // ۳۰۰ میلی‌ثانیه بعد از جشنِ تیک → جمع شدن (پاداشِ دوم)
      fr.delayUntil = wantFold ? _t + 0.3 : _t;
      if (wantFold && celebrate) fr.msgAt = _t + 0.3;
    }
    final dt = (_t - fr.lastT).clamp(0.0, 0.05).toDouble();
    fr.lastT = _t;
    if (_t >= fr.delayUntil) {
      final dur = n > 14 ? 0.45 : 0.75;
      fr.p = (fr.p + (wantFold ? -dt : dt) / dur).clamp(0.0, 1.0).toDouble();
    }
    return fr;
  }

  /// شفافیتِ قدم‌زن: بعد از انجام، نرم به حالتِ کم‌رنگ می‌رود
  double _doneWalkerOp(ActionNode a, String tk) {
    if (!nodeFinished(a)) return 1.0;
    final t0 = _doneBurstAt[a.id];
    if (t0 == null) return _kDoneWalkerFade;
    final p = ((_t - t0 - 0.5) / 0.6).clamp(0.0, 1.0).toDouble();
    return _l(1.0, _kDoneWalkerFade, p * p * (3 - 2 * p));
  }

  /// این شاخه و همه‌ی زیرشاخه‌هایش در روزِ [tk] انجام شده‌اند؟
  bool _subtreeDone(ActionNode n, String tk) =>
      nodeFinished(n) &&
      _visibleActs(n.children).every((k) => _subtreeDone(k, tk));

  /// تعدادِ گره‌های «تمام‌شده» در فرزندان
  int _countFinished(List<ActionNode> list) {
    var c = 0;
    for (final n in list) {
      c += (nodeFinished(n) ? 1 : 0) + _countFinished(_visibleActs(n.children));
    }
    return c;
  }

  int _countVisible(List<ActionNode> list) {
    var c = 0;
    for (final n in list) {
      c += 1 + _countVisible(_visibleActs(n.children));
    }
    return c;
  }

  /// دکمه‌ی پنهان/نمایشِ کامل هدف: روی خط «من ← هدف»، کمی بیرون از دایره‌ی «من».
  /// هدفِ پنهان فقط به یک نگین کم‌رنگ با اسمش تبدیل می‌شود؛ با یک تپ برمی‌گردد.
  void _hideBtn(Canvas canvas, Goal g, Color tc) {
    final me = state.me;
    final dx = g.x - me.x, dy = g.y - me.y;
    final len = math.max(math.sqrt(dx * dx + dy * dy), 1.0);
    // هدفِ پنهان همیشه نگین بازگشت دارد؛ برای هدفِ باز، فقط وقتی جا هست
    if (!_isHidden(g) && len < me.radius + 60) return;
    final k = (0.6 / (cam.scale <= 0 ? 1.0 : cam.scale)).clamp(1.0, 3.0).toDouble();
    final br = 11.0 * k;
    final dist = me.radius + 16 + br;
    final c = Offset(me.x + dx / len * dist, me.y + dy / len * dist);
    final col = hexColor(g.color, hexColor(kPalette[0]));
    final hidden = _isHidden(g);
    hits.add(HitEntry(
        type: 'goalHide',
        id: g.id,
        kind: HitKind.handle,
        center: c,
        radius: br + 7));
    _pts..add(c.translate(-br, -br))..add(c.translate(br, br));

    canvas.drawCircle(c, br,
        Paint()..color = isDark ? const Color(0xE612142A) : const Color(0xF2FFFFFF));
    canvas.drawCircle(
        c,
        br,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * k.clamp(1.0, 1.6)
          ..color = withOp(col, hidden ? 0.55 : 0.95));
    // چشم
    final w = br * 0.55, h = br * 0.34;
    final ink = withOp(hidden ? tc : col, hidden ? 0.7 : 1.0);
    final sw = 1.6 * k.clamp(1.0, 1.6);
    final eye = Path()
      ..moveTo(c.dx - w, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - h * 2, c.dx + w, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + h * 2, c.dx - w, c.dy);
    final sp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    canvas.drawPath(eye, sp);
    canvas.drawCircle(c, br * 0.14, Paint()..color = ink);
    if (hidden) {
      canvas.drawLine(c + Offset(-w * 0.8, h * 1.7), c + Offset(w * 0.8, -h * 1.7),
          sp..strokeWidth = sw * 1.2);
      if (g.name.isNotEmpty) {
        drawText(canvas, g.name, c.dx, c.dy + br + 10 * k,
            size: 9.5 * k,
            color: withOp(tc, 0.7),
            weight: FontWeight.w600,
            outline: 2.5);
      }
    }
  }

  Goal? _goalOf(Ring r) {
    for (final g in state.goals) {
      if (g.id == r.goalId) return g;
    }
    return null;
  }

  void _addCircleBounds(Offset c, double r) {
    _pts..add(c.translate(-r, -r))..add(c.translate(r, r));
  }

  // ───────────────────────── هاله ─────────────────────────

  void _halo(Canvas canvas, Offset c, Color color, double r, double pf,
      String? freqKey) {
    final f = kFreqBands[freqKey] ?? kFreqBands['alpha']!;
    final base = f.speed;
    double tri(double dur) {
      final p = (_t / dur) % 1.0;
      return p < 0.5 ? p * 2 : (1 - p) * 2;
    }

    final blur =
        cam.scale < 0.3 ? null : const MaskFilter.blur(BlurStyle.normal, 4);
    final to = tri(base * 1.35);
    canvas.drawCircle(c, _l(r * 1.7 * pf, r * 2.2 * pf, to),
        Paint()
          ..color = withOp(color, _l(0.07, 0.16, to))
          ..maskFilter = blur);
    final tm = tri(base);
    canvas.drawCircle(c, _l(r * 1.25 * pf, r * 1.55 * pf, tm),
        Paint()
          ..color = withOp(color, _l(0.13, 0.24, tm))
          ..maskFilter = blur);
    final ti = tri(base * 0.8);
    canvas.drawCircle(
        c,
        _l(r * 0.88 * pf, r * 1.08 * pf, ti),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = withOp(color, _l(0.45, 0.75, ti)));
  }

  void _aura(Canvas canvas, Offset c, double r, UserFreq u) {
    final band = kFreqBands[u.band]!;
    final col = hexColor(band.color);
    final glowR = r * (1.6 + u.progress * 0.9);
    final glowOp = 0.15 + u.progress * 0.25;
    canvas.drawCircle(c, glowR, Paint()..color = withOp(col, glowOp));
    canvas.drawCircle(c, glowR * 0.6,
        Paint()..color = withOp(Colors.white, glowOp * 0.55));
    final dur = band.speed * 1.4;
    final op = 0.35 + u.progress * 0.45;
    for (var i = 0; i < 3; i++) {
      final local = _t - i * band.speed / 3;
      if (local < 0) continue;
      final p = (local % dur) / dur;
      canvas.drawCircle(
          c,
          _l(r * 1.15, r * 3.2, p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 + u.progress * 1.6
            ..color = withOp(col, op * (1 - p)));
    }
  }

  void _circleImage(Canvas canvas, Offset c, double r, ui.Image im) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(center: c, radius: r),
        image: im,
        fit: BoxFit.cover);
    canvas.restore();
  }

  /// ایموجی(ها)ی کوچک روی گوشه‌ی بالا-راستِ یک دایره‌ی عکس/GIF.
  /// تا ۳ ایموجی کنار هم در یک کپسول مرتب نشان داده می‌شود؛
  /// لبه‌ی راستِ کپسول همان‌جای نشان تک‌ایموجی می‌ماند و به سمت داخل بزرگ می‌شود.
  /// نوشته‌ی آزاد (چند کلمه) به‌صورت چندخطی؛ [maxW] حداکثر عرض هر خط
  List<TextPainter> _wrapLines(
      String text, double fs, double maxW, Color col, FontWeight w,
      [String? ff]) {
    final words = text.trim().split(RegExp(r'\s+'));
    final lines = <String>[];
    var cur = '';
    for (final wd in words) {
      final cand = cur.isEmpty ? wd : '$cur $wd';
      if (cur.isNotEmpty && textCache.get(cand, fs, col, w, fontFamily: ff).width > maxW) {
        lines.add(cur);
        cur = wd;
      } else {
        cur = cand;
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    return [for (final l in lines) textCache.get(l, fs, col, w, fontFamily: ff)];
  }

  /// نوشته‌ی آزاد داخل دایره‌ای به شعاع [r]؛ اگر زیاد باشد کوچک‌تر می‌شود
  void _fitTextInCircle(
      Canvas canvas, Offset c, double r, String text, Color col,
      [String? ff]) {
    var fs = r * 0.75;
    var tps = <TextPainter>[];
    for (var i = 0; i < 16; i++) {
      tps = _wrapLines(text, fs, r * 1.7, col, FontWeight.w600, ff);
      final h = tps.fold<double>(0, (a, t) => a + t.height);
      final mw = tps.fold<double>(0, (a, t) => math.max(a, t.width));
      if ((h <= r * 1.6 && mw <= r * 1.75) || fs < 5) break;
      fs *= 0.85;
    }
    final total = tps.fold<double>(0, (a, t) => a + t.height);
    var y = c.dy - total / 2;
    for (final t in tps) {
      t.paint(canvas, Offset(c.dx - t.width / 2, y));
      y += t.height;
    }
  }

  /// نشانِ نوشته‌ی آزاد گوشه‌ی بالا-راست (کپسولِ چندخطی، رشد به چپ/پایین)
  void _textBadge(Canvas canvas, Offset c, double r, String text,
      [double k = 1.0, String? ff]) {
    final br = math.max(9.0, r * 0.46) * k;
    final fs = br * 0.95;
    final bc = c + Offset(r * 0.72, -r * 0.72);
    final tps = _wrapLines(text, fs, math.max(r * 3.2, 90.0),
        const Color(0xFF000000), FontWeight.w600, ff);
    if (tps.isEmpty) return;
    final pad = br * 0.4;
    final maxLine = tps.fold<double>(0, (a, t) => math.max(a, t.width));
    final textH = tps.fold<double>(0, (a, t) => a + t.height);
    final w = maxLine + pad * 2;
    final h = math.max(br * 2, textH + pad);
    final rect = Rect.fromLTWH(bc.dx + br - w, bc.dy - br, w, h);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(math.min(br, h / 2)));
    canvas.drawRRect(rr, Paint()..color = withOp(const Color(0xFFFFFFFF), 0.92));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = withOp(const Color(0xFF000000), 0.18));
    var y = rect.top + (h - textH) / 2;
    for (final t in tps) {
      t.paint(canvas, Offset(rect.center.dx - t.width / 2, y));
      y += t.height;
    }
  }

  static final RegExp _kTextChar = RegExp(r'[\p{L}\p{N}\p{P}\p{Z}]', unicode: true);

  /// ایموجی/نوشته‌ی انیمیشن (وقتی عکس نیست): ایموجی‌ها کنار هم در یک ردیفِ
  /// فاصله‌دار، نوشته در خط جدا (زیر ایموجی‌ها) تا قاطی و شلوغ نشوند.
  void _walkerGlyphs(Canvas canvas, Offset c, double r, String text, double k,
      String? ff) {
    final emojis = <String>[];
    final buf = StringBuffer();
    for (final ch in text.characters) {
      if (ch.trim().isEmpty) {
        buf.write(' ');
      } else if (_kTextChar.hasMatch(ch)) {
        buf.write(ch);
      } else {
        emojis.add(ch);
      }
    }
    final label = buf.toString().trim();
    const black = Color(0xFF000000);
    final base = r * 1.9 * k;

    // فقط نوشته: مثل قبل، یک خط
    if (emojis.isEmpty) {
      final tp = textCache.get(label, base, black, FontWeight.w400, fontFamily: ff);
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      return;
    }

    // اندازه‌ی ایموجی‌ها: هرچه تعداد بیشتر، کمی کوچک‌تر تا ردیف از حد بیرون نزند
    final n = emojis.length;
    final efs = base * (n == 1 ? 1.0 : (n == 2 ? 0.8 : (n == 3 ? 0.68 : 0.56)));
    final etps = [
      for (final e in emojis) textCache.get(e, efs, black, FontWeight.w400)
    ];
    final gap = efs * 0.22;
    var rowW = gap * (etps.length - 1);
    var rowH = 0.0;
    for (final t in etps) {
      rowW += t.width;
      rowH = math.max(rowH, t.height);
    }

    TextPainter? ttp;
    if (label.isNotEmpty) {
      // نوشته کمی کوچک‌تر از ایموجی‌ها، تا همه با هم جا بگیرند
      ttp = textCache.get(label, base * 0.55, black, FontWeight.w600,
          fontFamily: ff);
    }
    final lineGap = ttp == null ? 0.0 : efs * 0.12;
    final totalH = rowH + lineGap + (ttp?.height ?? 0);
    var y = c.dy - totalH / 2;
    var x = c.dx - rowW / 2;
    for (final t in etps) {
      t.paint(canvas, Offset(x, y + (rowH - t.height) / 2));
      x += t.width + gap;
    }
    if (ttp != null) {
      ttp.paint(canvas, Offset(c.dx - ttp.width / 2, y + rowH + lineGap));
    }
  }

  /// ایموجی‌های انیمیشنِ دارای عکس: بدون کادر سفید و با همان چیدمانِ «روی‌هم»ِ آیکونِ هدف
  /// (اولی جلو و بزرگ‌تر، بقیه پشتش)، گوشه‌ی بالا-راستِ عکس.
  void _walkerEmojiCluster(Canvas canvas, Offset c, double r, String emoji,
      [double k = 1.0, String? ff]) {
    final text = emoji.trim();
    if (text.isEmpty) return;
    final rr = math.max(11.0, r * 0.56) * k;
    final bc = c + Offset(r * 0.78, -r * 0.78);
    const black = Color(0xFF000000);
    if (isTextIcon(text)) {
      drawText(canvas, text, bc.dx, bc.dy,
          size: rr * 0.95,
          color: black,
          weight: FontWeight.w600,
          outline: 3,
          vCenter: true,
          fontFamily: ff);
      return;
    }
    final cs = text.characters.where((e) => e.trim().isNotEmpty).take(3).toList();
    if (cs.isEmpty) return;
    if (cs.length == 1) {
      drawText(canvas, cs.first, bc.dx, bc.dy,
          size: rr * 1.7, color: black, vCenter: true);
      return;
    }
    const slots = [
      (0.28, 0.30, 1.25),
      (-0.14, -0.34, 1.05),
      (-0.46, 0.34, 0.85),
    ];
    for (var i = cs.length - 1; i >= 0; i--) {
      drawText(canvas, cs[i], bc.dx + rr * slots[i].$1,
          bc.dy + rr * slots[i].$2,
          size: rr * slots[i].$3, color: black, vCenter: true);
    }
  }

  void _emojiBadge(Canvas canvas, Offset c, double r, String emoji,
      [double k = 1.0, String? ff]) {
    if (isTextIcon(emoji)) {
      _textBadge(canvas, c, r, emoji, k, ff);
      return;
    }
    final list = emoji.characters.where((x) => x.trim().isNotEmpty).take(3).toList();
    if (list.isEmpty) return;
    final br = math.max(9.0, r * 0.46) * k;
    final fs = br * (list.length == 1 ? 1.35 : 1.15);
    final bc = c + Offset(r * 0.72, -r * 0.72);
    if (list.length == 1) {
      canvas.drawCircle(bc, br, Paint()..color = withOp(const Color(0xFFFFFFFF), 0.92));
      canvas.drawCircle(
          bc,
          br,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = withOp(const Color(0xFF000000), 0.18));
      final tp = textCache.get(list.first, fs, const Color(0xFF000000), FontWeight.w400);
      tp.paint(canvas, bc - Offset(tp.width / 2, tp.height / 2));
      return;
    }
    final tps = [
      for (final e in list)
        textCache.get(e, fs, const Color(0xFF000000), FontWeight.w400)
    ];
    final gap = br * 0.12;
    final pad = br * 0.32;
    var inner = gap * (tps.length - 1);
    for (final t in tps) {
      inner += t.width;
    }
    final w = inner + pad * 2;
    final h = br * 2;
    // لبه‌ی راست ثابت، رشد به سمت چپ
    final cx = bc.dx + br - w / 2;
    final rect = Rect.fromCenter(center: Offset(cx, bc.dy), width: w, height: h);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(br));
    canvas.drawRRect(rr, Paint()..color = withOp(const Color(0xFFFFFFFF), 0.92));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = withOp(const Color(0xFF000000), 0.18));
    var x = rect.left + pad;
    for (final t in tps) {
      t.paint(canvas, Offset(x, bc.dy - t.height / 2));
      x += t.width + gap;
    }
  }

  /// دکمه‌ی پلی/توقف + چیپِ تعداد تکرار (۱× ۲× ۳× ∞) کنار گرهٔ دارای صدا.
  /// [dir] = سمتِ چیپ نسبت به دکمه (+۱ راست، -۱ چپ)
  void _voiceBtn(Canvas canvas, Offset c, String type, String id,
      Map<String, dynamic> extra, String key,
      {double dir = 1, double r = 11}) {
    final v = extra[key];
    if (v is! String || v.isEmpty) return;
    final pid = '$type:$id:$key';
    final on = MapVoicePlayer.instance.playing.value == pid;
    const green = Color(0xFF178A7C);
    const deep = Color(0xFF0F5B53);
    final rep = MapVoicePlayer.repeatOf(extra, key);
    final label = rep == 0 ? '∞' : '${toFa(rep)}×';

    // چیپ تکرار
    final chip = Rect.fromCenter(
        center: c + Offset(dir * (r + 17), 0), width: 30, height: 20);
    final cr = RRect.fromRectAndRadius(chip, const Radius.circular(10));
    canvas.drawRRect(cr, Paint()..color = const Color(0xF2FFFFFF));
    canvas.drawRRect(
        cr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = green);
    drawText(canvas, label, chip.center.dx, chip.center.dy + 4.2,
        size: rep == 0 ? 15 : 11, color: deep, weight: FontWeight.w800);
    hits.add(HitEntry(
        type: 'voiceRepeat',
        id: pid,
        kind: HitKind.handle,
        rect: chip,
        payload: extra,
        voiceKey: key));

    // دکمه‌ی پلی / توقف
    canvas.drawCircle(c, r + 1.6, Paint()..color = const Color(0xF2FFFFFF));
    canvas.drawCircle(c, r, Paint()..color = on ? deep : green);
    final ink = Paint()..color = Colors.white;
    if (on) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: r * 0.75, height: r * 0.75),
              const Radius.circular(1.5)),
          ink);
    } else {
      final tri = Path()
        ..moveTo(c.dx - r * 0.28, c.dy - r * 0.5)
        ..lineTo(c.dx + r * 0.52, c.dy)
        ..lineTo(c.dx - r * 0.28, c.dy + r * 0.5)
        ..close();
      canvas.drawPath(tri, ink);
    }
    hits.add(HitEntry(
        type: 'voicePlay',
        id: pid,
        kind: HitKind.handle,
        center: c,
        radius: r + 4,
        payload: extra,
        voiceKey: key));
  }

  /// دکمه‌ی ویدیو (پخش روی نقشه) کنار گرهٔ دارای ویدیو
  void _videoBtn(Canvas canvas, Offset c, String type, String id,
      Map<String, dynamic> extra, String key,
      {double r = 11}) {
    final v = extra[key];
    if (v is! String || v.isEmpty) return;
    final pid = '$type:$id:$key';
    final on = MapVideoPlayer.instance.current.value?.id == pid;
    const blue = Color(0xFF5B5BD6);
    const deep = Color(0xFF3C3CA8);
    canvas.drawCircle(c, r + 1.6, Paint()..color = const Color(0xF2FFFFFF));
    canvas.drawCircle(c, r, Paint()..color = on ? deep : blue);
    final ink = Paint()..color = Colors.white;
    final body = Rect.fromCenter(
        center: c + Offset(-r * 0.12, 0), width: r * 0.95, height: r * 0.7);
    canvas.drawRRect(
        RRect.fromRectAndRadius(body, Radius.circular(r * 0.14)), ink);
    final lens = Path()
      ..moveTo(body.right + r * 0.06, c.dy - r * 0.12)
      ..lineTo(body.right + r * 0.36, c.dy - r * 0.3)
      ..lineTo(body.right + r * 0.36, c.dy + r * 0.3)
      ..lineTo(body.right + r * 0.06, c.dy + r * 0.12)
      ..close();
    canvas.drawPath(lens, ink);
    hits.add(HitEntry(
        type: 'videoPlay',
        id: pid,
        kind: HitKind.handle,
        center: c,
        radius: r + 4,
        payload: extra,
        voiceKey: key));
  }

  // ───────────────────────── من ─────────────────────────

  void _drawMe(Canvas canvas, Color tc) {
    final me = state.me;
    final c = Offset(me.x, me.y);
    final r = me.radius;
    final u = userFrequencyState(state);
    final band = kFreqBands[u.band]!;
    if (_haloOn(me.extra, false)) {
      _aura(canvas, c, r, u);
      _halo(canvas, c, hexColor(band.color), r, 1, u.band);
    }
    final meColor = hexColor(me.color.isEmpty ? band.color : me.color);
    _addCircleBounds(c, r);
    hits.add(HitEntry(
        type: 'me', id: '', kind: HitKind.node, center: c, radius: r));
    _voiceBtn(canvas, c + Offset((r + 16) * 0.7071, -(r + 16) * 0.7071), 'me',
        'me', me.extra, 'voice');
    _videoBtn(canvas, c + Offset(-(r + 16) * 0.7071, -(r + 16) * 0.7071), 'me',
        'me', me.extra, 'video');

    final meFont = _fontOf(me.extra);
    final meEmoji = (me.extra['emoji'] is String)
        ? (me.extra['emoji'] as String).trim()
        : '';
    if (meEmoji.isNotEmpty && me.images.isEmpty) {
      // ایموجیِ «من» (وقتی عکس نیست؛ اگر عکس هم باشد هر دو نشان داده می‌شوند) — همه‌ی ایموجی‌ها
      if (isTextIcon(meEmoji)) {
        _fitTextInCircle(canvas, c, r, meEmoji, const Color(0xFF000000), meFont);
      } else {
        final tp = textCache.get(
            meEmoji, r * 1.9, const Color(0xFF000000), FontWeight.w400);
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
      if (me.name.isNotEmpty) {
        final lr = drawText(canvas, me.name, c.dx + me.labelDX,
            c.dy + r * 1.05 + me.labelDY,
            size: me.labelSize ?? _labelSize('me'),
            color: tc,
            weight: FontWeight.w700,
            outline: 3,
            fontFamily: meFont);
        hits.add(HitEntry(type: 'me', id: '', kind: HitKind.label, rect: lr));
      }
    } else if (me.images.isEmpty) {
      canvas.drawCircle(c, r, Paint()..color = meColor);
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..color = meColor);
      final s = r * 0.42, cy2 = c.dy - r * 0.12;
      final pp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = withOp(tc, 0.85);
      drawDashed(
          canvas,
          Path()..addOval(Rect.fromCircle(center: Offset(c.dx, cy2), radius: s)),
          pp,
          [4, 3]);
      final lp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = withOp(tc, 0.85);
      canvas.drawLine(
          Offset(c.dx - s * 0.5, cy2), Offset(c.dx + s * 0.5, cy2), lp);
      canvas.drawLine(
          Offset(c.dx, cy2 - s * 0.5), Offset(c.dx, cy2 + s * 0.5), lp);
      drawText(canvas, me.name, c.dx, c.dy + r * 0.62,
          size: math.max(8, _fs() - 4),
          color: tc,
          weight: FontWeight.w700,
          fontFamily: meFont);
    } else {
      final im = images.get(me.images.first.src, animate: true, t: _t);
      if (im != null) {
        _circleImage(canvas, c, r, im);
      } else {
        canvas.drawCircle(c, r, Paint()..color = withOp(meColor, 0.4));
      }
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..color = meColor);
      if (meEmoji.isNotEmpty) _emojiBadge(canvas, c, r, meEmoji, 1.0, meFont);
      final lr = drawText(canvas, me.name, c.dx + me.labelDX,
          c.dy + 6 + me.labelDY,
          size: me.labelSize ?? _labelSize('me'),
          color: tc,
          weight: FontWeight.w700,
          outline: 3,
          fontFamily: meFont);
      if (me.name.isNotEmpty) {
        hits.add(
            HitEntry(type: 'me', id: '', kind: HitKind.label, rect: lr));
      }
    }
  }

  void _nodeIcon(Canvas canvas, Offset c, double r0, List<ImageItem> imgs,
      String icon, Color color, double iconScale, Color tc) {
    final r = r0 * iconScale;
    if (imgs.isNotEmpty && imgs.first.src.isNotEmpty) {
      final im = images.get(imgs.first.src, animate: true, t: _t);
      if (im != null) {
        _circleImage(canvas, c, r, im);
        canvas.drawCircle(
            c,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = withOp(color, 0.55));
      } else {
        canvas.drawCircle(c, r, Paint()..color = withOp(color, 0.4));
      }
      if (icon.trim().isNotEmpty) _emojiBadge(canvas, c, r, icon);
    } else if (icon.trim().isNotEmpty && isTextIcon(icon)) {
      _fitTextInCircle(canvas, c, r, icon.trim(), tc);
    } else if (icon.trim().isNotEmpty) {
      final cs = icon.characters.where((e) => e.trim().isNotEmpty).take(3).toList();
      if (cs.length <= 1) {
        drawText(canvas, cs.isEmpty ? icon : cs.first, c.dx, c.dy,
            size: r * 1.7, color: tc, vCenter: true);
      } else {
        // چند ایکون «روی‌هم»: اولی جلو و بزرگ‌تر، بقیه پشتش (مثل مغز)
        const slots = [
          (0.28, 0.30, 1.25),
          (-0.14, -0.34, 1.05),
          (-0.46, 0.34, 0.85),
        ];
        for (var i = cs.length - 1; i >= 0; i--) {
          drawText(canvas, cs[i], c.dx + r * slots[i].$1,
              c.dy + r * slots[i].$2,
              size: r * slots[i].$3, color: tc, vCenter: true);
        }
      }
    } else {
      canvas.drawCircle(c, r, Paint()..color = withOp(color, 0.85));
    }
  }

  // ───────────────────────── هدف ─────────────────────────

  void _drawGoal(Canvas canvas, Goal g, Color tc) {
    final r0 = g.radius;
    final c = Offset(g.x, g.y);
    final col = hexColor(g.color, hexColor(kPalette[0]));
    if (_haloOn(g.extra, false)) {
      _halo(canvas, c, col, r0 * math.max(1.0, g.iconScale), 1, g.freq);
    }
    _nodeIcon(canvas, c, r0, g.images, g.icon, col, g.iconScale, tc);
    final r = r0 * g.iconScale;
    _goalProgressRing(canvas, g, c, math.max(r, r0), col);
    _addCircleBounds(c, r);
    hits.add(HitEntry(
        type: 'goal',
        id: g.id,
        kind: HitKind.node,
        center: c,
        radius: math.max(r, r0) + 8));
    {
      final d = math.max(r, r0) + 22;
      _voiceBtn(canvas, c + Offset(d * 0.7071, -d * 0.7071), 'goal', g.id,
          g.extra, 'voice');
      _videoBtn(canvas, c + Offset(-d * 0.7071, -d * 0.7071), 'goal', g.id,
          g.extra, 'video');
    }

    var off = -(r0 + 22);
    if (r > r0) off += (off < 0 ? -1 : 1) * (r - r0);
    final gtc = _tcOf(g.extra, tc);
    final lr = drawText(
        canvas, g.name, c.dx + g.labelDX, c.dy + off + g.labelDY,
        size: g.labelSize ?? _labelSize('goal'),
        color: gtc,
        weight: FontWeight.w600,
        outline: 3,
        fontFamily: _fontOf(g.extra));
    if (g.name.isNotEmpty) {
      hits.add(HitEntry(
          type: 'goal', id: g.id, kind: HitKind.label, rect: lr));
    }

    if ((_showDateOf(g.extra) || _showTimeOf(g.extra)) &&
        g.createdAt != null &&
        g.createdAt! > 0) {
      final stamp = _formatStamp(g.createdAt!, g.extra);
      if (stamp.isNotEmpty) {
        drawText(
            canvas,
            stamp,
            c.dx + g.labelDX,
            c.dy + off + g.labelDY + (g.labelSize ?? _labelSize('goal')) * 1.15,
            size: math.max(9, (g.labelSize ?? _labelSize('goal')) * 0.62),
            color: withOp(gtc, 0.6),
            weight: FontWeight.w400,
            outline: 2);
      }
    }

    _goalShutter(canvas, g, col, tc, r);

    // رسیدن به هدف: میوه‌ی طلاییِ آیکونِ هدف + بارانِ گلبرگ (فقط لحظه‌ی رسیدن)
    if (g.reached) {
      if (_reachSeen[g.id] == false) {
        _reachAt[g.id] = _t;
        HapticFeedback.mediumImpact();
      }
      _reachSeen[g.id] = true;
      _goalFruit(canvas, g, c, math.max(r, r0));
      final t0 = _reachAt[g.id];
      if (t0 != null) {
        if (_t - t0 > 2.8) {
          _reachAt.remove(g.id);
        } else {
          _petalBurst(canvas, c, math.max(r, r0), _t - t0);
        }
      }
    } else {
      _reachSeen[g.id] = false;
      _reachAt.remove(g.id);
    }
  }

  /// میوه‌ی طلاییِ هدفِ رسیده‌شده؛ آیکونِ خودِ هدف داخلش است
  void _goalFruit(Canvas canvas, Goal g, Offset c, double r) {
    final fr = (r * 0.55).clamp(12.0, 24.0).toDouble();
    final fc = c + Offset(r + fr * 0.9, fr * 0.2);
    final pulse = 1 + math.sin(_t * 2.0) * 0.04;
    canvas.drawCircle(
        fc,
        fr * 1.9,
        Paint()
          ..color = const Color(0x55FFC83D)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    // دمگل و برگ
    canvas.drawLine(fc + Offset(0, -fr * 0.9), fc + Offset(fr * 0.15, -fr * 1.35),
        Paint()
          ..color = const Color(0xFF8D6E63)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
    final lf = fc + Offset(fr * 0.15, -fr * 1.3);
    canvas.drawPath(
        Path()
          ..moveTo(lf.dx, lf.dy)
          ..quadraticBezierTo(lf.dx + fr * 0.8, lf.dy - fr * 0.15,
              lf.dx + fr * 0.75, lf.dy + fr * 0.45)
          ..quadraticBezierTo(lf.dx + fr * 0.2, lf.dy + fr * 0.5, lf.dx, lf.dy),
        Paint()..color = const Color(0xFF43A047));
    final br = fr * pulse;
    canvas.drawCircle(
        fc,
        br,
        Paint()
          ..shader = ui.Gradient.radial(
              fc + Offset(-br * 0.3, -br * 0.3),
              br * 1.4,
              const [Color(0xFFFFF1A8), Color(0xFFFFC83D), Color(0xFFD9971C)],
              const [0.0, 0.55, 1.0]));
    canvas.drawCircle(
        fc,
        br,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFB77B12));
    if (g.icon.trim().isNotEmpty) {
      _drawEmoji(canvas, fc, 0, br * 1.05, Colors.black, g.icon);
    } else {
      _drawEmoji(canvas, fc, 0, br * 1.05, Colors.white, '★');
    }
    canvas.drawOval(
        Rect.fromCenter(
            center: fc + Offset(-br * 0.45, -br * 0.5),
            width: br * 0.38,
            height: br * 0.22),
        Paint()..color = const Color(0xAAFFFFFF));
  }

  /// بارانِ گلبرگ دور هدف در لحظه‌ی رسیدن (۲٫۸ ثانیه)
  void _petalBurst(Canvas canvas, Offset c, double r, double el) {
    const cols = [
      Color(0xFFF48FB1),
      Color(0xFFFFFFFF),
      Color(0xFFFFD54F),
      Color(0xFFCE93D8),
      Color(0xFFFF8A65),
    ];
    final p = (el / 2.8).clamp(0.0, 1.0).toDouble();
    final e = 1 - (1 - p) * (1 - p);
    for (var i = 0; i < 28; i++) {
      final ang = i * 2.399963;
      final dist = r * (1.3 + (i % 5) * 0.55) * e;
      final x = c.dx + math.cos(ang) * dist;
      final y = c.dy + math.sin(ang) * dist * 0.8 + p * p * 80;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(ang + p * 5);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 4.2, height: 8),
          Paint()..color = cols[i % cols.length].withValues(alpha: (1 - p) * 0.9));
      canvas.restore();
    }
  }

  /// شاخه‌ی گل و برگ سرِ شاخه‌ی تمام‌شده (جهتش ادامه‌ی شاخه است).
  /// ترکیبِ برگ و گل: بعضی فقط برگ، بعضی برگ + گل (پنج‌گلبرگ، خوشه، غنچه، بابونه).
  /// نوع و رنگ از روی id ثابت است. p: ۰ → ۱ انیمیشنِ شکفتن
  static void _sprig(Canvas canvas, Offset tip, double dir, double r, String id,
      double p,
      {bool budOnly = false, bool flower = false}) {
    var h = 7;
    for (final u in id.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    const petals = [
      Color(0xFFF48FB1),
      Color(0xFFFFFFFF),
      Color(0xFFFFD54F),
      Color(0xFFCE93D8),
      Color(0xFFFF8A65),
      Color(0xFF90CAF9),
    ];
    const greens = [
      [Color(0xFF2E7D32), Color(0xFF81C784)],
      [Color(0xFF388E3C), Color(0xFFA5D66B)],
      [Color(0xFF1B7F4B), Color(0xFF6FCF97)],
    ];
    // flower: غنچه‌ای که بعد از ۳ روزِ پشت‌سرهم گل شده؛ شکل/رنگ تصادفی (ثابت)،
    // و تصادفی با برگ یا بی‌برگ
    final kind = flower ? 2 + h % 4 : h % 6;
    final flowerLeaves = !flower || ((h ~/ 216) % 2 == 0);
    final pc = petals[(h ~/ 6) % petals.length];
    final gc = greens[(h ~/ 36) % greens.length];
    final k = Curves.easeOutBack.transform(p.clamp(0.0, 1.0).toDouble());
    if (k <= 0.02) return;

    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(dir + math.pi / 2); // «بالا» (-y) = ادامه‌ی شاخه
    canvas.scale(k);
    final R = r;

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0x33000000);

    void leaf(double y, double ang, double len, double wid) {
      canvas.save();
      canvas.translate(0, y);
      canvas.rotate(ang);
      final lp = Path()
        ..moveTo(0, 0)
        ..cubicTo(wid, -len * 0.25, wid * 0.8, -len * 0.8, 0, -len)
        ..cubicTo(-wid * 0.8, -len * 0.8, -wid, -len * 0.25, 0, 0);
      canvas.drawPath(
          lp,
          Paint()
            ..shader = ui.Gradient.linear(
                Offset.zero, Offset(0, -len), [gc[0], gc[1]]));
      canvas.drawPath(lp, edge);
      canvas.drawLine(
          Offset.zero,
          Offset(0, -len * 0.82),
          Paint()
            ..color = const Color(0x55FFFFFF)
            ..strokeWidth = 0.7);
      canvas.restore();
    }

    void petal(double ang, double len, double wid, Color col,
        [Offset at = Offset.zero]) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(ang);
      final pp = Path()
        ..moveTo(0, 0)
        ..cubicTo(wid * 0.9, -len * 0.15, wid * 0.7, -len * 0.95, 0, -len)
        ..cubicTo(-wid * 0.7, -len * 0.95, -wid * 0.9, -len * 0.15, 0, 0);
      canvas.drawPath(
          pp,
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, Offset(0, -len), [
              Color.lerp(col, const Color(0xFFFFA000), 0.3)!,
              col,
            ]));
      canvas.drawPath(pp, edge);
      canvas.restore();
    }

    void blossom(Offset c, double rr, int n, Color col, Color center,
        {double rot = 0, double wid = 0.8}) {
      for (var i = 0; i < n; i++) {
        petal(rot + i * 2 * math.pi / n, rr, rr * wid, col, c);
      }
      canvas.drawCircle(c, rr * 0.26, Paint()..color = center);
      canvas.drawCircle(c + Offset(-rr * 0.07, -rr * 0.07), rr * 0.09,
          Paint()..color = const Color(0x88FFFFFF));
    }

    void bud(Offset c, double ang, double rr, Color col) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(ang);
      final b = Rect.fromCenter(
          center: Offset(0, -rr * 0.5), width: rr * 0.7, height: rr * 1.1);
      canvas.drawOval(b, Paint()..color = col);
      canvas.drawOval(b, edge);
      canvas.drawPath(
          Path()
            ..moveTo(-rr * 0.32, -rr * 0.05)
            ..lineTo(0, rr * 0.3)
            ..lineTo(rr * 0.32, -rr * 0.05)
            ..close(),
          Paint()..color = gc[0]);
      canvas.restore();
    }

    if (budOnly) {
      // غنچه‌ی واقعی: کاسبرگ سبز، گلبرگ‌های روی‌هم‌افتاده و نوکِ تیز.
      // به‌صورت تصادفی (ثابت برای هر id): بی‌برگ، تک‌برگ یا دوبرگ
      // هر غنچه ظاهرِ مخصوصِ خودش را دارد (ثابت برای هر id): رنگ، اندازه، شکل
      var h2 = (h % 2147483646) + 1;
      double rnd() {
        h2 = (h2 * 48271) % 2147483647; // بدون سرریز (سازگار با وب)
        return h2 / 2147483647.0;
      }
      rnd();
      rnd();
      rnd();
      final Rb = R * (0.75 + rnd() * 0.65); // اندازه: ۰٫۷۵ تا ۱٫۴ برابر
      final bc = HSLColor.fromAHSL(
              1.0, rnd() * 360, 0.5 + rnd() * 0.35, 0.56 + rnd() * 0.16)
          .toColor();
      final wK = 0.46 + rnd() * 0.38; // باریک تا چاق
      final hK = 1.15 + rnd() * 0.85; // کوتاه تا کشیده
      final belly = 0.8 + rnd() * 0.35; // گردی بدنه
      final lc = (h ~/ 216) % 3; // تعداد برگ: ۰، ۱ یا ۲
      final side = ((h ~/ 648) & 1) == 0 ? 1.0 : -1.0;
      final lean = (((h ~/ 1296) % 5) - 2) * 0.05; // کمی خمیدگی
      final dark = Color.lerp(bc, const Color(0xFF000000), 0.28)!;
      final light = Color.lerp(bc, const Color(0xFFFFFFFF), 0.45)!;

      // ساقه
      canvas.drawLine(
          Offset.zero,
          Offset(0, -Rb * 0.8),
          Paint()
            ..color = gc[0]
            ..strokeWidth = math.max(1.1, Rb * 0.15)
            ..strokeCap = StrokeCap.round);
      // برگ‌ها
      if (lc >= 1) leaf(-Rb * 0.12, -0.95 * side, Rb * 0.95, Rb * 0.34);
      if (lc == 2) leaf(-Rb * 0.12, 0.95 * side, Rb * 0.85, Rb * 0.30);

      canvas.save();
      canvas.translate(0, -Rb * 0.7);
      canvas.rotate(lean);
      final w = Rb * wK;
      final hh = Rb * hK;
      // بدنه‌ی غنچه: قطره‌ی کشیده با نوکِ تیز
      final body = Path()
        ..moveTo(0, 0)
        ..cubicTo(w * 1.05 * belly, -hh * 0.12, w * 0.95 * belly, -hh * 0.62, 0, -hh)
        ..cubicTo(-w * 0.95 * belly, -hh * 0.62, -w * 1.05 * belly, -hh * 0.12, 0, 0)
        ..close();
      canvas.drawPath(
          body,
          Paint()
            ..shader = ui.Gradient.linear(
                Offset(-w, 0), Offset(w, -hh * 0.5), [light, bc, dark],
                [0.0, 0.45, 1.0]));
      canvas.drawPath(body, edge);
      // درزِ گلبرگ‌های روی‌هم‌افتاده
      final seam = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, Rb * 0.07)
        ..strokeCap = StrokeCap.round
        ..color = withOp(dark, 0.55);
      canvas.drawPath(
          Path()
            ..moveTo(-w * 0.1, -hh * 0.06)
            ..quadraticBezierTo(w * 0.62, -hh * 0.5, w * 0.04, -hh * 0.96),
          seam);
      canvas.drawPath(
          Path()
            ..moveTo(w * 0.1, -hh * 0.06)
            ..quadraticBezierTo(-w * 0.55, -hh * 0.45, -w * 0.12, -hh * 0.8),
          seam);
      // برق
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(-w * 0.42, -hh * 0.5),
              width: w * 0.22,
              height: hh * 0.32),
          Paint()..color = const Color(0x55FFFFFF));
      // کاسبرگ‌های سبز دورِ پایه‌ی غنچه
      Path sepal(double dx, double ang, double len, double wid) {
        return Path()
          ..moveTo(dx, 0)
          ..quadraticBezierTo(dx + wid * math.cos(ang), -len * 0.45,
              dx + len * 0.55 * math.sin(ang), -len)
          ..quadraticBezierTo(dx - wid * 0.2, -len * 0.5, dx, 0)
          ..close();
      }
      final sp = Paint()..color = gc[0];
      canvas.drawPath(sepal(0, -0.55, hh * 0.52, w * 0.8), sp);
      canvas.drawPath(sepal(0, 0.55, hh * 0.52, -w * 0.8), sp);
      canvas.drawPath(sepal(0, 0.0, hh * 0.36, w * 0.5), Paint()..color = gc[1]);
      canvas.restore();
      canvas.restore();
      return;
    }

    // ساقه
    canvas.drawLine(
        Offset.zero,
        Offset(0, -R * 1.05),
        Paint()
          ..color = gc[0]
          ..strokeWidth = math.max(1.2, R * 0.17)
          ..strokeCap = StrokeCap.round);

    // برگ‌ها (همه‌ی انواع برگ دارند)
    final leafOnly = kind <= 1;
    if (flowerLeaves) {
      leaf(-R * 0.25, -0.85, R * 1.15, R * 0.46);
      leaf(-R * 0.25, 0.85, R * 1.15, R * 0.46);
      leaf(-R * 0.62, -0.5, R * (leafOnly ? 1.1 : 0.9), R * 0.4);
      leaf(-R * 0.62, 0.5, R * (leafOnly ? 1.1 : 0.9), R * 0.4);
    }
    final top = Offset(0, -R * 1.15);

    switch (kind) {
      case 0: // فقط برگ: برگِ سرِ شاخه
        leaf(-R * 1.0, 0, R * 1.0, R * 0.42);
      case 1: // فقط برگ: سه‌برگه
        leaf(-R * 1.0, 0, R * 1.2, R * 0.46);
        leaf(-R * 1.0, -0.35, R * 0.9, R * 0.36);
        leaf(-R * 1.0, 0.35, R * 0.9, R * 0.36);
      case 2: // گلِ پنج‌گلبرگ
        blossom(top, R * 0.95, 5, pc, const Color(0xFFFFC107));
      case 3: // خوشه‌ی شکوفه
        blossom(top, R * 0.7, 6, Color.lerp(pc, Colors.white, 0.4)!,
            const Color(0xFFE8A33D));
        blossom(Offset(-R * 0.85, -R * 0.8), R * 0.5, 6,
            Color.lerp(pc, Colors.white, 0.55)!, const Color(0xFFE8A33D),
            rot: 0.5);
        blossom(Offset(R * 0.85, -R * 0.85), R * 0.5, 6,
            Color.lerp(pc, Colors.white, 0.55)!, const Color(0xFFE8A33D),
            rot: 0.2);
      case 4: // گلِ درشت + دو غنچه
        bud(Offset(0, -R * 0.55), -0.9, R * 0.8, pc);
        bud(Offset(0, -R * 0.55), 0.9, R * 0.8, pc);
        blossom(top, R * 1.0, 5, pc, const Color(0xFFFFC107), rot: 0.3);
      default: // بابونه
        blossom(top, R * 1.05, 9, Colors.white, const Color(0xFFFFB300),
            wid: 0.42);
    }
    canvas.restore();

    // جرقه‌های کوچک هنگامِ شکفتن
    if (p < 1.0) {
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + dir;
        final d = r * (1.3 + p * 2.0);
        canvas.drawCircle(
            tip + Offset(math.cos(a) * d, math.sin(a) * d),
            1.6,
            Paint()..color = const Color(0xFFFFC83D).withValues(alpha: 1 - p));
      }
    }
  }

  /// رسمِ گل/غنچه‌ی درخت برای باغچه (همان شکلِ نقشه)
  static void sprigAt(Canvas canvas, Offset tip, double dir, double r,
          String id, double p,
          {bool budOnly = false, bool flower = false}) =>
      _sprig(canvas, tip, dir, r, id, p, budOnly: budOnly, flower: flower);

  /// دقیقه‌های کارِ امروزِ یک شاخه (ثبت‌شده + تایمرِ در حال اجرا)
  double _plantMinutes(ActionNode a, String todayK) {
    var s = (a.time[todayK] as num?)?.toDouble() ?? 0.0;
    final ts = a.timerStart ?? 0;
    if (ts > 0) s += (DateTime.now().millisecondsSinceEpoch - ts) / 1000.0;
    return s / 60.0;
  }

  /// مجموعِ همه‌ی دقیقه‌های ثبت‌شده‌ی یک شاخه (همه‌ی روزها + تایمرِ در حال اجرا)
  double _totalMinutes(ActionNode a) {
    var s = 0.0;
    for (final v in a.time.values) {
      if (v is num && v > 0) s += v.toDouble();
    }
    final ts = a.timerStart ?? 0;
    if (ts > 0) s += (DateTime.now().millisecondsSinceEpoch - ts) / 1000.0;
    return s / 60.0;
  }

  /// تعدادِ روزهایی که این شاخه ثبت/انجام شده
  int _doneDayCount(ActionNode a) {
    final keys = <String>{...a.logs.keys, ...a.time.keys, ...a.entries.keys};
    var n = 0;
    for (final k in keys) {
      if (footDoneOn(a, k)) n++;
    }
    return n;
  }

  /// برگ، غنچه و گل روی تنه‌ی شاخه/زیرشاخه (با همان منطقِ زمانیِ گیاهِ تمرکز)
  void _trunkFlora(Canvas canvas, ActionNode a, geo.TwigGeom geom,
      geo.Cubic cub, double scale, int depth) {
    final r = 5.0 * math.max(0.55, scale);
    final poly = geom.poly;
    final running = (a.timerStart ?? 0) > 0;
    final t0 = _bloomAt[a.id];
    final bp = t0 == null ? 1.0 : ((_t - t0) / 1.2).clamp(0.0, 1.0).toDouble();
    drawTrunkFlora(
      canvas,
      pointAt: (t) => poly != null && poly.length > 1
          ? geo.polyPointAt(poly, t).pt
          : cub.at(t),
      angleAt: (t) => poly != null && poly.length > 1
          ? geo.polyPointAt(poly, t).angle
          : cub.tangent(t),
      r: r,
      id: a.id,
      minutes: _totalMinutes(a),
      doneDays: _doneDayCount(a),
      finished: nodeFinished(a),
      running: running,
      bloom: bp,
      slots: depth == 0 ? 6 : 4,
      sprig: (c, o, d, rr, i, p, fl) =>
          _sprig(c, o, d, rr, i, p, budOnly: !fl, flower: fl),
    );
  }

  /// گیاهِ تمرکز روی نوکِ شاخه: تایمر روشن = در حال رشد؛ بعد از توقف:
  /// کارِ تمام‌شده = گل، وگرنه غنچه لابه‌لای برگ و شاخه‌ها.
  void _plant(Canvas canvas, ActionNode a, Offset tip, double ang, double r,
      String todayK) {
    final running = (a.timerStart ?? 0) > 0;
    if (running) {
      _plantRunSeen[a.id] = true;
      _plantStopAt.remove(a.id);
    } else if (_plantRunSeen[a.id] == true) {
      _plantRunSeen[a.id] = false;
      _plantStopAt[a.id] = _t;
    }
    final t0 = _plantStopAt[a.id];
    final bp = t0 == null ? 1.0 : ((_t - t0) / 1.2).clamp(0.0, 1.0).toDouble();
    if (t0 != null && _t - t0 > 3.0) _plantStopAt.remove(a.id);
    drawFocusPlant(
      canvas,
      tip: tip,
      dir: ang,
      r: r,
      id: a.id,
      minutes: _plantMinutes(a, todayK),
      mode: running
          ? kPlantGrowing
          : (nodeFinished(a) ? kPlantFlowers : kPlantBuds),
      bloom: bp,
      sprig: (c, o, d, rr, i, p, fl) =>
          _sprig(c, o, d, rr, i, p, budOnly: !fl, flower: fl),
    );
  }

  /// حلقه‌ی پیشرفت دور دایره‌ی هدف؛ همان درصدِ نوار «فهرست اهداف»
  /// (مجموع وزن قدم‌ها × ۳، حداکثر ۱۰۰٪). هدفِ بدون قدم یا رسیده‌شده حلقه ندارد.
  void _goalProgressRing(
      Canvas canvas, Goal g, Offset c, double r, Color col) {
    if (g.reached || g.actions.isEmpty) return;
    final p = (sumWeight(g.actions) * 3 / 100).clamp(0.0, 1.0).toDouble();
    final rr = r + 5;
    const w = 3.2;
    canvas.drawCircle(
        c,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = withOp(col, 0.18));
    if (p <= 0) return;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: rr),
        -math.pi / 2,
        math.pi * 2 * p,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..color = withOp(col, 0.95));
  }

  /// نشانِ «قدم بعدی» روی نوکِ شاخه در حالت «فقط امروز»
  void _nextStepMark(Canvas canvas, Offset end, Color color, double scale) {
    final base = math.max(11.0, 13.0 * scale);
    final pulse = 1.0 + 0.12 * math.sin(_t * 3.0);
    canvas.drawCircle(end, base * 1.5 * pulse, _stroke(color, 6, 0.22));
    canvas.drawCircle(end, base * pulse, _stroke(color, 2.4, 0.95));
  }

  void _goalShutter(Canvas canvas, Goal g, Color col, Color tc, double r) {
    final n = goalBranchCount(state, g);
    if (n == 0) return;
    // زیرِ دایره‌ی هدف، وسط (نوشته بالاست و دکمه‌ی صدا بالا-راست؛ قاطی نمی‌شوند)
    final cx = g.x, cy = g.y + r + 20;
    final open = !g.collapsed;
    hits.add(HitEntry(
        type: 'goalToggle',
        id: g.id,
        kind: HitKind.handle,
        rect: Rect.fromLTWH(cx - 34, cy - 19, 68, 38)));
    final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 27, cy - 11, 54, 22), const Radius.circular(11));
    final ink = open ? tc : const Color(0xFF1B1400);
    if (!open) canvas.drawRRect(pill, Paint()..color = withOp(col, 0.92));
    canvas.drawRRect(
        pill,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = withOp(col, open ? 0.75 : 1.0));
    final chev = Path();
    if (open) {
      chev
        ..moveTo(-4, 1.8)
        ..lineTo(0, -2.2)
        ..lineTo(4, 1.8);
    } else {
      chev
        ..moveTo(-4, -1.8)
        ..lineTo(0, 2.2)
        ..lineTo(4, -1.8);
    }
    canvas.drawPath(
        chev.shift(Offset(cx - 14, cy)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = withOp(ink, open ? 0.75 : 0.95));
    drawText(canvas, toFa(n), cx + 7, cy + 4.3,
        size: 12,
        color: withOp(ink, open ? 0.8 : 1.0),
        weight: FontWeight.w700);
  }

  void _drawRing(Canvas canvas, Ring r, Color tc) {
    final c = Offset(r.x, r.y);
    final rad = r.radius;
    final col = hexColor(r.color, hexColor(kRingColor));
    final big = rad * math.max(1.0, r.iconScale);
    if (_haloOn(r.extra, false)) {
      _halo(canvas, c, col, big, 1.2, null);
    }
    _nodeIcon(canvas, c, rad, r.images, r.icon, col, r.iconScale, tc);
    _addCircleBounds(c, rad * r.iconScale);
    hits.add(HitEntry(
        type: 'ring',
        id: r.id,
        kind: HitKind.node,
        center: c,
        radius: math.max(big, rad) + 8));
    {
      final d = math.max(big, rad) + 22;
      _voiceBtn(canvas, c + Offset(d * 0.7071, -d * 0.7071), 'ring', r.id,
          r.extra, 'voice');
      _videoBtn(canvas, c + Offset(-d * 0.7071, -d * 0.7071), 'ring', r.id,
          r.extra, 'video');
    }

    if (r.label.isNotEmpty) {
      final lines = wrapText(r.label, 16);
      final lx = c.dx + r.labelDX;
      final ly = c.dy - (big + 20) + r.labelDY;
      Rect? lr;
      for (var i = 0; i < lines.length; i++) {
        final b = drawText(canvas, lines[i], lx, ly + i * 16,
            size: r.labelSize ?? _labelSize('ring'),
            color: _tcOf(r.extra, col),
            weight: FontWeight.w700,
            outline: 3,
            outlineColor: const Color(0xFF0A0C18),
            fontFamily: _fontOf(r.extra));
        lr = lr == null ? b : lr.expandToInclude(b);
      }
      if (lr != null) {
        hits.add(HitEntry(
            type: 'ring', id: r.id, kind: HitKind.label, rect: lr));
      }
    }
    if (r.note.isNotEmpty) {
      final lines = wrapText(r.note, 22);
      final ly = c.dy + big + 18;
      for (var i = 0; i < lines.length; i++) {
        drawText(canvas, lines[i], c.dx, ly + i * 16,
            size: math.max(8, _fs() - 3),
            color: _tcOf(r.extra, tc),
            weight: FontWeight.w400,
            outline: 2.5,
            fontFamily: _fontOf(r.extra));
      }
    }
  }

  // ───────────────────────── تنه ─────────────────────────

  void _branches(Canvas canvas, MapHost h, Color tc,
      {required bool trunkOnly}) {
    final cp = geo.trunkControlPoints(h, state.me);
    final col =
        hexColor(h.color, hexColor(h.isRing ? kRingColor : kPalette[0]));
    if (h.isRing) {
      _taperedBezier(canvas, cp, col, 3.2, 1.6, 0.6);
    } else if (!(h is Goal && h.extra['showTrunk'] != true)) {
      // خطِ تنه‌ی هدف دیگر کشیده نمی‌شود (جاده جایش را گرفته)؛ فقط با showTrunk=true
      final ts = (h is Goal && h.trunkStyle.isNotEmpty)
          ? h.trunkStyle
          : state.trunkStyle;
      _trunk(canvas, cp, col, kTrunkStyles.containsKey(ts) ? ts : kDefaultTrunkStyle,
          width: (h is Goal && h.trunkWidth > 0) ? h.trunkWidth : 3.0);
    }
    _pts..add(cp.p0)..add(cp.p3);

    if (h is Goal) {
      if (!h.collapsed) {
        _walker(canvas, h, cp, col);
      }
      _goalTrophy(canvas, h, col);
    }

    // شاخه‌های هدف کنارِ جاده شروع می‌شوند (نه روی آن): نقاطِ دو سمتِ جاده
    List<Offset>? sideA, sideB, mid;
    if (h is Goal) {
      const roadOff = 26.0;
      sideA = WalkLayer.roadSidePoints(state, h, roadOff);
      sideB = WalkLayer.roadSidePoints(state, h, -roadOff);
      // خط‌وسطِ جاده: قدم‌های شاخه/زیرشاخه روی همین راه می‌روند (نه کنارِ جاده)
      mid = WalkLayer.roadSidePoints(state, h, 0.0);
    }
    ({Offset o, double d, List<Offset> route}) originOf(int i, double t) {
      final pts = (i.isEven ? sideA : sideB);
      if (pts == null || pts.length < 4) {
        return (
          o: cp.at(t),
          d: cp.tangent(t),
          route: [for (var k = 0; k <= 16; k++) cp.at(t + (0.94 - t) * k / 16)]
        );
      }
      final n = pts.length - 1;
      final ix = (t * n).round().clamp(1, n - 1).toInt();
      final v = pts[ix + 1] - pts[ix - 1];
      final endIx = (0.94 * n).round().clamp(ix + 1, n).toInt();
      // شاخه کنارِ جاده شروع می‌شود؛ قدم‌ها بعد از چند گام نرم به خط‌وسطِ
      // جاده می‌آیند و از آنجا تا هدف روی جاده می‌روند
      final ctr = mid;
      if (ctr == null || ctr.length != pts.length) {
        return (
          o: pts[ix],
          d: math.atan2(v.dy, v.dx),
          route: [for (var k = ix; k <= endIx; k++) pts[k]]
        );
      }
      const blend = 3;
      final r = <Offset>[pts[ix]];
      for (var k = ix; k < endIx; k++) {
        if (k - ix < blend) {
          for (var j = 1; j <= 4; j++) {
            final f = j / 4.0;
            final u = (k - ix) + f;
            var w = (u / blend).clamp(0.0, 1.0).toDouble();
            w = w * w * (3 - 2 * w);
            final sp = Offset.lerp(pts[k], pts[k + 1], f)!;
            final cp2 = Offset.lerp(ctr[k], ctr[k + 1], f)!;
            r.add(Offset.lerp(sp, cp2, w)!);
          }
        } else {
          r.add(ctr[k + 1]);
        }
      }
      return (o: pts[ix], d: math.atan2(v.dy, v.dx), route: r);
    }

    if (trunkOnly) {
      // جمع‌شده: مسیر شاخه‌ها (خطِ بسیار کم‌رنگ) و ردپای قدم‌ها می‌ماند
      if (state.extra['doneFeetCollapse'] != true) {
        final ga = _visibleActs(h.actions);
        for (var i = 0; i < ga.length; i++) {
          final t = math.min(0.9, 0.15 + i * 0.09);
          final og = originOf(i, t);
          _twigGhost(canvas, h, col, og.o, og.d, ga[i],
              i.isEven ? 1 : -1, 1.0, tc,
              route: og.route,
              trunkLane: (i % 3) - 1);
        }
      }
      return;
    }
    final acts = _visibleActs(h.actions);
    for (var i = 0; i < acts.length; i++) {
      final t = math.min(0.9, 0.15 + i * 0.09);
      final og = originOf(i, t);
      _twig(canvas, h, col, og.o, og.d, acts[i],
          i.isEven ? 1 : -1, 1.0, tc,
          route: og.route,
          trunkLane: (i % 3) - 1);
    }
  }

  Paint _stroke(Color col, double w, double op,
          {StrokeCap cap = StrokeCap.round}) =>
      Paint()
        ..style = PaintingStyle.stroke
        ..color = withOp(col, op)
        ..strokeWidth = w
        ..strokeCap = cap
        ..strokeJoin = StrokeJoin.round;

  Path _pathOf(geo.Cubic k) => Path()
    ..moveTo(k.p0.dx, k.p0.dy)
    ..cubicTo(k.p1.dx, k.p1.dy, k.p2.dx, k.p2.dy, k.p3.dx, k.p3.dy);

  /// [width] = ضخامت پایه‌ی خط (پیش‌فرض ۳)؛ همه‌ی سبک‌ها نسبت به آن بزرگ/کوچک می‌شوند
  void _trunk(Canvas c, geo.Cubic cp, Color col, String style,
      {double width = 3.0}) {
    final k = width / 3.0; // ضریب نسبت به ضخامت پیش‌فرض
    // فاصله‌ی خط‌چین‌ها هم کمی با ضخامت رشد می‌کند تا خط ضخیم بدون فاصله نشود
    final dk = k.clamp(0.7, 2.6).toDouble();
    switch (style) {
      case 'solid':
        c.drawPath(_pathOf(cp), _stroke(col, 3 * k, 0.9));
      case 'dotted':
        drawDashed(c, _pathOf(cp), _stroke(col, 3.6 * k, 0.9), [0.1, 8 * dk]);
      case 'dashdot':
        drawDashed(
            c,
            _pathOf(cp),
            _stroke(col, 3 * k, 0.9, cap: StrokeCap.butt),
            [14 * dk, 7 * dk, 2 * dk, 7 * dk]);
      case 'long':
        drawDashed(c, _pathOf(cp),
            _stroke(col, 3 * k, 0.9, cap: StrokeCap.butt), [26 * dk, 13 * dk]);
      case 'double':
        {
          final d = cp.p3 - cp.p0;
          final len = d.distance == 0 ? 1.0 : d.distance;
          final off = 2.6 * k + (k > 1 ? (k - 1) * 0.8 : 0);
          final n = Offset(-d.dy / len * off, d.dx / len * off);
          for (final sgn in [1.0, -1.0]) {
            final o = n * sgn;
            c.drawPath(
                _pathOf(geo.Cubic(cp.p0 + o, cp.p1 + o, cp.p2 + o, cp.p3 + o)),
                _stroke(col, 1.6 * k, 0.9));
          }
        }
      case 'glow':
        c.drawPath(_pathOf(cp), _stroke(col, 9 * k, 0.16));
        c.drawPath(_pathOf(cp), _stroke(col, 2.8 * k, 0.95));
      case 'taper':
        _taperedBezier(c, cp, col, 5.2 * k, 1.6 * k, 0.9);
      default:
        drawDashed(c, _pathOf(cp),
            _stroke(col, 3 * k, 0.9, cap: StrokeCap.butt), [9 * dk, 9 * dk]);
    }
  }

  void _taperedBezier(
      Canvas c, geo.Cubic cp, Color col, double w0, double w1, double op) {
    const seg = 7;
    final p = _stroke(col, w0, op);
    for (var s = 0; s < seg; s++) {
      p.strokeWidth = w0 + (w1 - w0) * ((s + 0.5) / seg);
      c.drawLine(cp.at(s / seg), cp.at((s + 1) / seg), p);
    }
  }

  void _taperedPoly(
      Canvas c, List<Offset> pts, Color col, double w0, double w1, double op) {
    final cum = geo.polyCum(pts);
    final tot = cum.last == 0 ? 1.0 : cum.last;
    final p = _stroke(col, w0, op);
    for (var i = 1; i < pts.length; i++) {
      final f = ((cum[i - 1] + cum[i]) / 2) / tot;
      p.strokeWidth = w0 + (w1 - w0) * f;
      c.drawLine(pts[i - 1], pts[i], p);
    }
  }

  // ───────────────────────── شمارش لاگ ─────────────────────────

  static int _jalaliDayNum(String jk) {
    final p = jk.split('-').map((e) => int.tryParse(e) ?? 0).toList();
    if (p.length != 3) return 0;
    const cum = [0, 31, 62, 93, 124, 155, 186, 216, 246, 276, 306, 336];
    final jy = p[0];
    final jm = p[1].clamp(1, 12);
    final jd = p[2];
    return jy * 365 + cum[jm - 1] + jd;
  }

  static bool _isDoneLog(dynamic v) =>
      v == true ||
      v == 'انجام شد ✓' ||
      (v is String && v.isNotEmpty);

  int _logCount(ActionNode a) {
    var n = 0;
    for (final v in a.logs.values) {
      if (_isDoneLog(v)) n++;
    }
    return n;
  }

  /// آیا این شاخه/زیرشاخه در روزِ [jk] انجام/ثبت شده؟
  /// (تیک/متن در logs، یا زمان ثبت‌شده با تایمر/مدت/ساعت)
  bool _doneOn(ActionNode a, String jk) => footDoneOn(a, jk);

  /// آیا این شاخه/زیرشاخه حداقل یک روزِ انجام‌شده (یا «تمام شد») دارد؟
  bool _hasDoneDay(ActionNode a) {
    if (nodeFinished(a) || (a.timerStart ?? 0) > 0) return true;
    for (final k in a.logs.keys) {
      if (footDoneOn(a, k)) return true;
    }
    for (final k in a.time.keys) {
      if (footDoneOn(a, k)) return true;
    }
    for (final k in a.entries.keys) {
      if (footDoneOn(a, k)) return true;
    }
    return false;
  }

  /// روزهایی (از روزهای قبل) که غنچه‌شان گل می‌شود: در هر دسته‌ی ۳ روزِ
  /// پشت‌سرهم، یکی از غنچه‌ها (تصادفی ولی ثابت) گل می‌شود.
  Set<String> _flowerDays(
      ActionNode a, String todayK, List<String> pastKeys, bool doneTodayToo) {
    final sig = '$todayK|$doneTodayToo|${pastKeys.length}|${pastKeys.join(',')}';
    final c = _flowerDaysCache[a.id];
    if (c != null && _flowerSigCache[a.id] == sig) return c;
    final done = <String>{...pastKeys, if (doneTodayToo) todayK};
    final out = <String>{};
    if (done.length >= 3) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final run = <String>[];
      void flush() {
        for (var g = 0; g + 3 <= run.length; g += 3) {
          final grp = run
              .sublist(g, g + 3)
              .where((k) => k != todayK || !doneTodayToo)
              .toList();
          if (grp.isEmpty) continue;
          var hh = 5;
          for (final u in '${a.id}|fl|${run[g]}'.codeUnits) {
            hh = (hh * 31 + u) & 0x7fffffff;
          }
          out.add(grp[hh % grp.length]);
        }
        run.clear();
      }

      // از قدیمی‌ترین روز تا امروز؛ حداکثر ۷۳۰ روز
      for (var i = 730; i >= 0; i--) {
        final k = jKey(DateTime(today.year, today.month, today.day - i));
        if (done.contains(k)) {
          run.add(k);
        } else {
          flush();
        }
      }
      flush();
    }
    _flowerSigCache[a.id] = sig;
    _flowerDaysCache[a.id] = out;
    return out;
  }

  /// تعداد روزهای انجام‌شده، بدون احتساب امروز
  int _pastDoneDays(ActionNode a, String todayK) {
    final keys = <String>{...a.logs.keys, ...a.time.keys, ...a.entries.keys};
    var n = 0;
    for (final k in keys) {
      if (k != todayK && _doneOn(a, k)) n++;
    }
    return n;
  }

  int _goalTotalLogs(Goal g) {
    var n = 0;
    void walk(List<ActionNode> list) {
      for (final a in list) {
        n += _logCount(a);
        walk(a.children);
      }
    }
    walk(g.actions);
    return n;
  }

  // ───────────────────────── شکل قدم ─────────────────────────

  Path _footPath(double size, {bool left = false}) {
    final k = size / 16.0 * 20.0;
    final m = Matrix4.identity()..scale(left ? -k : k, k);
    return footBasePath().transform(m.storage);
  }

  void _drawFoot(
    Canvas canvas,
    Offset pos,
    double angle,
    double size,
    Color color, {
    bool outline = false,
    double strokeW = 1.4,
    bool left = false,
  }) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    final path = _footPath(size, left: left);
    if (outline) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    } else {
      canvas.drawPath(path, Paint()..color = color);
    }
    canvas.restore();
  }

  // ───────────────────────── قدم‌زن روی تنه ─────────────────────────

  /// قدم‌زن هدف (آبی): کل تنه، رفت و برگشتی.
  void _walker(Canvas canvas, Goal g, geo.Cubic cp, Color col0) {
    // کاربر «نمایش انیمیشن» را خاموش کرده → قدم‌زنِ این هدف کشیده نمی‌شود
    if (g.extra['showWalker'] == false) return;
    final fcHex = g.extra['footColor'];
    final col = (fcHex is String && fcHex.isNotEmpty)
        ? hexColor(fcHex, col0)
        : col0;
    final playing =
        !walkerIsStill(g.extra) && (g.extra['walkerPlaying'] as bool? ?? true);
    final speed =
        ((g.extra['walkerSpeed'] as num?)?.toDouble() ?? 1.5).clamp(0.3, 4.0);
    final manualT = (g.extra['walkerPos'] as num?)?.toDouble();
    // طول گام متناسب با اندازه‌ی پا (قبلاً همیشه ۱/۳۲ طول تنه بود و روی تنه‌ی
    // بلند گام‌ها خیلی بزرگ می‌شد). سرعتِ حرکت روی مسیر تقریباً ثابت می‌ماند.
    final walkerBase = 20.0 *
        state.footScale.clamp(kFootScaleMin, kFootScaleMax) *
        ((g.extra['walkerSize'] as num?)?.toDouble() ?? 1.0)
            .clamp(kWalkerSizeMin, kWalkerSizeMax);
    // قدم‌زن روی خودِ جاده‌ی کشیده‌شده راه می‌رود (نه روی منحنیِ صافِ تنه)
    final roadPts = WalkLayer.roadRoute(state, g);
    final _Curve walkCurve = (roadPts != null && roadPts.length >= 2)
        ? _RouteCurve(roadPts)
        : _CubicCurve(cp);
    var trunkLen = 0.0;
    if (walkCurve is _RouteCurve) {
      trunkLen = walkCurve.length;
    } else {
      var prevPt = cp.at(0);
      for (var i = 1; i <= 24; i++) {
        final q = cp.at(i / 24);
        trunkLen += (q - prevPt).distance;
        prevPt = q;
      }
    }
    final wStepLen =
        (walkerBase * 1.5 / math.max(trunkLen, 1.0)).clamp(0.004, 1.0 / 32);
    final wSteps = math.max(32, (1.0 / wStepLen).round());
    final wSpeed = speed * math.min(2.5, wSteps / 32.0);
    _walkerCore(
      canvas,
      walkCurve,
      col,
      tMin: 0.06,
      tMax: 0.94,
      stepLen: wStepLen.toDouble(),
      totalSteps: wSteps,
      playing: playing,
      speed: wSpeed.toDouble(),
      manualT: manualT,
      baseSize: 20.0 *
          state.footScale.clamp(kFootScaleMin, kFootScaleMax) *
          ((g.extra['walkerSize'] as num?)?.toDouble() ?? 1.0)
              .clamp(kWalkerSizeMin, kWalkerSizeMax),
      trailCount: 5,
      hitType: 'walker',
      hitId: g.id,
      hostId: g.id,
      photos: walkerPhotosOf(g.extra),
      emoji: walkerEmojiOf(g.extra),
      emojiScale: _walkerEmojiScale(g.extra),
      emojiFont: _fontOf(g.extra, 'walkerFont'),
      halo: g.extra['walkerHalo'] != false,
      haloScale: ((g.extra['walkerHaloScale'] as num?)?.toDouble() ?? 1.0),
      voiceExtra: g.extra,
    );
  }

  /// قدم‌زن شاخه/زیرشاخه: از نقطه‌ی ساخته شدن شاخه، روی شاخه‌های پدر تا تنه،
  /// و بعد روی تنه تا هدف اصلی؛ رفت و برگشتی.
  void _branchWalker(Canvas canvas, List<Offset> routePts, int lane,
      ActionNode a, Color color0, double baseSize, String hostId,
      {bool ghost = false}) {
    if (routePts.length < 2) return;
    // کاربر «نمایش انیمیشن» این شاخه/زیرشاخه را خاموش کرده (فقط یادداشت‌ها
    // اگه روشن باشند هنوز کشیده می‌شوند)
    final hiddenW = a.extra['showWalker'] == false;
    // انیمیشن خاموش است: فقط غنچه‌ها (تیکِ تقویم) کشیده می‌شوند؛ اگر هیچ روزِ
    // انجام‌شده‌ای نبود (یا شاخه جمع‌شده بود) مثل قبل چیزی رسم نمی‌شود
    if (hiddenW &&
        a.extra['footNotesShow'] != true &&
        (ghost || !_hasDoneDay(a))) {
      return;
    }
    final fcHex = a.extra['footColor'];
    final color = (fcHex is String && fcHex.isNotEmpty)
        ? hexColor(fcHex, color0)
        : color0;
    final todayK = jKey(DateTime.now());
    final doneToday = footDoneToday(a, todayK);
    // کار انجام شد / منتظر جواب / کاملاً تمام شد → کلِ انیمیشن (عکس، ایموجی،
    // قدم‌ها، نوشته‌ها) زیرِ یک غنچه (تمام‌شده: گل/برگ) می‌رود. لمسِ غنچه = باز/بسته.
    final closedToday = !ghost && !hiddenW && footClosedToday(a, todayK);
    final revealed = a.extra['budOpenDay'] == todayK;
    final collapsed = closedToday && !revealed;
    final finBud = nodeFinished(a);
    final fixed = _pastDoneDays(a, todayK) +
        ((ghost && footDoneOn(a, todayK)) ? 1 : 0);
    final route = _RouteCurve(routePts);
    hits.routes[a.id] = routePts;
    // رشدِ برگ روی تنه/شاخه/زیرشاخه با وقتی که کاربر می‌گذارد
    if (!ghost) {
      final gm = actionTotalMinutes(a);
      if (gm > 0) {
        drawTrunkGrowth(canvas, route.at, route.tangent, a.id, gm, _t,
            scale: (baseSize / 15.0).clamp(0.7, 2.0).toDouble());
      }
    }
    final sizeMul = state.footScale.clamp(kFootScaleMin, kFootScaleMax);
    final footMul = (a.footSize ?? 1.0).clamp(kWalkerSizeMin, kFootSizeMax);
    // ضریبِ بزرگ‌نمایی قدمِ شاخه/زیرشاخه: قبلاً حتی روی ۲۰۰٪ از دایره‌ی متصل و
    // دکمه‌ی تایمر کوچک‌تر بود (آن‌ها حداقل اندازه‌ی ثابت دارند).
    const kBranchFootBoost = 2.4;
    final size = baseSize * 1.2 * sizeMul * footMul * kBranchFootBoost;
    final len = math.max(route.length, 1.0);
    // قدم‌های ثبت‌شده: کوچک‌تر از قدم‌زن، اندازه‌شان قابل تنظیم؛ اگر جا کم بود
    // کوچک‌تر می‌شوند تا همه پشت‌سرهم و بدون روی‌هم‌افتادن در مسیر جا شوند.
    final pastMul =
        ((a.extra['pastFootSize'] as num?)?.toDouble() ?? 0.6).clamp(0.2, 6.0);
    var pastSize = size * 0.5 * pastMul;
    // فاصله‌ی هر قدم با قدمِ قبلی (قبلاً ۲٫۲؛ حالا جا برای گل/برگِ بین قدم‌ها)
    var stride = pastSize * 10.0 / len;
    if (fixed * stride > 0.88) {
      // اول فاصله‌ی بین قدم‌ها کمتر می‌شود (تا حدی)، بعد اندازه‌ی قدم‌ها
      // (حداقل فاصله ۵ برابرِ اندازه تا قدم‌ها توی هم نروند)
      stride = math.max(pastSize * 5.0 / len, 0.88 / fixed);
    }
    if (fixed * stride > 0.88) {
      final fit = 0.88 / (fixed * stride);
      pastSize *= fit;
      stride *= fit;
    }

    // ─── روزهای قبل: هر روزِ ثبت‌شده یک جفت پا (چپ و راست)، پشت سر هم از شروع مسیر ───
    // جفت پا کنار هم (چپ و راست روی یک نقطه)، کمی کم‌رنگ‌تر از قدمِ امروز
    // روزهای انجام‌شده به ترتیب تاریخ؛ هر قدمِ کم‌رنگ = یک روز (تپ = تقویم همان روز)
    final pastDayKeys = <String>{...a.logs.keys, ...a.time.keys, ...a.entries.keys}
        .where((k) => (k != todayK || ghost) && _doneOn(a, k))
        .toList()
      ..sort((x, y) => _jkOrd(x).compareTo(_jkOrd(y)));
    // گل یا برگِ هر روزِ انجام‌شده، بین قدمِ آن روز و قدمِ بعدی (کنارِ مسیر).
    // لمس: شاخه و زیرشاخه‌های جمع‌شده نمایان می‌شوند؛ دوباره بزنی به همین حالت برمی‌گردد.
    final flowerDays = ghost
        ? const <String>{}
        : _flowerDays(a, todayK, pastDayKeys, _doneOn(a, todayK));
    void bloomAt(int slot, String dk) {
      final u = (0.03 + slot * stride).clamp(0.0, 0.95).toDouble();
      // غنچه روی خودِ قدمِ همان روز می‌نشیند (قدم‌ها دیده می‌مانند)
      final pt = route.at(u);
      final tg = route.tangent(u);
      var hh = 11;
      for (final c in '${a.id}|$dk'.codeUnits) {
        hh = (hh * 31 + c) & 0x7fffffff;
      }
      final side = (hh & 1) == 0 ? 1.0 : -1.0;
      final dir = tg + side * math.pi / 2;
      final nv = Offset(math.cos(dir), math.sin(dir));
      final isFlower = flowerDays.contains(dk);
      final sr = (pastSize * 0.42).clamp(4.0, 11.0).toDouble() *
          (isFlower ? 1.3 : 1.0);
      final tip = pt;
      hits.markPts['${a.id}|$dk'] = tip;
      _sprig(canvas, tip, dir, sr, '${a.id}|$dk', 1.0,
          budOnly: !isFlower, flower: isFlower);
      // لمسِ گل/برگ: متنِ همان روز (یادداشت؛ اگر نداشت نامِ شاخه) دیده می‌شود،
      // دوباره لمس = متن پنهان و فقط گل/برگ
      final nAll = a.extra['footNotes'];
      final nRaw = nAll is Map ? nAll[dk] : null;
      final note = nRaw is String ? nRaw.trim() : '';
      // فقط یادداشتِ همان روز؛ نامِ شاخه دوباره نوشته نمی‌شود (خودش روی نقشه هست)
      final shown = note;
      final od = a.extra['dayNotesOpen'];
      final isOpen = od is List &&
          od.contains(dk) &&
          shown.isNotEmpty &&
          !(a.extra['footNotesShow'] == true && note.isNotEmpty);
      if (isOpen) {
        final lines = wrapText(shown.replaceAll('\n', ' '), 22);
        final shownLines = lines.length > 3 ? lines.sublist(0, 3) : lines;
        final fs = _fs() * 0.5;
        final lh = fs * 1.3;
        final base = tip + nv * (sr * 2.5 + fs * 0.6);
        for (var i = 0; i < shownLines.length; i++) {
          var ln = shownLines[i];
          if (i == 2 && lines.length > 3) ln = '$ln…';
          drawText(canvas, ln, base.dx,
              base.dy + (i - (shownLines.length - 1) / 2) * lh,
              size: fs, color: Colors.black, vCenter: true, outline: 2.5);
        }
      }
      // تاریخِ همان روز (کوچک، زیرِ غنچه/گل)؛ لمس = تقویمِ همان روز
      if (!isOpen) {
        final dp = dk.split('-');
        final jm = dp.length == 3 ? int.tryParse(dp[1]) : null;
        final jd = dp.length == 3 ? int.tryParse(dp[2]) : null;
        if (jm != null && jd != null && jm >= 1 && jm <= 12) {
          final fs2 = _fs() * 0.42;
          drawText(canvas, '${toFa(jd)} ${kJalaliMonths[jm - 1]}',
              tip.dx + nv.dx * (sr * 2.3 + fs2 * 0.6),
              tip.dy + nv.dy * (sr * 2.3 + fs2 * 0.6),
              size: fs2,
              color: const Color(0xFF5B5F77),
              vCenter: true,
              outline: 2.2);
        }
      }
      _lateHits.add(HitEntry(
        type: 'pastBloom',
        id: a.id,
        hostId: hostId,
        kind: HitKind.handle,
        center: tip + nv * (sr * 1.2),
        radius: sr * 1.6,
        voiceKey: dk,
      ));
    }

    for (var k = 0; k < fixed && !hiddenW && !collapsed; k++) {
      final u = (0.03 + k * stride).clamp(0.0, 0.95).toDouble();
      // هر روز که می‌گذرد قدمِ آن روز کم‌رنگ‌تر می‌شود (جدیدترین ۶۲٪ → قدیمی‌ترها تا ۱۴٪)
      final age = fixed - 1 - k;
      final footOp = (0.62 - 0.06 * age).clamp(0.14, 0.62).toDouble();
      _drawWalkerFoot(canvas, route, u, -1.0, pastSize, withOp(color, footOp));
      _drawWalkerFoot(canvas, route, u, 1.0, pastSize, withOp(color, footOp));
      if (k < pastDayKeys.length) {
        final dk = pastDayKeys[k];
        hits.add(HitEntry(
          type: 'pastFoot',
          id: a.id,
          hostId: hostId,
          kind: HitKind.handle,
          center: route.at(u),
          radius: pastSize * 1.3,
          voiceKey: dk,
        ));
        bloomAt(k, dk);
      }
    }

    // انیمیشن خاموش: قدم‌ها دیده نمی‌شوند ولی غنچه/گلِ هر روزِ انجام‌شده روی شاخه می‌ماند
    if (hiddenW && !ghost) {
      for (var k = 0; k < fixed && k < pastDayKeys.length; k++) {
        bloomAt(k, pastDayKeys[k]);
      }
    }

    // شاخه‌ی جمع‌شده: فقط ردپای پیشرفت می‌ماند
    if (ghost) return;

    // یادداشتِ روزها: بالای پاها، مشکی، بدون دورخط؛ همراه با انیمیشن
    // (چه متحرک، چه ثابت، چه پنهان)
    final showNotes = !collapsed &&
        a.extra['footNotesShow'] == true &&
        a.extra['footNotes'] is Map;
    final notes = showNotes ? a.extra['footNotes'] as Map : const {};
    final noteSize = (_fs() *
            0.5 *
            ((a.extra['footNotesSize'] as num?)?.toDouble() ?? 1.0)
                .clamp(0.5, 4.0))
        .toDouble();
    // هر یادداشت استایلِ خودش را دارد (فونت/اندازه/رنگ/جابه‌جایی/پنهان از نقشه)
    void noteAbove(String? jk, Object? t, Offset anchor, double lift) {
      if (t is! String || jk == null) return;
      final st = footNoteStyle(a, jk, create: false);
      if (st['hidden'] == true) return;
      var txt = t.trim().replaceAll('\n', ' ');
      if (txt.isEmpty) return;
      if (txt.length > 28) txt = '${txt.substring(0, 27)}…';
      final fid = st['font'] as String?;
      String? fam;
      if (fid != null && fid != 'default') {
        NoteFonts.ensure(fid);
        fam = NoteFonts.familyOf(fid);
      }
      final mul = ((st['size'] as num?)?.toDouble() ?? 1.0).clamp(0.4, 5.0);
      final col0 = st['color'] is int ? Color(st['color'] as int) : Colors.black;
      final noteDone = st['done'] == true;
      final noteWait = st['waiting'] == true;
      // یادداشتِ انجام‌شده کمی کم‌رنگ می‌شود و روی آن خط می‌خورد (مثل to-do)
      final col = noteDone ? col0.withValues(alpha: 0.6) : col0;
      final dx = (st['dx'] as num?)?.toDouble() ?? 0.0;
      final dy = (st['dy'] as num?)?.toDouble() ?? 0.0;
      final fs = noteSize * mul;
      final r = drawText(canvas, txt, anchor.dx + dx, anchor.dy - lift + dy,
          size: fs, color: col, vCenter: true, fontFamily: fam);
      var hitRect = r;
      if (noteDone) {
        canvas.drawLine(
          Offset(r.left - 1, r.center.dy),
          Offset(r.right + 1, r.center.dy),
          Paint()
            ..color = col
            ..strokeWidth = (fs * 0.09).clamp(1.2, 4.0).toDouble()
            ..strokeCap = StrokeCap.round,
        );
        // نشانِ کوچک کنار نوشته: تیکِ ریز (انجام شد) / ⏳ ریز (منتظر جواب)
        if (noteWait) {
          final g = drawText(canvas, '⏳', r.right + fs * 0.6, r.center.dy,
              size: fs * 0.62, color: col, vCenter: true);
          hitRect = r.expandToInclude(g);
        } else {
          final br = math.max(3.5, fs * 0.3);
          final c = Offset(r.right + br + 3, r.center.dy);
          _miniCheck(canvas, c, br);
          hitRect = r.expandToInclude(Rect.fromCircle(center: c, radius: br));
        }
      }
      hits.add(HitEntry(
        type: 'footNote',
        id: a.id,
        hostId: hostId,
        kind: HitKind.label,
        rect: hitRect.inflate(4),
        voiceKey: jk,
      ));
    }

    // یادداشتِ «قدمِ فعلی»: امروز؛ اگه نداشت نزدیک‌ترین روزِ آینده؛ بعد روزِ از دست رفته
    Object? curNote;
    String? curKey;
    if (showNotes) {
      final past = <String>{...a.logs.keys, ...a.time.keys, ...a.entries.keys}
          .where((k) => k != todayK && _doneOn(a, k))
          .toList()
        ..sort((x, y) => _jkOrd(x).compareTo(_jkOrd(y)));
      for (var k = 0; k < past.length; k++) {
        final u = (0.03 + k * stride).clamp(0.0, 0.95).toDouble();
        noteAbove(past[k], notes[past[k]], route.at(u), pastSize * 1.3 + 4);
      }
      final cand = notes.keys
          .whereType<String>()
          .where((k) =>
              !past.contains(k) &&
              (notes[k] as Object?) is String &&
              (notes[k] as String).trim().isNotEmpty)
          .toList()
        ..sort((x, y) => _jkOrd(x).compareTo(_jkOrd(y)));
      final tOrd = _jkOrd(todayK);
      String? pick;
      if (cand.contains(todayK)) {
        pick = todayK;
      } else {
        for (final k in cand) {
          if (_jkOrd(k) > tOrd) {
            pick = k;
            break;
          }
        }
        pick ??= cand.isEmpty ? null : cand.last;
      }
      curKey = pick;
      curNote = pick == null ? null : notes[pick];
    }

    if (hiddenW) {
      // انیمیشن پنهان است: یادداشت بالای جای قدمِ جدید روی مسیر
      final u = (0.03 + fixed * stride).clamp(0.0, 0.95).toDouble();
      noteAbove(curKey, curNote, route.at(u), pastSize * 1.3 + 4);
      // امروز انجام شده (تیکِ تقویم، زمان، یادداشت…) → غنچه روی نوکِ شاخه
      if (!ghost &&
          !finBud &&
          (_plantMinutes(a, todayK) > 0 || footClosedToday(a, todayK))) {
        var ang = route.tangent(0.0) + math.pi; // ادامه‌ی شاخه، رو به بیرون
        if (math.sin(ang) > 0) ang = -ang; // رو به پایین نباشد
        final sr0 = 8.5 * math.max(0.8, baseSize / 15.0);
        if (_plantMinutes(a, todayK) > 0) {
          _plant(canvas, a, routePts.first, ang, sr0 * 0.75, todayK);
        } else {
          _sprig(canvas, routePts.first, ang, sr0, '${a.id}|bud', 1.0,
              budOnly: true);
        }
      }
      return;
    }

    final stepLen = (size * 0.8 / len).clamp(0.006, 0.07);
    final totalSteps = math.max(4, (1.0 / stepLen).round());
    final speed = 1.5 * (a.footSpeed ?? 1.0).clamp(0.2, 3.0);
    final stagger = (a.id.hashCode & 0xFF) / 255.0 * 10.0;
    final pref = (a.id.hashCode & 1) == 0 ? 1.0 : -1.0;
    final posToday = footPosToday(a, todayK);
    final still = walkerIsStill(a.extra);
    // غنچه ثابت می‌ماند (هنگامِ بسته بودن انیمیشن راه نمی‌رود)
    final playingNow = !still && !collapsed && footEffectivePlaying(a, todayK);

    void core(bool playing, double? manual) =>
        _fade(canvas, collapsed ? 1.0 : _doneWalkerOp(a, todayK), () => _walkerCore(
          canvas,
          route,
          color,
          tMin: 0.0,
          tMax: 1.0,
          stepLen: stepLen.toDouble(),
          totalSteps: totalSteps,
          playing: playing,
          speed: speed.toDouble(),
          manualT: manual,
          baseSize: size,
          trailCount: 0,
          timeOffset: stagger,
          pref: pref,
          hitType: 'foot',
          hitId: a.id,
          hostId: hostId,
          withBody: false,
          photos: walkerPhotosOf(a.extra),
          emoji: walkerEmojiOf(a.extra),
          emojiScale: _walkerEmojiScale(a.extra),
          emojiFont: _fontOf(a.extra, 'walkerFont'),
          halo: a.extra['walkerHalo'] != false,
          haloScale: ((a.extra['walkerHaloScale'] as num?)?.toDouble() ?? 1.0),
          voiceExtra: a.extra,
          followManual: true,
          // بسته: فقط غنچه (تمام‌شده: گل/برگ)؛ باز شده: چهره + غنچه‌ی کوچکِ بستن
          bloomId: collapsed ? '${a.id}|bud' : null,
        ));

    if (!doneToday) {
      // ─── امروز هنوز ثبت نشده: قدم جدید، پررنگ (متوقف؛ مگر کاربر پلی بزند) ───
      final u = (0.03 + fixed * stride).clamp(0.0, 0.95).toDouble();
      final bodyU =
          (posToday ?? (u + stepLen * 0.45)).clamp(0.0, 1.0).toDouble();
      final st = _walkerRt.putIfAbsent('foot:${a.id}', _WalkerRt.new);
      if (!playingNow) {
        st.frozenT = bodyU;
        st.frozenRet = false;
        st.playing = false;
        st.cyc = null;
        st.seenManual = bodyU;
      } else if (!st.playing) {
        st.frozenT = bodyU;
        st.frozenRet = false;
        st.seenManual = bodyU;
      }
      core(playingNow, playingNow ? posToday : bodyU);
    } else {
      // ─── امروز ثبت شده: قدم با رنگ واقعی ───
      // اگر متوقف است و جای مشخصی ندارد، به‌ترتیب بعد از آخرین قدمِ ثبت‌شده
      // می‌ایستد (نه وسط مسیر)؛ راه رفتنش همچنان از ابتدا تا انتها و برگشت است.
      if (!playingNow && posToday == null) {
        final st = _walkerRt.putIfAbsent('foot:${a.id}', _WalkerRt.new);
        if (still || (!st.playing && st.frozenT == null)) {
          final u = (0.03 + fixed * stride).clamp(0.0, 0.95).toDouble();
          st.frozenT = (u + stepLen * 0.45).clamp(0.0, 1.0).toDouble();
          st.frozenRet = false;
          st.playing = false;
          st.cyc = null;
        }
      }
      core(playingNow, posToday);
    }
    // غنچه: همیشه روی نوکِ همین شاخه/زیرشاخه، با اندازه‌ی ثابت (مستقل از عکس/زوم
    // انیمیشن). کارِ کاملاً تمام‌شده خودش گل/برگِ سرِ شاخه را دارد (لمسش = باز/بسته).
    final plantMin = ghost ? 0.0 : _plantMinutes(a, todayK);
    if (!ghost && !hiddenW && !finBud && (plantMin > 0 || closedToday)) {
      var ang = route.tangent(0.0) + math.pi; // ادامه‌ی شاخه، رو به بیرون
      if (math.sin(ang) > 0) ang = -ang; // رو به پایین نباشد
      final tip0 = routePts.first;
      final sr0 = 8.5 * math.max(0.8, baseSize / 15.0);
      if (plantMin > 0) {
        // گیاهِ تمرکز: تایمر روشن = رشد؛ بعد از توقف = غنچه‌ها لابه‌لای برگ‌ها
        _plant(canvas, a, tip0, ang, sr0 * 0.75, todayK);
      } else {
        _sprig(canvas, tip0, ang, sr0, '${a.id}|bud', 1.0, budOnly: true);
      }
    }
    if (closedToday && !finBud) {
      var ang = route.tangent(0.0) + math.pi;
      if (math.sin(ang) > 0) ang = -ang;
      final tip0 = routePts.first;
      final sr0 = 8.5 * math.max(0.8, baseSize / 15.0);
      _lateHits.add(HitEntry(
        type: 'walkerBud',
        id: a.id,
        hostId: hostId,
        kind: HitKind.handle,
        center: tip0 + Offset(math.cos(ang), math.sin(ang)) * (sr0 * 1.2),
        radius: sr0 * 1.7,
      ));
    }
    // زیرِ غنچه همه‌چیز پنهان است؛ فقط وضعیتِ «تمام شد» ثبت می‌ماند تا با باز کردنِ
    // غنچه جشنِ تازه تکرار نشود
    final fin = nodeFinished(a);
    if (collapsed) {
      if (fin) _doneSeen[a.id] = true;
      return;
    }
    // یادداشت بالای انیمیشن، همراه با حرکتش
    noteAbove(curKey, curNote, _lastBodyPos, _lastBodyR * 1.5 + 8);
    // دکمه‌ی تایمر / ثبت زمان روی خود انیمیشن
    // ساعت روی نقشه نمایش داده نمی‌شود؛ دکمه‌ی ⏱ هم برای کارِ تمام‌شده پنهان است
    if (!nodeFinished(a) || (a.timerStart ?? 0) > 0) {
      _timeBtn(canvas, a, hostId, _lastBodyPos, _lastBodyR);
    }
    // مُهرِ «انجام شد» + پالسِ عصبی تا هدف
    // «امروز کار کردم» (ثبتِ زمان/تیکِ روز): فقط یک حلقه‌ی نازکِ کهربایی، بدون کم‌رنگ شدن
    if (!fin && footDoneOn(a, todayK)) {
      canvas.drawCircle(
          _lastBodyPos,
          _lastBodyR + 3.0,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = withOp(const Color(0xFFE8A33D), 0.85));
    }
    // «کاملاً تمام شد»: حلقه‌ی سبز + تیک + جشن
    _doneSeal(canvas, a, fin, route, _lastBodyPos, _lastBodyR, 0);
  }

  /// پاداشِ مغز: وقتی قدمِ امروز ثبت شد
  /// ۱) حلقه‌ی کامل و مُهرِ ✓ روی چهره (حالتِ دائمی تا آخر امروز)
  /// ۲) لحظه‌ی ثبت: موج از چهره + پالسِ نوری که روی مسیر تا هدف می‌رود و آنجا می‌درخشد
  void _doneSeal(Canvas canvas, ActionNode a, bool done, _Curve route,
      Offset body, double bodyR, double todaySecs) {
    if (!done) {
      _doneSeen[a.id] = false;
      _doneBurstAt.remove(a.id);
      return;
    }
    // انتقال از «نشده» به «شده» در همین اجرا → انیمیشن؛ بازکردن اپ با قدمِ انجام‌شده بی‌صدا
    if (_doneSeen[a.id] == false) {
      _doneBurstAt[a.id] = _t;
      HapticFeedback.lightImpact();
    }
    _doneSeen[a.id] = true;

    const green = Color(0xFF1E9E6A);
    final tb0 = _doneBurstAt[a.id];
    final el0 = tb0 == null ? 99.0 : _t - tb0;

    // حلقه: بعد از تیک، ساعت‌گرد پر می‌شود؛ بعدش یک حلقه‌ی ساده و آرام (بدون هاله)
    final ringR = bodyR + 3.5;
    final sweep = Curves.easeOutCubic.transform((el0 / 0.45).clamp(0.0, 1.0).toDouble());
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = withOp(green, 0.9);
    if (sweep >= 0.999) {
      canvas.drawCircle(body, ringR, ringPaint);
    } else {
      canvas.drawArc(Rect.fromCircle(center: body, radius: ringR), -math.pi / 2,
          2 * math.pi * sweep, false, ringPaint);
    }

    // تیکِ ادغام‌شده روی خودِ حلقه (نه شناور بالای عکس)
    final bp = Curves.easeOutBack.transform(((el0 - 0.3) / 0.25).clamp(0.0, 1.0).toDouble());
    if (bp > 0) {
      final mc = body + Offset(0, -ringR);
      const mr = 7.0;
      canvas.drawCircle(mc, (mr + 1.5) * bp, Paint()..color = const Color(0xF2FFFFFF));
      canvas.drawCircle(mc, mr * bp, Paint()..color = green);
      final tp = ((el0 - 0.4) / 0.3).clamp(0.0, 1.0).toDouble();
      if (tp > 0) {
        final ck = Path()
          ..moveTo(mc.dx - mr * 0.42, mc.dy + mr * 0.02)
          ..lineTo(mc.dx - mr * 0.1, mc.dy + mr * 0.36)
          ..lineTo(mc.dx + mr * 0.46, mc.dy - mr * 0.32);
        final m = ck.computeMetrics().first;
        canvas.drawPath(
            m.extractPath(0, m.length * tp),
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.9
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round);
      }
    }

    final t0 = _doneBurstAt[a.id];
    if (t0 == null) return;
    final el = _t - t0;
    if (el > 2.6) {
      _doneBurstAt.remove(a.id);
      return;
    }

    // موج‌ها از چهره
    for (var k = 0; k < 2; k++) {
      final p = ((el - k * 0.35) / 1.1).clamp(0.0, 1.0).toDouble();
      if (p <= 0 || p >= 1) continue;
      final e = 1 - (1 - p) * (1 - p);
      canvas.drawCircle(
          body,
          bodyR * (1.0 + 2.4 * e),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 * (1 - p) + 0.5
            ..color = withOp(green, 0.7 * (1 - p)));
    }

    // پالسِ عصبی: از جای چهره روی مسیر تا هدف
    var tb = 0.0;
    var best = double.infinity;
    for (var k = 0; k <= 40; k++) {
      final d = (route.at(k / 40) - body).distanceSquared;
      if (d < best) {
        best = d;
        tb = k / 40;
      }
    }
    final u = ((el - 0.15) / 1.6).clamp(0.0, 1.0).toDouble();
    final eu = u * u * (3 - 2 * u);
    final head = tb + (1 - tb) * eu;
    if (u > 0 && u < 1) {
      for (var j = 0; j < 7; j++) {
        final tj = math.max(tb, head - j * 0.018);
        canvas.drawCircle(
            route.at(tj),
            math.max(1.2, 4.6 - j * 0.55),
            Paint()
              ..color = withOp(const Color(0xFFFFE08A), 0.95 - j * 0.12)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
      }
    }
    // رسیدن به هدف: درخششِ کوتاه
    final pg = ((el - 1.75) / 0.8).clamp(0.0, 1.0).toDouble();
    if (pg > 0 && pg < 1) {
      final gp = route.at(1.0);
      canvas.drawCircle(
          gp,
          8 + 30 * pg,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2 * (1 - pg) + 0.5
            ..color = withOp(const Color(0xFFFFC94D), 0.85 * (1 - pg)));
    }
  }

  /// دکمه‌ی کوچک ⏱ کنار قدم: باز کردن تایمر و ثبت زمانِ امروز
  void _timeBtn(
      Canvas canvas, ActionNode a, String hostId, Offset body, double bodyR) {
    final d = math.max(bodyR * 1.3, 20.0) + 12;
    final c = body + Offset(-d * 0.7071, d * 0.7071);
    const r = 6.5; // قبلاً ۱۱؛ کوچک‌تر تا روی نقشه جلب‌توجه نکند
    final live = (a.timerStart ?? 0) > 0;
    canvas.drawCircle(c, r + 1.6, Paint()..color = const Color(0xF2FFFFFF));
    canvas.drawCircle(c, r,
        Paint()..color = live ? const Color(0xFFE5484D) : const Color(0xFF1E9E6A));
    final ink = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r * 0.55, ink);
    canvas.drawLine(c, c + const Offset(0, -r * 0.38), ink);
    canvas.drawLine(c, c + const Offset(r * 0.28, 0), ink);
    hits.add(HitEntry(
      type: 'actionTime',
      id: a.id,
      hostId: hostId,
      kind: HitKind.handle,
      center: c,
      radius: r + 8,
    ));
  }

  void _walkerCore(
    Canvas canvas,
    _Curve cp,
    Color col, {
    required double tMin,
    required double tMax,
    required double stepLen,
    required int totalSteps,
    required bool playing,
    required double speed,
    double? manualT,
    required double baseSize,
    required int trailCount,
    double timeOffset = 0,
    double laneOff = 0,
    double pref = 1.0,
    required String hitType,
    required String hitId,
    required String hostId,
    bool withBody = true,
    List<String> photos = const [],
    String emoji = '',
    double emojiScale = 1.0,
    String? emojiFont,
    bool halo = true,
    double haloScale = 1.0,
    Map<String, dynamic>? voiceExtra,
    bool followManual = false,
    // بسته (غنچه): عکس، ایموجی، قدم‌ها و لمس‌ها پنهان‌اند؛ خودِ غنچه سرِ شاخه
    // توسط _branchWalker رسم می‌شود (اندازه‌ی ثابت، مستقل از اندازه‌ی عکس)
    String? bloomId,
  }) {
    final range = tMax - tMin;
    final tt = _t + timeOffset;
    final mine = <Offset>[];

    // ─── موقعیت بدنه + جهت (رفت / برگشت) ───
    // موقعیت به‌صورت تجمعی نگه داشته می‌شود (نه از ساعت سراسری) تا بعد از
    // توقف و ادامه، قدم‌زن از همان نقطه‌ی توقف راه بیفتد و نپرد.
    final st = _walkerRt.putIfAbsent('$hitType:$hitId', _WalkerRt.new);
    final cycleLen = totalSteps * 2.0;
    double bodyT;
    bool returning = false;
    double cyc = 0;
    if (playing) {
      // کاربر وسط حرکت قدم را جابه‌جا کرده → از همان‌جا ادامه بده (متوقف نمی‌شود)
      if (followManual && manualT != null && manualT != st.seenManual) {
        st.frozenT = manualT.clamp(tMin, tMax).toDouble();
        st.frozenRet = false;
        st.playing = false;
        st.cyc = null;
      }
      if (followManual) st.seenManual = manualT ?? st.seenManual;
      if (!st.playing || st.cyc == null) {
        final fz = st.frozenT;
        if (fz != null) {
          // ادامه از نقطه‌ی توقف، با همان جهتِ قبل
          final step = ((fz - tMin) / range).clamp(0.0, 1.0) * totalSteps;
          cyc = (st.frozenRet ? cycleLen - step : step) % cycleLen;
        } else {
          cyc = (tt * speed) % cycleLen;
        }
        st.frozenT = null;
      } else {
        var dt = tt - st.lastTt;
        if (dt < 0 || dt > 1.0) dt = 0;
        cyc = (st.cyc! * cycleLen + dt * speed) % cycleLen;
      }
      st.cyc = cyc / cycleLen;
      st.lastTt = tt;
      st.playing = true;
      double stepNum;
      if (cyc < totalSteps) {
        stepNum = cyc;
      } else {
        stepNum = cycleLen - cyc;
        returning = true;
      }
      bodyT = tMin + (stepNum / totalSteps).clamp(0.0, 1.0) * range;
      st.lastBodyT = bodyT;
      st.lastRet = returning;
    } else {
      if (st.playing) {
        // همین الان متوقف شد → موقعیت و جهتِ آخر را نگه دار
        st.frozenT = st.lastBodyT;
        st.frozenRet = st.lastRet;
      }
      // کاربر با انگشت جابه‌جا کرده → موقعیت جدید
      if (manualT != null && manualT != st.seenManual) {
        st.frozenT = manualT;
      }
      st.seenManual = manualT;
      st.playing = false;
      st.cyc = null;
      bodyT = (st.frozenT ?? manualT ?? (tMin + range / 2)).clamp(tMin, tMax);
      returning = st.frozenRet;
    }
    final dir = returning ? -1.0 : 1.0;

    // ─── فقط عکس انتخاب‌شده (اولی) نشون داده می‌شه؛ بقیه فقط ذخیره‌ان ───
    // ایموجی (اگر گذاشته شده) جای عکس/دایره را می‌گیرد
    final hasEmoji = emoji.isNotEmpty;
    final String? photo = photos.isNotEmpty ? photos.first : null;

    // ─── فاز قدم ───
    final stepPhase = playing ? cyc % 1.0 : 0.0;
    final leftSwinging = stepPhase < 0.5;
    final swingPhase = leftSwinging ? stepPhase * 2 : (stepPhase - 0.5) * 2;
    final swingEase = _easeInOut(swingPhase);

    // ─── موقعیت پاها (نسبت به جهت حرکت) ───
    final footGap = stepLen * 0.45;
    final plantedT = (bodyT - dir * footGap).clamp(0.02, 0.98);
    final swingStart = plantedT;
    final swingEnd = (bodyT + dir * footGap).clamp(0.02, 0.98);
    final swingingT = swingStart + (swingEnd - swingStart) * swingEase;

    final leftT = leftSwinging ? swingingT : plantedT;
    final rightT = leftSwinging ? plantedT : swingingT;

    const maxLift = 5.0;
    final leftLift =
        leftSwinging ? math.sin(swingPhase * math.pi) * maxLift : 0.0;
    final rightLift =
        leftSwinging ? 0.0 : math.sin(swingPhase * math.pi) * maxLift;

    // ─── دنباله (پشت سر، نسبت به جهت حرکت) ───
    for (var i = 1; i <= trailCount && bloomId == null; i++) {
      final trailT = (bodyT - dir * i * stepLen).clamp(0.02, 0.98);
      if (trailT < tMin - 0.001 || trailT > tMax + 0.001) continue;
      final trailSize = baseSize * math.max(0.2, 0.5 - i * 0.06);
      final trailOpacity = (1.0 - i / (trailCount + 1)) * 0.42;
      final trailIsLeft = (i + (leftSwinging ? 0 : 1)) % 2 == 0;
      _drawWalkerFoot(canvas, cp, trailT, trailIsLeft ? -1.0 : 1.0, trailSize,
          withOp(col, trailOpacity),
          lift: 0,
          outline: true,
          returning: returning,
          laneOff: laneOff,
          others: _walkerPts,
          pref: pref);
    }

    // ─── دو پا (زیرِ غنچه پنهان) ───
    if (bloomId == null) {
      _drawWalkerFoot(canvas, cp, leftT, -1.0, baseSize, withOp(col, 0.92),
          lift: leftLift,
          returning: returning,
          laneOff: laneOff,
          others: _walkerPts,
          mine: mine,
          pref: pref);
      _drawWalkerFoot(canvas, cp, rightT, 1.0, baseSize, withOp(col, 0.92),
          lift: rightLift,
          returning: returning,
          laneOff: laneOff,
          others: _walkerPts,
          mine: mine,
          pref: pref);
      _walkerPts.addAll(mine);
    }

    // ─── بدنه ───
    final bodyPt = cp.at(bodyT);
    final bodyAng = cp.tangent(bodyT);
    final nx = -math.sin(bodyAng);
    final ny = math.cos(bodyAng);

    final bobFreq = speed * 2;
    final bobPhase = (tt * bobFreq * math.pi * 2) % (math.pi * 2);
    final bob = playing ? math.sin(bobPhase) * 1.5 : 0.0;

    // اندازه‌ی سر: با عکس بزرگ و واضح، بدون عکس کوچک‌تر
    final hasPhoto = photo != null && photo.isNotEmpty;
    final pulseRate = playing ? (1.0 + speed * 0.5) : 0.4;
    final pulse =
        (hasPhoto || hasEmoji) ? 1.0 : 0.94 + math.sin(tt * pulseRate * 2 * math.pi) * 0.06;
    final bodyR = ((hasPhoto || hasEmoji)
            ? math.max(18.0, baseSize * 1.1)
            : math.max(8.0, baseSize * 0.45)) *
        pulse;

    // سر آدم: پشتِ پاها (سمت ساقه/پاشنه)، با فاصله‌ی خیلی کم از پای عقبی
    final rearPt = cp.at(plantedT);
    final rearAng = cp.tangent(plantedT);
    final back =
        (baseSize * 0.5 + baseSize * 0.12 + bodyR) * dir;
    final bodyPos = Offset(
        rearPt.dx - math.cos(rearAng) * back + nx * (bob + laneOff),
        rearPt.dy - math.sin(rearAng) * back + ny * (bob + laneOff));

    _lastBodyPos = bodyPos;
    _lastBodyR = bodyR;

    if (halo && bloomId == null) {
      final hs = haloScale.clamp(0.3, 2.5).toDouble();
      canvas.drawCircle(
          bodyPos,
          bodyR * 2.6 * hs,
          Paint()
            ..color = withOp(col, 0.20)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      canvas.drawCircle(
          bodyPos,
          bodyR * 1.35 * hs,
          Paint()
            ..color = withOp(col, 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }

    if (bloomId != null) {
      // زیرِ غنچه: چیزی کشیده نمی‌شود
    } else {
      ui.Image? faceImg;
      if (hasPhoto) {
        faceImg = images.get(photo!, animate: true, t: _t);
        // اگر عکس نوبتی هنوز بارگذاری نشده، تا آماده شدن عکس اول نشون داده می‌شه
        if (faceImg == null && photos.isNotEmpty) faceImg = images.get(photos.first);
      }
      if (hasEmoji && faceImg == null) {
        // ایموجی به‌جای دایره (بدون قاب)، وسط همان جایگاه
        _walkerGlyphs(canvas, bodyPos, bodyR, emoji, emojiScale, emojiFont);
        if (!playing) {
          final bc = bodyPos + Offset(bodyR * 0.72, bodyR * 0.72);
          final br = math.max(7.0, bodyR * 0.34);
          canvas.drawCircle(bc, br, Paint()..color = withOp(const Color(0xFF000000), 0.62));
          final tri = Path()
            ..moveTo(bc.dx - br * 0.28, bc.dy - br * 0.45)
            ..lineTo(bc.dx + br * 0.5, bc.dy)
            ..lineTo(bc.dx - br * 0.28, bc.dy + br * 0.45)
            ..close();
          canvas.drawPath(tri, Paint()..color = const Color(0xFFFFFFFF));
        }
      } else if (faceImg != null) {
        // عکس کاربر داخل دایره
        final dst = Rect.fromCircle(center: bodyPos, radius: bodyR);
        final side = math.min(faceImg.width, faceImg.height).toDouble();
        final src = Rect.fromCenter(
            center: Offset(faceImg.width / 2, faceImg.height / 2),
            width: side,
            height: side);
        canvas.save();
        canvas.clipPath(Path()..addOval(dst));
        canvas.drawImageRect(faceImg, src, dst, Paint()..isAntiAlias = true);
        canvas.restore();
        canvas.drawCircle(
            bodyPos,
            bodyR,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..color = withOp(col, 0.95));
        if (hasEmoji) {
          _walkerEmojiCluster(
              canvas, bodyPos, bodyR, emoji, emojiScale, emojiFont);
        }
        if (!playing) {
          // نشان ▶ : با یک تپ دوباره راه می‌افته
          final bc = bodyPos + Offset(bodyR * 0.72, bodyR * 0.72);
          final br = math.max(7.0, bodyR * 0.34);
          canvas.drawCircle(bc, br, Paint()..color = withOp(const Color(0xFF000000), 0.62));
          final tri = Path()
            ..moveTo(bc.dx - br * 0.28, bc.dy - br * 0.45)
            ..lineTo(bc.dx + br * 0.5, bc.dy)
            ..lineTo(bc.dx - br * 0.28, bc.dy + br * 0.45)
            ..close();
          canvas.drawPath(tri, Paint()..color = const Color(0xFFFFFFFF));
        }
      } else {
        canvas.drawCircle(
            bodyPos,
            bodyR,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0
              ..color = withOp(col, 0.92));
        canvas.drawCircle(
            bodyPos, bodyR * 0.42, Paint()..color = withOp(col, 0.92));
        if (!playing) {
          final r = bodyR * 0.32;
          canvas.drawRect(
            Rect.fromCenter(center: bodyPos, width: r, height: r),
            Paint()..color = withOp(col, 0.92),
          );
        }
      }

    }

    // زیرِ غنچه: لمس‌های چهره/قدم/دکمه‌ها غیرفعال (فقط خودِ غنچه لمس می‌شود)
    if (bloomId != null) return;
    hits.add(HitEntry(
      type: hitType,
      id: hitId,
      hostId: hostId,
      kind: HitKind.handle,
      center: bodyPos,
      radius: baseSize * 1.4,
    ));
    // ناحیه‌ی لمس چهره (تپ = توقف/پلی، نگه‌داشتن = عکس‌ها). آخر ثبت می‌شه تا اولویت داشته باشه.
    hits.add(HitEntry(
      type: 'face',
      id: hitId,
      hostId: hostId,
      kind: HitKind.handle,
      center: bodyPos,
      radius: math.max(bodyR * 1.3, 20),
    ));
    if (voiceExtra != null) {
      final d = math.max(bodyR * 1.3, 20.0) + 16;
      _voiceBtn(canvas, bodyPos + Offset(d * 0.7071, -d * 0.7071), hitType,
          hitId, voiceExtra, 'walkerVoice',
          r: 10);
      _videoBtn(canvas, bodyPos + Offset(-d * 0.7071, -d * 0.7071), hitType,
          hitId, voiceExtra, 'walkerVideo',
          r: 10);
    }
  }

  void _drawWalkerFoot(
    Canvas canvas,
    _Curve cp,
    double t,
    double side,
    double size,
    Color color, {
    double lift = 0,
    bool outline = false,
    bool returning = false,
    double laneOff = 0,
    List<Offset>? others,
    List<Offset>? mine,
    double pref = 1.0,
  }) {
    final pt = cp.at(t);
    final tang = cp.tangent(t);
    // جهت پا: در برگشت ۱۸۰ درجه می‌چرخد تا پنجه رو به جهت حرکت باشد
    final heading = returning ? tang + math.pi : tang;
    final nx = -math.sin(heading);
    final ny = math.cos(heading);
    final sideOffset = size * 0.32 * side;
    final total = sideOffset + lift;
    final lnx = -math.sin(tang);
    final lny = math.cos(tang);
    var pos = Offset(pt.dx + nx * total + lnx * laneOff,
        pt.dy + ny * total + lny * laneOff);

    // فقط وقتی به پای دیگری نزدیک شد، کمی از خط هدف کنار می‌رود
    // و بعد از دور شدن دوباره روی خط برمی‌گردد.
    if (others != null && others.isNotEmpty) {
      final r = size * 1.7;
      var dev = 0.0;
      for (final q in others) {
        final dd = pos - q;
        final d = dd.distance;
        if (d >= r) continue;
        var w = 1 - d / r;
        w = w * w * (3 - 2 * w);
        final proj = dd.dx * lnx + dd.dy * lny;
        final sgn = proj.abs() < size * 0.2 ? pref : (proj > 0 ? 1.0 : -1.0);
        dev += sgn * w * r * 0.8;
      }
      dev = dev.clamp(-size * 1.6, size * 1.6).toDouble();
      pos = Offset(pos.dx + lnx * dev, pos.dy + lny * dev);
    }
    mine?.add(pos);
    _drawFoot(canvas, pos, heading + math.pi / 2, size, color,
        outline: outline, strokeW: outline ? 1.2 : 1.4, left: side < 0);
  }

  // ───────────────────────── جام ─────────────────────────

  void _goalTrophy(Canvas canvas, Goal g, Color col) {
    if (g.extra['trophyVisible'] == false) return;

    final totalLogs = _goalTotalLogs(g);
    if (totalLogs == 0) return;

    final progress = (totalLogs / 30.0).clamp(0.0, 1.0);

    final cx = g.x + g.radius + 34;
    final cy = g.y - g.radius - 34;

    final pulse = 0.9 + math.sin(_t * 2.2) * 0.1;
    final size = 26.0 * pulse;

    canvas.drawCircle(
      Offset(cx, cy),
      size * 1.7,
      Paint()
        ..color = withOp(col, 0.15 + 0.35 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      size * 0.95,
      Paint()
        ..color = withOp(col, 0.35 + 0.5 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final rayPaint = Paint()
      ..color = withOp(col, 0.7)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = (i / 8) * math.pi * 2 + _t * 0.5;
      final r1 = size * 1.1;
      final r2 = size * (1.3 + math.sin(_t * 3 + i) * 0.15);
      canvas.drawLine(
        Offset(cx + math.cos(a) * r1, cy + math.sin(a) * r1),
        Offset(cx + math.cos(a) * r2, cy + math.sin(a) * r2),
        rayPaint,
      );
    }

    _drawEmoji(canvas, Offset(cx, cy), 0, size, col, '🏆');

    drawText(
      canvas,
      '${(progress * 100).round()}٪',
      cx,
      cy + size * 0.95,
      size: 11,
      color: withOp(col, 0.85),
      weight: FontWeight.w700,
      outline: 2,
    );

    hits.add(HitEntry(
      type: 'trophy',
      id: g.id,
      hostId: g.id,
      kind: HitKind.handle,
      center: Offset(cx, cy),
      radius: size * 1.2,
    ));
  }

  // ───────────────────────── کمکی ─────────────────────────

  /// ضریب اندازه‌ی نوشته/ایکونِ انیمیشن (extra['walkerEmojiSize'])
  static double _walkerEmojiScale(Map<String, dynamic> extra) =>
      ((extra['walkerEmojiSize'] as num?)?.toDouble() ?? 1.0)
          .clamp(kEmojiSizeMin, 3.0)
          .toDouble();

  void _drawEmoji(Canvas canvas, Offset at, double angle, double size,
      Color color, String emoji) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
            fontSize: size,
            color: color,
            fontFamilyFallback: GoogleFonts.emojiFallback),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  /// تیکِ سبزِ ریز (دایره‌ی پر + تیکِ سفید) برای کارهای تمام‌شده؛ به‌جای نوشته‌ی ✓ که شلوغ بود
  void _miniCheck(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1E9E6A));
    canvas.drawPath(
        Path()
          ..moveTo(c.dx - r * 0.45, c.dy + r * 0.02)
          ..lineTo(c.dx - r * 0.1, c.dy + r * 0.38)
          ..lineTo(c.dx + r * 0.5, c.dy - r * 0.34),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.1, r * 0.3)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white);
  }

  List<ActionNode> _visibleActs(List<ActionNode> list) {
    final out = <ActionNode>[];
    for (final n in list) {
      if (n.extra['achieved'] == true) {
        out.addAll(_visibleActs(n.children));
      } else {
        out.add(n);
      }
    }
    return out;
  }

  void _routineRing(Canvas canvas, Offset center, double tipR, Color color,
      double scale, ActionNode a) {
    final R = tipR + 5.5 * math.max(0.8, scale);
    final sw = 2.2 * math.max(0.8, scale);
    final days = jalaaliCurrentWeekDates();
    final tKey = todayJK();
    final rect = Rect.fromCircle(center: center, radius: R);

    const step = 2 * math.pi / 7;
    const gap = 0.34;

    for (var i = 0; i < 7; i++) {
      final k = days[i];
      final has = truthy(a.logs[k]);
      final isToday = k == tKey;
      final a0 = -math.pi / 2 + i * step + gap / 2;
      final a1 = -math.pi / 2 + (i + 1) * step - gap / 2;
      final op = has ? 0.95 : (isToday ? 0.55 : 0.20);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = isToday ? sw * 1.45 : sw
        ..color = withOp(color, op);
      canvas.drawArc(rect, a0, a1 - a0, false, paint);
    }

    if (!truthy(a.logs[tKey])) {
      canvas.drawCircle(center, tipR * 0.55,
          Paint()..color = const Color(0xFF0A0C18).withAlpha(140));
    }

    final streak = routineStreak(a);
    if (streak >= 2) {
      final fs = 8.5 * math.max(0.9, scale);
      drawText(canvas, toFa(streak), center.dx, center.dy - R - 3.5,
          size: fs, color: color, weight: FontWeight.w700, outline: 2);
    }
  }

  void _twig(Canvas canvas, MapHost h, Color hostColor, Offset originPt,
      double originDir, ActionNode a, int side, double scale, Color tc,
      {List<Offset>? route, int trunkLane = 0, int depth = 0}) {
    final weight = a.weight == 0 ? 5.0 : a.weight;
    final color = (a.color != null && a.color!.isNotEmpty)
        ? hexColor(a.color, hostColor)
        : hostColor;
    final isRoutine = a.isRoutine;
    final cs = _circleScaleOf(a);
    final atc = _tcOf(a.extra, tc);

    // پاداش: شاخه‌ای که امروز انجام شده کم‌رنگ می‌شود؛ اگر خودش و همه‌ی
    // زیرشاخه‌هایش انجام شده باشند، زیرشاخه‌ها هم جمع می‌شوند (فقط برای امروز).
    final tk = todayJK();
    final doneNow = nodeFinished(a);
    final visKids = _visibleActs(a.children);
    // همه‌ی زیرشاخه‌ها «کاملاً تمام» شده‌اند؟ (ثبتِ زمان/تیکِ روزانه حساب نمی‌شود)
    final allKidsDone =
        visKids.isNotEmpty && visKids.every((k) => _subtreeDone(k, tk));
    // کاربر می‌تواند جمعِ خودکار را باز کند (foldOpen) یا هر شاخه را دستی جمع کند (folded)
    final manualOpen = a.extra['foldOpen'] == true;
    final manualFold = a.extra['folded'] == true;
    final autoFold = allKidsDone && !manualOpen;
    final fr = _stepFold(a.id, visKids.isNotEmpty, autoFold || manualFold,
        _countVisible(visKids),
        celebrate: autoFold && !manualFold);
    final frp = fr?.p ?? 1.0;
    final foldKids = fr != null && frp <= 0.001;
    final foldAnim = fr != null && frp > 0.001 && frp < 0.999;
    final keepFeet = state.extra['doneFeetCollapse'] != true;
    var fadeOpen = false;
    void openFade() {
      if (doneNow && !fadeOpen) {
        // پیش‌فرض: خیلی ملایم (۸۵٪) + ✓ سبز؛ با گزینه‌ی تنظیمات (doneDim) مثل قبل ۵۰٪
        canvas.saveLayer(
            null,
            Paint()
              ..color = Color.fromRGBO(
                  0, 0, 0, state.extra['doneDim'] == true ? _kDoneFade : 0.85));
        fadeOpen = true;
      }
    }

    void closeFade() {
      if (fadeOpen) {
        canvas.restore();
        fadeOpen = false;
      }
    }

    openFade();
    final geom = geo.computeTwigGeom(h, a, originPt, originDir, side, scale);
    geo.applyBranchStyle(geom, geo.effBranchStyle(h, a), side);
    final end = geom.end;
    _pts.add(end);
    hits.geom[a.id] = ActionGeomEntry(h.id, geom.originPt, end, scale);
    hits.add(HitEntry(
        type: 'action',
        id: a.id,
        hostId: h.id,
        kind: HitKind.handle,
        center: end,
        radius: math.max(15.0, 18 * scale)));

    final baseW = math.max(1.0, (1.9 + weight * 1.05) * scale);
    final tipW = math.max(0.7, baseW * 0.38);
    final cub = geo.Cubic(geom.originPt, geom.c1, geom.c2, end);
    // خط درخشان پیش‌فرض برای شاخه و زیرشاخه: یک لایه‌ی پهن و کم‌رنگ زیر خط
    if (a.extra['twigGlow'] != false) {
      final gp = Path();
      if (geom.poly != null && geom.poly!.length > 1) {
        gp.moveTo(geom.poly!.first.dx, geom.poly!.first.dy);
        for (var i = 1; i < geom.poly!.length; i++) {
          gp.lineTo(geom.poly![i].dx, geom.poly![i].dy);
        }
      } else {
        gp.moveTo(cub.p0.dx, cub.p0.dy);
        gp.cubicTo(cub.p1.dx, cub.p1.dy, cub.p2.dx, cub.p2.dy, cub.p3.dx,
            cub.p3.dy);
      }
      canvas.drawPath(gp, _stroke(color, baseW * 3.2 + 3, 0.15));
    }
    if (geom.poly != null) {
      _taperedPoly(canvas, geom.poly!, color, baseW, tipW, 0.92);
    } else {
      _taperedBezier(canvas, cub, color, baseW, tipW, 0.92);
    }

    // برگ، غنچه و گل روی خودِ تنه‌ی شاخه/زیرشاخه
    if (scale >= 0.28 && a.extra['trunkFlora'] == true) {
      _trunkFlora(canvas, a, geom, cub, scale, depth);
    }

    if (_haloOn(a.extra, false)) {
      final tipR0 = math.max(1.8, 2 + weight * 0.28 * scale) * cs;
      _halo(canvas, end, color, math.max(tipR0 * 1.6, 9.0 * scale), 1, null);
    }

    if (route != null) {
      // مسیر قدم‌ها: از نوک شاخه → ابتدای شاخه (برگشت روی خود شاخه) →
      // شاخه‌های پدر → تنه → هدف اصلی؛ و دوباره برعکس.
      final own = <Offset>[];
      if (geom.poly != null) {
        own.addAll(geom.poly!.reversed);
      } else {
        for (var k = 0; k <= 16; k++) {
          own.add(cub.at(1.0 - k / 16));
        }
      }
      hits.twigs[a.id] = TwigGeom(List<Offset>.of(own), color, a.text.trim());
      own.addAll(route);
      closeFade();
      _branchWalker(canvas, own, trunkLane, a, color, 15.0 * scale, h.id);
      openFade();
    }

    final kids = foldKids ? const <ActionNode>[] : visKids;
    if (kids.isNotEmpty) {
      canvas.drawCircle(end, math.max(2.0, 2.6 * scale) * cs,
          _stroke(color, 1.2, 0.55));
      closeFade(); // زیرشاخه‌ها با شفافیتِ خودشان کشیده می‌شوند
      for (var i = 0; i < kids.length; i++) {
        // اولین زیرشاخه‌ی لیست سرِ شاخه (نوک) است؛ بعدی‌ها به‌ترتیب به ابتدای شاخه نزدیک می‌شوند
        // کل طول شاخه استفاده می‌شود تا زیرشاخه‌ها یک‌جا جمع نشوند
        final tt = 0.15 + ((kids.length - i) / (kids.length + 1)) * 0.8;
        Offset co;
        double cd;
        if (geom.poly != null) {
          final q = geo.polyPointAt(geom.poly!, tt);
          co = q.pt;
          cd = q.angle;
        } else {
          co = cub.at(tt);
          cd = cub.tangent(tt);
        }
        // مسیر بچه: از نقطه‌ی اتصال، برگشت روی همین شاخه تا ابتدایش، بعد مسیر خود شاخه
        final childRoute = <Offset>[];
        if (route != null) {
          for (var k = 0; k <= 12; k++) {
            final u = tt * (1 - k / 12);
            childRoute.add(geom.poly != null
                ? geo.polyPointAt(geom.poly!, u).pt
                : cub.at(u));
          }
          childRoute.addAll(route);
        }
        void drawKid() => _twig(canvas, h, hostColor, co, cd, kids[i],
            i.isEven ? 1 : -1, scale * 0.72, tc,
            route: route == null ? null : childRoute,
            trunkLane: trunkLane,
            depth: depth + 1);
        if (!foldAnim) {
          drawKid();
        } else {
          // جمع شدنِ حلزونی: هر زیرشاخه (از دورترین به نزدیک‌ترین) دور نقطه‌ی
          // اتصالش می‌پیچد، کوچک و محو می‌شود
          final f = 1.0 - frp;
          final r = kids.length <= 1 ? 0.0 : i / (kids.length - 1);
          final fi = ((f - r * 0.4) / 0.6).clamp(0.0, 1.0).toDouble();
          final e = fi * fi * (3 - 2 * fi);
          final sc = 1.0 - e;
          if (sc > 0.03) {
            canvas.saveLayer(
                null, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - e * 0.85));
            canvas.save();
            canvas.translate(co.dx, co.dy);
            if (_countVisible(kids) <= 14) {
              canvas.rotate(e * 2.6 * (i.isEven ? 1 : -1));
            }
            canvas.scale(sc);
            canvas.translate(-co.dx, -co.dy);
            drawKid();
            canvas.restore();
            canvas.restore();
          }
        }
      }
      openFade();
    } else if (a.images.isNotEmpty) {
      final radius = math.max(1.8, 2 + weight * 0.28 * scale);
      final cnt = math.min(a.images.length, 3);
      for (var i = 0; i < cnt; i++) {
        final e = a.images[i];
        final ang = (i / cnt) * math.pi * 2 - math.pi / 2;
        final off = Offset(math.cos(ang) * radius * 0.7 + e.dx,
            math.sin(ang) * radius * 0.7 + e.dy);
        final rect = Rect.fromCenter(
            center: end + off, width: e.size, height: e.size);
        final im = images.get(e.src, animate: true, t: _t);
        if (im != null) {
          paintImage(
              canvas: canvas, rect: rect, image: im, fit: BoxFit.contain);
        }
        hits.add(HitEntry(
            type: 'action',
            id: a.id,
            hostId: h.id,
            kind: HitKind.image,
            imgIdx: i,
            rect: rect));
      }
      if (a.images.length > 3) {
        drawText(canvas, '+${a.images.length - 3}', end.dx + radius * 0.7,
            end.dy + radius * 0.7 + 4,
            size: 10, color: tc, outline: 2);
      }
    } else {
      canvas.drawCircle(end, math.max(1.8, 2 + weight * 0.28 * scale) * cs,
          Paint()..color = color);
    }

    // ردپای پیشرفت: شاخه جمع می‌شود ولی قدم‌هایش (کم‌رنگ) سر جایشان می‌مانند
    if ((foldKids || foldAnim) && keepFeet) {
      closeFade();
      _fade(canvas, foldKids ? 1.0 : (1.0 - frp), () {
        _ghostKids(canvas, h, hostColor, a, geom, cub, visKids, route,
            trunkLane, scale, tc, depth);
      });
      openFade();
    }

    // کارِ تمام‌شده: یک گل یا برگِ کوچک (برای هر شاخه ثابت و تصادفی) سرِ شاخه می‌شکفد
    if (doneNow) {
      if (_bloomSeen[a.id] == false) _bloomAt[a.id] = _t;
      _bloomSeen[a.id] = true;
      final t0 = _bloomAt[a.id];
      final bp = t0 == null ? 1.0 : ((_t - t0) / 0.9).clamp(0.0, 1.0).toDouble();
      if (t0 != null && _t - t0 > 3.0) _bloomAt.remove(a.id);
      final sc = math.max(0.8, scale);
      // جهتِ رشد = ادامه‌ی شاخه؛ اگر رو به پایین بود، رو به بالا برمی‌گردد
      var dx = end.dx - geom.c2.dx, dy = end.dy - geom.c2.dy;
      if (dx * dx + dy * dy < 1) {
        dx = end.dx - geom.originPt.dx;
        dy = end.dy - geom.originPt.dy;
      }
      if (dy > 0) dy = -dy;
      final dir = math.atan2(dy, dx);
      final sr = 10.5 * sc; // گل و برگ بزرگ‌تر (قبلاً ۷)
      if (_plantMinutes(a, tk) > 0) {
        // امروز با تایمر/زمان کار شده: گیاهِ رشدکرده با گل‌ها
        _plant(canvas, a, end, dir, 6.4 * sc, tk);
      } else {
        _sprig(canvas, end, dir, sr, a.id, bp);
      }
      _lateHits.add(HitEntry(
          type: 'bloomToggle',
          id: a.id,
          hostId: h.id,
          kind: HitKind.handle,
          center: end + Offset(math.cos(dir), math.sin(dir)) * (sr * 1.1),
          radius: sr * 1.5));
    } else {
      _bloomSeen[a.id] = false;
      _bloomAt.remove(a.id);
    }

    // دکمه‌ی جمع/باز (قرصِ کوچکِ حرفه‌ای): «تعداد + فلش».
    // باز: فلشِ بالا (لمس = جمع شدن)؛ جمع‌شده: «تمام‌شده از کل» + فلشِ پایین (لمس = باز شدن).
    // جای دکمه: بالای نوشته‌ی شاخه، با فاصله از قدم‌زن/عکس و شاخه و زیرشاخه‌ها؛
    // اگر نوشته‌ای نباشد زیرِ گره (باز هم بیرونِ دایره‌ی عکس/قدم‌زن).
    void foldBtn(Rect? lr) {
      final total = _countVisible(visKids);
      final open = !foldKids;
      final label = open
          ? toFa(total)
          : '${toFa(_countFinished(visKids))} از ${toFa(total)}';
      const fs = 10.5;
      const fw = FontWeight.w600;
      final tw = textCache.get(label, fs, atc, fw).width;
      const ph = 19.0, padX = 8.0, icW = 7.0, gapIc = 5.0;
      final w = padX + tw + gapIc + icW + padX;

      // شعاعِ تقریبیِ قدم‌زن/عکسِ سرِ شاخه؛ دکمه باید بیرونِ آن بماند
      final walkerOn = a.extra['showWalker'] != false;
      final walkR = walkerOn
          ? (21.6 *
                  scale *
                  state.footScale.clamp(kFootScaleMin, kFootScaleMax) *
                  (a.footSize ?? 1.0).clamp(kWalkerSizeMin, kFootSizeMax))
              .clamp(8.0, 140.0)
              .toDouble()
          : 8.0 * scale;
      final clear = walkR + 10.0;

      double gapTo(Offset c) {
        final r = Rect.fromCenter(center: c, width: w, height: ph);
        final dx = math.max(math.max(r.left - end.dx, end.dx - r.right), 0.0);
        final dy = math.max(math.max(r.top - end.dy, end.dy - r.bottom), 0.0);
        return math.sqrt(dx * dx + dy * dy);
      }

      Offset c;
      if (lr != null) {
        // بالای نوشته، وسطِ آن
        c = Offset(lr.center.dx, lr.top - 10.0 - ph / 2);
        final dir = (lr.center.dx - end.dx) >= 0 ? 1.0 : -1.0;
        final limit = dir > 0 ? lr.right - w / 2 : lr.left + w / 2;
        var guard = 0;
        // اول در امتدادِ نوشته از قدم‌زن دور می‌شود، بعد در صورتِ نیاز بالاتر می‌رود
        while (gapTo(c) < clear && guard++ < 80) {
          final nx = c.dx + dir * 3.0;
          if ((dir > 0 && nx <= limit) || (dir < 0 && nx >= limit)) {
            c = Offset(nx, c.dy);
          } else {
            c = Offset(c.dx, c.dy - 3.0);
          }
        }
      } else {
        c = Offset(end.dx, end.dy + clear + ph / 2);
      }

      final pill = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: w, height: ph),
          const Radius.circular(ph / 2));
      // سایه‌ی نرم تا از زمینه جدا شود
      canvas.drawRRect(
          pill.shift(const Offset(0, 1.4)),
          Paint()
            ..color = const Color(0x2E000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6));
      canvas.drawRRect(
          pill, Paint()..color = withOp(atc, open ? 0.10 : 0.16));
      canvas.drawRRect(
          pill,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = withOp(atc, open ? 0.45 : 0.65));
      drawText(canvas, label, pill.left + padX, c.dy,
          size: fs,
          color: withOp(atc, 0.95),
          weight: fw,
          align: LabelAlign.left,
          outline: 2,
          vCenter: true);
      final ch = Offset(pill.right - padX - icW / 2, c.dy);
      final up = open ? -1.0 : 1.0; // باز: فلشِ رو به بالا
      canvas.drawPath(
          Path()
            ..moveTo(ch.dx - 3.2, ch.dy - up * 1.6)
            ..lineTo(ch.dx, ch.dy + up * 1.6)
            ..lineTo(ch.dx + 3.2, ch.dy - up * 1.6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = withOp(atc, 0.9));
      hits.add(HitEntry(
          type: 'foldToggle',
          id: a.id,
          hostId: h.id,
          kind: HitKind.label,
          rect: pill.outerRect.inflate(8)));
    }

    final hasFoldBtn = visKids.isNotEmpty && !foldAnim;
    final labelShown =
        a.text.isNotEmpty && (!doneNow || a.extra['labelOpen'] == true);
    if (hasFoldBtn && !labelShown) {
      foldBtn(null);
    }

    if (state.extra['todayOnly'] == true &&
        TodayFocus.nodeId.isNotEmpty &&
        a.id == TodayFocus.nodeId) {
      _nextStepMark(canvas, end, color, scale);
    }

    // دکمه‌ی پلی صدای شاخه/زیرشاخه: سمتِ مخالفِ نوشته
    _voiceBtn(canvas, end + Offset(side > 0 ? -22 : 22, -14), 'action', a.id,
        a.extra, 'voice',
        dir: side > 0 ? -1 : 1, r: 10);
    _videoBtn(
        canvas,
        end +
            Offset(side > 0 ? -22 : 22,
                (a.extra['voice'] is String && (a.extra['voice'] as String).isNotEmpty) ? -42 : -14),
        'action',
        a.id,
        a.extra,
        'video',
        r: 10);

    if (isRoutine) {
      final tipR = math.max(1.8, 2 + weight * 0.28 * scale) * cs;
      _routineRing(canvas, end, tipR, color, scale, a);
    }

    // کارِ تمام‌شده: نوشته پنهان است و با لمسِ گل/برگِ سرِ شاخه نشان داده می‌شود
    if (a.text.isNotEmpty && (!doneNow || a.extra['labelOpen'] == true)) {
      final lines = wrapText(a.text,
          math.max(10, (18 * math.min(1.0, scale + 0.35)).round()));
      final right = kLabelRtlAnchor ? side > 0 : side < 0;
      final lx = end.dx + (side > 0 ? 8 : -8) + a.labelDX;
      final ly = end.dy + 4 + a.labelDY;
      final fs = a.labelSize ?? _labelSize('action', scale);
      Rect? lr;
      for (var i = 0; i < lines.length; i++) {
        final b = drawText(canvas, lines[i], lx, ly + i * 16,
            size: fs,
            color: atc,
            weight: FontWeight.w400,
            align: right ? LabelAlign.right : LabelAlign.left,
            outline: 2.5,
            fontFamily: _fontOf(a.extra));
        lr = lr == null ? b : lr.expandToInclude(b);
      }
      if (lr != null) {
        hits.add(HitEntry(
            type: 'action',
            id: a.id,
            hostId: h.id,
            kind: HitKind.label,
            rect: lr));
      }

      // تاریخ/ساعتِ شاخه و زیرشاخه روی نقشه نمایش داده نمی‌شود
      if (hasFoldBtn) {
        foldBtn(lr);
      }
    }
    closeFade();

    // پیامِ کوتاهِ تکمیل، هم‌زمان با شروعِ جمع شدن
    if (fr != null && fr.target == true) {
      final me = _t - fr.msgAt;
      if (me >= 0 && me < 2.0) {
        final op = me < 0.3 ? me / 0.3 : (me > 1.5 ? (2.0 - me) / 0.5 : 1.0);
        drawText(canvas, 'یک شاخه تموم شد ✓', end.dx,
            end.dy - 24 * math.max(0.8, scale) - me * 6,
            size: 11,
            color: withOp(const Color(0xFF1E9E6A), op.clamp(0.0, 1.0).toDouble()),
            outline: 2.5);
      }
    }
  }

  /// زیرشاخه‌های جمع‌شده: خطِ بسیار کم‌رنگ + فقط ردپای قدم‌ها
  void _ghostKids(Canvas canvas, MapHost h, Color hostColor, ActionNode a,
      geo.TwigGeom geom, geo.Cubic cub, List<ActionNode> kids,
      List<Offset>? route, int trunkLane, double scale, Color tc, int depth) {
    for (var i = 0; i < kids.length; i++) {
      final tt = 0.15 + ((kids.length - i) / (kids.length + 1)) * 0.8;
      Offset co;
      double cd;
      if (geom.poly != null) {
        final q = geo.polyPointAt(geom.poly!, tt);
        co = q.pt;
        cd = q.angle;
      } else {
        co = cub.at(tt);
        cd = cub.tangent(tt);
      }
      final childRoute = <Offset>[];
      if (route != null) {
        for (var k = 0; k <= 12; k++) {
          final u = tt * (1 - k / 12);
          childRoute.add(geom.poly != null
              ? geo.polyPointAt(geom.poly!, u).pt
              : cub.at(u));
        }
        childRoute.addAll(route);
      }
      _twigGhost(canvas, h, hostColor, co, cd, kids[i], i.isEven ? 1 : -1,
          scale * 0.72, tc,
          route: route == null ? null : childRoute, trunkLane: trunkLane);
    }
  }

  void _twigGhost(Canvas canvas, MapHost h, Color hostColor, Offset originPt,
      double originDir, ActionNode a, int side, double scale, Color tc,
      {List<Offset>? route, int trunkLane = 0}) {
    final color = (a.color != null && a.color!.isNotEmpty)
        ? hexColor(a.color, hostColor)
        : hostColor;
    final geom = geo.computeTwigGeom(h, a, originPt, originDir, side, scale);
    geo.applyBranchStyle(geom, geo.effBranchStyle(h, a), side);
    final end = geom.end;
    final cub = geo.Cubic(geom.originPt, geom.c1, geom.c2, end);
    _pts.add(end);
    hits.geom[a.id] = ActionGeomEntry(h.id, geom.originPt, end, scale);
    final gp = Path();
    if (geom.poly != null && geom.poly!.length > 1) {
      gp.moveTo(geom.poly!.first.dx, geom.poly!.first.dy);
      for (var i = 1; i < geom.poly!.length; i++) {
        gp.lineTo(geom.poly![i].dx, geom.poly![i].dy);
      }
    } else {
      gp.moveTo(cub.p0.dx, cub.p0.dy);
      gp.cubicTo(
          cub.p1.dx, cub.p1.dy, cub.p2.dx, cub.p2.dy, cub.p3.dx, cub.p3.dy);
    }
    canvas.drawPath(gp, _stroke(color, 1.1, 0.13));
    if (route != null) {
      final own = <Offset>[];
      if (geom.poly != null) {
        own.addAll(geom.poly!.reversed);
      } else {
        for (var k = 0; k <= 16; k++) {
          own.add(cub.at(1.0 - k / 16));
        }
      }
      hits.twigs[a.id] = TwigGeom(List<Offset>.of(own), color, a.text.trim());
      own.addAll(route);
      _branchWalker(canvas, own, trunkLane, a, color, 15.0 * scale, h.id,
          ghost: true);
    }
    final kids = _visibleActs(a.children);
    if (kids.isNotEmpty) {
      _ghostKids(canvas, h, hostColor, a, geom, cub, kids, route, trunkLane,
          scale, tc, 0);
    }
  }
}

/// غنچه‌ی کوچکِ یک روزِ انجام‌شده برای خانه‌ی تقویم؛ همان شکل و رنگِ غنچه‌ی نقشه
/// (seed: امروز '<id>|bud'، روزهای قبل '<id>|<کلید روز>').
class DayBudIcon extends StatelessWidget {
  const DayBudIcon({super.key, required this.seed, this.size = 25});
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _DayBudPainter(seed)),
      );
}

class _DayBudPainter extends CustomPainter {
  _DayBudPainter(this.seed);
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    MapPainter._sprig(canvas, Offset(size.width / 2, size.height * 0.92),
        -math.pi / 2, size.width * 0.2, seed, 1.0,
        budOnly: true);
  }

  @override
  bool shouldRepaint(covariant _DayBudPainter old) => old.seed != seed;
}
