import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../services/app_prefs.dart';
import 'package:video_player/video_player.dart';

import '../state/gratitude_store.dart';
import '../services/media_db.dart';

const _kGold = Color(0xFFC9A24B);
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF7C8B87);
const _kBorder = Color(0xFFE7E5DB);
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

// ───────────────────── slide model ─────────────────────

class _Slide {
  final String key;
  final bool isVideo;
  final String src;
  const _Slide({required this.key, required this.isVideo, required this.src});
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
  static const _fadeMs = 700;

  final _cfg = _SlideshowCfg();
  bool _cfgLoaded = false;

  List<_Slide> _slides = [];

  // دو اسلات برای cross-fade
  final List<int> _slotIdx = [-1, -1];
  final List<VideoPlayerController?> _slotVid = [null, null];

  /// اسلاتی که در حال حاضر «روی» است (کاملاً نمایان).
  int _activeSlot = 0;

  /// اسلاتی که در حال fade-in است. -1 یعنی انتقالی در جریان نیست.
  int _pendingSlot = -1;

  Timer? _timer;
  bool _paused = false;
  Duration _remaining = Duration.zero;
  DateTime? _startedAt;

  late final AnimationController _transition;

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _fadeMs),
      value: 0,
    );
    _loadCfg();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _transition.dispose();
    _slotVid[0]?.dispose();
    _slotVid[1]?.dispose();
    super.dispose();
  }

  // ────── cfg ──────

  Future<void> _loadCfg() async {
    try {
      final sp = await AppPrefs.getInstance();
      final raw = sp.getString(_kKey);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw) as Map;
        _cfg.value = (j['value'] as num?)?.toDouble() ?? 5;
        _cfg.unit = j['unit'] as String? ?? 's';
        _cfg.order = j['order'] as String? ?? 'seq';
        _cfg.loop = j['loop'] as bool? ?? true;
      }
    } catch (_) {}
    _refreshSlides();
    if (mounted) setState(() => _cfgLoaded = true);
    if (_slides.isNotEmpty) {
      _showAt(0, initial: true);
    }
  }

  Future<void> _saveCfg() async {
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setString(_kKey, jsonEncode({
        'value': _cfg.value,
        'unit': _cfg.unit,
        'order': _cfg.order,
        'loop': _cfg.loop,
      }));
    } catch (_) {}
  }

  // ────── slides list ──────

  void _refreshSlides() {
    final out = <_Slide>[];
    for (final e in widget.store.entries) {
      if (e.source == 'purchase') continue;
      for (final im in e.images) {
        out.add(_Slide(
          key: 'g${e.id}_${im.id}',
          isVideo: _isVideoSrc(im.src),
          src: im.src,
        ));
      }
    }
    if (_cfg.order == 'rnd') out.shuffle();
    _slides = out;
  }

  static bool _isVideoSrc(String src) =>
      src.startsWith('data:video/') ||
      (MediaDb.isRef(src) && MediaDb.isVideo(src));

  // ────── slot management ──────

  void _clearSlot(int slot) {
    _slotIdx[slot] = -1;
    final ctl = _slotVid[slot];
    if (ctl != null) {
      try {
        ctl.pause();
      } catch (_) {}
      ctl.dispose();
      _slotVid[slot] = null;
    }
  }

  void _loadIntoSlot(int slot, int slideIdx) {
    final slide = _slides[slideIdx];
    _slotIdx[slot] = slideIdx;
    if (slide.isVideo) {
      _setupVideo(slot, slide.src);
    }
  }

  Future<void> _setupVideo(int slot, String src) async {
    _slotVid[slot]?.dispose();
    _slotVid[slot] = null;
    try {
      final ctl =
          VideoPlayerController.networkUrl(Uri.parse(MediaDb.toDataUrl(src) ?? src));
      await ctl.initialize();
      await ctl.setLooping(true);
      await ctl.setVolume(0);
      await ctl.play();
      if (!mounted) {
        ctl.dispose();
        return;
      }
      _slotVid[slot] = ctl;
      setState(() {});
    } catch (_) {}
  }

  /// نمایش اسلایدِ شماره‌ی `idx` با cross-fade.
  void _showAt(int idx, {bool initial = false}) {
    if (_slides.isEmpty) return;
    idx = idx.clamp(0, _slides.length - 1);

    if (initial) {
      _clearSlot(0);
      _clearSlot(1);
      _loadIntoSlot(0, idx);
      _activeSlot = 0;
      _pendingSlot = -1;
      _transition.value = 0;
      setState(() {});
      _scheduleNext();
      return;
    }

    // اگر انتقالی در جریان است، آن را تمام کن.
    if (_pendingSlot != -1) {
      _transition.stop();
      final old = _pendingSlot;
      _clearSlot(old);
      _activeSlot = 1 - old;
      _pendingSlot = -1;
      _transition.value = 0;
    }

    final next = 1 - _activeSlot;
    _clearSlot(next);
    _loadIntoSlot(next, idx);
    _pendingSlot = next;

    _transition.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _activeSlot = next;
        _pendingSlot = -1;
        _transition.value = 0;
      });
      // اسلات قدیمی را پاک کن
      _clearSlot(1 - next);
    });
    setState(() {});
  }

  int _currentSlideIdx() =>
      _activeSlot >= 0 && _activeSlot < 2 ? _slotIdx[_activeSlot] : -1;

  // ────── navigation ──────

  void _step(int dir, {required bool manual}) {
    if (_slides.length < 1) return;
    final cur = _currentSlideIdx();
    if (cur < 0) {
      _showAt(0);
      return;
    }
    int next = cur + dir;
    if (next >= _slides.length) {
      if (_cfg.loop || manual) {
        next = 0;
        if (_cfg.order == 'rnd') _refreshSlides();
      } else {
        next = _slides.length - 1;
      }
    } else if (next < 0) {
      if (_cfg.loop || manual) {
        next = _slides.length - 1;
      } else {
        next = 0;
      }
    }
    if (manual) {
      _paused = false;
    }
    _showAt(next);
  }

  void _goTo(int idx) {
    if (_slides.isEmpty) return;
    _showAt(idx);
    _paused = false;
    _scheduleNext();
  }

  // ────── timing ──────

  void _scheduleNext() {
    _timer?.cancel();
    _timer = null;
    if (_paused) return;
    if (_slides.length < 2) return;
    _remaining = Duration(milliseconds: _cfg.ms);
    _startedAt = DateTime.now();
    _timer = Timer(_remaining, () {
      if (!mounted) return;
      _step(1, manual: false);
    });
  }

  void _togglePause() {
    if (_slides.length < 2) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer?.cancel();
      _timer = null;
    } else {
      _scheduleNext();
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
        onTap: _togglePause,
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
              _slotWidget(0),
              _slotWidget(1),
              // شمارنده
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
                    '${_toFa(_currentSlideIdx() + 1)} / ${_toFa(_slides.length)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // نوار پیشرفت
              if (!_paused && _slides.length > 1 && _startedAt != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 3,
                  child: _ProgressBar(
                    key: ValueKey(
                        '${_currentSlideIdx()}_${_cfg.ms}_${_startedAt!.millisecondsSinceEpoch}'),
                    duration: Duration(milliseconds: _cfg.ms),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotWidget(int slot) {
    final idx = _slotIdx[slot];
    if (idx < 0 || idx >= _slides.length) return const SizedBox.shrink();

    final opacity = _slotOpacity(slot);
    if (opacity <= 0.001) return const SizedBox.shrink();

    final slide = _slides[idx];
    Widget child;
    if (slide.isVideo) {
      final ctl = _slotVid[slot];
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

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: child,
    );
  }

  double _slotOpacity(int slot) {
    if (_pendingSlot == -1) {
      return slot == _activeSlot ? 1.0 : 0.0;
    }
    if (slot == _activeSlot) return 1.0 - _transition.value;
    if (slot == _pendingSlot) return _transition.value;
    return 0.0;
  }

  Widget _navRow() {
    return Row(
      children: [
        Expanded(
          child: _navBtn('‹ بعدی', () {
            _step(1, manual: true);
          }),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _navBtn('قبلی ›', () {
            _step(-1, manual: true);
          }),
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
                _scheduleNext();
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
            _scheduleNext();
          },
        ),
        _ddl(
          value: _cfg.order,
          options: const [('seq', 'به‌ترتیب'), ('rnd', 'تصادفی')],
          onChanged: (v) {
            setState(() {
              _cfg.order = v;
              _refreshSlides();
            });
            _saveCfg();
            _goTo(0);
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

  static Uint8List? _dataUrlToBytes(String src) {
    try {
      if (MediaDb.isRef(src)) return MediaDb.bytes(src);
      if (!src.startsWith('data:')) return null;
      final i = src.indexOf(',');
      if (i < 0) return null;
      return base64Decode(src.substring(i + 1));
    } catch (_) {
      return null;
    }
  }

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
            child: const ColoredBox(color: Color(0xFFC9A24B)),
          ),
        ],
      ),
    );
  }
}
