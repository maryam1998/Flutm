import 'dart:math' as math;

import 'package:flutter/foundation.dart' show StringCharacters;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/constants.dart' show hexColor;
import '../map/map_ops.dart' show nodeFinished;
import '../map/map_painter.dart' show MapPainter;
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../services/quiet_snack.dart';
import '../state/goal_ops.dart' show collectNodes;
import '../state/map_store.dart';
import '../theme/web_palette.dart';

/// 🌳 باغچه: هدف‌های رسیده‌شده را می‌شود به‌صورت درخت (با شاخه، زیرشاخه، گل، غنچه و
/// برگ) در باغچه‌ی بالای نقشه کاشت. وضعیت در `Goal.extra['planted']` می‌ماند.

bool goalPlanted(Goal g) => g.extra['planted'] == true;

// ───────────────────────── کاشتن / برداشتن ─────────────────────────

/// پرسشِ کاشتن (با پیش‌نمایشِ درخت روی خاک). بله = درخت در باغچه‌ی بالای نقشه.
Future<void> plantGoalInGarden(
    BuildContext context, MapStore store, Goal g) async {
  if (goalPlanted(g)) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('کاشتنِ درخت در باغچه 🌱'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 170,
              width: 200,
              child: GoalTreeView(goal: g, animate: false),
            ),
            const SizedBox(height: 8),
            Text(
              'هدفِ «${g.name.isEmpty ? 'بدون نام' : g.name}» با همه‌ی شاخه‌ها، '
              'زیرشاخه‌ها، گل‌ها و برگ‌هایش به‌صورت یک درخت در باغچه‌ی بالای '
              'نقشه کاشته می‌شود.',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.8, fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('فعلاً نه')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بکار 🌳')),
      ],
    ),
  );
  if (ok != true) return;
  GardenStrip.collapsed.value = false;
  void doPlant() {
    g.extra['planted'] = true;
    g.extra['plantedAt'] = DateTime.now().millisecondsSinceEpoch;
    store.changed();
  }

  if (!context.mounted) {
    doPlant();
    return;
  }
  // آدمک درخت (با همه‌ی شاخه و زیرشاخه‌هایش) را برمی‌دارد، تا باغچه می‌برد و می‌کارد
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    doPlant();
    return;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: IgnorePointer(
        child: _PlantingWalk(
          goal: g,
          onPlanted: doPlant,
          onDone: () => entry.remove(),
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

// ───────────────────────── آدمک درخت را می‌برد و می‌کارد ─────────────────────────

class _PlantingWalk extends StatefulWidget {
  const _PlantingWalk(
      {required this.goal, required this.onPlanted, required this.onDone});
  final Goal goal;
  final VoidCallback onPlanted, onDone;

  @override
  State<_PlantingWalk> createState() => _PlantingWalkState();
}

class _PlantingWalkState extends State<_PlantingWalk>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _planted = false;

  static const double _kPlantAt = 0.74;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4800))
      ..addListener(() {
        if (!_planted && _c.value >= _kPlantAt) {
          _planted = true;
          widget.onPlanted();
        }
      })
      ..addStatusListener((st) {
        if (st == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _WalkPainter(widget.goal, _c.value, mq.size, mq.padding.top),
      ),
    );
  }
}

class _WalkPainter extends CustomPainter {
  _WalkPainter(this.g, this.t, this.screen, this.topInset);
  final Goal g;
  final double t;
  final Size screen;
  final double topInset;

  static const double _walkEnd = 0.55;
  static const double _plantAt = 0.74;
  static const double _treeW = 92, _treeH = 104;

