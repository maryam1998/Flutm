import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/map_models.dart';
import '../screens/add_goal_dialog.dart';
import '../screens/goals_sheet.dart';
import 'draw_utils.dart' show toFa;
import 'hit_registry.dart';
import 'walk_marks.dart';
import 'world_painter.dart';

/// نمای اول‌شخص: کاربر روی جاده‌ی یکی از هدف‌هایش راه می‌رود و دورتادورِ خودش
/// را (۳۶۰ درجه، با انگشت) می‌بیند؛ انگار خودِ انیمیشنِ پا روی مسیر است.
Future<void> openWalkView(BuildContext context, MapState state) async {
  void say(String m) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  if (state.goals.isEmpty) {
    say('اول یک هدف بساز تا جاده‌اش را قدم بزنی 🚶');
    return;
  }
  Goal? g;
  if (state.goals.length == 1) {
    g = state.goals.first;
  } else {
    g = await showModalBottomSheet<Goal>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('روی جاده‌ی کدام هدف قدم بزنی؟',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final x in state.goals)
              ListTile(
                leading: Text(x.icon.isEmpty ? '🎯' : x.icon,
                    style: const TextStyle(fontSize: 22)),
                title: Text(x.name.isEmpty ? 'هدف' : x.name),
                onTap: () => Navigator.of(ctx).pop(x),
              ),
          ],
        ),
      ),
    );
  }
  if (g == null || !context.mounted) return;

  // جاده‌ی اصلی یا از چشمِ پاهای یکی از شاخه‌ها (تا سرِ شاخه و برگشت)
  final routes = HitRegistry.current?.routes ?? const <String, List<Offset>>{};
  final opts = <({ActionNode node, int depth, List<Offset> route})>[];
  void collect(List<ActionNode> list, int depth) {
    for (final a in list) {
      final r = routes[a.id];
      if (r != null && r.length >= 2) {
        opts.add((node: a, depth: depth, route: List<Offset>.of(r)));
      }
      collect(a.children, depth + 1);
    }
  }

  collect(g.actions, 0);
  ActionNode? branch;
  List<Offset>? branchRoute;
  if (opts.isNotEmpty) {
    final goal = g;
    final picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('از چشمِ کدام پا ببینی؟',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ListTile(
                leading: const Text('🛣️', style: TextStyle(fontSize: 22)),
                title: Text('جاده‌ی اصلیِ ${goal.name.isEmpty ? 'هدف' : goal.name}'),
                subtitle: const Text('از «من» تا هدف'),
                onTap: () => Navigator.of(ctx).pop('trunk'),
              ),
              for (final o in opts)
                ListTile(
                  contentPadding:
                      EdgeInsetsDirectional.only(start: 16.0 + o.depth * 18, end: 16),
                  leading: const Text('👣', style: TextStyle(fontSize: 20)),
                  title: Text(o.node.text.trim().isEmpty ? 'شاخه' : o.node.text.trim()),
                  subtitle: const Text('تا سرِ شاخه می‌روند و برمی‌گردند'),
                  onTap: () => Navigator.of(ctx).pop(o),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    if (picked is ({ActionNode node, int depth, List<Offset> route})) {
      branch = picked.node;
      branchRoute = picked.route;
    }
  }

  final WalkData? data0 = (branch != null && branchRoute != null)
      ? WalkLayer.prepareBranch(state, g, branch, branchRoute)
      : WalkLayer.prepare(state, g);
  if (data0 == null) {
    say(branch != null
        ? 'مسیرِ این شاخه خیلی کوتاه است.'
        : 'مسیر این هدف خیلی کوتاه است؛ هدف را کمی از «من» دورتر بگذار.');
    return;
  }
  final WalkData data = data0;
  final startFrac =
      branch != null ? null : (g.extra['walkerPos'] as num?)?.toDouble();
  await Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => WalkViewPage(data: data, startFrac: startFrac),
  ));
}

