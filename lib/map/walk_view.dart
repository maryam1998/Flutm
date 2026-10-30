import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/map_models.dart';
import 'draw_utils.dart' show toFa;
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
  final data = WalkLayer.prepare(state, g);
  if (data == null) {
    say('مسیر این هدف خیلی کوتاه است؛ هدف را کمی از «من» دورتر بگذار.');
    return;
  }
  final startFrac = (g.extra['walkerPos'] as num?)?.toDouble();
  await Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => WalkViewPage(data: data, startFrac: startFrac),
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
    if (cam.walking) {
      cam.d += cam.dir * 26.0 * sp * dt;
      cam.phase += dt * 7.0 * math.sqrt(sp);
      final maxD = widget.data.maxD;
      if (cam.dir > 0 && cam.d >= maxD) {
        cam.d = maxD;
        cam.walking = false;
        if (!_arrived && mounted) setState(() => _arrived = true);
      } else if (cam.dir < 0 && cam.d <= 0) {
        cam.d = 0;
        cam.walking = false;
        if (mounted) setState(() {});
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
                        if (_arrived) {
                          msg = '🎯 به آخرِ جاده‌ی هدفت رسیدی';
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
