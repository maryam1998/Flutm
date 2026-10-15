import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../services/media_db.dart';
import '../theme/grat_palette.dart';

/// پخش‌کننده‌ی صوتِ شکرگذاری — معادل `.audio-player-box` وب (تگ <audio controls>).
/// منبع: data URL ضبط‌شده با VoiceService (یا هر URL دیگر).
/// از video_player استفاده می‌کنه (صوت رو هم پخش می‌کنه) تا پکیج تازه‌ای لازم نباشه.
class AudioPlayerBox extends StatefulWidget {
  final String src;
  final String name;
  final VoidCallback? onRemove;

  const AudioPlayerBox({
    super.key,
    required this.src,
    this.name = '',
    this.onRemove,
  });

  @override
  State<AudioPlayerBox> createState() => _AudioPlayerBoxState();
}

class _AudioPlayerBoxState extends State<AudioPlayerBox> {
  VideoPlayerController? _c;
  bool _busy = false;
  bool _failed = false;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  /// مرورگرها MIME «audio/m4a» و «audio/x-m4a» رو نمی‌شناسن؛ audio/mp4 درسته.
  static String _normalize(String src) {
    if (!src.startsWith('data:')) return src;
    return src
        .replaceFirst('data:audio/m4a;', 'data:audio/mp4;')
        .replaceFirst('data:audio/x-m4a;', 'data:audio/mp4;')
        .replaceFirst('data:audio/aac;', 'data:audio/mp4;');
  }

  Future<VideoPlayerController> _make() async {
    final src = _normalize(MediaDb.toDataUrl(widget.src) ?? widget.src);
    if (src.startsWith('data:') && !kIsWeb) {
      final comma = src.indexOf(',');
      final bytes = base64Decode(src.substring(comma + 1));
      final dir = await getTemporaryDirectory();
      final f = File(
          '${dir.path}/grat_audio_${DateTime.now().microsecondsSinceEpoch}.m4a');
      await f.writeAsBytes(bytes);
      return VideoPlayerController.file(f);
    }
    return VideoPlayerController.networkUrl(Uri.parse(src));
  }

  void _tick() {
    final c = _c;
    if (c == null || !mounted) return;
    final v = c.value;
    final ended = v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 120);
    setState(() {
      _pos = v.position;
      _dur = v.duration;
      _playing = v.isPlaying && !ended;
    });
    if (ended && v.isPlaying) {
      c.pause();
      c.seekTo(Duration.zero);
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    try {
      if (_c == null) {
        setState(() {
          _busy = true;
          _failed = false;
        });
        final c = await _make();
        await c.initialize();
        c.addListener(_tick);
        _c = c;
        if (!mounted) return;
        setState(() {
          _busy = false;
          _dur = c.value.duration;
        });
        await c.play();
        return;
      }
      final c = _c!;
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        if (_dur > Duration.zero && _pos >= _dur - const Duration(milliseconds: 200)) {
          await c.seekTo(Duration.zero);
        }
        await c.play();
      }
    } catch (e) {
      debugPrint('AudioPlayerBox failed: $e');
      _c?.removeListener(_tick);
      await _c?.dispose();
      _c = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
          _playing = false;
        });
      }
    }
  }

  static String _fa(String s) => s.replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
      );

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return _fa('$m:$s');
  }

  @override
  Widget build(BuildContext context) {
    final p = GratPalette.of(context);
    final total = _dur.inMilliseconds <= 0 ? 1 : _dur.inMilliseconds;
    final value = (_pos.inMilliseconds / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.mic_none, size: 15, color: p.emerald700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.name.isEmpty ? 'صوت' : widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: p.muted),
                ),
              ),
              if (widget.onRemove != null)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration:
                        BoxDecoration(color: p.danger, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            textDirection: TextDirection.ltr,
            children: [
              GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.emerald700,
                  ),
                  alignment: Alignment.center,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _playing ? Icons.pause : Icons.play_arrow,
                          size: 22,
                          color: Colors.white,
                        ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: p.emerald500,
                    inactiveTrackColor: p.line,
                    thumbColor: p.emerald500,
                  ),
                  child: Slider(
                    value: value,
                    onChanged: (_c == null || _dur == Duration.zero)
                        ? null
                        : (v) => _c!.seekTo(Duration(
                            milliseconds: (v * _dur.inMilliseconds).round())),
                  ),
                ),
              ),
              Text(
                '${_fmt(_pos)} / ${_fmt(_dur)}',
                style: TextStyle(fontSize: 10.5, color: p.muted),
              ),
            ],
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('پخش این صدا ممکن نشد',
                  style: TextStyle(fontSize: 11, color: p.danger)),
            ),
        ],
      ),
    );
  }
}
