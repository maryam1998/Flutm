import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../state/map_store.dart';
import 'camera.dart';
import 'draw_utils.dart';
import 'map_painter.dart';

/// بوم نقشه: رسم + pan/zoom (لمس، موس و چرخ)
class MapCanvas extends StatefulWidget {
  const MapCanvas({super.key, required this.cam, required this.boundsBox});
  final CameraController cam;
  final MapBoundsBox boundsBox;

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  final NodeImageCache _images = NodeImageCache();
  double _lastScale = 1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _images.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MapStore>();
    return LayoutBuilder(builder: (context, box) {
      widget.cam.initCenter(Size(box.maxWidth, box.maxHeight));
      return Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) {
            widget.cam.zoomAt(e.localPosition, math.exp(-e.scrollDelta.dy / 500));
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => _lastScale = 1,
          onScaleUpdate: (d) {
            widget.cam.panBy(d.focalPointDelta);
            if (d.pointerCount > 1 || d.scale != 1) {
              final f = d.scale / _lastScale;
              _lastScale = d.scale;
              if (f != 1) widget.cam.zoomAt(d.localFocalPoint, f);
            }
          },
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: MapPainter(
                state: store.state,
                cam: widget.cam,
                time: _time,
                images: _images,
                boundsBox: widget.boundsBox,
              ),
            ),
          ),
        ),
      );
    });
  }
}
