import 'dart:math' as math;
import 'dart:ui';

import '../models/constants.dart';
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

/// جای خالی روی دایره‌ی دور «من» برای هدف جدید
Offset pickGoalSpot(MapState s) {
  final rad = 210.0 + math.min(s.goals.length, 12) * 12;
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
      extra: {'createdAt': DateTime.now().millisecondsSinceEpoch, 'radius': radius},
    );

void resetBranchPos(ActionNode n) {
  n.detached = false;
  n.dir = null;
  n.len = null;
  n.bend1 = null;
  n.bend2 = null;
  n.originX = null;
  n.originY = null;
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