  @override
  void paint(Canvas canvas, Size size) {
    // جای درخت در باغچه: ابتدای نوار (سمت راست در صفحه‌ی راست‌به‌چپ)
    final spot = Offset(screen.width - 8 - 8 - 46, topInset + 58 + 30 + 80);
    final stand = spot + const Offset(0, 46);
    final start = Offset(screen.width * 0.5, screen.height * 0.78);
    final ctl = Offset(
        (start.dx + stand.dx) / 2 - 70, (start.dy + stand.dy) / 2);

    Offset q(double u) {
      final v = 1 - u;
      return Offset(v * v * start.dx + 2 * v * u * ctl.dx + u * u * stand.dx,
          v * v * start.dy + 2 * v * u * ctl.dy + u * u * stand.dy);
    }

    final walkT = (t / _walkEnd).clamp(0.0, 1.0).toDouble();
    final e = Curves.easeInOut.transform(walkT);
    var pos = q(e);
    var heading = math.atan2(q(math.min(1.0, e + 0.02)).dy - q(math.max(0.0, e - 0.02)).dy,
        q(math.min(1.0, e + 0.02)).dx - q(math.max(0.0, e - 0.02)).dx);
    var opacity = (t / 0.06).clamp(0.0, 1.0).toDouble();
    final moving = walkT < 1.0 || t > 0.8;
    var phase = walkT * 14.0;

    // بعد از کاشتن: آدمک به عقب برمی‌گردد و محو می‌شود
    if (t > 0.8) {
      final u = ((t - 0.8) / 0.2).clamp(0.0, 1.0).toDouble();
      pos = stand + Offset(0, 90 * u);
      heading = math.pi / 2;
      opacity = 1 - u;
      phase = u * 8;
    } else if (walkT >= 1.0) {
      heading = -math.pi / 2;
    }

    // خاک و درخت (تا لحظه‌ی کاشت)
    if (t < _plantAt) {
      final plantU = ((t - _walkEnd) / (_plantAt - _walkEnd)).clamp(0.0, 1.0).toDouble();
      final carried = pos + const Offset(0, -46);
      final treeAt = Offset.lerp(carried, spot, 0.0)!;
      final sc = 0.5 + 0.4 * Curves.easeOut.transform(plantU);
      canvas.save();
      canvas.translate(treeAt.dx, treeAt.dy - _treeH * 0.8 * sc);
      canvas.translate(0, 0);
      canvas.scale(sc);
      canvas.translate(-_treeW / 2, 0);
      _GoalTreePainter(g, 1.0, soil: plantU)
          .paint(canvas, const Size(_treeW, _treeH));
      canvas.restore();
    }

    if (opacity <= 0.01) return;
    _walker(canvas, pos, heading, phase, moving, opacity);
  }

  /// آدمک از بالا: دایره (سر و بدن) + دو پا که یکی‌درمیان جلو می‌روند
  void _walker(Canvas canvas, Offset c, double heading, double phase,
      bool moving, double opacity) {
    final col = hexColor(g.color, const Color(0xFF3E9B4F));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(heading);
    final sw = moving ? math.sin(phase) : 0.0;
    final foot = Paint()..color = const Color(0xFF3B2A1A).withValues(alpha: 0.8 * opacity);
    for (final side in const [-1.0, 1.0]) {
      final off = side * sw * 7;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(off, side * 6), width: 11, height: 5.5),
          foot);
    }
    canvas.restore();
    canvas.drawCircle(c + const Offset(0, 2), 13, Paint()..color = Colors.black.withValues(alpha: 0.18 * opacity));
    canvas.drawCircle(c, 13, Paint()..color = col.withValues(alpha: opacity));
    canvas.drawCircle(
        c,
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.9 * opacity));
    final icon = g.icon.characters.take(2).toString();
    if (icon.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
            text: icon,
            style: TextStyle(
                fontSize: 14, color: Colors.white.withValues(alpha: opacity))),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _WalkPainter old) => true;
}

void _unplant(MapStore store, Goal g) {
  g.extra.remove('planted');
  g.extra.remove('plantedAt');
  store.changed();
}

// ───────────────────────── نوار باغچه ─────────────────────────

class GardenStrip extends StatelessWidget {
  const GardenStrip({super.key});

  /// بازه/جمع‌شدنِ نوار (فقط برای همین اجرا)
  static final ValueNotifier<bool> collapsed = ValueNotifier<bool>(false);

  static const double _kOpenH = 140;
  static const double _kClosedH = 36;

