import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/app_prefs.dart';
import 'package:video_player/video_player.dart';

import '../models/gratitude_entry.dart';
import '../services/data_url_cache.dart';

String _fa(int n) => n.toString().replaceAllMapped(
    RegExp(r'\d'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)]);

/// تصویر از data-URL یا مسیر asset
Widget gratImageFromSrc(String src,
    {BoxFit fit = BoxFit.cover, int cacheWidth = 1000}) {
  if (src.isEmpty) return const SizedBox.shrink();
  if (src.startsWith('data:')) {
    final bytes = DataUrlCache.bytes(src);
    if (bytes == null) {
      return const Icon(Icons.broken_image, color: Colors.grey);
    }
    return Image.memory(bytes,
        fit: fit,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.grey));
  }
  return Image.asset(src,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, color: Colors.grey));
}

// ═══════════════════════════ ویدیو ═══════════════════════════

/// ساخت کنترلر ویدیو از data-URL / مسیر فایل / آدرس.
/// روی موبایل data-URL مستقیم پخش نمی‌شود، پس اول در فایل موقت نوشته می‌شود.
Future<VideoPlayerController> gratVideoController(String src) async {
  if (src.startsWith('data:')) {
    if (kIsWeb) return VideoPlayerController.networkUrl(Uri.parse(src));
    final bytes = base64Decode(src.substring(src.indexOf(',') + 1));
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/gv_${src.hashCode}_${bytes.length}.mp4');
    if (!await f.exists()) await f.writeAsBytes(bytes, flush: true);
    return VideoPlayerController.file(f);
  }
  if (src.startsWith('http') || src.startsWith('blob:') || kIsWeb) {
    return VideoPlayerController.networkUrl(Uri.parse(src));
  }
  return VideoPlayerController.file(File(src));
}

/// پخش‌کننده‌ی ویدیوی شکرگذاری با کنترل (مثل <video controls> وب)
class GratVideoView extends StatefulWidget {
  const GratVideoView({super.key, required this.src, this.onRemove});
  final String src;
  final VoidCallback? onRemove;

  @override
  State<GratVideoView> createState() => _GratVideoViewState();
}

class _GratVideoViewState extends State<GratVideoView> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = await gratVideoController(widget.src);
      await c.initialize();
      await c.setLooping(false);
      c.addListener(() {
        if (mounted) setState(() {});
      });
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() => _c = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    Widget body;
    if (_failed) {
      body = const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
            child: Text('ویدیو پخش نشد',
                style: TextStyle(color: Colors.white70, fontSize: 12))),
      );
    } else if (c == null || !c.value.isInitialized) {
      body = const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => c.value.isPlaying ? c.pause() : c.play(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                    aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
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
          VideoProgressIndicator(c, allowScrubbing: true),
        ],
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(color: Colors.black, child: body),
        ),
        if (widget.onRemove != null)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: widget.onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                    color: Color(0xFFE5484D), shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 15, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════ آلبوم ═══════════════════════════

/// آلبوم تمام‌صفحه‌ی عکس‌ها (مثل vg-viewer وب):
/// زوم با دو انگشت، ورق‌زدن، شمارنده، نمای شبکه‌ای، حذف، و اسلایدشوی خودکار
/// (لمس = توقف؛ ورق‌زدن یا قبلی/بعدی = ادامه).
Future<void> showGratAlbum(
  BuildContext context, {
  required List<GratitudeImage> Function() images,
  void Function(GratitudeImage im)? onRemove,
  VoidCallback? onChanged,
  int start = 0,
  String cfgKey = 'gratSlideshow',
}) {
  if (images().isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (_, __, ___) => _GratAlbum(
        getImages: images,
        onRemove: onRemove,
        onChanged: onChanged,
        start: start,
        cfgKey: cfgKey,
      ),
    ),
  );
}

class _GratAlbum extends StatefulWidget {
  const _GratAlbum({
    required this.getImages,
    required this.start,
    this.cfgKey = 'gratSlideshow',
    this.onRemove,
    this.onChanged,
  });
  final String cfgKey;
  final List<GratitudeImage> Function() getImages;
  final void Function(GratitudeImage im)? onRemove;
  final VoidCallback? onChanged;
  final int start;

  @override
  State<_GratAlbum> createState() => _GratAlbumState();
}

class _GratAlbumState extends State<_GratAlbum> {
  late final PageController _pc;
  final _tc = TransformationController();
  late int _idx;
  bool _paused = false;
  bool _zoomed = false;
  bool _grid = false;
  Timer? _timer;

  // تنظیم همان اسلایدشوی تب (gratSlideshow)
  double _value = 5;
  String _unit = 's';
  String _order = 'seq';
  bool _loop = true;

  List<GratitudeImage> get _list => widget.getImages();

