import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// یک تصویر angels. id یکتا برای ردیابی موقعیتش روی صفحه.
class AngelImage {
  final String id;
  final Uint8List bytes;
  AngelImage({required this.id, required this.bytes});
}

/// تنظیمات و لیست تصاویر متحرک شناور (angels).
/// معادل `appAngels` در localStorage نسخه‌ی وب.
class AngelsStore extends ChangeNotifier {
  static const _kOn = 'angels_on';
  static const _kSize = 'angels_size';
  static const _kSpeed = 'angels_speed';
  static const _kOpacity = 'angels_opacity';
  static const _kSoft = 'angels_soft';
  static const _kBlend = 'angels_blend';
  static const _kFs = 'angels_fs';
  static const _kImages = 'angels_images_v1';

  static const int maxImageBytes = 10 * 1024 * 1024;

  bool _on = false;
  double _size = 140;
  double _speed = 3;
  double _opacity = 0.85;
  bool _soft = true;
  String _blend = 'normal';
  bool _fs = true;
  final List<AngelImage> _images = [];

  bool get on => _on;
  double get size => _size;
  double get speed => _speed;
  double get opacity => _opacity;
  bool get soft => _soft;
  String get blend => _blend;
  bool get fs => _fs;
  List<AngelImage> get images => List.unmodifiable(_images);
  bool get hasImages => _images.isNotEmpty;

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _on = sp.getBool(_kOn) ?? false;
      _size = (sp.getDouble(_kSize) ?? 140).clamp(60, 320);
      _speed = (sp.getDouble(_kSpeed) ?? 3).clamp(1, 12);
      _opacity = (sp.getDouble(_kOpacity) ?? 0.85).clamp(0.2, 1.0);
      _soft = sp.getBool(_kSoft) ?? true;
      _blend = sp.getString(_kBlend) ?? 'normal';
      _fs = sp.getBool(_kFs) ?? true;

      final raw = sp.getString(_kImages);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          _images.clear();
          for (final e in list) {
            if (e is Map) {
              final id = e['id'] as String? ?? '';
              final b64 = e['b64'] as String? ?? '';
              if (id.isNotEmpty && b64.isNotEmpty) {
                try {
                  _images.add(AngelImage(id: id, bytes: base64Decode(b64)));
                } catch (_) {}
              }
            }
          }
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_kOn, _on);
      await sp.setDouble(_kSize, _size);
      await sp.setDouble(_kSpeed, _speed);
      await sp.setDouble(_kOpacity, _opacity);
      await sp.setBool(_kSoft, _soft);
      await sp.setString(_kBlend, _blend);
      await sp.setBool(_kFs, _fs);

      final list = _images
          .map((im) => {'id': im.id, 'b64': base64Encode(im.bytes)})
          .toList();
      await sp.setString(_kImages, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> setOn(bool v) async {
    _on = v;
    await _persist();
    notifyListeners();
  }

  Future<void> setSize(double v) async {
    _size = v.clamp(60, 320);
    await _persist();
    notifyListeners();
  }

  Future<void> setSpeed(double v) async {
    _speed = v.clamp(1, 12);
    await _persist();
    notifyListeners();
  }

  Future<void> setOpacity(double v) async {
    _opacity = v.clamp(0.2, 1.0);
    await _persist();
    notifyListeners();
  }

  Future<void> setSoft(bool v) async {
    _soft = v;
    await _persist();
    notifyListeners();
  }

  Future<void> setBlend(String v) async {
    _blend = (v == 'screen' || v == 'multiply') ? v : 'normal';
    await _persist();
    notifyListeners();
  }

  Future<void> setFs(bool v) async {
    _fs = v;
    await _persist();
    notifyListeners();
  }

  /// اضافه‌کردن یک تصویر. اگر حجم بیش از ۱۰MB باشد false برمی‌گرداند.
  Future<bool> addImage(Uint8List bytes) async {
    if (bytes.isEmpty) return false;
    if (bytes.length > maxImageBytes) return false;
    final id = 'a${DateTime.now().millisecondsSinceEpoch}_${_images.length}';
    _images.add(AngelImage(id: id, bytes: bytes));
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> removeImage(String id) async {
    _images.removeWhere((im) => im.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    if (_images.isEmpty) return;
    _images.clear();
    await _persist();
    notifyListeners();
  }
}
