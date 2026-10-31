import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../models/jalali.dart' show jKey;
import '../models/map_models.dart';
import '../screens/add_goal_dialog.dart';
import '../screens/goals_sheet.dart';
import '../state/map_store.dart';
import 'camera.dart';
import 'draw_utils.dart' show toFa, NodeImageCache;
import 'hit_registry.dart';
import 'map_ops.dart' show findActionNode, footPosToday;
import 'map_painter.dart' show MapPainter, WalkSync;
import 'walk_marks.dart';
import 'world_painter.dart';

/// نقطه‌ی شروعِ نمای راه‌رفتنِ یک شاخه روی مسیرِ دوربین (۰ = سمتِ هدف … ۱ = نوکِ
/// شاخه). پای انیمیشنی روی نقشه از نوکِ شاخه شروع به حرکت می‌کند؛ پس همان‌جا
/// شروع می‌شود، مگر اینکه کاربر «امروز» پا را دستی جابه‌جا کرده باشد (همان‌طور که
/// نقشه هم فقط موقعیتِ امروز را قبول می‌کند؛ موقعیتِ روزهای قبل نادیده است).
double _branchStartFrac(ActionNode n) {
  final today = footPosToday(n, jKey(DateTime.now()));
  return (1.0 - (today ?? 0.0)).clamp(0.0, 1.0).toDouble();
}

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
  final startFrac = branch != null
      ? _branchStartFrac(branch)
      : (g.extra['walkerPos'] as num?)?.toDouble();
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

  final reg = HitRegistry.current;
  final routes = reg?.routes ?? const <String, List<Offset>>{};
  final twigs = reg?.twigs ?? const <String, TwigGeom>{};
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
        final tw = twigs[a.id];
        // فاصله تا «خودِ شاخه»؛ مسیرِ کاملِ پا (r) تنه‌ی جاده را هم دربر دارد و
        // اگر با آن سنجیده شود همیشه یک شاخه به‌جای جاده‌ی اصلی انتخاب می‌شد
        if (r != null && r.length >= 2 && tw != null && tw.pts.isNotEmpty) {
          final d = distTo(tw.pts);
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
  // شاخه فقط وقتی انتخاب می‌شود که از جاده‌ی اصلی به وسطِ صفحه نزدیک‌تر باشد
  if (brGoal != null &&
      brNode != null &&
      brRoute != null &&
      brD <= reach &&
      brD < bestGoalD) {
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
  final sf1 = brNode == null ? null : _branchStartFrac(brNode!);
  await Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => WalkViewPage(data: d1, startFrac: sf1),
  ));
}

