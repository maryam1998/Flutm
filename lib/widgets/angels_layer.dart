import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../state/angels_store.dart';
import 'angel_video_view.dart';

/// لایه‌ی تصاویر و ویدیوهای متحرک شناور روی همه‌ی تب‌ها.
/// - عکس‌ها: با ShaderMask (در RepaintBoundary برای پشتیبانی از GIF)
/// - ویدیوها روی وب: HTML `<video>` با CSS mask
/// - ویدیوها روی نیتیو: VideoPlayer + ShaderMask
class AngelsLayer extends StatefulWidget {
  const AngelsLayer({super.key});

  @override
  State<AngelsLayer> createState() => _AngelsLayerState();
}

class _AngelsLayerState extends State<AngelsLayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final List<_AngelItem> _items = [];
  final math.Random _rng = math.Random();

  String _signature = '';
  bool _fromTick = false;
  Size _screen = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastElapsed = Duration.zero;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final it in _items) {
      it.dispose();
    }
    _items.clear();
    _ticker.dispose();
    super.dispose();
  }

  // ─────── انیمیشن ───────

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    // حدود ۳۰ فریم در ثانیه کافی است (حرکتِ فرشته‌ها کند است) و نصفِ بار می‌شود
    if ((elapsed - _lastElapsed).inMilliseconds < 30) return;
    var dtMs = (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;
    if (dtMs < 0) dtMs = 16;
    dtMs = dtMs.clamp(0, 50);
    final dt = dtMs / 1000.0;

    final store = context.read<AngelsStore>();
    final sp = store.speed * 14.0;
    final s = store.size;
    final w = _screen.width;
    final h = _screen.height;
    if (w <= 0 || h <= 0) return;

    for (final it in _items) {
      if (!it.x.isFinite || !it.y.isFinite || !it.vx.isFinite || !it.vy.isFinite) {
        final a0 = _rng.nextDouble() * math.pi * 2;
        it.x = _rng.nextDouble() * math.max(10, w - s);
        it.y = _rng.nextDouble() * math.max(10, h - s);
        it.vx = math.cos(a0);
        it.vy = math.sin(a0);
        it.ph = 0;
      }

      it.ph += dt * 0.7;
      final ang = math.atan2(it.vy, it.vx) + math.sin(it.ph) * dt * 0.8;
      it.vx = math.cos(ang);
      it.vy = math.sin(ang);

      it.x += it.vx * sp * dt;
      it.y += it.vy * sp * dt;

      // با لبه‌ی محو (soft) کمی بیرون‌زدگی مجاز است؛ بدون محو، آیتم کاملاً داخل صفحه می‌ماند
      final spill = store.soft ? 0.15 : 0.0;
      final m = -s * spill;
      final maxX = math.max(m, w - s * (1 - spill));
      final maxY = math.max(m, h - s * (1 - spill));
      if (it.x < m) { it.x = m; it.vx = it.vx.abs(); }
      if (it.x > maxX) { it.x = maxX; it.vx = -it.vx.abs(); }
      if (it.y < m) { it.y = m; it.vy = it.vy.abs(); }
      if (it.y > maxY) { it.y = maxY; it.vy = -it.vy.abs(); }

      it.dispY = it.y + math.sin(it.ph * 2) * 6;
    }
    if (mounted) {
      _fromTick = true;
      setState(() {});
    }
  }

  // ─────── sync با store ───────

  void _syncItems(AngelsStore store, Size screen) {
    final sig = '${store.images.map((e) => 'i${e.id}').join('|')}'
        '--'
        '${store.videos.map((e) => 'v${e.id}').join('|')}';
    if (sig == _signature && _screen == screen) return;
    _signature = sig;
    _screen = screen;

    final aliveImgs = store.images.map((e) => e.id).toSet();
    final aliveVids = store.videos.map((e) => e.id).toSet();
    _items.removeWhere((it) {
      if (it.isVideo) {
        if (aliveVids.contains(it.id)) return false;
      } else {
        if (aliveImgs.contains(it.id)) return false;
      }
      it.dispose();
      return true;
    });

    final existingImgIds =
        _items.where((it) => !it.isVideo).map((it) => it.id).toSet();
    for (final im in store.images) {
      if (existingImgIds.contains(im.id)) continue;
      final a = _rng.nextDouble() * math.pi * 2;
      _items.add(_AngelItem(
        id: im.id,
        isVideo: false,
        imageBytes: im.bytes,
        x: _rng.nextDouble() * math.max(10, screen.width - store.size),
        y: _rng.nextDouble() * math.max(10, screen.height - store.size),
        vx: math.cos(a),
        vy: math.sin(a),
        ph: _rng.nextDouble() * 6.28,
      ));
    }

    final existingVidIds =
        _items.where((it) => it.isVideo).map((it) => it.id).toSet();
    for (final v in store.videos) {
      if (existingVidIds.contains(v.id)) continue;
      _loadVideo(store, v, screen);
    }
  }

  Future<void> _loadVideo(
    AngelsStore store,
    AngelVideo v,
    Size screen,
  ) async {
    final placeholder = _AngelItem(
      id: v.id,
      isVideo: true,
      loading: true,
      x: 0,
      y: 0,
      vx: 0,
      vy: 0,
      ph: 0,
    );
    _items.add(placeholder);

    final blob = await store.loadVideoBlob(v.id);
    if (blob == null) {
      _items.removeWhere((it) => identical(it, placeholder));
      return;
    }
    final url = await store.videoBlobUrl(blob.bytes, blob.mime);
    if (url == null) {
      _items.removeWhere((it) => identical(it, placeholder));
      return;
    }

    // روی وب: دیگر VideoPlayer لازم نیست — از HTML video استفاده می‌کنیم
    if (kIsWeb) {
      if (!mounted) return;
      final a = _rng.nextDouble() * math.pi * 2;
      setState(() {
        placeholder.loading = false;
        placeholder.blobUrl = url;
        placeholder.x =
            _rng.nextDouble() * math.max(10, screen.width - store.size);
        placeholder.y =
            _rng.nextDouble() * math.max(10, screen.height - store.size);
        placeholder.vx = math.cos(a);
        placeholder.vy = math.sin(a);
        placeholder.ph = _rng.nextDouble() * 6.28;
      });
      return;
    }

    // روی نیتیو: VideoPlayer
    final ctl = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await ctl.initialize();
      await ctl.setLooping(true);
      await ctl.setVolume(0);
      await ctl.play();
    } catch (_) {
      ctl.dispose();
      try {
        await store.revokeBlobUrl(url);
      } catch (_) {}
      _items.removeWhere((it) => identical(it, placeholder));
      return;
    }
    if (!mounted) {
      ctl.dispose();
      return;
    }
    final a = _rng.nextDouble() * math.pi * 2;
    setState(() {
      placeholder.loading = false;
      placeholder.videoController = ctl;
      placeholder.blobUrl = url;
      placeholder.x =
          _rng.nextDouble() * math.max(10, screen.width - store.size);
      placeholder.y =
          _rng.nextDouble() * math.max(10, screen.height - store.size);
      placeholder.vx = math.cos(a);
      placeholder.vy = math.sin(a);
      placeholder.ph = _rng.nextDouble() * 6.28;
    });
  }

  void _ensureTickerRunning(AngelsStore store) {
    final shouldRun = store.on && store.hasAssets;
    if (shouldRun && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
      _lastElapsed = Duration.zero;
    }
  }

  // ─────── build ───────

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AngelsStore>();
    final screen = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    // بازسازیِ ناشی از تیکِ انیمیشن نیازی به sync دوباره ندارد (هر فریم رشته می‌ساخت)
    final fromTick = _fromTick;
    _fromTick = false;
    if (!fromTick) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncItems(store, screen);
        _ensureTickerRunning(store);
      });
    }

    if (!store.on || !store.hasAssets) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final it in _items)
            if (!it.loading)
              Positioned(
                // روی پیکسل واقعی گرد می‌شود تا لبه‌ی لایه محو/خط‌دار نشود
                left: (it.x * dpr).roundToDouble() / dpr,
                top: (it.dispY * dpr).roundToDouble() / dpr,
                // لایه‌ی جدا برای هر فرشته: با حرکت فقط جابه‌جا می‌شود و دوباره رسم نمی‌شود
                // (حالت ترکیب screen/multiply باید با پشت‌زمینه ترکیب شود، پس لایه‌ی جدا ندارد)
                child: store.blend == 'normal'
                    ? RepaintBoundary(
                        child: _AngelWidget(
                          item: it,
                          size: (store.size * dpr).roundToDouble() / dpr,
                          opacity: store.opacity,
                          soft: store.soft,
                          blend: store.blend,
                        ),
                      )
                    : _AngelWidget(
                        item: it,
                        size: (store.size * dpr).roundToDouble() / dpr,
                        opacity: store.opacity,
                        soft: store.soft,
                        blend: store.blend,
                      ),
              ),
        ],
      ),
    );
  }
}

