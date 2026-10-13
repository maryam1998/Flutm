import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceService {
  static final AudioRecorder _rec = AudioRecorder();

  static bool _isRecording = false;
  static DateTime? _startedAt;
  static String? _currentPath;

  static bool get isRecording => _isRecording;
  static DateTime? get startedAt => _startedAt;
  static Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// شروع ضبط. اگر مجوز نبود false برمی‌گرداند.
  static Future<bool> start() async {
    try {
      if (!await _rec.hasPermission()) return false;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
      _currentPath = path;
      return true;
    } catch (e) {
      debugPrint('VoiceService.start failed: $e');
      return false;
    }
  }

  /// توقف و برگرداندن data URL صوتی. اگر خطا داد null برمی‌گرداند.
  /// اگر حجم بیش از ۵ مگابایت باشد هم null برمی‌گرداند.
  static Future<String?> stop() async {
    try {
      if (!_isRecording) return null;
      final path = await _rec.stop();
      _isRecording = false;
      _startedAt = null;
      final p = path ?? _currentPath;
      _currentPath = null;
      if (p == null) return null;

      final f = File(p);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      // پاک‌سازی
      try {
        await f.delete();
      } catch (_) {}
      if (bytes.length > 5 * 1024 * 1024) return null;
      return 'data:audio/m4a;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('VoiceService.stop failed: $e');
      _isRecording = false;
      _startedAt = null;
      _currentPath = null;
      return null;
    }
  }

  /// لغو ضبط بدون ذخیره
  static Future<void> cancel() async {
    try {
      if (_isRecording) {
        await _rec.stop();
      }
      if (_currentPath != null) {
        try {
          final f = File(_currentPath!);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
    _isRecording = false;
    _startedAt = null;
    _currentPath = null;
  }

  static Future<void> dispose() async {
    try {
      await _rec.dispose();
    } catch (_) {}
  }
}
