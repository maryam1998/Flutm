import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show FontFeature;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/audio_mime.dart';
import '../services/data_url_cache.dart';
import '../services/quiet_snack.dart';

const Color _kInk = Color(0xFF000000);
const Color _kMuted = Color(0xFF7C8B87);
const Color _kBorder = Color(0xFFE7E5DB);

/// پخش‌کننده‌ی صدا (ویس ضبط‌شده یا موسیقی) از data-URL — معادل `<audio controls>` وب.
class AudioClipView extends StatefulWidget {
  const AudioClipView({
    super.key,
    required this.src,
    this.title,
    this.onRemove,
  });

  final String src;
  final String? title;
  final VoidCallback? onRemove;

  @override
  State<AudioClipView> createState() => _AudioClipViewState();
}

class _AudioClipViewState extends State<AudioClipView> {
  final AudioPlayer _p = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _playing = false;
  bool _failed = false;
  bool _completed = false;
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;
  double _rate = 1.0;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _subs.add(_p.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
    }));
    _subs.add(_p.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    }));
    _subs.add(_p.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    }));
    _subs.add(_p.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _completed = true;
        _pos = Duration.zero;
      });
    }));
    _init();
  }

  Future<void> _init() async {
    try {
      await _p.setReleaseMode(ReleaseMode.stop);
      await _p.setSource(_sourceOf(widget.src));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// وب: data-URL مستقیم؛ موبایل: بایت‌ها (data-URL روی موبایل پخش نمی‌شود)
  static Source _sourceOf(String src) {
    if (!src.startsWith('data:')) return UrlSource(src);
    final Uint8List? bytes = DataUrlCache.bytes(src);
    if (bytes == null) return UrlSource(src);
    // ذخیره‌های قدیمی با برچسب اشتباه (مثلاً audio/m4a برای webm) اصلاح می‌شن
    if (kIsWeb) return UrlSource(fixAudioDataUrl(src, bytes));
    return BytesSource(bytes, mimeType: sniffAudioMime(bytes));
  }

  @override
  void didUpdateWidget(covariant AudioClipView old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src) {
      _failed = false;
      _completed = false;
      _pos = Duration.zero;
      _dur = Duration.zero;
      _p.stop();
      _init();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _p.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_failed) return;
    try {
      if (_playing) {
        await _p.pause();
      } else {
        if (_completed) {
          await _p.seek(Duration.zero);
          _completed = false;
        }
        await _p.resume();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  // ───────────── منوی ⋮ (مثل پلیر مرورگر): Download / Playback speed ─────────────

  static String _extOfMime(String mime) {
    switch (mime) {
      case 'audio/mpeg':
        return 'mp3';
      case 'audio/mp4':
        return 'm4a';
      case 'audio/webm':
        return 'webm';
      case 'audio/ogg':
        return 'ogg';
      case 'audio/wav':
        return 'wav';
      case 'audio/flac':
        return 'flac';
      case 'audio/aac':
        return 'aac';
      case 'audio/amr':
        return 'amr';
      case 'audio/aiff':
        return 'aiff';
      default:
        return 'mp3';
    }
  }

  Future<void> _download() async {
    try {
      final bytes = DataUrlCache.bytes(widget.src);
      if (bytes == null) throw StateError('no bytes');
      var name = (widget.title ?? '').trim();
      if (name.isEmpty) name = 'audio';
      name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (!RegExp(r'\.[A-Za-z0-9]{2,5}$').hasMatch(name)) {
        name = '$name.${_extOfMime(sniffAudioMime(bytes))}';
      }
      await FilePicker.platform.saveFile(
        dialogTitle: 'Download',
        fileName: name,
        bytes: bytes,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).quietSnack(const SnackBar(
        content: Text('ذخیره‌ی فایل صدا نشد'),
        duration: Duration(milliseconds: 1600),
      ));
    }
  }

  Future<void> _setRate(double r) async {
    try {
      await _p.setPlaybackRate(r);
      if (mounted) setState(() => _rate = r);
    } catch (_) {}
  }

  Future<void> _toggleMute() async {
    try {
      await _p.setVolume(_muted ? 1.0 : 0.0);
      if (mounted) setState(() => _muted = !_muted);
    } catch (_) {}
  }

  RelativeRect _menuPos(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(ctx).context.findRenderObject() as RenderBox;
    final tl = box.localToGlobal(Offset.zero, ancestor: overlay);
    // منو زیر/کنار دکمه، هم‌تراز با لبه‌ی راستِ دکمه (مثل کروم)
    return RelativeRect.fromLTRB(
      tl.dx + box.size.width - 200,
      tl.dy + box.size.height,
      overlay.size.width - (tl.dx + box.size.width),
      0,
    );
  }

  Future<void> _openMenu(BuildContext btnCtx) async {
    final pos = _menuPos(btnCtx);
    final pick = await showMenu<String>(
      context: context,
      position: pos,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      items: [
        PopupMenuItem<String>(
          value: 'download',
          height: 52,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: const [
              Icon(Icons.download, size: 22, color: Color(0xFF202124)),
              SizedBox(width: 18),
              Text('Download',
                  style: TextStyle(fontSize: 15, color: Color(0xFF202124))),
            ]),
          ),
        ),
        PopupMenuItem<String>(
          value: 'speed',
          height: 52,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: const [
              Icon(Icons.slow_motion_video,
                  size: 22, color: Color(0xFF202124)),
              SizedBox(width: 18),
              Text('Playback speed',
                  style: TextStyle(fontSize: 15, color: Color(0xFF202124))),
            ]),
          ),
        ),
      ],
    );
    if (!mounted || pick == null) return;
    if (pick == 'download') {
      await _download();
    } else if (pick == 'speed') {
      final r = await showMenu<double>(
        context: context,
        position: pos,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
        items: [
          for (final v in const [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
            PopupMenuItem<double>(
              value: v,
              height: 44,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(children: [
                  SizedBox(
                    width: 30,
                    child: v == _rate
                        ? const Icon(Icons.check,
                            size: 20, color: Color(0xFF202124))
                        : null,
                  ),
                  Text(v == 1.0 ? 'Normal' : '$v',
                      style: const TextStyle(
                          fontSize: 15, color: Color(0xFF202124))),
                ]),
              ),
            ),
        ],
      );
      if (r != null) await _setRate(r);
    }
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString();
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _dur.inMilliseconds;
    final value = total <= 0
        ? 0.0
        : (_pos.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
    final title = (widget.title ?? '').trim();
    const pillBg = Color(0xFFF1F3F4);
    const ink = Color(0xFF202124);

    // دقیقاً مثل اسکرین‌شات: [✕ گرد خاکستری] [برچسب] [کپسول پلیر: ▶ زمان نوار 🔊 ⋮]
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            if (widget.onRemove != null) ...[
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                      color: Color(0xFFE0E0E0), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 15, color: ink),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (title.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 54),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 11, color: _kMuted),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.only(left: 4, right: 0),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _failed
                    ? const Center(
                        child: Text('صدا پخش نشد',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(fontSize: 12, color: _kMuted)))
                    : Row(
                        children: [
                          GestureDetector(
                            onTap: _toggle,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              child: Icon(
                                  _playing ? Icons.pause : Icons.play_arrow,
                                  size: 26,
                                  color: ink),
                            ),
                          ),
                          Text(
                            '${_fmt(_pos)} / ${_fmt(_dur)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: ink,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: ink,
                                inactiveTrackColor: const Color(0xFFD0D3D6),
                                thumbColor: ink,
                                overlayShape: SliderComponentShape.noOverlay,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                              ),
                              child: Slider(
                                value: value,
                                onChanged: total <= 0
                                    ? null
                                    : (v) => setState(() => _pos = Duration(
                                        milliseconds: (v * total).round())),
                                onChangeEnd: total <= 0
                                    ? null
                                    : (v) => _p.seek(Duration(
                                        milliseconds: (v * total).round())),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _toggleMute,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                  _muted ? Icons.volume_off : Icons.volume_up,
                                  size: 21,
                                  color: ink),
                            ),
                          ),
                          Builder(
                            builder: (btnCtx) => GestureDetector(
                              onTap: () => _openMenu(btnCtx),
                              behavior: HitTestBehavior.opaque,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 6),
                                child:
                                    Icon(Icons.more_vert, size: 22, color: ink),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
