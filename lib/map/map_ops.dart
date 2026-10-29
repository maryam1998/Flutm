import 'dart:math' as math;
import 'dart:ui';

import '../models/constants.dart';
import '../models/jalali.dart' show jKey;
import '../models/map_models.dart';
import 'geometry.dart';

class FoundAction {
  FoundAction(this.node, this.list);
  final ActionNode node;
  final List<ActionNode> list;
}

FoundAction? findActionNode(List<ActionNode> list, String id) {
  for (final item in list) {
    if (item.id == id) return FoundAction(item, list);
    final f = findActionNode(item.children, id);
    if (f != null) return f;
  }
  return null;
}

class Nearest {
  Nearest(this.pt, this.dist);
  final Offset pt;
  final double dist;
}

/// نزدیک‌ترین نقطه‌ی منحنی به q (پورت nearestOnBezier)
Nearest nearestOnCubic(Cubic c, Offset q) {
  const n = 40;
  var bestT = 0.0, bestD = double.infinity;
  var bestPt = c.p0;
  for (var i = 0; i <= n; i++) {
    final t = i / n;
    final p = c.at(t);
    final d = (p - q).distance;
    if (d < bestD) {
      bestD = d;
      bestT = t;
      bestPt = p;
    }
  }
  var lo = math.max(0.0, bestT - 1 / n), hi = math.min(1.0, bestT + 1 / n);
  for (var it = 0; it < 14; it++) {
    final t1 = lo + (hi - lo) / 3, t2 = hi - (hi - lo) / 3;
    final p1 = c.at(t1), p2 = c.at(t2);
    final d1 = (p1 - q).distance, d2 = (p2 - q).distance;
    if (d1 < d2) {
      hi = t2;
      if (d1 < bestD) {
        bestD = d1;
        bestPt = p1;
      }
    } else {
      lo = t1;
      if (d2 < bestD) {
        bestD = d2;
        bestPt = p2;
      }
    }
  }
  return Nearest(bestPt, bestD);
}

int goalBranchCount(MapState s, Goal g) {
  var n = countActions(g.actions);
  for (final r in s.ringsOfGoal(g)) {
    n += countActions(r.actions);
  }
  return n;
}

bool ringIsOrphan(MapState s, Ring r) => !s.goals.any((g) => g.id == r.goalId);

double _distToGoalPath(MapState s, Goal g, Offset p) {
  final cp = trunkControlPoints(g, s.me);
  var best = double.infinity;
  for (var i = 0; i <= 28; i++) {
    final d = (cp.at(i / 28) - p).distance;
    if (d < best) best = d;
  }
  return best;
}

/// اگه حلقه نزدیک مسیر یک هدف باشه، زیرمجموعه‌ی اون هدف میشه. پیام‌ها رو برمی‌گردونه.
List<String> autoLinkRings(MapState s) {
  final msgs = <String>[];
  if (s.goals.isEmpty) return msgs;
  for (final r in s.rings) {
    final th = (r.radius == 0 ? 30.0 : r.radius) + 70;
    Goal? cur;
    for (final g in s.goals) {
      if (g.id == r.goalId) cur = g;
    }
    final pos = Offset(r.x, r.y);
    if (cur != null && _distToGoalPath(s, cur, pos) <= th) continue;
    Goal? best;
    var bestD = 0.0;
    for (final g in s.goals) {
      if (g.reached || identical(g, cur)) continue;
      final d = _distToGoalPath(s, g, pos);
      if (d <= th && (best == null || d < bestD)) {
        best = g;
        bestD = d;
      }
    }
    if (best != null) {
      // آهنربا: موقع وصل‌شدن، دقیقاً روی مسیر هدف می‌نشینه (بعدش با انگشت آزادانه قابل جابه‌جایی‌ه)
      final snap = nearestOnCubic(trunkControlPoints(best, s.me), pos);
      r.x = snap.pt.dx;
      r.y = snap.pt.dy;
      r.goalId = best.id;
      best.lastActivity = DateTime.now().millisecondsSinceEpoch;
      msgs.add('نشانه روی مسیر «${best.name.isEmpty ? 'هدف' : best.name}» قرار گرفت و زیرمجموعه‌اش شد');
    }
  }
  return msgs;
}

/// چرخاندن یک هدف (با خط، نشانه‌های روی مسیرش و شاخه‌های جداشده) به‌اندازه‌ی [d]
/// رادیان دورِ «من»؛ فاصله‌اش از «من» ثابت می‌ماند.
void rotateGoalAroundMe(MapState s, Goal g, double d) {
  final cx = s.me.x, cy = s.me.y;
  final c = math.cos(d), sn = math.sin(d);
  Offset rot(double x, double y) {
    final dx = x - cx, dy = y - cy;
    return Offset(cx + dx * c - dy * sn, cy + dx * sn + dy * c);
  }

  final gp = rot(g.x, g.y);
  g.x = gp.dx;
  g.y = gp.dy;
  for (final r in s.rings) {
    if (r.goalId != g.id) continue;
    final rp = rot(r.x, r.y);
    r.x = rp.dx;
    r.y = rp.dy;
    _rotDetached(r.actions, rot, d);
  }
  _rotDetached(g.actions, rot, d);
}