  /// ارتفاعی که نوار از بالای صفحه می‌گیرد (برای پایین‌تر بردنِ کارتِ «قدم بعدی»)
  static double inset(MapStore s) {
    if (!s.state.goals.any((g) => g.reached && goalPlanted(g))) return 0;
    return collapsed.value ? _kClosedH : _kOpenH;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MapStore>();
    final planted = store.state.goals
        .where((g) => g.reached && goalPlanted(g))
        .toList()
      // تازه‌ترین درخت اول (ابتدای نوار)، همان‌جایی که آدمک می‌کارد
      ..sort((a, b) => ((b.extra['plantedAt'] as num?) ?? 0)
          .compareTo((a.extra['plantedAt'] as num?) ?? 0));
    if (planted.isEmpty) return const SizedBox.shrink();
    final wp = WebPalette.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: collapsed,
      builder: (_, closed, __) => Container(
        decoration: BoxDecoration(
          color: wp.panelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: wp.panelBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => collapsed.value = !closed,
              child: SizedBox(
                height: 30,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Text('🌳 باغچه‌ی من',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: wp.textMain)),
                      const SizedBox(width: 6),
                      Text(toFa(planted.length),
                          style: TextStyle(fontSize: 11, color: wp.textDim)),
                      const Spacer(),
                      Icon(closed ? Icons.expand_more : Icons.expand_less,
                          size: 18, color: wp.textDim),
                    ],
                  ),
                ),
              ),
            ),
            if (!closed)
              SizedBox(
                height: 104,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: planted.length,
                  itemBuilder: (ctx, i) {
                    final g = planted[i];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showTreeSheet(ctx, store, g),
                      child: SizedBox(
                        width: 92,
                        child: Stack(
                          children: [
                            Positioned.fill(
                                child: GoalTreeView(
                                    key: ValueKey(g.id), goal: g)),
                            Positioned(
                              left: 4,
                              right: 4,
                              bottom: 1,
                              child: Text(
                                g.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                          color: Color(0xAA000000),
                                          blurRadius: 3)
                                    ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── برگهٔ جزئیاتِ درخت ─────────────────────────

void _showTreeSheet(BuildContext context, MapStore store, Goal g) {
  var when = '';
  final ra = g.extra['reachedAt'];
  if (ra is num) {
    final d = DateTime.fromMillisecondsSinceEpoch(ra.toInt());
    final j = toJalaali(d.year, d.month, d.day);
    when = 'رسیدن به هدف: ${toFa(j.jy)}/${toFa(j.jm)}/${toFa(j.jd)}';
  }
  final all = collectNodes(g.actions);
  final fin = all.where(nodeFinished).length;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE4E6EE),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            SizedBox(
                height: 210,
                width: 260,
                child: GoalTreeView(goal: g, animate: false)),
            const SizedBox(height: 8),
            Text(g.name.isEmpty ? 'بدون نام' : g.name,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black)),
            if (when.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(when,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF5B5F77))),
              ),
            const SizedBox(height: 6),
            Text(
              '${toFa(g.actions.length)} شاخه · ${toFa(all.length)} گره · '
              '${toFa(fin)} کارِ تمام‌شده (گل)',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5B5F77)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'می‌توانی همین درخت را در یک باغچه‌ی واقعی هم بکاری 🌿\n'
                'کاشتنِ یک نهالِ واقعی، یادگارِ ماندگاری از مسیری است که تا '
                'رسیدن به این هدف رفته‌ای.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    height: 1.9, fontSize: 12.5, color: Color(0xFF1B5E3C)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _unplant(store, g);
              },
              child: const Text('برداشتن از باغچه',
                  style: TextStyle(color: Color(0xFF5B5F77))),
            ),
          ],
        ),
      ),
    ),
  );
}

// ───────────────────────── نمایشِ درخت ─────────────────────────

/// درختِ یک هدف روی خاک. اگر همین الان کاشته شده باشد، درخت کم‌کم از خاک رشد می‌کند.
class GoalTreeView extends StatefulWidget {
  const GoalTreeView({super.key, required this.goal, this.animate = true});
  final Goal goal;
  final bool animate;

  @override
  State<GoalTreeView> createState() => _GoalTreeViewState();
}

