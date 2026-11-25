import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/map_models.dart';
import 'hit_registry.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  موجِ شکرگزاری + زنده‌شدنِ زمین + هیولاهای دوست‌داشتنیِ ذهن
//
//  ۱) هر شکرگزاریِ تازه یک موج از «من» روی نقشه پخش می‌کند؛ وقتی موج به یک
//     درخت خشکیده یا چشمه‌ی خشک می‌رسد، آن درخت سبز می‌شود / آن چشمه می‌جوشد.
//     (فقط یک عدد در state.extra['gratLife'] ذخیره می‌شود؛ جایگاه‌ها ثابت‌اند.)
//  ۲) هر شاخه/زیرشاخه می‌تواند یک «مانعِ ذهنی» (هیولا) داشته باشد
//     (extra['monster']). با یکی از این سه کار، هیولا دوستِ کاربر می‌شود و
//     به شکل پروانه می‌رود: شکرگزاری، تمرینِ «شناخت خود»، تمام‌کردنِ تایمر.
// ═══════════════════════════════════════════════════════════════════════════

/// یک نوع هیولا
class MonsterKind {
  const MonsterKind(this.id, this.name, this.emoji, this.hint);
  final String id, name, emoji, hint;
}

const List<MonsterKind> kMonsters = [
  MonsterKind('lazy', 'تنبلی', '🦥', 'یک تنبلِ کوچولو که به پای آدم می‌چسبد'),
  MonsterKind('cloud', 'ابر سیاه', '🌧️', 'ابرِ کوچکِ غمگینی که بالای سرت می‌ماند'),
  MonsterKind('judge', 'ترس از قضاوت', '👀', 'پشمالوی چشم‌چشمی که نگران نگاه بقیه است'),
  MonsterKind('ocd', 'وسواس', '🌀', 'یک گلوله‌ی فرفری که مدام چک می‌کند'),
  MonsterKind('doubt', 'تردید', '❓', 'هیولای علامت‌سوالی که نمی‌داند برود یا نه'),
];

MonsterKind? monsterKindOf(String? id) {
  if (id == null) return null;
  for (final k in kMonsters) {
    if (k.id == id) return k;
  }
  return null;
}

class _Ripple {
  _Ripple(this.startMs, this.reach);
  final int startMs;
  final double reach;
}

class MapSpirits {
  MapSpirits._();

  static MapState Function()? _state;
  static VoidCallback? _changed;
  static void Function(String)? _toast;

  /// حداقلِ ثانیه‌ی تایمر که «تمام‌شده» حساب شود
  static const int minTimerSeconds = 30;

  /// سرعتِ پخشِ موج (واحدِ دنیا در ثانیه)
  static const double _rippleSpeed = 240;

  static final List<_Ripple> _ripples = [];

  /// از سازنده‌ی MapStore صدا زده می‌شود
  static void bind(MapState Function() state, VoidCallback changed,
      void Function(String) toast) {
    _state = state;
    _changed = changed;
    _toast = toast;
  }

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  // ───────────────────────── رویدادها ─────────────────────────

  /// شکرگزاریِ تازه ثبت شد
  static void onGratitude() {
    final get = _state;
    if (get == null) return;
    final s = get();
    final n = (s.extra['gratLife'] as num?)?.toInt() ?? 0;
    final now = _nowMs();
    s.extra['gratLife'] = n + 1;
    s.extra['gratLifeAt'] = now;
    final reach = _spotDist(s.me.radius, n) + 170;
    _ripples.add(_Ripple(now, reach));
    if (_ripples.length > 4) _ripples.removeAt(0);
    _freeOne(by: 'gratitude');
    _changed?.call();
  }

  /// یک تمرینِ «شناخت خود» انجام شد
  static void onSelfKnowledge() {
    if (_freeOne(by: 'self')) _changed?.call();
  }

  /// تایمرِ یک شاخه تمام شد
  static void onTimerDone(String actionId, int seconds) {
    if (seconds < minTimerSeconds) return;
    if (_freeOne(actionId: actionId, by: 'timer')) _changed?.call();
  }

  static bool _freeOne({String? actionId, required String by}) {
    final get = _state;
    if (get == null) return false;
    final s = get();
    ActionNode? hit;
    ActionNode? first;
    void walk(List<ActionNode> l) {
      for (final a in l) {
        final m = a.extra['monster'];
        if (m is String && m.isNotEmpty) {
          first ??= a;
          if (actionId != null && a.id == actionId) hit = a;
        }
        walk(a.children);
      }
    }

    for (final g in s.goals) {
      walk(g.actions);
    }
    for (final r in s.rings) {
      walk(r.actions);
    }
    final t = hit ?? first;
    if (t == null) return false;
    final type = t.extra['monster'] as String;
    t.extra.remove('monster');
    t.extra['monsterFarewell'] = {'type': type, 'at': _nowMs(), 'by': by};
    s.extra['monstersFreed'] =
        ((s.extra['monstersFreed'] as num?)?.toInt() ?? 0) + 1;
    final name = monsterKindOf(type)?.name ?? 'هیولا';
    final how = by == 'gratitude'
        ? 'با شکرگزاری‌ات'
        : by == 'timer'
            ? 'با تایمرت'
            : 'با تمرینِ شناخت خود';
    _toast?.call('«$name» $how دوستت شد و به‌شکل پروانه رفت 🦋');
    return true;
  }

