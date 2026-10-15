import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'media_db.dart';

class VoiceService {
  static final AudioRecorder _rec = AudioRecorder();

  static bool _isRecording = false;
  static DateTime? _startedAt;
  static AudioEncoder _encoder = AudioEncoder.aacLc;

  static bool get isRecording => _isRecording;
  static DateTime? get startedAt => _startedAt;
  static Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  static Future<bool> start() async {
    try {
      if (!await _rec.hasPermission()) return false;

      String path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      // مرورگرها همه‌ی کدک‌ها رو برای MediaRecorder ندارن (کروم تا همین اواخر aac نداشت)،
      // پس اولین کدکِ پشتیبانی‌شده انتخاب می‌شه.
      var enc = AudioEncoder.aacLc;
      for (final c in const [
        AudioEncoder.aacLc,
        AudioEncoder.opus,
        AudioEncoder.wav,
      ]) {
        try {
          if (await _rec.isEncoderSupported(c)) {
            enc = c;
            break;
          }
        } catch (_) {}
      }
      _encoder = enc;

      await _rec.start(
        RecordConfig(
          encoder: enc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _isRecording = true;
      _startedAt = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('VoiceService.start failed: $e');
      return false;
    }
  }

  static Future<String?> stop() async {
    try {
      if (!_isRecording) return null;
      final out = await _rec.stop();
      _isRecording = false;
      _startedAt = null;
      if (out == null) return null;

      Uint8List? bytes;
      var mime = _mimeFor(_encoder);
      if (kIsWeb) {
        final r = await http.get(Uri.parse(out));
        bytes = r.bodyBytes;
        final ct = (r.headers['content-type'] ?? '').split(';').first.trim();
        if (ct.startsWith('audio/')) mime = ct;
      } else {
        final f = File(out);
        if (!await f.exists()) return null;
        bytes = await f.readAsBytes();
        try {
          await f.delete();
        } catch (_) {}
      }

      if (bytes == null || bytes.isEmpty) return null;
      if (bytes.length > 100 * 1024 * 1024) return null;

      return MediaDb.putBytes(bytes, mime);
    } catch (e) {
      debugPrint('VoiceService.stop failed: $e');
      _isRecording = false;
      _startedAt = null;
      return null;
    }
  }

  static String _mimeFor(AudioEncoder e) {
    switch (e) {
      case AudioEncoder.opus:
        return 'audio/ogg';
      case AudioEncoder.wav:
        return 'audio/wav';
      default:
        return 'audio/mp4';
    }
  }

  static Future<void> cancel() async {
    try {
      if (_isRecording) {
        final out = await _rec.stop();
        if (out != null && !kIsWeb) {
          try {
            final f = File(out);
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
    _isRecording = false;
    _startedAt = null;
  }

  static Future<void> dispose() async {
    try {
      await _rec.dispose();
    } catch (_) {}
  }
}
