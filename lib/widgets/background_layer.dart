import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../state/background_store.dart';
import 'web_background.dart';

/// لایه‌ی پس‌زمینه‌ی مشترک که روی همه‌ی تب‌ها نمایش داده می‌شه.
/// اگه پس‌زمینه‌ای تنظیم نشده باشه، گرادیان پیش‌فرض برمی‌گردونه.
class BackgroundLayer extends StatefulWidget {
  const BackgroundLayer({super.key, required this.child});
  final Widget child;

  @override
  State<BackgroundLayer> createState() => _BackgroundLayerState();
}

class _BackgroundLayerState extends State<BackgroundLayer> {
  VideoPlayerController? _videoCtl;
  String? _loadedPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bg = context.watch<BackgroundStore>();
    _syncVideo(bg);
  }

  Future<void> _syncVideo(BackgroundStore bg) async {
    if (bg.kind != BgKind.video || bg.videoPath == null) {
      if (_videoCtl != null) {
        await _videoCtl!.dispose();
        _videoCtl = null;
        _loadedPath = null;
      }
      return;
    }
    if (_loadedPath == bg.videoPath) return;

    if (_videoCtl != null) {
      await _videoCtl!.dispose();
      _videoCtl = null;
    }
    _loadedPath = bg.videoPath;
    final ctl = VideoPlayerController.file(File(bg.videoPath!));
    try {
      await ctl.initialize();
      await ctl.setLooping(true);
      await ctl.setVolume(0);
      await ctl.play();
      if (!mounted) {
        await ctl.dispose();
        return;
      }
      setState(() => _videoCtl = ctl);
    } catch (_) {
      _loadedPath = null;
    }
  }

  @override
  void dispose() {
    _videoCtl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.watch<BackgroundStore>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget bgWidget;
    if (bg.kind == BgKind.image && bg.imageBytes != null) {
      bgWidget = _bgImage(bg);
    } else if (bg.kind == BgKind.video && _videoCtl != null && _videoCtl!.value.isInitialized) {
      bgWidget = _bgVideo(bg);
    } else {
      bgWidget = WebBackground(isDark: isDark);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        bgWidget,
        widget.child,
      ],
    );
  }

  Widget _bgImage(BackgroundStore bg) {
    Widget img = Image.memory(
      bg.imageBytes!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
    if (bg.blur > 0) {
      img = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: bg.blur, sigmaY: bg.blur),
        child: img,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        img,
        Container(
          color: Colors.white.withValues(alpha: (1 - bg.opacity).clamp(0.0, 0.9)),
        ),
      ],
    );
  }

  Widget _bgVideo(BackgroundStore bg) {
    Widget v = FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _videoCtl!.value.size.width,
        height: _videoCtl!.value.size.height,
        child: VideoPlayer(_videoCtl!),
      ),
    );
    if (bg.blur > 0) {
      v = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: bg.blur, sigmaY: bg.blur),
        child: v,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        v,
        Container(
          color: Colors.white.withValues(alpha: (1 - bg.opacity).clamp(0.0, 0.9)),
        ),
      ],
    );
  }
}

// کمکی ساده برای ساخت Uri فایل
class FileUri {
  static Uri filePath(String path) => Uri.file(path);
}
