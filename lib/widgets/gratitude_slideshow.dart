import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../models/gratitude_entry.dart';
import '../state/gratitude_store.dart';

const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kCard = Colors.white;

// ───────────────────── config ─────────────────────

class _SlideshowCfg {
  double value;
  String unit;
  String order;
  bool loop;

  _SlideshowCfg({
    this.value = 5,
    this.unit = 's',
    this.order = 'seq',
    this.loop = true,
  });

  int get ms {
    final v = value <= 0 ? 5.0 : value;
    final unitMs = unit == 'h' ? 3600000 : (unit == 'm' ? 60000 : 1000);
    return (v * unitMs).round().clamp(500, 1 << 31);
  }
}

// ───────────────────── widget ─────────────────────

class GratitudeSlideshow extends StatefulWidget {
  final GratitudeStore store;
  final VoidCallback? onOpenAlbum;

  const GratitudeSlideshow({
    super.key,
    required this.store,
    this.onOpenAlbum,
  });

  @override
  State<GratitudeSlideshow> createState() => _GratitudeSlideshowState();
}

class _GratitudeSlideshowState extends State<GratitudeSlideshow>
    with TickerProviderStateMixin {
  static const _kKey = 'gratSlideshow';

  final _cfg = _SlideshowCfg();
  bool _cfgLoaded = false;

  List<_Slide> _slides = [];
  int _pos = 0;

  Timer? _timer;
  bool _paused = false;
  Duration _remaining = Duration.zero;
  DateTime? _startedAt;

  int _activeLayer = 0;
  late final AnimationController _fade;

  VideoPlayerController? _vid0;
  VideoPlayerController? _vid1;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 1,
    );
    _loadCfg();
    _refreshSlides();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    _vid0?.dispose();
    _vid1?.dispose();
    super.dispose();
  }

  // ────── cfg ──────

  Future<void> _loadCfg() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kKey);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw) as Map;
        _cfg.value = (j['value'] as num?)?.toDouble() ?? 5;
        _cfg.unit = j['unit'] as String? ?? 's';
        _cfg.order = j['order'] as String? ?? 'seq';
        _cfg.loop = j['loop'] as bool? ?? true;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _cfgLoaded = true);
      _restart();
    }
  }

  Future<void> _saveCfg() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kKey, jsonEncode({
        'value': _cfg.value,
        'unit': _cfg.unit,
        'order': _cfg.order,
        'loop': _cfg.loop,
      }));
    } catch (_) {}
  }

  // ────── slides ──────

  void _refreshSlides() {
    final out = <_Slide>[];
    for (final e in widget.store.entries) {
      if (e.source == 'purchase') continue;
      for (final im in e.images) {
        final isVideo = _isVideoSrc(im.src);
        out.add(_Slide(
          key: 'g${e.id}_${im.id}',
          isVideo: isVideo,
          src: im.src,
        ));
      }
    }
    if (_cfg.order == 'rnd') {
      out.shuffle();
    }
    _slides = out;
    if (_pos >= _slides.length) _pos = 0;
  }

  static bool _isVideoSrc(String src) {
    if (!src.startsWith('data:')) return false;
    return src.startsWith('data:video/');
  }

  // ────── timing ──────

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (_paused) return;
    if (_slides.length < 2) return;
    _remaining = Duration(milliseconds: _cfg.ms);
    _startedAt = DateTime.now();
    _timer = Timer(_remaining, _tick);
  }

  void _tick() {
    if (!mounted) return;
    if (_slides.length < 2) return;
    _step(1, manual: false);
  }

  void _step(int dir, {required bool manual}) {
    if (_slides.isEmpty) return;
    final n = _slides.length;
    _pos = (_pos + dir) % n;
    if (_pos < 0) _pos = n - 1;

    if (manual) {
      _paused = false;
    }
    _showCurrent();
    if (!_paused) _restart();
  }

  void _showCurrent() {
    final idx = _pos.clamp(0, _slides.length - 1);
    final slide = _slides[idx];
    final next = 1 - _activeLayer;

    if (slide.isVideo) {
      _setupVideo(next, slide.src);
    } else {
      _clearLayer(next);
    }
    setState(() {
      _activeLayer = next;
    });
    _fade.forward(from: 0);
  }

  Future<void> _setupVideo(int layer, String src) async {
    _clearLayer(layer);
    try {
      final uri = Uri.parse(src);
      final ctl = VideoPlayerController.networkUrl(uri);
      await ctl.initialize();
      await ctl.setLooping(true);
      await ctl.setVolume(0);
      await ctl.play();
      if (layer == 0) {
        _vid0 = ctl;
      } else {
        _vid1 = ctl;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _clearLayer(int layer) {
    if (layer == 0) {
      _vid0?.dispose();
      _vid0 = null;
    } else {
      _vid1?.dispose();
      _vid1 = null;
    }
  }

  static Uint8List? _dataUrlToBytes(String src) {
    try {
      if (!src.startsWith('data:')) return null;
      final i = src.indexOf(',');
      if (i < 0) return null;
      return base64Decode(src.substring(i + 1));
    } catch (_) {
      return null;
    }
  }

  // ────── gestures ──────

  void _onTap() {
    if (_slides.isEmpty) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer?.cancel();
      _timer = null;
    } else {
      _restart();
    }
  }

  // ────── build ──────

  @override
  Widget build(BuildContext context) {
    if (!_cfgLoaded) return const SizedBox.shrink();
    if (_slides.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '🖼️ تصاویر شکرگذاری‌ها',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
        ),
        _stage(),
        const SizedBox(height: 8),
        _navRow(),
        const SizedBox(height: 8),
        _settingsRow(),
        if (widget.onOpenAlbum != null) ...[
          const SizedBox(height: 8),
          _albumBtn(),
        ],
      ],
    );
  }

  Widget _stage() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -200) {
            _step(1, manual: true);
          } else if (v > 200) {
            _step(-1, manual: true);
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              _layer(0),
              _layer(1),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_toFa(_pos + 1)} / ${_toFa(_slides.length)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (!_paused && _slides.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 3,
                  child: _ProgressBar(
                    key: ValueKey(
                        '${_pos}_${_cfg.ms}_${_startedAt?.millisecondsSinceEpoch}'),
                    duration: Duration(milliseconds: _cfg.ms),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _layer(int layer) {
    if (_slides.isEmpty) return const SizedBox.shrink();
    final idx = _pos.clamp(0, _slides.length - 1);
    final slide = _slides[idx];
    final isActive = layer == _activeLayer;

    Widget child;
    if (slide.isVideo) {
      final ctl = layer == 0 ? _vid0 : _vid1;
      if (ctl != null && ctl.value.isInitialized) {
        child = Center(
          child: AspectRatio(
            aspectRatio: ctl.value.aspectRatio,
            child: VideoPlayer(ctl),
          ),
        );
      } else {
        child = const SizedBox.shrink();
      }
    } else {
      final bytes = _dataUrlToBytes(slide.src);
      child = bytes != null
          ? Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            )
          : const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _fade,
      builder: (_, __) {
        final t = isActive ? _fade.value : 1 - _fade.value;
        return Opacity(opacity: t.clamp(0.0, 1.0), child: child);
      },
    );
  }

  Widget _navRow() {
    return Row(
      children: [
        Expanded(
          child: _navBtn('‹ بعدی', () => _step(1, manual: true)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _navBtn('قبلی ›', () => _step(-1, manual: true)),
        ),
      ],
    );
  }

  Widget _navBtn(String label, VoidCallback onTap) {
    return Material(
      color: _kCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('هر', style: TextStyle(fontSize: 12, color: _kInk)),
        SizedBox(
          width: 64,
          child: TextFormField(
            initialValue: _trimNum(_cfg.value),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: _kInk),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder),
              ),
            ),
            onChanged: (v) {
              final n = double.tryParse(_normDigits(v));
              if (n != null && n > 0) {
                _cfg.value = n;
                _saveCfg();
                if (!_paused) _restart();
              }
            },
          ),
        ),
        _ddl(
          value: _cfg.unit,
          options: const [('s', 'ثانیه'), ('m', 'دقیقه'), ('h', 'ساعت')],
          onChanged: (v) {
            setState(() => _cfg.unit = v);
            _saveCfg();
            if (!_paused) _restart();
          },
        ),
        _ddl(
          value: _cfg.order,
          options: const [('seq', 'به‌ترتیب'), ('rnd', 'تصادفی')],
          onChanged: (v) {
            setState(() {
              _cfg.order = v;
              _refreshSlides();
              _pos = 0;
            });
            _saveCfg();
            if (!_paused) _restart();
          },
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() => _cfg.loop = !_cfg.loop);
            _saveCfg();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _cfg.loop
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: _kGold,
                ),
                const SizedBox(width: 4),
                const Text('تکرار',
                    style: TextStyle(fontSize: 12, color: _kInk)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ddl({
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: const TextStyle(fontSize: 12.5, color: _kInk),
        items: [
          for (final o in options)
            DropdownMenuItem(
              value: o.$1,
              child: Text(o.$2,
                  style: const TextStyle(fontSize: 12.5, color: _kInk)),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _albumBtn() {
    return Material(
      color: _kCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onOpenAlbum,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: const Text(
            'مشاهده‌ی همه‌ی عکس‌ها ▦',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
        ),
      ),
    );
  }

  // ────── helpers ──────

  static String _toFa(int n) => n.toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
      );

  static String _trimNum(double n) {
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    return n.toString();
  }

  static String _normDigits(String s) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = fa.indexOf(ch);
      final j = ar.indexOf(ch);
      if (i >= 0) {
        b.write(i);
      } else if (j >= 0) {
        b.write(j);
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }
}

// ───────────────────── slide model ─────────────────────

class _Slide {
  final String key;
  final bool isVideo;
  final String src;
  const _Slide({required this.key, required this.isVideo, required this.src});
}

// ───────────────────── progress bar ─────────────────────

class _ProgressBar extends StatefulWidget {
  final Duration duration;
  const _ProgressBar({super.key, required this.duration});

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.18)),
          ),
          FractionallySizedBox(
            widthFactor: _c.value,
            child: const ColoredBox(color: Color(0xFFC9962B)),
          ),
        ],
      ),
    );
  }
}