  // ───────────────────────── جایگاهِ درخت‌ها و چشمه‌ها ─────────────────────────

  static double _spotDist(double meR, int i) =>
      meR + 150 + 58 * math.sqrt(i.toDouble());

  static Offset _spotPos(Offset me, double meR, int i) {
    final ang = i * 2.399963 + 0.7;
    final d = _spotDist(meR, i);
    return me + Offset(math.cos(ang) * d, math.sin(ang) * d * 0.82);
  }

  static double _h(int i, int k) {
    final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  static double _smooth(double x) {
    final c = x.clamp(0.0, 1.0).toDouble();
    return c * c * (3 - 2 * c);
  }

  // ───────────────────────── رسم: موج و زمینِ زنده ─────────────────────────

  /// زیرِ جاده‌ها و گره‌ها (بعد از زمین) صدا زده می‌شود. مختصاتِ «دنیا».
  static void paintLife(
      Canvas canvas, MapState s, Rect view, double zoom, double t, bool dark) {
    final life = (s.extra['gratLife'] as num?)?.toInt() ?? 0;
    final lifeAt = (s.extra['gratLifeAt'] as num?)?.toInt() ?? 0;
    final now = _nowMs();
    final me = Offset(s.me.x, s.me.y);
    final meR = s.me.radius;
    final z = zoom <= 0 ? 1.0 : zoom;

    _ripples.removeWhere((r) => (now - r.startMs) / 1000.0 * _rippleSpeed > r.reach + 80);

    // سایه‌ی ریز هم نباشد وقتی خیلی زوم‌اوت است
    final tiny = z < 0.07;
    if (!tiny) {
      final cull = view.inflate(90);
      final shown = math.min(life, 400);
      final total = shown + 5; // پنج درختِ خشکِ منتظر
      for (var i = 0; i < total; i++) {
        final p = _spotPos(me, meR, i);
        if (!cull.contains(p)) continue;
        final alive = i < life;
        var g = 0.0;
        if (alive) {
          if (i == life - 1 && lifeAt > 0) {
            final wake = lifeAt + ((_spotDist(meR, i) / _rippleSpeed) * 1000).round();
            g = _smooth((now - wake) / 2400.0);
          } else {
            g = 1.0;
          }
        }
        // وقتی موجی از رویش رد می‌شود یک ضربانِ کوچک
        var pulse = 1.0;
        if (alive && g >= 1.0) {
          final dist = (p - me).distance;
          for (final r in _ripples) {
            final rr = (now - r.startMs) / 1000.0 * _rippleSpeed;
            final d = (rr - dist).abs();
            if (d < 70) pulse += 0.10 * (1 - d / 70);
          }
        }
        final sz = (0.85 + _h(i, 1) * 0.45) * pulse;
        final isSpring = _h(i, 2) < 0.4;
        if (isSpring) {
          _spring(canvas, p, sz, g, t, dark, i);
        } else {
          _tree(canvas, p, sz, g, t, dark, i);
        }
      }
    }

    // خودِ موج‌ها
    final k = (1.0 / z).clamp(0.8, 5.0).toDouble();
    final base = dark ? const Color(0xFFA8F0C0) : const Color(0xFF3FA66B);
    for (final r in _ripples) {
      final age = (now - r.startMs) / 1000.0;
      final rad = age * _rippleSpeed;
      final f = (1 - rad / (r.reach + 80)).clamp(0.0, 1.0).toDouble();
      if (f <= 0) continue;
      canvas.drawCircle(
          me,
          rad,
          Paint()
            ..style = PaintingStyle.fill
            ..color = base.withValues(alpha: 0.07 * f));
      for (var j = 0; j < 3; j++) {
        final rj = rad - j * 38.0;
        if (rj <= meR) continue;
        canvas.drawCircle(
            me,
            rj,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (3.4 - j * 1.0) * k
              ..color = base.withValues(alpha: (0.50 - j * 0.14) * f));
      }
    }
  }

  // ───────────────────────── درخت ─────────────────────────

  static void _tree(
      Canvas canvas, Offset p, double s, double g, double t, bool dark, int seed) {
    final u = s;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    // سایه‌ی زیرِ درخت
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 38 * u, height: 10 * u),
        Paint()..color = const Color(0xFF000000).withValues(alpha: dark ? 0.22 : 0.13));

    final dryTrunk = dark ? const Color(0xFF8E7C62) : const Color(0xFF8A7757);
    final liveTrunk = dark ? const Color(0xFF8A6A48) : const Color(0xFF6B4A2B);
    final trunkC = Color.lerp(dryTrunk, liveTrunk, g)!;
    final sway = math.sin(t * 1.1 + seed) * 1.6 * u * (0.3 + 0.7 * g);

