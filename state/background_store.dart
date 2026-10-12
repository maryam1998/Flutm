import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundStore extends ChangeNotifier {
  static const _kImgKey = 'bg_image';
  static const _kBlurKey = 'bg_blur';
  static const _kOpKey = 'bg_opacity';

  Uint8List? _bytes;
  double _blur = 0;
  double _opacity = 0.6;

  Uint8List? get imageBytes => _bytes;
  double get blur => _blur;
  double get opacity => _opacity;
  bool get hasImage => _bytes != null;

  final _picker = ImagePicker();

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final b64 = sp.getString(_kImgKey);
      if (b64 != null && b64.isNotEmpty) {
        _bytes = base64Decode(b64);
      }
      _blur = sp.getDouble(_kBlurKey) ?? 0;
      _opacity = sp.getDouble(_kOpKey) ?? 0.6;
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> pickImage() async {
    try {
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (f == null) return false;
      _bytes = await f.readAsBytes();
      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('pickImage failed: $e');
      return false;
    }
  }

  Future<void> setBlur(double v) async {
    _blur = v.clamp(0, 20);
    await _save();
    notifyListeners();
  }

  Future<void> setOpacity(double v) async {
    _opacity = v.clamp(0.1, 1.0);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _bytes = null;
    _blur = 0;
    _opacity = 0.6;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_kImgKey);
      await sp.remove(_kBlurKey);
      await sp.remove(_kOpKey);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (_bytes != null) {
        await sp.setString(_kImgKey, base64Encode(_bytes!));
      } else {
        await sp.remove(_kImgKey);
      }
      await sp.setDouble(_kBlurKey, _blur);
      await sp.setDouble(_kOpKey, _opacity);
    } catch (_) {}
  }
}