/// نمای راه‌رفتن از چشمِ همان پای انیمیشنی که کاربر رویش کشیده است:
/// [type] = 'walker' (پای آبیِ جاده‌ی هدف) یا 'foot' (پای یک شاخه/زیرشاخه).
Future<void> openWalkViewForFoot(BuildContext context, MapState state,
    String type, String hostId, String id) async {
  void say(String m) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  final host = state.findHost(hostId);
  if (host is! Goal) {
    say('نمای راه‌رفتن فقط برای جاده‌ی هدف‌ها و شاخه‌هایشان است.');
    return;
  }
  if (type == 'walker') {
    final data = WalkLayer.prepare(state, host);
    if (data == null) {
      say('مسیر این هدف خیلی کوتاه است؛ هدف را کمی از «من» دورتر بگذار.');
      return;
    }
    final sf = (host.extra['walkerPos'] as num?)?.toDouble();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => WalkViewPage(data: data, startFrac: sf),
    ));
    return;
  }
  final found = findActionNode(host.actions, id);
  final route = HitRegistry.current?.routes[id];
  if (found == null || route == null || route.length < 2) {
    say('مسیرِ این شاخه الان روی نقشه نیست.');
    return;
  }
  final data =
      WalkLayer.prepareBranch(state, host, found.node, List<Offset>.of(route));
  if (data == null) {
    say('مسیرِ این شاخه خیلی کوتاه است.');
    return;
  }
  final sfb = _branchStartFrac(found.node);
  await Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => WalkViewPage(data: data, startFrac: sfb),
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
  bool _autoTurn = false; // چرخشِ نرمِ ۱۸۰ درجه‌ی سر هنگامِ برگشت
  double _hold = 0; // مکثِ رفت‌وبرگشت (ثانیه)
  int _speedIdx = 0;
  static const _speeds = [1.0, 3.0, 8.0];

  // ── نمای «نقشه‌ی ۳بعدی»: همان نقشه‌ی واقعی (همه‌چیز همان‌طور که هست) کج‌شده
  //    و دوربین پشتِ پاها؛ با دکمه می‌شود به نمای اول‌شخصِ قبلی برگشت ──
  bool _map3d = false;
  final CameraController _mcam = CameraController();
  final MapBoundsBox _mbounds = MapBoundsBox();
  final ValueNotifier<double> _mtime = ValueNotifier<double>(0);
  late final HitRegistry _mHits;
  MapPainter? _mPainter;
  MapState? _mState;
  bool _mDark = false;
  double _mSpan = 2000;
  double _mHead = 0;
  bool _mHeadInit = false;
  double _mRoadYaw = 0;
  int _zoomIdx = 1;
  static const _zooms = [0.5, 0.8, 1.25];

  /// پایین‌ترین جایی که دوربین برمی‌گردد: در نمای شاخه همان محلِ اتصالِ شاخه به
  /// جاده (کمی قبلش)، تا رفت‌وبرگشت فقط روی خودِ شاخه‌ی ثبت‌شده باشد نه روی
  /// جاده‌ی مستقیمِ اصلی
  double get _lo => widget.data.isBranch
      ? math.min(
          math.max(widget.data.startD, widget.data.branchFrom - 24.0),
          widget.data.maxD)
      : widget.data.minD;

  @override
  void initState() {
    super.initState();
    // وقتی از روی قدمِ یک شاخه (مثلاً A2) وارد می‌شوی، اول همان نقشه‌ی واقعی
    // با همه‌چیزش (غنچه، گل، برگ، تابلو، شاخه‌ها…) کج و پشتِ پاها دیده می‌شود
    // و مسیرِ همان شاخه جلوی توست؛ با دکمه‌ی نقشه می‌شود به نمای اول‌شخص رفت
    _map3d = widget.data.isBranch;
    final f = widget.startFrac;
    if (f != null) {
      cam.d = (f.clamp(0.0, 1.0) * widget.data.length)
          .clamp(_lo, widget.data.maxD)
          .toDouble();
      // پای شاخه روی نقشه از نوک شروع می‌کند و به سمتِ جاده‌ی اصلی می‌رود؛
      // رفت = نوک ← جاده، برگشت = جاده ← نوک
      if (widget.data.isBranch || cam.d >= widget.data.maxD - 0.5) {
        cam.dir = -1.0;
      }
    } else if (widget.data.startD > 0) {
      cam.d = widget.data.startD
          .clamp(widget.data.minD, widget.data.maxD)
          .toDouble();
    }
    // ثبتِ لمسِ نقشه‌ی ۳بعدی؛ سازنده‌اش `current` را عوض می‌کند و برش می‌گردانیم
    final prevHits = HitRegistry.current;
    _mHits = HitRegistry();
    HitRegistry.current = prevHits;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    WalkSync.pos.clear();
    _ticker.dispose();
    _tick.dispose();
    _mtime.dispose();
    super.dispose();
  }

  /// جهتِ حرکت عوض شد: دید یک‌دفعه ۱۸۰ درجه نمی‌پرد؛ سر نرم به جهتِ تازه می‌چرخد
  void _flipDir() {
    cam.dir = -cam.dir;
    cam.yaw = _wrap(cam.yaw + math.pi);
    _yawVel = 0;
    _autoTurn = true;
  }

  void _onTick(Duration e) {
    final dt = ((e - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = e;
    cam.t += dt;
    _mtime.value = e.inMicroseconds / 1e6;
    final sp = _speeds[_speedIdx];
    final lo = _lo;
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
          _flipDir();
          _hold = 1.6;
          if (mounted) setState(() => _arrived = true);
        } else {
          cam.walking = false;
          if (!_arrived && mounted) setState(() => _arrived = true);
        }
      } else if (cam.dir < 0 && cam.d <= lo) {
        cam.d = lo;
        if (loop) {
          // برگشت تمام شد؛ مکثِ کوتاه و دوباره رفت
          _flipDir();
          _hold = 0.8;
        } else {
          cam.walking = false;
          if (mounted) setState(() {});
        }
      }
    }
    if (_autoTurn) {
      if (_dragging) {
        _autoTurn = false;
      } else {
        cam.yaw = _wrap(cam.yaw) * math.pow(0.18, dt).toDouble();
        if (cam.yaw.abs() < 0.01) {
          cam.yaw = 0;
          _autoTurn = false;
        }
      }
    }
    // چرخشِ آزادِ ۳۶۰ درجه: سر همان‌جا که رها کردی می‌ماند (با کمی لغزش)
    if (!_dragging && _yawVel != 0) {
      cam.yaw = _wrap(cam.yaw + _yawVel * dt);
      _yawVel *= math.pow(0.02, dt).toDouble();
      if (_yawVel.abs() < 0.01) _yawVel = 0;
    }
    if (_map3d) _syncMap3d(dt);
    _tick.value++;
  }

  /// دوربینِ نقشه‌ی ۳بعدی را روی جای فعلیِ پاها می‌گذارد و رو به جهتِ حرکت می‌چرخاند
  void _syncMap3d(double dt) {
    final data = widget.data;
    final cr = data.camRoad ?? data.road;
    final lc = cr.length;
    final dc = cam.d.clamp(0.0, lc).toDouble();
    final p = cr.pos(dc);
    final pa = cr.pos(math.max(0.0, dc - 16));
    final pb = cr.pos(math.min(lc, dc + 16));
    final rv = pb - pa;
    if (rv.distance >= 0.01) _mRoadYaw = math.atan2(rv.dy, rv.dx);
    final target =
        _wrap((cam.dir >= 0 ? _mRoadYaw : _mRoadYaw + math.pi) + cam.yaw);
    if (!_mHeadInit) {
      _mHead = target;
      _mHeadInit = true;
    } else {
      final k = 1.0 - math.pow(0.0005, dt).toDouble();
      _mHead = _wrap(_mHead + _wrap(target - _mHead) * k);
    }
    // پاهای انیمیشنیِ روی نقشه همان جا و همان جهتِ دوربین راه بروند
    if (data.isBranch) {
      final id = data.branchId;
      // مسیرِ پا روی نقشه از نوکِ شاخه به سمتِ جاده است؛ دوربین برعکس
      if (id != null && lc > 0) {
        WalkSync.pos['foot:$id'] = (1.0 - dc / lc, cam.dir > 0);
      }
    } else if (data.goalId.isNotEmpty && lc > 0) {
      WalkSync.pos['walker:${data.goalId}'] = (dc / lc, cam.dir < 0);
    }
    final sc = _zooms[_zoomIdx];
    _mcam.scale = sc;
    _mcam.x = _mSpan / 2 - p.dx * sc;
    _mcam.y = _mSpan / 2 - p.dy * sc;
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
        if (cam.dir > 0 && cam.d >= maxD - 0.5) _flipDir();
        if (cam.dir < 0 && cam.d <= _lo + 0.5) _flipDir();
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
      _flipDir();
      cam.walking = true;
      _arrived = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.data;
    final minD = _lo;
    final span = math.max(1.0, data.maxD - minD);
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
                _autoTurn = false;
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
              child: _map3d
                  ? _buildMap3d(context, dark)
                  : CustomPaint(
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
                              ((cam.d - minD) / span * 100).clamp(0, 100).round();
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
                  if (_map3d) ...[
                    const SizedBox(width: 10),
                    _roundBtn(Icons.zoom_in, () {
                      setState(() => _zoomIdx = (_zoomIdx + 1) % _zooms.length);
                    }),
                  ],
                ],
              ),
            ),
          ),
          ),
          if (data.isBranch)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 56, 8, 0),
                  child: Center(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _tick,
                      builder: (_, __, ___) {
                        final nm = data.name.contains('›')
                            ? data.name.split('›').last.trim()
                            : data.name;
                        final going = cam.dir > 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: data.branchColor, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: data.branchColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  going
                                      ? 'شاخه‌ی «$nm» ← به سمتِ سرِ شاخه'
                                      : 'شاخه‌ی «$nm» ← برگشت به جاده',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
                          msg = data.isBranch
                              ? '🌱 به سرِ شاخه رسیدی؛ برمی‌گردی…'
                              : (data.loop
                                  ? '🎯 نزدیکِ هدف رسیدی؛ برمی‌گردی…'
                                  : '🎯 به آخرِ جاده‌ی هدفت رسیدی');
                        } else if (cam.dir < 0 && data.loop) {
                          msg = '↩️ در حال برگشت…';
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
                        const SizedBox(width: 14),
                        _roundBtn(
                            _map3d ? Icons.directions_walk : Icons.map_outlined,
                            () => setState(() {
                              _map3d = !_map3d;
                              if (!_map3d) WalkSync.pos.clear();
                            })),
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

  MapPainter _painterFor(MapState st, bool dark) {
    if (_mPainter == null || !identical(_mState, st) || _mDark != dark) {
      _mState = st;
      _mDark = dark;
      _mPainter = MapPainter(
        state: st,
        cam: _mcam,
        time: _mtime,
        images: NodeImageCache.shared,
        boundsBox: _mbounds,
        hits: _mHits,
        isDark: dark,
      );
    }
    return _mPainter!;
  }

  /// نقشه‌ی واقعی (با همه‌ی چیزهایش) در حالتِ ۳بعدی: نقشه رو به جهتِ حرکت چرخانده
  /// و کج می‌شود؛ دوربین پشتِ پاهاست و هرچه روی نقشه هست همان‌طور دیده می‌شود.
  Widget _buildMap3d(BuildContext context, bool dark) {
    final st = context.watch<MapStore>().state;
    final painter = _painterFor(st, dark);
    final bg = dark ? const Color(0xFF10142A) : Colors.white;
    final skyTop = dark ? const Color(0xFF0B1226) : const Color(0xFF86C1EE);
    final skyLow = dark ? const Color(0xFF2B3558) : const Color(0xFFEAF4FB);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      if (w <= 0 || h <= 0) return const SizedBox.shrink();
      final lw = w * 1.8, lh = h * 2.0;
      final up = h * 1.5; // بخشِ بالای نقطه‌ی ایستادن در لایه
      final anchor = Offset(lw / 2, up);
      final span = h * 3.4;
      _mSpan = span;
      _mcam.view = Size(span, span);
      _syncMap3d(0);
      final persp = 0.55 / h;
      return SizedBox(
        width: w,
        height: h,
        child: ValueListenableBuilder<int>(
          valueListenable: _tick,
          builder: (_, __, ___) {
            final tilt =
                (0.85 + cam.pitch * 0.5).clamp(0.55, 1.05).toDouble();
            final proj = up * math.cos(tilt) / (1 + persp * up * math.sin(tilt));
            final edgeY = h * 0.72 - proj; // لبه‌ی دورِ نقشه روی صفحه
            final fogH = math.max(1.0, math.min(h, edgeY + h * 0.22));
            final stop =
                ((edgeY + h * 0.02) / fogH).clamp(0.05, 0.95).toDouble();
            final m = Matrix4.identity()
              ..setEntry(3, 2, persp)
              ..rotateX(-tilt);
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(child: ColoredBox(color: skyLow)),
                Positioned(
                  left: w / 2 - lw / 2,
                  top: h * 0.72 - up,
                  width: lw,
                  height: lh,
                  child: Transform(
                    origin: anchor,
                    transform: m,
                    child: CustomPaint(
                      size: Size(lw, lh),
                      painter: _Map3dPainter(
                        inner: painter,
                        head: () => _mHead,
                        anchor: anchor,
                        span: span,
                        bg: bg,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: fogH,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            skyTop,
                            skyLow,
                            skyLow.withValues(alpha: 0.0),
                          ],
                          stops: [0.0, stop, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
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

/// نقشه‌ی واقعی را (با [MapPainter]) رو به جهتِ حرکت می‌چرخاند؛ کجیِ ۳بعدی را
/// ویجتِ Transform روی همین لایه می‌اندازد.
class _Map3dPainter extends CustomPainter {
  _Map3dPainter({
    required this.inner,
    required this.head,
    required this.anchor,
    required this.span,
    required this.bg,
  });

  final MapPainter inner;
  final double Function() head;
  final Offset anchor;
  final double span;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..color = bg);
    // نقطه‌ی ایستادنِ پاها (وسطِ بومِ نقشه) روی [anchor]؛ جهتِ حرکت = بالا
    canvas.translate(anchor.dx, anchor.dy);
    canvas.rotate(-math.pi / 2 - head());
    canvas.translate(-span / 2, -span / 2);
    inner.paint(canvas, Size(span, span));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Map3dPainter old) => true;
}