    // تنه
    final trunk = Path()
      ..moveTo(-4.5 * u, 0)
      ..quadraticBezierTo(-2.5 * u, -20 * u, -2.2 * u + sway * 0.3, -40 * u)
      ..lineTo(2.2 * u + sway * 0.3, -40 * u)
      ..quadraticBezierTo(2.5 * u, -20 * u, 4.5 * u, 0)
      ..close();
    canvas.drawPath(trunk, Paint()..color = trunkC);

    // شاخه‌ها: [x۰, y۰, x۱, y۱]
    final br = <List<double>>[
      [0, -26, -17, -45],
      [0, -32, 16, -51],
      [0, -39, -5, -62],
      [-17, -45, -26, -52],
      [16, -51, 24, -60],
    ];
    final bp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = trunkC;
    for (var i = 0; i < br.length; i++) {
      final b = br[i];
      final sw = (i < 3 ? 3.0 : 1.8) * u;
      bp.strokeWidth = sw;
      final dx = i < 3 ? sway * 0.5 : sway;
      canvas.drawLine(Offset(b[0] * u, b[1] * u),
          Offset(b[2] * u + dx, b[3] * u), bp);
    }

    // برگ‌ها (کم‌کم، یکی‌یکی)
    if (g > 0.0) {
      final leaves = <List<double>>[
        [-17, -45, 11],
        [16, -51, 12],
        [-5, -62, 13],
        [-26, -52, 8],
        [24, -60, 8.5],
        [-4, -48, 12],
        [6, -57, 9],
      ];
      for (var i = 0; i < leaves.length; i++) {
        final q = leaves[i];
        final gi = _smooth(g * 1.5 - i * 0.14);
        if (gi <= 0) continue;
        final c = Offset(q[0] * u + sway, q[1] * u);
        final r = q[2] * u * gi;
        final tint = _h(seed * 7 + i, 5);
        final dk = Color.lerp(const Color(0xFF2F8A4E), const Color(0xFF3E9B5A), tint)!;
        final lt = Color.lerp(const Color(0xFF79C46A), const Color(0xFF9BD67A), tint)!;
        canvas.drawCircle(c + Offset(1.2 * u, 1.8 * u), r,
            Paint()..color = dk.withValues(alpha: 0.95));
        canvas.drawCircle(c + Offset(-1.0 * u, -1.0 * u), r * 0.82,
            Paint()..color = lt.withValues(alpha: 0.95));
      }
      // درخششِ لحظه‌ی بیدارشدن
      if (g < 1.0) {
        final glow = math.sin(g * math.pi);
        canvas.drawCircle(
            Offset(sway, -50 * u),
            34 * u * (0.6 + g * 0.6),
            Paint()..color = const Color(0xFFFFE9A0).withValues(alpha: 0.30 * glow));
      }
    }
    canvas.restore();
  }

  // ───────────────────────── چشمه ─────────────────────────

  static void _spring(
      Canvas canvas, Offset p, double s, double g, double t, bool dark, int seed) {
    final u = s;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    // خاکِ ترک‌خورده
    final mud = dark ? const Color(0xFF8D7A55) : const Color(0xFFB59A6A);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 58 * u, height: 22 * u),
        Paint()..color = mud.withValues(alpha: 0.55 * (1 - g * 0.5)));
    if (g < 1.0) {
      final cp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * u
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5E4A2C).withValues(alpha: 0.55 * (1 - g));
      const cr = <List<double>>[
        [-20, -2, -8, 1], [-8, 1, -4, 6], [4, -3, 14, 0],
        [14, 0, 21, 5], [-4, 5, 4, 7], [10, -6, 17, -9],
      ];
      for (final c in cr) {
        canvas.drawLine(Offset(c[0] * u, c[1] * u), Offset(c[2] * u, c[3] * u), cp);
      }
    }
    // آب
    if (g > 0.0) {
      final rx = 22 * u * g, ry = 8.5 * u * g;
      final water = dark ? const Color(0xFF4A9AD0) : const Color(0xFF58B7E8);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
          Paint()..color = water.withValues(alpha: 0.88));
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(-rx * 0.25, -ry * 0.25),
              width: rx * 1.2,
              height: ry * 0.9),
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.22));
      // حلقه‌های آرامِ روی آب
      for (var k = 0; k < 2; k++) {
        final ph = (t * 0.55 + k * 0.5 + seed * 0.13) % 1.0;
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: rx * 2 * ph, height: ry * 2 * ph),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1 * u
              ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55 * (1 - ph) * g));
      }
      // جوششِ آب: چند قطره‌ی بالا‌پایین
      final dp = Paint()..color = water.withValues(alpha: 0.85 * g);
      for (var k = 0; k < 4; k++) {
        final ph = (t * 0.9 + k * 0.27 + _h(seed, 9 + k)) % 1.0;
        final x = (k - 1.5) * 4.0 * u + math.sin(k * 2.1 + seed) * 2 * u;
        final y = -math.sin(ph * math.pi) * (10 + k * 3) * u * g;
        canvas.drawCircle(Offset(x, y - 3 * u), (1.3 + 0.3 * (k % 2)) * u, dp);
      }
    }
    // علف دورِ چشمه: خشک → سبز
    final tufts = <List<double>>[
      [-27, 1], [-20, 8], [-6, 11], [9, 10], [22, 7], [28, 0], [-24, -6], [24, -6],
    ];
    for (var i = 0; i < tufts.length; i++) {
      final q = tufts[i];
      final col = Color.lerp(const Color(0xFFB6A06A), const Color(0xFF5DB664), g)!;
      final tp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.5 * u
        ..color = col.withValues(alpha: 0.85);
      final len = (4 + 4 * g + (i % 3)) * u;
      final sw = math.sin(t * 1.4 + i + seed) * 1.2 * u;
      final b = Offset(q[0] * u, q[1] * u);
      canvas.drawLine(b, b + Offset(sw - 1.8 * u, -len), tp);
      canvas.drawLine(b, b + Offset(sw + 1.8 * u, -len * 0.85), tp);
    }
    canvas.restore();
  }

  // ───────────────────────── رسم: هیولاها ─────────────────────────

  /// بعد از جاده‌ها و قبل از «من» صدا زده می‌شود. [twigs] = hits.twigs
  /// (مسیرِ خودِ هر شاخه از نوک به‌سمتِ پدر؛ فقط شاخه‌های دیده‌شده در این فریم).
  static void paintMonsters(Canvas canvas, MapState s,
      Map<String, TwigGeom> twigs, double t, bool dark, double zoom) {
    final z = zoom <= 0 ? 1.0 : zoom;
    final boost = (15.0 / (17.0 * z)).clamp(1.0, 3.2).toDouble();
    final now = _nowMs();

    void one(ActionNode a) {
      final m = a.extra['monster'];
      final fw = a.extra['monsterFarewell'];
      String? type;
      double age = -1;
      if (m is String && m.isNotEmpty) {
        type = m;
      } else if (fw is Map) {
        final at = (fw['at'] as num?)?.toInt() ?? 0;
        final ty = fw['type'];
        age = (now - at) / 1000.0;
        if (ty is String && age >= 0 && age < 4.6) type = ty;
      }
      if (type == null) return;
      final geo = twigs[a.id];
      if (geo == null || geo.pts.length < 2) return;
      final hp = _along(geo.pts, 0.45);
      final dir = hp.$2;
      final r = 17.0 * boost;
      // کمی کنارِ جاده تا خطِ جاده دیده شود
      final c = hp.$1 + Offset(-math.sin(dir), math.cos(dir)) * (r * 0.55);
      var seed = 0;
      for (final ch in a.id.codeUnits) {
        seed = (seed * 31 + ch) & 0xFFFF;
      }
      _monster(canvas, type, c, r, t, seed, dark, age);
    }

    void walk(List<ActionNode> l) {
      for (final a in l) {
        one(a);
        walk(a.children);
      }
    }

    for (final g in s.goals) {
      if (g.extra['hidden'] == true) continue;
      walk(g.actions);
    }
    for (final r in s.rings) {
      walk(r.actions);
    }
  }

  /// نقطه و جهتِ روی چندخطی در کسرِ [f] از طول
  static (Offset, double) _along(List<Offset> pts, double f) {
    var len = 0.0;
    for (var i = 1; i < pts.length; i++) {
      len += (pts[i] - pts[i - 1]).distance;
    }
    var d = len * f.clamp(0.0, 1.0);
    for (var i = 1; i < pts.length; i++) {
      final seg = (pts[i] - pts[i - 1]).distance;
      if (d <= seg || i == pts.length - 1) {
        final k = seg == 0 ? 0.0 : (d / seg).clamp(0.0, 1.0).toDouble();
        final v = pts[i] - pts[i - 1];
        return (Offset.lerp(pts[i - 1], pts[i], k)!, math.atan2(v.dy, v.dx));
      }
      d -= seg;
    }
    return (pts.first, 0.0);
  }

  static const Color _ink = Color(0xFF2A2A3C);

  static Color _bodyColor(String type, bool dark) {
    switch (type) {
      case 'lazy':
        return dark ? const Color(0xFFB7A68E) : const Color(0xFFA8977F);
      case 'cloud':
        return dark ? const Color(0xFF8A91AE) : const Color(0xFF6E7694);
      case 'judge':
        return dark ? const Color(0xFFA996E0) : const Color(0xFF9B87D6);
      case 'ocd':
        return dark ? const Color(0xFF74C4BA) : const Color(0xFF62B3AA);
      default:
        return dark ? const Color(0xFF8FB0D8) : const Color(0xFF7FA0C9);
    }
  }

  static void _monster(Canvas canvas, String type, Offset c, double r, double t,
      int seed, bool dark, double age) {
    final ph = seed * 0.37;
    final farewell = age >= 0;
    final body = _bodyColor(type, dark);

    // ضریب‌های مرحله‌ی خداحافظی
    final bodyA = farewell ? 1 - _smooth((age - 1.7) / 0.5) : 1.0;
    final flyA = farewell
        ? _smooth((age - 1.8) / 0.5) * (1 - _smooth((age - 3.8) / 0.8))
        : 0.0;
    final happy = farewell && age < 2.2;

    var bob = math.sin(t * 2.1 + ph) * r * 0.07;
    if (farewell && age < 2.0) {
      bob -= math.sin(age * 7).abs() * r * 0.35 * (1 - age / 2.0);
    }
    var jx = 0.0;
    if (type == 'ocd' && !farewell && ((t * 0.7 + ph) % 1.0) < 0.15) {
      jx = math.sin(t * 40) * r * 0.05;
    }
    final center = c + Offset(jx, bob);

    if (bodyA > 0.02) {
      // سایه‌ی زیرِ هیولا
      canvas.drawOval(
          Rect.fromCenter(
              center: c + Offset(0, r * 0.95),
              width: r * 1.7,
              height: r * 0.4),
          Paint()
            ..color =
                const Color(0xFF000000).withValues(alpha: 0.14 * bodyA));
      canvas.save();
      // کوچک‌شدن هنگامِ تبدیل به پروانه
      canvas.translate(center.dx, center.dy);
      final sc = 0.55 + 0.45 * bodyA;
      canvas.scale(sc, sc);
      _drawBody(canvas, type, r, t, ph, body, bodyA, happy, dark);
      canvas.restore();
    }

    if (farewell) {
      // دل‌ها
      if (age < 2.2) {
        final hp = Paint()
          ..color = const Color(0xFFFF7A9C).withValues(alpha: 0.85);
        for (var k = 0; k < 3; k++) {
          final q = ((age * 0.8 + k * 0.33) % 1.0);
          final hx = center.dx + (k - 1) * r * 0.7 + math.sin(q * 6 + k) * r * 0.15;
          final hy = center.dy - r * 1.2 - q * r * 1.6;
          _heart(canvas, Offset(hx, hy), r * 0.22 * (1 - q * 0.4), hp,
              (1 - q).clamp(0.0, 1.0).toDouble());
        }
      }
      // پروانه
      if (flyA > 0.02) {
        final fa = (age - 2.0).clamp(0.0, 3.0).toDouble();
        final px = center.dx + math.sin(fa * 2.2) * r * 0.9;
        final py = center.dy - r * 0.4 - fa * r * 2.0;
        _butterfly(canvas, Offset(px, py), r * 0.7, body, t, flyA);
      }
    }
  }

  static void _heart(Canvas canvas, Offset c, double s, Paint p, double a) {
    if (a <= 0.02) return;
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 1.1)
      ..cubicTo(c.dx - s * 2.2, c.dy - s * 0.2, c.dx - s * 0.9, c.dy - s * 1.7,
          c.dx, c.dy - s * 0.5)
      ..cubicTo(c.dx + s * 0.9, c.dy - s * 1.7, c.dx + s * 2.2, c.dy - s * 0.2,
          c.dx, c.dy + s * 1.1)
      ..close();
    canvas.drawPath(path, Paint()..color = p.color.withValues(alpha: 0.85 * a));
  }

  static void _butterfly(
      Canvas canvas, Offset c, double s, Color body, double t, double a) {
    final flap = (math.sin(t * 16)).abs() * 0.8 + 0.2;
    final wing = Color.lerp(body, const Color(0xFFFFFFFF), 0.35)!;
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(side * flap, 1.0);
      canvas.drawOval(Rect.fromLTWH(0, -s * 0.9, s * 0.95, s * 0.95),
          Paint()..color = wing.withValues(alpha: 0.9 * a));
      canvas.drawOval(Rect.fromLTWH(0, -s * 0.05, s * 0.7, s * 0.75),
          Paint()..color = body.withValues(alpha: 0.85 * a));
      canvas.restore();
    }
    canvas.drawLine(
        c + Offset(0, -s * 0.7),
        c + Offset(0, s * 0.5),
        Paint()
          ..strokeWidth = s * 0.14
          ..strokeCap = StrokeCap.round
          ..color = _ink.withValues(alpha: 0.8 * a));
  }

  // ───────────────────────── بدنِ هر هیولا ─────────────────────────

  static void _drawBody(Canvas canvas, String type, double r, double t,
      double ph, Color body, double a, bool happy, bool dark) {
    final edge = Color.lerp(body, const Color(0xFF000000), 0.28)!;
    final lite = Color.lerp(body, const Color(0xFFFFFFFF), 0.38)!;
    final fill = Paint()..color = body.withValues(alpha: a);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = edge.withValues(alpha: 0.85 * a);

    switch (type) {
      case 'lazy':
        {
          // دست‌هایی که آویزان‌اند
          final arm = Path()
            ..moveTo(-r * 0.85, -r * 0.1)
            ..quadraticBezierTo(-r * 1.25, r * 0.35, -r * 0.95, r * 0.8);
          final arm2 = Path()
            ..moveTo(r * 0.85, -r * 0.1)
            ..quadraticBezierTo(r * 1.25, r * 0.35, r * 0.95, r * 0.8);
          final ap = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.34
            ..strokeCap = StrokeCap.round
            ..color = body.withValues(alpha: a);
          canvas.drawPath(arm, ap);
          canvas.drawPath(arm2, ap);
          final o = Rect.fromCenter(
              center: Offset.zero, width: r * 2.0, height: r * 1.8);
          canvas.drawOval(o, fill);
          canvas.drawOval(o, line);
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(0, r * 0.28), width: r * 1.2, height: r * 0.95),
              Paint()..color = lite.withValues(alpha: 0.7 * a));
          // صورتِ خواب‌آلود
          _eyes(canvas, r, a, happy ? 'happy' : 'sleepy', 0.42, 0.26, 0, 0);
          _blush(canvas, r, a, happy ? 0.5 : 0.28);
          if (!happy) {
            // zzz
            final zp = Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.08
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFF6A6F8A).withValues(alpha: 0.9 * a);
            for (var k = 0; k < 2; k++) {
              final q = ((t * 0.45 + k * 0.5 + ph) % 1.0);
              final zs = r * (0.16 + 0.09 * k);
              final zc = Offset(r * 0.9 + q * r * 0.5, -r * 0.9 - q * r * 0.9);
              final al = (1 - q).clamp(0.0, 1.0).toDouble();
              zp.color = const Color(0xFF6A6F8A).withValues(alpha: 0.9 * a * al);
              canvas.drawPath(
                  Path()
                    ..moveTo(zc.dx - zs, zc.dy - zs)
                    ..lineTo(zc.dx + zs, zc.dy - zs)
                    ..lineTo(zc.dx - zs, zc.dy + zs)
                    ..lineTo(zc.dx + zs, zc.dy + zs),
                  zp);
            }
          }
        }
        break;
      case 'cloud':
        {
          final puffs = <List<double>>[
            [-0.75, 0.12, 0.62],
            [0.75, 0.12, 0.62],
            [-0.3, -0.38, 0.72],
            [0.38, -0.3, 0.66],
            [0.0, 0.2, 0.8],
          ];
          for (final q in puffs) {
            canvas.drawCircle(Offset(q[0] * r, q[1] * r), q[2] * r, fill);
          }
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(-r * 0.15, -r * 0.35),
                  width: r * 1.1,
                  height: r * 0.6),
              Paint()..color = lite.withValues(alpha: 0.45 * a));
          _eyes(canvas, r, a, happy ? 'happy' : 'sad', 0.38, 0.22, 0, 0.12);
          _blush(canvas, r, a, 0.3);
          if (!happy) {
            // باران
            final rp = Paint()
              ..strokeWidth = r * 0.07
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFF8DB4E8).withValues(alpha: 0.85 * a);
            for (var k = 0; k < 3; k++) {
              final q = ((t * 0.9 + k * 0.33 + ph) % 1.0);
              final x = (k - 1) * r * 0.55;
              final y = r * 0.85 + q * r * 0.9;
              rp.color = const Color(0xFF8DB4E8)
                  .withValues(alpha: 0.85 * a * (1 - q).clamp(0.0, 1.0));
              canvas.drawLine(Offset(x, y), Offset(x - r * 0.05, y + r * 0.22), rp);
            }
          }
        }
        break;
      case 'judge':
        {
          // پشمالو
          for (var k = 0; k < 14; k++) {
            final ang = k / 14 * math.pi * 2;
            final wob = math.sin(t * 3 + k + ph) * 0.05;
            final r0 = r * 0.9, r1 = r * (1.18 + wob);
            canvas.drawLine(Offset(math.cos(ang) * r0, math.sin(ang) * r0),
                Offset(math.cos(ang) * r1, math.sin(ang) * r1),
                Paint()
                  ..strokeWidth = r * 0.16
                  ..strokeCap = StrokeCap.round
                  ..color = body.withValues(alpha: a));
          }
          canvas.drawCircle(Offset.zero, r, fill);
          canvas.drawCircle(Offset.zero, r, line);
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(-r * 0.25, -r * 0.45),
                  width: r * 0.9,
                  height: r * 0.5),
              Paint()..color = lite.withValues(alpha: 0.45 * a));
          // سه چشم که دور و بر را نگاه می‌کنند
          final lx = math.sin(t * 0.9 + ph) * 0.35;
          final ly = math.cos(t * 0.7 + ph) * 0.2;
          if (happy) {
            _eyes(canvas, r, a, 'happy', 0.42, 0.26, 0, 0);
          } else {
            final spots = <List<double>>[
              [0.0, -0.32, 0.30],
              [-0.5, -0.02, 0.22],
              [0.5, -0.02, 0.22],
            ];
            for (final q in spots) {
              final ec = Offset(q[0] * r, q[1] * r);
              final er = q[2] * r;
              canvas.drawCircle(
                  ec, er, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a));
              canvas.drawCircle(
                  ec + Offset(lx * er * 0.6, ly * er * 0.6),
                  er * 0.5,
                  Paint()..color = _ink.withValues(alpha: a));
            }
            // دهانِ نگران
            final mp = Path()
              ..moveTo(-r * 0.25, r * 0.5)
              ..quadraticBezierTo(-r * 0.12, r * 0.4, 0, r * 0.5)
              ..quadraticBezierTo(r * 0.12, r * 0.6, r * 0.25, r * 0.5);
            canvas.drawPath(
                mp,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = r * 0.07
                  ..strokeCap = StrokeCap.round
                  ..color = _ink.withValues(alpha: 0.8 * a));
          }
          _blush(canvas, r, a, 0.28);
        }
        break;
      case 'ocd':
        {
          // دوتا فرِ بالای سر
          final tuft = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.12
            ..strokeCap = StrokeCap.round
            ..color = edge.withValues(alpha: 0.9 * a);
          canvas.drawPath(
              Path()
                ..moveTo(-r * 0.15, -r * 0.9)
                ..quadraticBezierTo(-r * 0.5, -r * 1.35, -r * 0.1, -r * 1.35),
              tuft);
          canvas.drawPath(
              Path()
                ..moveTo(r * 0.2, -r * 0.92)
                ..quadraticBezierTo(r * 0.6, -r * 1.3, r * 0.3, -r * 1.4),
              tuft);
          canvas.drawCircle(Offset.zero, r, fill);
          canvas.drawCircle(Offset.zero, r, line);
          // فنرِ روی شکم
          final sp = Path();
          const turns = 2.2;
          for (var i = 0; i <= 40; i++) {
            final f = i / 40;
            final ang = f * turns * math.pi * 2 + t * 1.2;
            final rr = r * 0.42 * f;
            final pt = Offset(math.cos(ang) * rr, r * 0.38 + math.sin(ang) * rr * 0.8);
            if (i == 0) {
              sp.moveTo(pt.dx, pt.dy);
            } else {
              sp.lineTo(pt.dx, pt.dy);
            }
          }
          canvas.drawPath(
              sp,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = r * 0.07
                ..strokeCap = StrokeCap.round
                ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75 * a));
          _eyes(canvas, r, a, happy ? 'happy' : 'wide', 0.4, 0.27, 0, -0.18);
          _blush(canvas, r, a, 0.26);
        }
        break;
      default:
        {
          final o = Rect.fromCenter(
              center: Offset.zero, width: r * 2.0, height: r * 1.85);
          canvas.drawOval(o, fill);
          canvas.drawOval(o, line);
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(-r * 0.25, -r * 0.4),
                  width: r * 0.95,
                  height: r * 0.5),
              Paint()..color = lite.withValues(alpha: 0.45 * a));
          _eyes(canvas, r, a, happy ? 'happy' : 'wide', 0.4, 0.26,
              happy ? 0 : -0.35, -0.3);
          if (!happy) {
            // ابروی بالارفته
            canvas.drawLine(
                Offset(r * 0.18, -r * 0.62),
                Offset(r * 0.62, -r * 0.8),
                Paint()
                  ..strokeWidth = r * 0.08
                  ..strokeCap = StrokeCap.round
                  ..color = _ink.withValues(alpha: 0.8 * a));
          }
          _blush(canvas, r, a, 0.26);
          // علامت‌سوالِ شناور
          final qy = -r * 1.35 + math.sin(t * 2.0 + ph) * r * 0.1;
          final qp = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.14
            ..strokeCap = StrokeCap.round
            ..color = edge.withValues(alpha: 0.9 * a);
          if (!happy) {
            final q = Path()
              ..moveTo(-r * 0.22, qy - r * 0.12)
              ..cubicTo(-r * 0.22, qy - r * 0.55, r * 0.3, qy - r * 0.55,
                  r * 0.3, qy - r * 0.2)
              ..cubicTo(r * 0.3, qy + r * 0.05, 0, qy + r * 0.05, 0, qy + r * 0.3);
            canvas.drawPath(q, qp);
            canvas.drawCircle(Offset(0, qy + r * 0.55), r * 0.08,
                Paint()..color = edge.withValues(alpha: 0.9 * a));
          }
        }
        break;
    }
  }

  /// صورتِ هیولا. mode: sleepy | happy | sad | wide
  static void _eyes(Canvas canvas, double r, double a, String mode,
      double spacing, double size, double pupilDX, double dy) {
    final ey = r * (dy - 0.05);
    final er = r * size;
    for (final side in const [-1.0, 1.0]) {
      final ec = Offset(side * r * spacing, ey);
      switch (mode) {
        case 'happy':
          canvas.drawArc(
              Rect.fromCircle(center: ec + Offset(0, er * 0.3), radius: er * 0.8),
              math.pi,
              math.pi,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = r * 0.09
                ..strokeCap = StrokeCap.round
                ..color = _ink.withValues(alpha: a));
          break;
        case 'sleepy':
          canvas.drawArc(Rect.fromCircle(center: ec, radius: er), 0, math.pi, true,
              Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a));
          canvas.drawCircle(ec + Offset(0, er * 0.35), er * 0.38,
              Paint()..color = _ink.withValues(alpha: a));
          canvas.drawLine(
              ec + Offset(-er, 0),
              ec + Offset(er, 0),
              Paint()
                ..strokeWidth = r * 0.08
                ..strokeCap = StrokeCap.round
                ..color = _ink.withValues(alpha: a));
          break;
        default:
          canvas.drawCircle(
              ec, er, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a));
          canvas.drawCircle(
              ec + Offset(pupilDX * er, er * (mode == 'sad' ? 0.25 : 0.0)),
              er * 0.52,
              Paint()..color = _ink.withValues(alpha: a));
          canvas.drawCircle(ec + Offset(-er * 0.18, -er * 0.22), er * 0.16,
              Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a));
          if (mode == 'sad') {
            // ابروهای غمگین
            canvas.drawLine(
                ec + Offset(-side * er * 1.0, -er * 1.15),
                ec + Offset(side * er * 0.5, -er * 1.6),
                Paint()
                  ..strokeWidth = r * 0.07
                  ..strokeCap = StrokeCap.round
                  ..color = _ink.withValues(alpha: 0.8 * a));
          }
      }
    }
    if (mode == 'happy') {
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset(0, r * (dy + 0.38)), width: r * 0.5, height: r * 0.34),
          0,
          math.pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.08
            ..strokeCap = StrokeCap.round
            ..color = _ink.withValues(alpha: a));
    } else if (mode == 'sad') {
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset(0, r * (dy + 0.52)), width: r * 0.4, height: r * 0.28),
          math.pi,
          math.pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.07
            ..strokeCap = StrokeCap.round
            ..color = _ink.withValues(alpha: 0.85 * a));
    } else if (mode == 'wide' || mode == 'sleepy') {
      canvas.drawCircle(Offset(0, r * (dy + 0.5)), r * (mode == 'wide' ? 0.07 : 0.05),
          Paint()..color = _ink.withValues(alpha: 0.8 * a));
    }
  }

  static void _blush(Canvas canvas, double r, double a, double k) {
    final p = Paint()..color = const Color(0xFFFF8FA8).withValues(alpha: k * a);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(-r * 0.62, r * 0.25), width: r * 0.3, height: r * 0.18),
        p);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(r * 0.62, r * 0.25), width: r * 0.3, height: r * 0.18),
        p);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  انتخابِ «مانعِ ذهنی» در ویرایشِ شاخه/زیرشاخه
