import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emotion.dart';

/// انتخاب فعلی توی ویجت شناور «آدم و احساسات».
/// بعد از اینکه یک رشته‌ی عصبی ازش مصرف کرد، ریست می‌شه.
/// انتخاب مثل وب (کلید echwSelectedEmotions_v5) ذخیره می‌شه.
class EmotionStore extends ChangeNotifier {
  static const _key = 'echwSelectedEmotions_v5';

  final Set<String> _selected = {};

  /// فاز بعدی «قبل / بعد» (وقتی از یه تمرین می‌آییم اینجا)
  String? capturePhase; // 'before' | 'after' | null
  String? capturePracticeKey;
  String? captureLabel;

  /// کال‌بکی که وقتی کاربر «ثبت» رو زد صدا زده می‌شه
  void Function(List<String> ids)? _onCaptureSave;

  List<String> get selectedIds => _selected.toList();

  /// انتخاب‌شده‌ها به ترتیب فرکانس (دقیقاً مثل EMOTIONS.filter در وب)
  List<Emotion> get selectedEmotions =>
      kEmotions.where((e) => _selected.contains(e.id)).toList();

  bool get hasSelection => _selected.isNotEmpty;
  bool get isCapturing => capturePhase != null;

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final j = jsonDecode(raw);
      if (j is List) {
        _selected
          ..clear()
          ..addAll(j.whereType<String>().where((id) => emotionById(id) != null));
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_key, jsonEncode(_selected.toList()));
    } catch (_) {}
  }

  void toggle(String id) {
    if (emotionById(id) == null) return;
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    _save();
    notifyListeners();
  }

  void setSelection(List<String> ids) {
    _selected
      ..clear()
      ..addAll(ids.where((id) => emotionById(id) != null));
    _save();
    notifyListeners();
  }

  void reset() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _save();
    notifyListeners();
  }

  void beginCapture({
    required String phase,
    required String practiceKey,
    required String label,
    List<String>? initial,
    void Function(List<String> ids)? onSave,
  }) {
    capturePhase = phase;
    capturePracticeKey = practiceKey;
    captureLabel = label;
    _onCaptureSave = onSave;
    if (initial != null) {
      _selected
        ..clear()
        ..addAll(initial.where((id) => emotionById(id) != null));
      _save();
    }
    notifyListeners();
  }

  void endCapture() {
    capturePhase = null;
    capturePracticeKey = null;
    captureLabel = null;
    _onCaptureSave = null;
    notifyListeners();
  }

  /// کاربر «ثبت» رو زد: کال‌بک رو صدا می‌زنیم، بعد capture رو می‌بندیم.
  void saveCapture() {
    final ids = selectedIds;
    final cb = _onCaptureSave;
    _onCaptureSave = null;
    endCapture();
    cb?.call(ids);
  }

  /// کاربر «انصراف» رو زد: بدون صدا زدن کال‌بک، فقط capture رو می‌بندیم.
  void cancelCapture() {
    _onCaptureSave = null;
    endCapture();
  }
}