// ─────── ویجت هر آیتم ───────

class _AngelWidget extends StatelessWidget {
  final _AngelItem item;
  final double size;
  final double opacity;
  final bool soft;
  final String blend;

  const _AngelWidget({
    required this.item,
    required this.size,
    required this.opacity,
    required this.soft,
    this.blend = 'normal',
  });

  /// مثل `mix-blend-mode` در وب: عادی / screen (محو تیره‌ها) / multiply (محو سفیدها)
  @override
  Widget build(BuildContext context) {
    final w = _content(context);
    if (blend == 'screen') return _BlendMask(blendMode: BlendMode.screen, child: w);
    if (blend == 'multiply') {
      return _BlendMask(blendMode: BlendMode.multiply, child: w);
    }
    return w;
  }

  Widget _content(BuildContext context) {
    // ─── ویدیو روی وب: HTML video با CSS mask ───
    if (item.isVideo && kIsWeb && item.blobUrl != null) {
      return buildAngelVideo(
        id: item.id,
        url: item.blobUrl!,
        soft: soft,
        size: size,
        opacity: opacity,
      );
    }

    // ─── ویدیو روی نیتیو: VideoPlayer ───
    if (item.isVideo) {
      final ctl = item.videoController;
      if (ctl == null || !ctl.value.isInitialized) {
        return const SizedBox.shrink();
      }
      Widget v = SizedBox(
        width: size,
        height: size,
        child: FittedBox(
          fit: BoxFit.contain,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: ctl.value.size.width,
            height: ctl.value.size.height,
            child: VideoPlayer(ctl),
          ),
        ),
      );
      if (soft) {
        v = RepaintBoundary(
          child: ShaderMask(
            shaderCallback: _maskShader,
            blendMode: BlendMode.dstIn,
            child: v,
          ),
        );
      }
      return Opacity(opacity: opacity, child: v);
    }