void _rotDetached(List<ActionNode> list, Offset Function(double, double) rot,
    double d) {
  for (final a in list) {
    if (a.detached && a.originX != null && a.originY != null) {
      final p = rot(a.originX!, a.originY!);
      a.originX = p.dx;
      a.originY = p.dy;
      if (a.dir != null) a.dir = a.dir! + d;
    }
    _rotDetached(a.children, rot, d);
  }
}

/// جای خالی روی دایره‌ی دور «من» برای هدف جدید
Offset pickGoalSpot(MapState s) {
  final rad = 420.0 + math.min(s.goals.length, 12) * 16;
  Offset? best;
  var bestD = -1.0;
  for (var i = 0; i < 48; i++) {
    final a = (i / 48) * math.pi * 2;
    final p = Offset(s.me.x + math.cos(a) * rad, s.me.y + math.sin(a) * rad);
    var d = 1e9;
    for (final g in s.goals) {
      d = math.min(d, (Offset(g.x, g.y) - p).distance);
    }
    if (best == null || d > bestD) {
      best = p;
      bestD = d;
    }
  }
  return best ?? Offset(s.me.x + rad, s.me.y);
}

ActionNode newAction({double radius = 12}) => ActionNode(
      text: '',
      weight: 5,
      extra: {
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'radius': radius,
        // انیمیشنِ حرکت به‌صورت پیش‌فرض خاموش است؛ کاربر خودش روشن می‌کند
        'showWalker': false,
      },
    );

void resetBranchPos(ActionNode n) {
  n.detached = false;
  n.dir = null;
  n.len = null;
  n.bend1 = null;
  n.bend2 = null;
  n.originX = null;
  n.originY = null;
  n.extra.remove('posMoved');
}

void resetBranchTree(List<ActionNode> list) {
  for (final n in list) {
    resetBranchPos(n);
    resetBranchTree(n.children);
  }
}

Ring newRingNearMe(MapState s) {
  final rnd = math.Random().nextDouble() * 40 - 20;
  return Ring(x: s.me.x + rnd, y: s.me.y + 130, color: kRingColor);
}

// ───────────── قدمِ شاخه/زیرشاخه: وضعیت امروز ─────────────

/// آیا شاخه/زیرشاخه در روزِ [jk] انجام/ثبت شده؟ (تیک، متن، یا زمانِ ثبت‌شده)
bool footDoneOn(ActionNode a, String jk) {
  final l = a.logs[jk];
  if (l == true || (l is String && l.isNotEmpty)) return true;
  final t = a.time[jk];
  if (t is num && t > 0) return true;
  final e = a.entries[jk];
  return e is List && e.isNotEmpty;
}

/// «کاملاً تمام شد»: جدا از ثبتِ روزانه. ثبتِ زمان/تیکِ روز فقط یعنی «امروز کار کردم»؛
/// کارهای تکراریِ روزانه (روتین) هیچ‌وقت «تمام» نمی‌شوند.
bool nodeFinished(ActionNode a) => a.extra['finished'] == true && !a.isRoutine;

/// امروز انجام شده؟ (تایمرِ در حال اجرا هم یعنی در حال انجام)
bool footDoneToday(ActionNode a, String todayJK) =>
    footDoneOn(a, todayJK) || (a.timerStart ?? 0) > 0;

/// آیا قدمِ امروز در حال حرکت است؟
/// انتخاب پلی/استاپِ کاربر فقط برای همان روز معتبر است؛ وگرنه
/// پیش‌فرض: ثبت‌شده → راه می‌رود، ثبت‌نشده → متوقف.
bool footEffectivePlaying(ActionNode a, String todayJK) {
  if (a.extra['footToggleDay'] == todayJK) return a.footPlaying;
  return footDoneToday(a, todayJK);
}

/// جایی که کاربر امروز با انگشت قدم را گذاشته (برای روزهای قبل نادیده)
double? footPosToday(ActionNode a, String todayJK) =>
    a.extra['footPosDay'] == todayJK ? a.footPos : null;

/// حالت «ثابت» انیمیشن (هدف/شاخه/زیرشاخه): ثبت روی نقشه دیده می‌شود ولی حرکت ندارد
bool walkerIsStill(Map<String, dynamic> extra) => extra['walkerMode'] == 'still';


/// استایلِ یادداشتِ یک روزِ شاخه روی نقشه: font, size, color, dx, dy, hidden
/// (متنِ یادداشت جدا در extra['footNotes'] می‌ماند و با حذف از نقشه پاک نمی‌شود)
Map<String, dynamic> footNoteStyle(ActionNode n, String jk,
    {bool create = true}) {
  var all = n.extra['footNoteStyles'];
  if (all is! Map) {
    if (!create) return const <String, dynamic>{};
    all = <String, dynamic>{};
    n.extra['footNoteStyles'] = all;
  }
  var st = all[jk];
  if (st is! Map) {
    if (!create) return const <String, dynamic>{};
    st = <String, dynamic>{};
    all[jk] = st;
  }
  return st.cast<String, dynamic>();
}

