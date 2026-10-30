import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/jalali.dart' show kJalaliMonths;
import '../models/map_models.dart';
import 'draw_utils.dart' show toFa;
import 'map_ops.dart' show footDoneOn, nodeFinished;

/// ثبت‌های نقشه برای «نمای راه‌رفتن» 🌸
///
/// هر روزِ انجام‌شده‌ی هر شاخه/زیرشاخه‌ی یک هدف (همان چیزی که روی نقشه به‌شکل
/// غنچه/گل با تاریخ دیده می‌شود) اینجا یک «نشانه» می‌شود و به ترتیبِ تاریخ
/// کنارِ جاده‌ی همان هدف می‌نشیند: قدیمی‌ترین نزدیکِ «من»، تازه‌ترین نزدیکِ هدف.
class WalkMark {
  WalkMark({
    required this.dayKey,
    required this.ord,
    required this.title,
    required this.note,
    required this.minutes,
    required this.flower,
    required this.finished,
    required this.seed,
    required this.color,
    this.pending = false,
    this.hostId = '',
    this.actionId = '',
  });

  /// شناسه‌ی هدف/حلقه‌ی صاحبِ شاخه و شناسه‌ی خودِ شاخه (برای بازکردنِ تقویمِ آن)
  final String hostId, actionId;

  /// شاخه/زیرشاخه‌ای که هنوز هیچ روزی برایش انجام نشده (نهالِ منتظر)
  final bool pending;

  /// کلیدِ روزِ جلالی (مثل ۱۴۰۵-۷-۲۰)
  final String dayKey;
  final int ord;

  /// نامِ شاخه/زیرشاخه
  final String title;

  /// یادداشتِ همان روز (می‌تواند خالی باشد)
  final String note;

  /// دقیقه‌های ثبت‌شده‌ی همان روز
  final int minutes;

  /// گل (true) یا غنچه (false)
  final bool flower;

  /// کارِ «کاملاً تمام شد»
  final bool finished;
  final int seed;
  final Color color;

  /// جای نشانه روی جاده (فاصله از ابتدای جاده) و سمتِ آن (+۱ / -۱)
  double sd = 0;
  double side = 1;

  String get dateLabel {
    if (pending) return 'هنوز انجام نشده';
    final p = dayKey.split('-');
    final jm = p.length == 3 ? int.tryParse(p[1]) : null;
    final jd = p.length == 3 ? int.tryParse(p[2]) : null;
    if (jm == null || jd == null || jm < 1 || jm > 12) return dayKey;
    return '${toFa(jd)} ${kJalaliMonths[jm - 1]}';
  }

  String get fullDateLabel {
    if (pending) return dateLabel;
    final p = dayKey.split('-');
    final jy = p.length == 3 ? int.tryParse(p[0]) : null;
    return jy == null ? dateLabel : '$dateLabel ${toFa(jy)}';
  }

  String get minutesLabel {
    if (minutes <= 0) return '';
    if (minutes < 60) return '${toFa(minutes)} دقیقه';
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '${toFa(h)} ساعت' : '${toFa(h)} ساعت و ${toFa(m)} دقیقه';
  }

  // کشِ متن‌ها (فقط یک‌بار چیده می‌شوند)
  TextPainter? _dateTp, _titleTp, _noteTp;

  TextPainter _tp(String text, double size, Color c,
      {FontWeight w = FontWeight.w600, int maxLines = 1, double maxW = 120}) {
    return TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: c, fontSize: size, fontWeight: w, height: 1.25)),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxW);
  }

  TextPainter get dateTp => _dateTp ??= _tp(
      minutes > 0 ? '$dateLabel · $minutesLabel' : dateLabel,
      9,
      const Color(0xFF3B3F57),
      w: FontWeight.w700,
      maxW: 130);
  TextPainter get titleTp => _titleTp ??=
      _tp(title.isEmpty ? 'کار' : title, 9, const Color(0xFF1F2937), maxW: 130);
  TextPainter? get noteTp {
    if (note.isEmpty) return null;
    return _noteTp ??= _tp(note.replaceAll('\n', ' '), 8.2,
        const Color(0xFF4B5563),
        w: FontWeight.w500, maxLines: 3, maxW: 130);
  }
}

int _ordOf(String jk) {
  final p = jk.split('-').map((e) => int.tryParse(e) ?? 0).toList();
  if (p.length != 3) return 0;
  const cum = [0, 31, 62, 93, 124, 155, 186, 216, 246, 276, 306, 336];
  return p[0] * 365 + cum[p[1].clamp(1, 12) - 1] + p[2];
}

