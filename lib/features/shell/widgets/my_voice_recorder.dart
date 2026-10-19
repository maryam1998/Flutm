// دکمه‌ی «ضبطِ صدایِ خودم» روی پلیر (تمرینِ shadowing) — معادلِ MyVoiceRecorder.jsx در Hope.
// کاملاً جدا از پخشِ اصلیِ TTS: با میکروفون ضبط می‌کند و پخشِ برگشتی‌اش یک پلیرِ مستقل است،
// پس می‌شود همزمان با صدای اصلی پخشش کرد و مقایسه کرد.
// ضبط فقط موقتی است (فایلِ کش)؛ با ✕ یا بسته شدنِ برنامه پاک می‌شود.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/theme/app_theme_colors.dart';

class MyVoiceRecorder extends StatefulWidget {
  const MyVoiceRecorder({super.key});

  @override
  State<MyVoiceRecorder> createState() => _MyVoiceRecorderState();
}

class _MyVoiceRecorderState extends State<MyVoiceRecorder> {
  final AudioRecorder _rec = AudioRecorder();
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _sub;
  bool _recording = false;
  bool _playing = false;
  bool _micDenied = false;
  String? _path;

  @override
  void dispose() {
    unawaited(_rec.dispose());
    _sub?.cancel();
    _player?.dispose();
    _deleteFile();
    super.dispose();
  }

  void _deleteFile() {
    final p = _path;
    if (p != null && !kIsWeb) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _start() async {
    setState(() => _micDenied = false);
    try {
      if (!await _rec.hasPermission()) {
        if (mounted) setState(() => _micDenied = true);
        return;
      }
      await _stopPlayback();
      _deleteFile();
      _path = null;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/shadow_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 192000,
          sampleRate: 44100,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
        ),
        path: path,
      );
      if (mounted) setState(() => _recording = true);
    } catch (_) {
      if (mounted) setState(() => _micDenied = true);
    }
  }

  Future<void> _stop() async {
    String? out;
    try {
      out = await _rec.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recording = false;
      _path = out;
    });
  }

  Future<void> _togglePlay() async {
    final p = _path;
    if (p == null) return;
    if (_playing) {
      await _stopPlayback();
      return;
    }
    try {
      final pl = _player ??= AudioPlayer();
      _sub ??= pl.playerStateStream.listen((st) {
        if (st.processingState == ProcessingState.completed && mounted) {
          setState(() => _playing = false);
        }
      });
      await pl.setFilePath(p);
      setState(() => _playing = true);
      await pl.play();
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _player?.stop();
    } catch (_) {}
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _delete() async {
    await _stopPlayback();
    _deleteFile();
    if (mounted) setState(() => _path = null);
  }

  Widget _btn(IconData icon, Color color, VoidCallback onTap, {String? tip}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Tooltip(
        message: tip ?? '',
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_micDenied)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text('اجازه‌ی میکروفون داده نشد',
                style: TextStyle(fontSize: 10, color: c.rose)),
          ),
        if (_path != null && !_recording) ...[
          _btn(_playing ? Icons.pause_circle_outline : Icons.play_circle_outline,
              c.teal, _togglePlay,
              tip: 'پخشِ صدای ضبط‌شده'),
          _btn(Icons.close, c.inkSoft, _delete, tip: 'پاک کردنِ ضبط'),
        ],
        _btn(
          _recording ? Icons.stop_circle : Icons.mic_none_outlined,
          c.rose,
          _recording ? _stop : _start,
          tip: _recording ? 'توقفِ ضبط' : 'ضبطِ صدای من',
        ),
      ],
    );
  }
}