class _GoalTreeViewState extends State<GoalTreeView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final at = (widget.goal.extra['plantedAt'] as num?)?.toInt() ?? 0;
    final fresh = widget.animate &&
        at > 0 &&
        DateTime.now().millisecondsSinceEpoch - at < 6000;
    _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
        value: fresh ? 0.0 : 1.0);
    if (fresh) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        painter: _GoalTreePainter(
            widget.goal, Curves.easeOutBack.transform(_c.value)),
        size: Size.infinite,
      ),
    );
  }
}

class _GoalTreePainter extends CustomPainter {
  _GoalTreePainter(this.g, this.grow, {this.soil = 1.0});
  final Goal g;
  final double grow;

  /// ۰..۱: اندازه‌ی تپه‌ی خاک (هنگام کاشتن از صفر بزرگ می‌شود)
  final double soil;

  static const _wood = Color(0xFF7A5230);
  static const _twig = Color(0xFF5E8F3E);

  int get _seed {
    var h = 7;
    for (final u in g.id.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return h;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = Offset(w / 2, h * 0.80);
    if (soil > 0.02) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.scale(soil);
      canvas.translate(-base.dx, -base.dy);
      _soil(canvas, w, h, base);
      canvas.restore();
    }
    final k = grow.clamp(0.0, 1.15).toDouble();
    if (k <= 0.03) return;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(k);
    _tree(canvas, h * 0.74);
    canvas.restore();
  }

