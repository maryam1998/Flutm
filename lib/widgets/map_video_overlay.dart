import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/map_video_player.dart';
import 'grat_media.dart' show gratVideoController;

/// کارت شناور پخش ویدیو روی نقشه (قابل جابه‌جایی با کشیدن نوار بالا)
class MapVideoOverlay extends StatelessWidget {
  const MapVideoOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ValueListenableBuilder<MapVideoRequest?>(
        valueListenable: MapVideoPlayer.instance.current,
        builder: (context, req, _) {
          if (req == null) return const SizedBox.shrink();
          return _MapVideoCard(key: ValueKey(req.token), req: req);
        },
      ),
    );
  }
}

class _MapVideoCard extends StatefulWidget {
  const _MapVideoCard({super.key, required this.req});
  final MapVideoRequest req;

  @override
  State<_MapVideoCard> createState() => _MapVideoCardState();
}

class _MapVideoCardState extends State<_MapVideoCard> {
  VideoPlayerController? _c;
  bool _failed = false;
  bool _loop = false;
  Offset? _pos;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    try {
      final c = await gratVideoController(widget.req.src);
      await c.initialize();
      await c.setLooping(_loop);
      c.addListener(_tick);
      if (!mounted) {
        c.removeListener(_tick);
        await c.dispose();
        return;
      }
      setState(() => _c = c);
      try {
        await c.play();
      } catch (_) {}
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    final c = _c;
    if (c != null) {
      c.removeListener(_tick);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, bc) {
      final w = math.min(bc.maxWidth - 24, 340.0);
      final maxVideoH = math.max(120.0, bc.maxHeight * 0.55);
      _pos ??= Offset((bc.maxWidth - w) / 2, 64);
      final p = Offset(
        _pos!.dx.clamp(0.0, math.max(0.0, bc.maxWidth - w)).toDouble(),
        _pos!.dy.clamp(0.0, math.max(0.0, bc.maxHeight - 120)).toDouble(),
      );
      final c = _c;
      Widget video;
      if (_failed) {
        video = const SizedBox(
          height: 120,
          child: Center(
              child: Text('ویدیو پخش نشد',
                  style: TextStyle(color: Colors.white70, fontSize: 12))),
        );
      } else if (c == null || !c.value.isInitialized) {
        video = const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      } else {
        video = ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxVideoH),
          child: GestureDetector(
            onTap: () => c.value.isPlaying ? c.pause() : c.play(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                    aspectRatio: c.value.aspectRatio <= 0
                        ? 16 / 9
                        : c.value.aspectRatio,
                    child: VideoPlayer(c)),
                if (!c.value.isPlaying)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 32),
                  ),
              ],
            ),
          ),
        );
      }
      return Stack(
        children: [
          Positioned(
            left: p.dx,
            top: p.dy,
            width: w,
            child: Material(
              color: const Color(0xF2111111),
              elevation: 10,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) => setState(() => _pos = p + d.delta),
                    child: SizedBox(
                      height: 36,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(Icons.drag_indicator,
                              size: 18, color: Colors.white54),
                          const Spacer(),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() => _loop = !_loop);
                              c?.setLooping(_loop);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.repeat_rounded,
                                  size: 20,
                                  color: _loop
                                      ? const Color(0xFF4FD1C5)
                                      : Colors.white54),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: MapVideoPlayer.instance.close,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.close_rounded,
                                  size: 22, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  video,
                  if (c != null && c.value.isInitialized)
                    VideoProgressIndicator(c, allowScrubbing: true),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
