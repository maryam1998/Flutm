import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../state/map_store.dart';
import 'camera.dart';
import 'draw_utils.dart';
import 'hit_registry.dart';
import 'map_interaction.dart';
import 'map_painter.dart';

class MapCanvas extends StatefulWidget {
  const MapCanvas({
    super.key,
    required this.cam,
    required this.boundsBox,
    required this.isResizeMode,
    required this.onEditMe,
    required this.onEditGoal,
    required this.onEditRing,
    required this.onEditAction,
    this.onTimeBranch,
    this.onShowBranchMenu,
  });

  final CameraController cam;
  final MapBoundsBox boundsBox;
  final bool Function() isResizeMode;
  final void Function() onEditMe;
  final void Function(String id) onEditGoal;
  final void Function(String id) onEditRing;
  final void Function(String hostId, String actionId) onEditAction;
  final void Function(String hostId, String actionId)? onTimeBranch;
  final void Function(String hostId, String actionId)? onShowBranchMenu;

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  final NodeImageCache _images = NodeImageCache();
  final HitRegistry _hits = HitRegistry();
  late final MapInteraction _touch;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6)..start();
    _touch = MapInteraction(
      cam: widget.cam,
      store: context.read<MapStore>(),
      hits: _hits,
      isResizeMode: widget.isResizeMode,
      onEditMe: widget.onEditMe,
      onEditGoal: widget.onEditGoal,
      onEditRing: widget.onEditRing,
      onEditAction: widget.onEditAction,
      onTimeBranch: widget.onTimeBranch,
      onShowBranchMenu: widget.onShowBranchMenu,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) _touch.reset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _touch.reset();
    _touch.dispose();
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
        behavior: HitTestBehavior.opaque,
        onPointerDown: _touch.pointerDown,
        onPointerMove: _touch.pointerMove,
        onPointerUp: _touch.pointerUp,
        onPointerCancel: _touch.pointerCancel,
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) _touch.scroll(e);
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
              hits: _hits,
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      );
    });
  }
}