  void _soil(Canvas canvas, double w, double h, Offset base) {
    final rect = Rect.fromCenter(
        center: Offset(base.dx, base.dy + h * 0.045),
        width: w * 0.9,
        height: h * 0.2);
    canvas.drawOval(
        rect.shift(const Offset(0, 2)), Paint()..color = const Color(0x33000000));
    canvas.drawOval(
        rect,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF9A6B45), Color(0xFF5B3B25)]).createShader(rect));
    // سنگ‌ریزه و ذره‌های خاک
    var s = _seed % 2147483646 + 1;
    double rnd() {
      s = (s * 48271) % 2147483647;
      return s / 2147483647.0;
    }

    for (var i = 0; i < 9; i++) {
      final x = rect.left + rect.width * (0.12 + 0.76 * rnd());
      final y = rect.top + rect.height * (0.25 + 0.55 * rnd());
      canvas.drawCircle(Offset(x, y), 0.8 + rnd() * 1.4,
          Paint()..color = const Color(0x553B2514));
    }
    // علف‌های کوچک روی لبه‌ی خاک
    final grass = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final t = 0.1 + 0.8 * rnd();
      final x = rect.left + rect.width * t;
      final y = rect.center.dy -
          rect.height * 0.5 * math.sqrt(math.max(0, 1 - math.pow(2 * t - 1, 2))) +
          1;
      canvas.drawLine(Offset(x, y), Offset(x - 1.5, y - 4 - rnd() * 3), grass);
      canvas.drawLine(Offset(x, y), Offset(x + 1.5, y - 3 - rnd() * 3), grass);
    }
  }

  void _leaf(Canvas canvas, Offset p, double ang, double len, Color c) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(ang);
    final w = len * 0.42;
    final lp = Path()
      ..moveTo(0, 0)
      ..cubicTo(w, -len * 0.25, w * 0.8, -len * 0.8, 0, -len)
      ..cubicTo(-w * 0.8, -len * 0.8, -w, -len * 0.25, 0, 0);
    canvas.drawPath(lp, Paint()..color = c);
    canvas.drawPath(
        lp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = const Color(0x33000000));
    canvas.restore();
  }

  void _tree(Canvas canvas, double H) {
    final sd = _seed;
    final sway = ((sd & 1) == 0 ? 1.0 : -1.0) * H * 0.05;
    final trunkH = H * 0.46;
    Offset trunkPt(double f) =>
        Offset(sway * f * f, -trunkH * f);

    // تنه
    final tp = Paint()
      ..color = _wood
      ..strokeCap = StrokeCap.round;
    const segs = 10;
    for (var i = 0; i < segs; i++) {
      tp.strokeWidth = H * (0.075 - 0.04 * i / segs);
      canvas.drawLine(trunkPt(i / segs), trunkPt((i + 1) / segs), tp);
    }

    final nodes = g.actions.where((a) => a.extra['hidden'] != true).take(6).toList();
    final n = nodes.length;
    for (var i = 0; i < n; i++) {
      final f = n == 1 ? 0.8 : 0.3 + 0.62 * i / (n - 1);
      final side = i.isEven ? 1.0 : -1.0;
      final ang = side * (0.55 + 0.35 * (1 - f));
      final len = H * 0.34 * (1 - 0.38 * f);
      _branch(canvas, trunkPt(f), ang, len, nodes[i], 0, H);
    }
    // برگ‌های تاج + میوه‌ی طلاییِ هدف روی نوکِ تنه
    final top = trunkPt(1.0);
    final lc = const [Color(0xFF3E9B4F), Color(0xFF6FCF97), Color(0xFF2E7D32)];
    for (var i = 0; i < 5; i++) {
      _leaf(canvas, top, -0.9 + i * 0.45, H * 0.16, lc[(sd + i) % 3]);
    }
    _fruit(canvas, top + Offset(0, -H * 0.06), H * 0.075);
  }

  void _fruit(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c + const Offset(0, 1.5), r, Paint()..color = const Color(0x33000000));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
              center: Alignment(-0.3, -0.4),
              colors: [Color(0xFFFFE08A), Color(0xFFE8A33D)]).createShader(rect));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0x55000000));
    final icon = g.icon.characters.take(2).toString();
    if (icon.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(text: icon, style: TextStyle(fontSize: r * 1.25)),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  /// شاخه + برگ‌های کنارش + حداکثر ۳ زیرشاخه (عمقِ ۱) و نشانِ وضعیت روی نوک:
  /// تمام‌شده = گل، شروع‌شده = غنچه، هنوز نه = برگ
  void _branch(Canvas canvas, Offset p0, double ang, double len, ActionNode a,
      int depth, double H) {
    final d = Offset(math.sin(ang), -math.cos(ang));
    final end = p0 + d * len + Offset(0, -len * 0.15);
    final c = p0 + d * (len * 0.5);
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = depth == 0 ? H * 0.032 : H * 0.02
          ..color = depth == 0 ? _wood : _twig);

    Offset at(double t) {
      final u = 1 - t;
      return Offset(u * u * p0.dx + 2 * u * t * c.dx + t * t * end.dx,
          u * u * p0.dy + 2 * u * t * c.dy + t * t * end.dy);
    }

    final gc = const [Color(0xFF3E9B4F), Color(0xFF6FCF97), Color(0xFF2E7D32)];
    for (var i = 0; i < 2; i++) {
      final t = 0.45 + 0.3 * i;
      final s = (i.isEven ? 1.0 : -1.0);
      _leaf(canvas, at(t), ang + s * 1.0, H * (depth == 0 ? 0.11 : 0.08),
          gc[(a.id.length + i) % 3]);
    }

    if (depth == 0) {
      final kids = a.children.where((k) => k.extra['hidden'] != true).take(3).toList();
      for (var j = 0; j < kids.length; j++) {
        final t = 0.4 + 0.2 * j;
        final s = (j.isEven ? 1.0 : -1.0);
        _branch(canvas, at(t), ang + s * 0.8, len * 0.5, kids[j], 1, H);
      }
    }

    final tdir = math.atan2(end.dy - c.dy, end.dx - c.dx);
    final r = H * (depth == 0 ? 0.075 : 0.055);
    if (nodeFinished(a)) {
      MapPainter.sprigAt(canvas, end, tdir, r, a.id, 1.0, flower: true);
    } else if (a.logs.isNotEmpty || a.time.isNotEmpty || a.entries.isNotEmpty) {
      MapPainter.sprigAt(canvas, end, tdir, r, a.id, 1.0, budOnly: true);
    } else {
      _leaf(canvas, end, ang - 0.4, r * 1.6, gc[a.id.length % 3]);
      _leaf(canvas, end, ang + 0.4, r * 1.6, gc[(a.id.length + 1) % 3]);
    }
  }

  @override
  bool shouldRepaint(covariant _GoalTreePainter old) =>
      true;
}