/// بدونِ هیچ پرسشی: نزدیک‌ترین شاخه به نقطه‌ی [focus] (مختصات نقشه) را پیدا می‌کند و
/// از چشمِ پاهایش می‌رود؛ اگر شاخه‌ای در [reach] نبود، جاده‌ی اصلیِ نزدیک‌ترین هدف.
Future<void> openWalkViewAt(
    BuildContext context, MapState state, Offset focus, double reach) async {
  void say(String m) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  if (state.goals.isEmpty) {
    say('اول یک هدف بساز تا جاده‌اش را قدم بزنی 🚶');
    return;
  }
  double distTo(List<Offset> pts) {
    var best = double.infinity;
    for (final q in pts) {
      final d = (q - focus).distance;
      if (d < best) best = d;
    }
    return best;
  }

  final routes = HitRegistry.current?.routes ?? const <String, List<Offset>>{};
  Goal? bestGoal;
  var bestGoalD = double.infinity;
  Goal? brGoal;
  ActionNode? brNode;
  List<Offset>? brRoute;
  var brD = double.infinity;
  for (final g in state.goals) {
    final road = WalkLayer.roadRoute(state, g);
    if (road != null && road.length >= 2) {
      final d = distTo(road);
      if (d < bestGoalD) {
        bestGoalD = d;
        bestGoal = g;
      }
    }
    void collect(List<ActionNode> list) {
      for (final a in list) {
        final r = routes[a.id];
        if (r != null && r.length >= 2) {
          final d = distTo(r);
          if (d < brD) {
            brD = d;
            brGoal = g;
            brNode = a;
            brRoute = List<Offset>.of(r);
          }
        }
        collect(a.children);
      }
    }

    collect(g.actions);
  }
  WalkData? data;
  if (brGoal != null && brNode != null && brRoute != null && brD <= reach) {
    data = WalkLayer.prepareBranch(state, brGoal!, brNode!, brRoute!);
  }
  if (data == null) {
    final g = bestGoal ?? state.goals.first;
    data = WalkLayer.prepare(state, g);
    if (data == null) {
      say('مسیر این هدف خیلی کوتاه است؛ هدف را کمی از «من» دورتر بگذار.');
      return;
    }
    final sf = (g.extra['walkerPos'] as num?)?.toDouble();
    if (!context.mounted) return;
    final d0 = data;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => WalkViewPage(data: d0, startFrac: sf),
    ));
    return;
  }
  if (!context.mounted) return;
  final d1 = data;
  await Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => WalkViewPage(data: d1),
  ));
}

class WalkViewPage extends StatefulWidget {
  const WalkViewPage({super.key, required this.data, this.startFrac});
  final WalkData data;

  /// جای فعلیِ انیمیشنِ پا روی مسیر (۰ تا ۱)؛ اگر نباشد از ابتدای جاده شروع می‌شود
  final double? startFrac;
  @override
  State<WalkViewPage> createState() => _WalkViewPageState();
}

