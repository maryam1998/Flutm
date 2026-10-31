import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/jalali.dart' show kJalaliMonths;
import '../models/map_models.dart';
import '../theme/vazir_font.dart';
import 'draw_utils.dart' show toFa;
import 'hit_registry.dart';
import 'map_painter.dart' show mapFlowerDays, paintMapSprig;
import 'map_ops.dart' show footDoneOn, nodeFinished;

/// سبکِ نوشته‌ی تابلوهای نمای راه‌رفتن: همان فونت و فونت‌های پشتیبانِ نوشته‌های
/// نقشه، تا فارسی، لاتین و ایموجی (و پرچم) همه‌جا دیده شوند و مربعِ خالی نیفتد.
TextStyle walkTextStyle(
    {required double size,
    required Color color,
    FontWeight w = FontWeight.w600,
    double? height}) {
  return GoogleFonts.vazirmatn().copyWith(
    fontFamilyFallback: [
      ...GoogleFonts.emojiFallback,
      'Segoe UI',
      'Tahoma',
      'Noto Sans',
      'Noto Color Emoji',
      'Segoe UI Emoji',
      'Apple Color Emoji',
    ],
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
  );
}

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

  /// جای دقیقِ این غنچه/گل روی نقشه (اگر نقشه رسمش کرده باشد)
  Offset? wpos;

  /// همان شناسه‌ای که نقشه برای شکل/رنگِ این غنچه/گل به کار برده
  String get sprigId => '$actionId|$dayKey';

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
          style: walkTextStyle(size: size, color: c, w: w, height: 1.25)),
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
      final mf = mapFlowerDays(a.id);
      final fl = mf ?? _flowerDays(a, keys);
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
      if (keys.isEmpty && !fin) {
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
  final reg = HitRegistry.current;
  for (final m in marks) {
    if (!m.pending) m.wpos = reg?.markPts['${m.actionId}|${m.dayKey}'];
  }
  marks.sort((x, y) {
    final c = x.ord.compareTo(y.ord);
    return c != 0 ? c : x.seed.compareTo(y.seed);
  });
  _placeOnTwigs(marks, reg);
  return marks;
}

/// قدم‌هایی که جای دقیقشان روی نقشه معلوم نیست (مثلاً نهالِ «هنوز انجام نشده») به‌جای
/// جاده‌ی اصلی، روی خودِ شاخه‌ی خودشان می‌نشینند: قدیمی‌ترین نزدیکِ نوکِ شاخه و
/// تازه‌ترین به سمتِ ابتدای شاخه. اگر هندسه‌ی شاخه روی نقشه نبود، مثلِ قبل می‌مانند.
void _placeOnTwigs(List<WalkMark> marks, HitRegistry? reg) {
  if (reg == null || reg.twigs.isEmpty) return;
  final byAction = <String, List<WalkMark>>{};
  for (final m in marks) {
    if (m.wpos != null || m.actionId.isEmpty) continue;
    (byAction[m.actionId] ??= <WalkMark>[]).add(m);
  }
  byAction.forEach((id, list) {
    final tw = reg.twigs[id];
    if (tw == null || tw.pts.length < 2) return;
    final pts = tw.pts; // نوکِ شاخه ← ابتدای شاخه
    final cum = <double>[0.0];
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum.last + (pts[i] - pts[i - 1]).distance);
    }
    final total = cum.last;
    if (total < 8) return;
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      final f = list.length == 1 ? 0.4 : 0.2 + 0.65 * i / (list.length - 1);
      final d = total * f;
      var k = 1;
      while (k < cum.length - 1 && cum[k] < d) {
        k++;
      }
      final seg = cum[k] - cum[k - 1];
      final t = seg <= 0 ? 0.0 : ((d - cum[k - 1]) / seg).clamp(0.0, 1.0);
      final p = Offset.lerp(pts[k - 1], pts[k], t)!;
      final dir = pts[k] - pts[k - 1];
      final len = dir.distance;
      final nrm = len > 0 ? Offset(-dir.dy / len, dir.dx / len) : Offset.zero;
      final side = ((m.seed >> 3) & 1) == 0 ? 1.0 : -1.0;
      m.wpos = p + nrm * (6.0 * side);
    }
  });
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
  // آن‌هایی که جای دقیقشان روی نقشه معلوم است سرِ جای خودشان می‌مانند
  final placed = all.where((m) => m.wpos != null).toList();
  final rest = all.where((m) => m.wpos == null).toList();
  if (rest.isEmpty) return placed;
  const first = 70.0;
  final last = math.max(first + 40, roadLength - 150.0);
  const minGap = 34.0, maxGap = 110.0;
  final span = last - first;
  var keep = rest;
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
  return [...placed, ...keep];
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
  final h = m.pending ? 15.0 : (m.flower ? 34.0 : 30.0);
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

  // خودِ غنچه/گل: همان شکل و رنگی که روی نقشه دارد
  if (!m.pending) {
    paintMapSprig(c, Offset(sway * 0.3, 0), -math.pi / 2, m.flower ? 11.5 : 9.0,
        m.sprigId,
        budOnly: !m.flower, flower: m.flower);
    if (m.finished) {
      c.drawCircle(Offset(sway, -h - 4), 1.8, _f(const Color(0xFFFFD54F)));
    }
  }

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