String _noteOf(ActionNode a, String dk) {
  final all = a.extra['footNotes'];
  if (all is Map && all[dk] is String) {
    final s = (all[dk] as String).trim();
    if (s.isNotEmpty) return s;
  }
  final l = a.logs[dk];
  if (l is String && l.trim().isNotEmpty && l != 'انجام شد ✓') {
    return l.trim();
  }
  final e = a.entries[dk];
  if (e is List) {
    final out = <String>[];
    for (final x in e) {
      if (x is Map && x['note'] is String) {
        final s = (x['note'] as String).trim();
        if (s.isNotEmpty) out.add(s);
      }
    }
    if (out.isNotEmpty) return out.join(' · ');
  }
  return '';
}

int _hash(String s) {
  var h = 7;
  for (final u in s.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return h;
}

/// روزهایی که غنچه‌شان گل می‌شود (همان قاعده‌ی نقشه: در هر ۳ روزِ پشت‌سرهم یکی)
Set<String> _flowerDays(ActionNode a, List<String> sortedDone) {
  final out = <String>{};
  if (sortedDone.length < 3) return out;
  final run = <String>[];
  var prev = -999;
  void flush() {
    for (var g = 0; g + 3 <= run.length; g += 3) {
      final grp = run.sublist(g, g + 3);
      out.add(grp[_hash('${a.id}|fl|${run[g]}') % grp.length]);
    }
    run.clear();
  }

  for (final k in sortedDone) {
    final o = _ordOf(k);
    if (prev != -999 && o != prev + 1) flush();
    run.add(k);
    prev = o;
  }
  flush();
  return out;
}

/// جای یک نشانه روی صفحه (برای لمسِ طولانی)؛ painter در هر فریم پرش می‌کند
class WalkHit {
  WalkHit(this.mark, this.rect, this.sc);
  final WalkMark mark;
  final Rect rect;
  final double sc;
}

/// آیا خودِ این شاخه یا یکی از زیرشاخه‌هایش روزی انجام شده؟
bool _anyDone(ActionNode a) {
  final own = <String>{...a.logs.keys, ...a.time.keys, ...a.entries.keys};
  if (own.any((k) => footDoneOn(a, k))) return true;
  return a.children.any(_anyDone);
}

/// همه‌ی ثبت‌های یک هدف (و حلقه‌های «نزدیک شدن به هدف»ش) به ترتیبِ تاریخ
List<WalkMark> collectWalkMarks(MapState s, Goal g) {
  final marks = <WalkMark>[];

  void walk(List<ActionNode> list, Color base, String hostId) {
    for (final a in list) {
      final col = (a.color != null && a.color!.isNotEmpty)
          ? _hex(a.color!, base)
          : base;
      final keys = <String>{...a.logs.keys, ...a.time.keys, ...a.entries.keys}
          .where((k) => footDoneOn(a, k))
          .toList()
        ..sort((x, y) => _ordOf(x).compareTo(_ordOf(y)));
      final fl = _flowerDays(a, keys);
      final fin = nodeFinished(a);
      for (var i = 0; i < keys.length; i++) {
        final dk = keys[i];
        final secs = (a.time[dk] as num?)?.toDouble() ?? 0.0;
        final last = i == keys.length - 1;
        marks.add(WalkMark(
          dayKey: dk,
          ord: _ordOf(dk),
          title: a.text.trim(),
          note: _noteOf(a, dk),
          minutes: (secs / 60).round(),
          flower: fl.contains(dk) || (fin && last),
          finished: fin && last,
          seed: _hash('${a.id}|$dk'),
          color: col,
          hostId: hostId,
          actionId: a.id,
        ));
      }
      // شاخه‌ای که هنوز انجام نشده هم کنارِ جاده دیده می‌شود (نهالِ منتظر)
      if (keys.isEmpty && !fin && a.text.trim().isNotEmpty && !_anyDone(a)) {
        marks.add(WalkMark(
          dayKey: '',
          ord: 1 << 30,
          title: a.text.trim(),
          note: '',
          minutes: 0,
          flower: false,
          finished: false,
          seed: _hash('${a.id}|pending'),
          color: col,
          pending: true,
          hostId: hostId,
          actionId: a.id,
        ));
      }
      walk(a.children, col, hostId);
    }
  }

  final base = _hex(g.color ?? '', const Color(0xFFE5484D));
  walk(g.actions, base, g.id);
  for (final r in s.ringsOfGoal(g)) {
    walk(r.actions, _hex(r.color, base), r.id);
  }
  marks.sort((x, y) {
    final c = x.ord.compareTo(y.ord);
    return c != 0 ? c : x.seed.compareTo(y.seed);
  });
  return marks;
}

Color _hex(String h, Color def) {
  var s = h.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  if (s.length != 6) return def;
  final v = int.tryParse(s, radix: 16);
  return v == null ? def : Color(0xFF000000 | v);
}

/// نشانه‌ها را روی جاده می‌چیند: قدیمی‌ترین نزدیکِ «من»، تازه‌ترین نزدیکِ هدف.
/// اگر خیلی زیاد بودند، تازه‌ترین‌ها نگه داشته می‌شوند.
List<WalkMark> layoutWalkMarks(List<WalkMark> all, double roadLength) {
  if (all.isEmpty) return const [];
  const first = 70.0;
  final last = math.max(first + 40, roadLength - 150.0);
  const minGap = 34.0, maxGap = 110.0;
  final span = last - first;
  var keep = all;
  final cap = (span / minGap).floor() + 1;
  if (keep.length > cap) keep = keep.sublist(keep.length - cap);
  final gap = keep.length <= 1
      ? 0.0
      : (span / (keep.length - 1)).clamp(minGap, maxGap).toDouble();
  const startAt = first;
  for (var i = 0; i < keep.length; i++) {
    final m = keep[i];
    m.sd = startAt + gap * i;
    m.side = ((m.seed >> 3) & 1) == 0 ? 1.0 : -1.0;
    if (i > 0 && keep[i - 1].side == m.side && (m.seed & 3) != 0) {
      m.side = -m.side; // کم‌وبیش یکی‌درمیان؛ نه خیلی منظم
    }
  }
  return keep;
}

/// نزدیک‌ترین نشانه به جای فعلیِ دوربین (برای کارتِ توضیح)
WalkMark? nearestMark(List<WalkMark> marks, double d, {double within = 38}) {
  WalkMark? best;
  var bd = within;
  for (final m in marks) {
    final x = (m.sd - d).abs();
    if (x < bd) {
      bd = x;
      best = m;
    }
  }
  return best;
}

// ───────────────────────── رسم ─────────────────────────

final Paint _wp = Paint();

Paint _f(Color c) => _wp
  ..style = PaintingStyle.fill
  ..shader = null
  ..color = c;

Paint _s(Color c, double w) => _wp
  ..style = PaintingStyle.stroke
  ..shader = null
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..color = c;

/// رسمِ یک نشانه. مبدأ = پای ساقه روی زمین؛ [sc] = مقیاسِ دورنما؛
/// [near] = نزدیکی (۰ دور … ۱ نزدیک) برای نمایشِ نوشته‌ها.
void drawWalkMark(Canvas c, WalkMark m, double x, double y, double sc,
    double t, bool dark, double near) {
  c.save();
  c.translate(x, y);
  c.scale(sc, sc);

  // سایه
  c.drawOval(Rect.fromCenter(center: const Offset(0, 1), width: 26, height: 5),
      _f(const Color(0x30000000)));

  final sway = math.sin(t * 1.3 + m.seed * 0.01) * 1.6;
  final h = m.pending ? 15.0 : (m.flower ? 30.0 : 25.0);
  final stemC = dark ? const Color(0xFF3F9B5B) : const Color(0xFF2E7D32);
  final leafC = dark ? const Color(0xFF5FBF7A) : const Color(0xFF66BB6A);

  if (m.pending) {
    // نهالِ کم‌رنگ: هنوز کاری ثبت نشده
    final pc = Color.lerp(m.color, const Color(0xFF9CA3AF), 0.45)!;
    final sp = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-1.5 + sway * 0.3, -h * 0.5, sway, -h);
    c.drawPath(sp, _s(stemC.withValues(alpha: 0.6), 1.8));
    for (final sgn in const [-1.0, 1.0]) {
      c.save();
      c.translate(sway * 0.5, -h * 0.7);
      c.rotate(sgn * 0.9);
      final lp = Path()
        ..moveTo(0, 0)
        ..cubicTo(3, -2, 3.2, -6, 0, -8)
        ..cubicTo(-3.2, -6, -3, -2, 0, 0);
      c.drawPath(lp, _f(leafC.withValues(alpha: 0.65)));
      c.restore();
    }
    c.drawCircle(Offset(sway, -h - 2), 3.4, _f(pc.withValues(alpha: 0.75)));
    c.drawCircle(Offset(sway, -h - 2), 3.4,
        _s(const Color(0xFF9CA3AF), 0.9));
  }

  // ساقه
  final top = Offset(sway, -h);
  final p = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(-3 + sway * 0.4, -h * 0.55, top.dx, top.dy);
  if (!m.pending) c.drawPath(p, _s(stemC, 2.2));

  // دو برگ
  for (final sgn in m.pending ? const <double>[] : const [-1.0, 1.0]) {
    final ly = -h * (sgn < 0 ? 0.35 : 0.52);
    c.save();
    c.translate(sway * 0.3 * (-ly / h), ly);
    c.rotate(sgn * 0.95);
    final lp = Path()
      ..moveTo(0, 0)
      ..cubicTo(4, -3, 4.5, -8, 0, -11)
      ..cubicTo(-4.5, -8, -4, -3, 0, 0);
    c.drawPath(lp, _f(leafC));
    c.restore();
  }

  // سر: گل یا غنچه
  c.save();
  c.translate(top.dx, top.dy);
  if (m.pending) {
    // سرِ نهال بالاتر کشیده شده است
  } else if (m.flower) {
    final pc = m.color;
    for (var i = 0; i < 6; i++) {
      c.save();
      c.rotate(i * math.pi / 3 + sway * 0.02);
      c.drawOval(Rect.fromCenter(center: const Offset(0, -5), width: 6.4, height: 9.5),
          _f(Color.lerp(pc, Colors.white, 0.18)!));
      c.restore();
    }
    c.drawCircle(Offset.zero, 3.1, _f(const Color(0xFFFFC83D)));
    c.drawCircle(const Offset(-0.8, -0.8), 1.1, _f(const Color(0xAAFFFFFF)));
    if (m.finished) {
      // تاجِ کوچکِ «کاملاً تمام شد»
      c.drawCircle(const Offset(0, -15), 1.6, _f(const Color(0xFFFFD54F)));
    }
  } else {
    final bud = Path()
      ..moveTo(0, 2)
      ..cubicTo(5.2, -1, 5, -8, 0, -12.5)
      ..cubicTo(-5, -8, -5.2, -1, 0, 2);
    c.drawPath(bud, _f(Color.lerp(m.color, Colors.white, 0.1)!));
    final inner = Path()
      ..moveTo(0, 1)
      ..cubicTo(2.4, -2, 2.3, -7, 0, -10.5)
      ..cubicTo(-0.3, -7, -1, -2, 0, 1);
    c.drawPath(inner, _f(Color.lerp(m.color, Colors.white, 0.4)!));
    // کاسبرگ
    final cal = Path()
      ..moveTo(-4, 1)
      ..quadraticBezierTo(0, -4, 4, 1)
      ..quadraticBezierTo(0, 2.6, -4, 1);
    c.drawPath(cal, _f(stemC));
  }
  c.restore();

  // تابلوی تاریخ/نام/یادداشت (فقط وقتی نزدیک است تا شلوغ نشود)
  if (near > 0.02) {
    final a = near.clamp(0.0, 1.0);
    final dtp = m.dateTp, ttp = m.titleTp, ntp = m.noteTp;
    final w = math.max(dtp.width, math.max(ttp.width, ntp?.width ?? 0)) + 14;
    final hh = dtp.height + ttp.height + (ntp != null ? ntp.height + 2 : 0) + 9;
    final by = -h - 20 - hh;
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(-w / 2 + sway, by, w, hh), const Radius.circular(6));
    c.saveLayer(
        Rect.fromLTWH(-w / 2 - 4 + sway, by - 4, w + 8, hh + 8),
        Paint()..color = Color.fromRGBO(0, 0, 0, a));
    // پایه‌ی تابلو
    c.drawLine(Offset(sway, by + hh), Offset(sway * 0.5, -h - 14),
        _s(const Color(0xFF6B4423), 1.4));
    c.drawRRect(r, _f(const Color(0xF0FFFDF5)));
    c.drawRRect(
        r, _s(m.pending ? const Color(0xFF9CA3AF) : const Color(0xFFC9962B), 1.4));
    var yy = by + 4.5;
    void put(TextPainter tp) {
      tp.paint(c, Offset(-tp.width / 2 + sway, yy));
      yy += tp.height + 1;
    }

    put(dtp);
    put(ttp);
    if (ntp != null) put(ntp);
    c.restore();
  }
  c.restore();
}
