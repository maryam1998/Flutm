import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/map_video_player.dart';
import '../services/media_blob.dart';
import 'grat_media.dart' show gratVideoController;
import 'map_html_video.dart';

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
  // عرض کارت — با پینچ دو انگشتی تغییر می‌کند
  double? _w;
  double _baseW = 0;
  // وب: آدرس ویدیو برای <video> HTML و نسبت واقعی ویدیو (بعد از لود متادیتا)
  String? _webUrl;
  double? _webRatio;
  double _webFrac = 0;
  bool _webPlaying = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  Future<void> _initWeb() async {
    try {
      final src = widget.req.src;
      final url = MediaBlob.isRef(src) ? await MediaBlob.playableSource(src) : src;
      if (url == null || url.isEmpty) throw StateError('video missing');
      if (!mounted) return;
      // نسبت واقعی را قبل از نمایش کارت بخوان تا کارت بعداً تغییر اندازه نده
      final r = await probeMapVideoRatio(url);
      if (!mounted) return;
      setState(() {
        _webRatio = r;
        _webUrl = url;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _init() async {
    if (kIsWeb) {
      await _initWeb();
      return;
    }
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
    if (kIsWeb) disposeMapHtmlVideo('${widget.req.token}');
    final c = _c;
    if (c != null) {
      c.removeListener(_tick);
      c.dispose();
    }
    super.dispose();
  }

  double _ratio(VideoPlayerController c) {
    final sz = c.value.size;
    if (sz.width > 0 && sz.height > 0) return sz.width / sz.height;
    final r = c.value.aspectRatio;
    return r <= 0 ? 16 / 9 : r;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, bc) {
      const headerH = 36.0;
      // وب: <video> بدون کنترل و بدون لمس؛ لمس‌ها (جابه‌جایی/پینچ/پخش) با فلاتر
      final barH = kIsWeb ? 16.0 : 6.0;
      const minW = 120.0;
      final c = _c;
      final ready = kIsWeb
          ? (!_failed && _webUrl != null)
          : (!_failed && c != null && c.value.isInitialized);
      final ratio = kIsWeb
          ? (_webRatio ?? 16 / 9)
          : (ready ? _ratio(c!) : 16 / 9);

      // حداکثر عرض: هم از نظر عرض صفحه، هم ارتفاع (تا ویدیو از کادر بیرون نزند)
      final maxByW = math.max(minW, bc.maxWidth - 8);
      final maxByH =
          math.max(minW, (bc.maxHeight - headerH - barH - 90) * ratio);
      final maxW = math.min(maxByW, maxByH);
      final defW = math.min(math.min(bc.maxWidth - 24, 340.0), maxW);
      final w = (_w ?? defW).clamp(minW, maxW).toDouble();
      final vh = ready ? w / ratio : 120.0;
      final cardH = headerH + vh + (ready ? barH : 0);

      _pos ??= Offset((bc.maxWidth - w) / 2, 64);
      final p = Offset(
        _pos!.dx.clamp(0.0, math.max(0.0, bc.maxWidth - w)).toDouble(),
        _pos!.dy.clamp(0.0, math.max(0.0, bc.maxHeight - cardH)).toDouble(),
      );

      double heightFor(double cw) =>
          headerH + (ready ? cw / ratio : 120.0) + (ready ? barH : 0);

      // جابه‌جایی با یک انگشت + تغییر اندازه با پینچ (حول مرکز کارت)
      Widget gestures(Widget child) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (d) {
              _baseW = w;
              _pos = p;
            },
            onScaleUpdate: (d) {
              final oldW = (_w ?? defW).clamp(minW, maxW).toDouble();
              final newW = d.pointerCount >= 2
                  ? (_baseW * d.scale).clamp(minW, maxW).toDouble()
                  : oldW;
              setState(() {
                _w = newW;
                _pos = (_pos ?? p) +
                    d.focalPointDelta +
                    Offset((oldW - newW) / 2,
                        (heightFor(oldW) - heightFor(newW)) / 2);
              });
            },
            child: child,
          );

      Widget video;
      if (_failed) {
        video = const SizedBox(
          height: 120,
          child: Center(
              child: Text('ویدیو پخش نشد',
                  style: TextStyle(color: Colors.white70, fontSize: 12))),
        );
      } else if (!ready) {
        video = const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      } else if (kIsWeb) {
        video = SizedBox(
          width: w,
          height: vh,
          child: buildMapHtmlVideo(
            key: ValueKey('mapvid-${widget.req.token}'),
            id: '${widget.req.token}',
            url: _webUrl!,
            loop: _loop,
            onRatio: (r) {
              if (mounted && r > 0 && r != _webRatio) {
                setState(() => _webRatio = r);
              }
            },
            onError: () {
              if (mounted) setState(() => _failed = true);
            },
            onState: (f, pl) {
              if (mounted && (pl != _webPlaying || (f - _webFrac).abs() > 0.002)) {
                setState(() {
                  _webFrac = f;
                  _webPlaying = pl;
                });
              }
            },
          ),
        );
        video = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => toggleMapHtmlVideo('${widget.req.token}'),
          child: Stack(
            alignment: Alignment.center,
            children: [
              video,
              if (!_webPlaying)
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
        );
      } else {
        // اندازه‌ی دقیق (بدون AspectRatio/ConstrainedBox/Clip) تا روی وب
        // ویدیو در یک نوار باریک بیرون از کادر نیفتد
        video = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => c!.value.isPlaying ? c.pause() : c.play(),
          child: SizedBox(
            width: w,
            height: vh,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(width: w, height: vh, child: VideoPlayer(c!)),
                if (!c!.value.isPlaying)
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
            // به‌جای Material(elevation) از DecoratedBox + ClipRRect استفاده شده:
            // لایه‌ی PhysicalShape روی وب باعث می‌شد عنصر <video> HTML از کارت
            // جدا شود و بیرون از کادر (کنار صفحه) بیفتد.
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xF2111111),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 14,
                      offset: Offset(0, 5)),
                ],
              ),
              // وب: هیچ کلیپی روی <video> نباید باشد (کلیپ روی platform view
              // ویدیو را از کادر جدا می‌کرد)؛ گوشه‌ها را همان DecoratedBox گرد می‌کند
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                clipBehavior: kIsWeb ? Clip.none : Clip.hardEdge,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  gestures(
                    SizedBox(
                      height: headerH,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(Icons.drag_indicator,
                              size: 18, color: Colors.white54),
                          const Spacer(),
                          if (ready)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (kIsWeb) {
                                  toggleMapHtmlVideo('${widget.req.token}');
                                } else if (c != null) {
                                  c.value.isPlaying ? c.pause() : c.play();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  (kIsWeb
                                          ? _webPlaying
                                          : (c?.value.isPlaying ?? false))
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
                  ready ? gestures(video) : video,
                  if (ready && kIsWeb)
                    LayoutBuilder(builder: (_, bc2) {
                      void seek(double dx) => seekMapHtmlVideo(
                          '${widget.req.token}', dx / bc2.maxWidth);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => seek(d.localPosition.dx),
                        onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
                        child: SizedBox(
                          height: barH,
                          child: Align(
                            alignment: Alignment.center,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(height: 4, color: Colors.white24),
                                FractionallySizedBox(
                                  widthFactor: _webFrac.clamp(0.0, 1.0),
                                  child: Container(
                                      height: 4,
                                      color: const Color(0xFF4FD1C5)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  if (ready && !kIsWeb)
                    SizedBox(
                      height: barH,
                      child: VideoProgressIndicator(c!,
                          allowScrubbing: true, padding: EdgeInsets.zero),
                    ),
                ],
              ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