    // ─── عکس یا GIF ───
    final b = item.imageBytes;
    if (b == null || b.isEmpty) return const SizedBox.shrink();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget img = Image.memory(
      b,
      width: size, // ارتفاع آزاد: نسبت عکس حفظ می‌شه (height:auto در وب)
      // دیکد در اندازه‌ی نمایش (نه اندازه‌ی کامل عکس/GIF) ⇒ رم و CPU خیلی کمتر
      cacheWidth: (size * dpr).round().clamp(64, 1600),
      fit: BoxFit.fitWidth,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
    );
    if (soft) {
      img = RepaintBoundary(
        child: ShaderMask(
          shaderCallback: _maskShader,
          blendMode: BlendMode.dstIn,
          child: img,
        ),
      );
    }
    return Opacity(opacity: opacity, child: img);
  }

  /// معادل `radial-gradient(ellipse at center, #000 52%, transparent 72%)` در CSS.
  /// در CSS شعاع بیضی «farthest-corner» است (نیم‌قطر × √۲)، نه نصفِ ضلع کوتاه؛
  /// قبلاً ماسک خیلی تنگ‌تر بود و فرشته بریده می‌شد. انتهای محو را ۰٫۷۰ گذاشتم
  /// (نه ۰٫۷۲) تا وسط لبه‌های کادر کاملاً شفاف شود و «کادر کمرنگ» دور عکس نیفتد.
  static Shader _maskShader(Rect rect) {
    const k = 1.4142135623730951;
    final m = Matrix4.identity()
      ..setEntry(0, 0, rect.width / 2 * k)
      ..setEntry(1, 1, rect.height / 2 * k)
      ..setTranslationRaw(rect.center.dx, rect.center.dy, 0);
    return ui.Gradient.radial(
      Offset.zero,
      1.0,
      const [Colors.white, Colors.white, Color(0x00FFFFFF)],
      const [0.0, 0.52, 0.70],
      TileMode.clamp,
      m.storage,
    );
  }
}

// ─────── مدل داخلی ───────

class _AngelItem {
  final String id;
  final bool isVideo;
  bool loading;
  Uint8List? imageBytes;
  VideoPlayerController? videoController;
  String? blobUrl;

  double x, y, vx, vy, ph, dispY;

  _AngelItem({
    required this.id,
    required this.isVideo,
    this.loading = false,
    this.imageBytes,
    this.videoController,
    this.blobUrl,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.ph,
  }) : dispY = y;

  void dispose() {
    try {
      videoController?.dispose();
    } catch (_) {}
    videoController = null;
    blobUrl = null;
  }
}


/// ترکیب رنگ با پشت‌زمینه (معادل CSS mix-blend-mode)
class _BlendMask extends SingleChildRenderObjectWidget {
  const _BlendMask({required this.blendMode, super.child});
  final BlendMode blendMode;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBlendMask(blendMode);

  @override
  void updateRenderObject(BuildContext context, _RenderBlendMask r) {
    r.blendMode = blendMode;
  }
}

class _RenderBlendMask extends RenderProxyBox {
  _RenderBlendMask(this._blendMode);
  BlendMode _blendMode;
  set blendMode(BlendMode v) {
    if (v == _blendMode) return;
    _blendMode = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = _blendMode,
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}
