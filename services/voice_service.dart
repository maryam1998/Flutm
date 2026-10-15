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

      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
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
      if (kIsWeb) {
        final r = await http.get(Uri.parse(out));
        bytes = r.bodyBytes;
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

      return MediaDb.putBytes(bytes, 'audio/m4a');
    } catch (e) {
      debugPrint('VoiceService.stop failed: $e');
      _isRecording = false;
      _startedAt = null;
      return null;
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