// ═══════════════════════════════════════════════════════════════════════════

class MonsterPicker extends StatelessWidget {
  const MonsterPicker({
    super.key,
    required this.extra,
    required this.onEdit,
    required this.ink,
    required this.muted,
    required this.accent,
  });

  final Map<String, dynamic> extra;

  /// تغییر را داخلِ setState + ذخیره اجرا می‌کند
  final void Function(VoidCallback fn) onEdit;
  final Color ink, muted, accent;

  @override
  Widget build(BuildContext context) {
    final cur = extra['monster'] is String ? extra['monster'] as String : '';
    Widget chip(String id, String label, bool sel, VoidCallback tap) {
      return ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12.5, color: ink)),
        selected: sel,
        selectedColor: accent.withValues(alpha: 0.18),
        backgroundColor: Colors.white,
        side: BorderSide(color: sel ? accent : muted.withValues(alpha: 0.3)),
        onSelected: (_) => tap(),
      );
    }

    final k = monsterKindOf(cur);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'یک مانعِ ذهنی روی مسیرِ این شاخه بگذار. با جنگ از بین نمی‌رود؛ '
          'با یک شکرگزاری، یک تمرینِ «شناخت خود» یا تمام‌کردنِ یک تایمر '
          'باهات دوست می‌شود و به‌شکل پروانه می‌رود 🦋',
          style: TextStyle(fontSize: 11, color: muted, height: 1.7),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip('', 'بدون مانع', cur.isEmpty, () {
              onEdit(() {
                extra.remove('monster');
                extra.remove('monsterAt');
              });
            }),
            for (final m in kMonsters)
              chip(m.id, '${m.emoji} ${m.name}', cur == m.id, () {
                onEdit(() {
                  extra['monster'] = m.id;
                  extra['monsterAt'] = DateTime.now().millisecondsSinceEpoch;
                  extra.remove('monsterFarewell');
                });
              }),
          ],
        ),
        if (k != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(k.hint,
                style: TextStyle(fontSize: 11, color: muted, height: 1.6)),
          ),
      ],
    );
  }
}
