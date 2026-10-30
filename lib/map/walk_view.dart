import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/map_models.dart';
import 'draw_utils.dart' show toFa;
import 'world_painter.dart';

/// نمای اول‌شخص: کاربر روی جاده‌ی یکی از هدف‌هایش راه می‌رود و چپ و راست را می‌بیند.
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
  await Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => WalkViewPage(data: data),
  ));
}

class WalkViewPage extends StatefulWidget {
  const WalkViewPage({super.key, required this.data});
  final WalkData data;
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
  bool _arrived = false;
  int _speedIdx = 0;
  static const _speeds = [1.0, 3.0, 8.0];

  @override
  void initState() {
    super.initState();
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
    if (!_dragging && cam.yaw != 0) {
      cam.yaw *= math.pow(0.05, dt).toDouble();
      if (cam.yaw.abs() < 0.002) cam.yaw = 0;
    }
    _tick.value++;
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
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              onHorizontalDragStart: (_) => _dragging = true,
              onHorizontalDragUpdate: (d) {
                cam.yaw = (cam.yaw - d.delta.dx * 0.005)
                    .clamp(-math.pi, math.pi)
                    .toDouble();
              },
              onHorizontalDragEnd: (_) => _dragging = false,
              onHorizontalDragCancel: () => _dragging = false,
              child: CustomPaint(
                painter: WalkPainter(data, cam, dark, _tick),
                size: Size.infinite,
              ),
            ),
          ),
          SafeArea(
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
                              'انگشتت را چپ و راست بکش تا اطرافت را ببینی · لمس = ایست/حرکت';
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