  @override
  void initState() {
    super.initState();
    final n = _list.length;
    _idx = widget.start.clamp(0, math.max(0, n - 1));
    _pc = PageController(initialPage: _idx);
    _tc.addListener(() {
      final z = _tc.value.getMaxScaleOnAxis() > 1.02;
      if (z != _zoomed) {
        setState(() => _zoomed = z);
        if (z) {
          _timer?.cancel();
        } else if (!_paused) {
          _schedule();
        }
      }
    });
    _loadCfg();
  }

  Future<void> _loadCfg() async {
    try {
      final sp = await AppPrefs.getInstance();
      final raw = sp.getString(widget.cfgKey);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw) as Map;
        _value = (j['value'] as num?)?.toDouble() ?? 5;
        _unit = j['unit'] as String? ?? 's';
        _order = j['order'] as String? ?? 'seq';
        _loop = j['loop'] as bool? ?? true;
      }
    } catch (_) {}
    _schedule();
  }

  int get _ms {
    final v = _value <= 0 ? 5.0 : _value;
    final u = _unit == 'h' ? 3600000 : (_unit == 'm' ? 60000 : 1000);
    return math.max(500, (v * u).round());
  }

  void _schedule([int? ms]) {
    _timer?.cancel();
    _timer = null;
    if (_paused || _zoomed || _grid || _list.length < 2) return;
    _timer = Timer(Duration(milliseconds: ms ?? _ms), _tick);
  }

  void _tick() {
    if (!mounted) return;
    final n = _list.length;
    if (n < 2 || _paused || _zoomed || _grid) return;
    int next;
    if (_order == 'rnd') {
      do {
        next = math.Random().nextInt(n);
      } while (next == _idx);
    } else {
      next = _idx + 1;
      if (next >= n) {
        if (!_loop) return;
        next = 0;
      }
    }
    _goTo(next);
    _schedule();
  }

  void _goTo(int i) {
    if (!_pc.hasClients) return;
    _pc.animateToPage(i,
        duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
  }

  /// ورق‌زدن/قبلی/بعدی → برگشت به حالت خودکار
  void _manual(int dir) {
    final n = _list.length;
    if (n == 0) return;
    setState(() => _paused = false);
    _goTo((_idx + dir + n) % n);
    _schedule(_ms + 400);
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer?.cancel();
    } else {
      _schedule();
    }
  }

  Future<void> _delete() async {
    final list = _list;
    if (_idx >= list.length || widget.onRemove == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('این عکس حذف بشه؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('نه')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.onRemove!(list[_idx]);
    widget.onChanged?.call();
    final n = _list.length;
    if (n == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _idx = _idx.clamp(0, n - 1));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (list.isEmpty) return const SizedBox.shrink();
    final idx = _idx.clamp(0, list.length - 1);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePause,
                child: PageView.builder(
                  controller: _pc,
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: list.length,
                  onPageChanged: (i) {
                    _tc.value = Matrix4.identity();
                    setState(() => _idx = i);
                    _schedule();
                  },
                  itemBuilder: (_, i) => InteractiveViewer(
                    transformationController: i == idx ? _tc : null,
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: gratImageFromSrc(list[i].src,
                          fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              // نوار بالا
              Positioned(
                top: 6,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 26),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_fa(idx + 1)} / ${_fa(list.length)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    if (_paused)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.pause_circle_outline,
                            color: Colors.white70, size: 24),
                      ),
                    if (widget.onRemove != null)
                      IconButton(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 24),
                      ),
                    IconButton(
                      onPressed: () {
                        setState(() => _grid = !_grid);
                        if (_grid) {
                          _timer?.cancel();
                        } else {
                          _schedule();
                        }
                      },
                      icon: const Icon(Icons.grid_view_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              // قبلی / بعدی
              if (list.length > 1) ...[
                Positioned(
                  left: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _arrow(Icons.chevron_left, () => _manual(1))),
                ),
                Positioned(
                  right: 6,
                  top: 0,
                  bottom: 0,
                  child:
                      Center(child: _arrow(Icons.chevron_right, () => _manual(-1))),
                ),
              ],
              if (_grid) _gridView(list, idx),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrow(IconData i, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
              color: Colors.black45, shape: BoxShape.circle),
          child: Icon(i, color: Colors.white, size: 26),
        ),
      );

  Widget _gridView(List<GratitudeImage> list, int cur) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.94),
        padding: const EdgeInsets.fromLTRB(10, 56, 10, 10),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () {
              setState(() => _grid = false);
              _pc.jumpToPage(i);
              _schedule();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: i == cur ? const Color(0xFFC9962B) : Colors.white24,
                    width: i == cur ? 2.5 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: gratImageFromSrc(list[i].src),
            ),
          ),
        ),
      ),
    );
  }
}