class _WalkViewPageState extends State<WalkViewPage>
    with SingleTickerProviderStateMixin {
  final cam = WalkCam();
  final _tick = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _dragging = false;
  double _yawVel = 0; // سرعتِ چرخشِ سر بعد از رها کردنِ انگشت (رادیان/ثانیه)
  bool _arrived = false;
  double _hold = 0; // مکثِ رفت‌وبرگشت (ثانیه)
  int _speedIdx = 0;
  static const _speeds = [1.0, 3.0, 8.0];

  @override
  void initState() {
    super.initState();
    final f = widget.startFrac;
    if (f != null) {
      cam.d = (f.clamp(0.0, 1.0) * widget.data.length)
          .clamp(0.0, widget.data.maxD)
          .toDouble();
    }
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tick.dispose();
    super.dispose();
  }

  void _onTick(Duration e) {
    final dt = ((e - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = e;
    cam.t += dt;
    final sp = _speeds[_speedIdx];
    final loop = widget.data.loop;
    if (loop && _hold > 0) {
      // مکثِ کوتاه سرِ شاخه / ابتدای مسیر؛ بعد برگشت
      _hold -= dt;
      if (_hold <= 0 && _arrived && mounted) setState(() => _arrived = false);
    } else if (cam.walking) {
      cam.d += cam.dir * 26.0 * sp * dt;
      cam.phase += dt * 7.0 * math.sqrt(sp);
      final maxD = widget.data.maxD;
      if (cam.dir > 0 && cam.d >= maxD) {
        cam.d = maxD;
        if (loop) {
          // مثلِ انیمیشنِ پا: سرِ شاخه می‌رسد، می‌ایستد و برمی‌گردد
          cam.dir = -1.0;
          _hold = 1.6;
          if (mounted) setState(() => _arrived = true);
        } else {
          cam.walking = false;
          if (!_arrived && mounted) setState(() => _arrived = true);
        }
      } else if (cam.dir < 0 && cam.d <= 0) {
        cam.d = 0;
        if (loop) {
          cam.dir = 1.0;
          _hold = 0.8;
        } else {
          cam.walking = false;
          if (mounted) setState(() {});
        }
      }
    }
    // چرخشِ آزادِ ۳۶۰ درجه: سر همان‌جا که رها کردی می‌ماند (با کمی لغزش)
    if (!_dragging && _yawVel != 0) {
      cam.yaw = _wrap(cam.yaw + _yawVel * dt);
      _yawVel *= math.pow(0.02, dt).toDouble();
      if (_yawVel.abs() < 0.01) _yawVel = 0;
    }
    _tick.value++;
  }

  /// زاویه را در بازه‌ی (-π, π] نگه می‌دارد تا چرخشِ پیوسته‌ی ۳۶۰ درجه ممکن باشد
  double _wrap(double a) {
    const tau = 2 * math.pi;
    var r = (a + math.pi) % tau;
    if (r < 0) r += tau;
    return r - math.pi;
  }

  /// نگاه دوباره رو به جهتِ حرکت
  void _lookForward() {
    setState(() {
      cam.yaw = 0;
      cam.pitch = 0;
      _yawVel = 0;
    });
  }

  void _toggle() {
    setState(() {
      if (!cam.walking) {
        final maxD = widget.data.maxD;
        if (cam.dir > 0 && cam.d >= maxD - 0.5) cam.dir = -1.0;
        if (cam.dir < 0 && cam.d <= 0.5) cam.dir = 1.0;
        _arrived = false;
      }
      cam.walking = !cam.walking;
    });
  }

  void _openMarkCalendar(Offset p) {
    WalkHit? best;
    for (final h in widget.data.hits) {
      if (!h.rect.contains(p)) continue;
      if (best == null || h.sc > best.sc) best = h;
    }
    final m = best?.mark;
    if (m == null || m.hostId.isEmpty || m.actionId.isEmpty) return;
    showGoalsSheet(
      context,
      onShowOnMap: (_) {
        if (mounted) Navigator.of(context).pop();
      },
      onAddGoal: () => showAddGoalDialog(context),
      focusHostId: m.hostId,
      focusActionId: m.actionId,
      focusJk: m.pending ? null : m.dayKey,
    );
  }

  void _turnAround() {
    setState(() {
      cam.dir = -cam.dir;
      cam.walking = true;
      _arrived = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.data;
    final maxD = math.max(1.0, data.maxD);
    return Scaffold(
      backgroundColor: Colors.black,
      // نمای راه‌رفتن تمام‌صفحه است و هیچ ورودیِ متنی ندارد؛ پس با کیبورد/
      // viewInsets کوچک نشود (روی وبِ موبایل باعثِ نوارِ باریک و صفحه‌ی سیاه می‌شد)
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              // لمسِ طولانیِ گل/برگ/غنچه: تقویمِ فهرستِ اهدافِ همان کار
              onLongPressStart: (d) => _openMarkCalendar(d.localPosition),
              onPanStart: (_) {
                _dragging = true;
                _yawVel = 0;
              },
              onPanUpdate: (d) {
                // کشیدن به راست/چپ = چرخش دورِ خود (آزاد، ۳۶۰ درجه)؛
                // کشیدن بالا/پایین = نگاه به آسمان/زمین
                cam.yaw = _wrap(cam.yaw - d.delta.dx * 0.005);
                cam.pitch = (cam.pitch + d.delta.dy * 0.004)
                    .clamp(-0.6, 0.6)
                    .toDouble();
              },
              onPanEnd: (d) {
                _dragging = false;
                _yawVel = (-d.velocity.pixelsPerSecond.dx * 0.005)
                    .clamp(-4.0, 4.0)
                    .toDouble();
              },
              onPanCancel: () => _dragging = false,
              child: CustomPaint(
                painter: WalkPainter(data, cam, dark, _tick),
                size: Size.infinite,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  _roundBtn(Icons.close, () => Navigator.of(context).pop()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ValueListenableBuilder<int>(
                        valueListenable: _tick,
                        builder: (_, __, ___) {
                          final pct =
                              (cam.d / maxD * 100).clamp(0, 100).round();
                          return Text(
                            '${data.icon} ${data.name}  ·  ${toFa(pct)}٪ مسیر',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: _tick,
                      builder: (_, __, ___) {
                        String? msg;
                        final mk = nearestMark(data.marks, cam.d);
                        if (mk != null) {
                          return _markCard(mk);
                        }
                        if (_arrived) {
                          msg = data.loop
                              ? '🌱 به سرِ شاخه رسیدی؛ برمی‌گردی…'
                              : '🎯 به آخرِ جاده‌ی هدفت رسیدی';
                        } else if (cam.t < 8) {
                          msg =
                              'انگشتت را به هر سو بکش و ۳۶۰ درجه دورِ خودت را ببین · لمس = ایست/حرکت';
                        }
                        if (msg == null) return const SizedBox(height: 0);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(msg,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        );
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _roundBtn(Icons.u_turn_left, _turnAround),
                        const SizedBox(width: 14),
                        _roundBtn(
                            cam.walking ? Icons.pause : Icons.play_arrow,
                            _toggle,
                            big: true),
                        const SizedBox(width: 14),
                        _roundBtn(null, () {
                          setState(() =>
                              _speedIdx = (_speedIdx + 1) % _speeds.length);
                        }, label: '×${toFa(_speeds[_speedIdx].round())}'),
                        const SizedBox(width: 14),
                        _roundBtn(Icons.explore_outlined, _lookForward),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// کارتِ توضیحِ ثبتِ نقشه (وقتی کنارش رد می‌شوی): تاریخ، نام، مدت و یادداشتِ کامل
  Widget _markCard(WalkMark m) {
    final parts = <String>[
      m.fullDateLabel,
      if (m.minutesLabel.isNotEmpty) m.minutesLabel,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${m.pending ? '🌰' : (m.finished ? '🌸' : (m.flower ? '🌼' : '🌱'))}  ${parts.join('  ·  ')}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w600),
          ),
          if (m.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(m.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          if (m.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(m.note,
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12.5, height: 1.4)),
            ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData? icon, VoidCallback onTap,
      {bool big = false, String? label}) {
    final sz = big ? 54.0 : 42.0;
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: sz,
          height: sz,
          child: Center(
            child: icon != null
                ? Icon(icon, color: Colors.white, size: big ? 30 : 22)
                : Text(label ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
