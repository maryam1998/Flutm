import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../state/background_store.dart';
import 'grat_media.dart' show gratVideoController;
import '../services/media_blob.dart';
import 'bg_video_view.dart';
import 'web_background.dart';

/// لایه‌ی پس‌زمینه‌ی مشترک روی همه‌ی تب‌ها — مثل `#ambient-bg` در وب:
///  • زیرش همیشه پس‌زمینه‌ی «ساده (Calm)» است؛
///  • تصویر/ویدیوی دلخواه با «شفافیت» انتخابی روی آن محو می‌شود (نه با لایه‌ی سفید)؛
///  • Blur روی خود تصویر اعمال می‌شود و تصویر ۱۶٪ بزرگ‌تر است تا لبه‌ها بعد از Blur دیده نشوند؛
///  • ظاهر شدن/محو شدن ۰٫۷ ثانیه.
class BackgroundLayer extends StatefulWidget {
  const BackgroundLayer({super.key, required this.child});
  final Widget child;

  @override
  State<BackgroundLayer> createState() => _BackgroundLayerState();
}

class _BackgroundLayerState extends State<BackgroundLayer> {
  VideoPlayerController? _videoCtl;
  String? _loadedPath;
  int _gen = 0;

  /// وب: آدرس ویدیو برای `<video>` HTML (blob-URL یا آدرس مستقیم)
  String? _webUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVideo(context.watch<BackgroundStore>());
  }

  Future<void> _disposeVideo() async {
    final c = _videoCtl;
    _videoCtl = null;
    _loadedPath = null;
    if (c != null) {
      try {
        await c.dispose();
      } catch (_) {}
    }
  }

  Future<void> _syncVideo(BackgroundStore bg) async {
    final want = bg.active && bg.kind == BgKind.video ? bg.videoPath : null;
    if (kIsWeb) {
      // وب: بدون VideoPlayer؛ فقط آدرس را پیدا می‌کنیم و `<video>` HTML نشان می‌دهد
      if (want == null) {
        if (_webUrl != null || _loadedPath != null) {
          _webUrl = null;
          _loadedPath = null;
          if (mounted) setState(() {});
        }
        return;
      }
      if (_loadedPath == want) return;
      final gen = ++_gen;
      _loadedPath = want;
      String? url;
      try {
        url = MediaBlob.isRef(want) ? await MediaBlob.playableSource(want) : want;
      } catch (_) {}
      if (!mounted || gen != _gen) return;
      if (url == null) _loadedPath = null;
      setState(() => _webUrl = url);
      return;
    }
    if (want == null) {
      if (_videoCtl != null) {
        await _disposeVideo();
        if (mounted) setState(() {});
      }
      return;
    }
    if (_loadedPath == want) return;

    final gen = ++_gen;
    await _disposeVideo();
    _loadedPath = want;
    try {
      final ctl = await gratVideoController(want);
      await ctl.initialize();
      await ctl.setLooping(true);
      await ctl.setVolume(0);
      await ctl.play();
      if (!mounted || gen != _gen) {
        await ctl.dispose();
        return;
      }
      setState(() => _videoCtl = ctl);
    } catch (_) {
      if (gen == _gen) _loadedPath = null;
    }
  }

  @override
  void dispose() {
    _videoCtl?.dispose();
    super.dispose();
  }

  Widget? _media(BackgroundStore bg) {
    Widget? m;
    if (bg.kind == BgKind.image && bg.imageBytes != null) {
      m = Image.memory(
        bg.imageBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (bg.kind == BgKind.video &&
        _videoCtl != null &&
        _videoCtl!.value.isInitialized) {
      m = FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _videoCtl!.value.size.width,
          height: _videoCtl!.value.size.height,
          child: VideoPlayer(_videoCtl!),
        ),
      );
    }
    if (m == null) return null;
    if (bg.blur > 0) {
      m = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: bg.blur,
          sigmaY: bg.blur,
          tileMode: TileMode.decal,
        ),
        child: m,
      );
    }
    // inset:-8% در وب ⇒ ۱۱۶٪ اندازه، وسط‌چین
    return Transform.scale(scale: 1.16, child: m);
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.watch<BackgroundStore>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final webVideo = kIsWeb && bg.active && bg.kind == BgKind.video;
    final media = (bg.active && !webVideo) ? _media(bg) : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        WebBackground(isDark: isDark),
        if (webVideo && _webUrl != null)
          IgnorePointer(
            child: buildBackgroundVideo(
              url: _webUrl!,
              opacity: bg.opacity,
              blur: bg.blur,
            ),
          ),
        IgnorePointer(
          child: ClipRect(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 700),
              curve: Curves.ease,
              opacity: media == null ? 0 : bg.opacity,
              child: media ?? const SizedBox.expand(),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