/// ── یادداشتِ قدم مثل to-do ──
/// «انجام شد» (روی نقشه و تقویم خط می‌خورد) و «منتظر جواب» (سهمِ من تمام شد؛
/// نتیجه دست دیگران است). هر دو در همان استایلِ یادداشت (footNoteStyles) ذخیره
/// می‌شوند، پس در بکاپ هم هستند و ساختار قبلی عوض نمی‌شود.
bool footNoteDone(ActionNode n, String jk) =>
    footNoteStyle(n, jk, create: false)['done'] == true;

bool footNoteWaiting(ActionNode n, String jk) =>
    footNoteStyle(n, jk, create: false)['waiting'] == true;

/// خط‌زدن / برداشتنِ خط. برداشتنِ تیک، «منتظر جواب» را هم برمی‌دارد.
/// خط‌خوردنِ یادداشت = «آن روز انجام شد»: روزِ همان یادداشت در تقویمِ قدم و
/// تقویمِ اهداف (هر دو از `logs` می‌خوانند) تیک می‌خورد.
void setFootNoteDone(ActionNode n, String jk, bool v) {
  final st = footNoteStyle(n, jk);
  if (v) {
    st['done'] = true;
    _syncDayLogFromNote(n, jk, st, true);
  } else {
    st.remove('done');
    st.remove('waiting');
    _syncDayLogFromNote(n, jk, st, false);
  }
}

/// «منتظر جواب» یعنی سهمِ من انجام شده؛ پس خودکار خط هم می‌خورد.
void setFootNoteWaiting(ActionNode n, String jk, bool v) {
  final st = footNoteStyle(n, jk);
  if (v) {
    st['waiting'] = true;
    st['done'] = true;
    _syncDayLogFromNote(n, jk, st, true);
  } else {
    st.remove('waiting');
  }
}

int _jkOrdOps(String k) {
  final p = k.split('-');
  if (p.length != 3) return 0;
  return (int.tryParse(p[0]) ?? 0) * 10000 +
      (int.tryParse(p[1]) ?? 0) * 100 +
      (int.tryParse(p[2]) ?? 0);
}

/// تیکِ خودکارِ روز با «انجام شد/منتظر جواب» ی یادداشت (فقط تا امروز).
/// فقط تیکی که خودِ یادداشت زده برمی‌گردد؛ تیک/زمانِ دستیِ کاربر دست‌نخورده می‌ماند.
void _syncDayLogFromNote(
    ActionNode n, String jk, Map<String, dynamic> st, bool done) {
  if (done) {
    if (_jkOrdOps(jk) > _jkOrdOps(jKey(DateTime.now()))) return;
    if (footDoneOn(n, jk)) return;
    n.logs[jk] = true;
    st['autoLog'] = true;
  } else if (st['autoLog'] == true) {
    st.remove('autoLog');
    if (n.logs[jk] == true) n.logs.remove(jk);
  }
}

/// آخرین یادداشتِ (تا امروز) این شاخه «منتظر جواب» است؟
/// یعنی سهمِ من تمام شده و نتیجه دستِ دیگران است → انیمیشن زیرِ غنچه می‌ماند.
bool footWaitingLatest(ActionNode n, String todayJK) {
  final notes = n.extra['footNotes'];
  if (notes is! Map) return false;
  final t = _jkOrdOps(todayJK);
  String? best;
  for (final e in notes.entries) {
    final k = e.key;
    final v = e.value;
    if (k is! String || v is! String || v.trim().isEmpty) continue;
    final o = _jkOrdOps(k);
    if (o == 0 || o > t) continue;
    if (best == null || o > _jkOrdOps(best)) best = k;
  }
  return best != null && footNoteWaiting(n, best);
}

/// امروز «بسته» است؟ → روی نقشه کلِ انیمیشن (عکس، ایموجی، قدم‌ها، نوشته‌ها)
/// زیرِ یک غنچه می‌رود (کاملاً تمام شد: گل/برگ). تایمرِ در حال اجرا = در حال کار.
bool footClosedToday(ActionNode a, String todayJK) {
  if ((a.timerStart ?? 0) > 0) return false;
  if (nodeFinished(a)) return true;
  if (footDoneOn(a, todayJK)) return true;
  if (footNoteDone(a, todayJK)) return true;
  return footWaitingLatest(a, todayJK);
}

/// با حذفِ متنِ یادداشت، وضعیتش هم پاک می‌شود (یادداشتِ تازه از اول شروع شود)
void clearFootNoteState(ActionNode n, String jk) {
  final all = n.extra['footNoteStyles'];
  if (all is! Map) return;
  final st = all[jk];
  if (st is! Map) return;
  st.remove('done');
  st.remove('waiting');
}
