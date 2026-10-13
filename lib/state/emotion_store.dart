import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emotion.dart';

/// انتخاب فعلی توی ویجت شناور «آدم و احساسات».
/// بعد از اینکه یک رشته‌ی عصبی ازش مصرف کرد، ریست می‌شه.
class EmotionStore extends ChangeNotifier {
  static const _kSelected = 'echwSelectedEmotions_v5';

  final Set<String> _selected = {};

  /// فاز بعدی «قبل / بعد» (وقتی از یه تمرین می‌آییم اینجا)
  String? capturePhase;   // 'before' | 'after' | null
  String? capturePracticeKey;
  String? captureLabel;

  /// کال‌بکی که وقتی کاربر «ثبت» رو زد صدا زده می‌شه
  void Function(List<String> ids)? _onCaptureSave;

  /// کال‌بکی که وقتی کاربر پنل رو با یک انتخاب بست صدا زده می‌شه.
  /// این معادل رویداد `echw:commit` در نسخه‌ی وب است.
  void Function(List<String> ids)? onCommitClose;

  bool loaded = false;

  List<String> get selectedIds => _selected.toList();

  bool get hasSelection => _selected.isNotEmpty;
  bool get isCapturing => capturePhase != null;

  /// لود انتخاب ذخیره‌شده از SharedPreferences (معادل localStorage در وب)
  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kSelected);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          _selected
            ..clear()
            ..addAll(list
                .map((e) => e.toString())
                .where((id) => emotionById(id) != null));
        }
      }
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kSelected, jsonEncode(_selected.toList()));
    } catch (_) {}
  }

  void toggle(String id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    _persist();
    notifyListeners();
  }

  void setSelection(List<String> ids) {
    _selected
      ..clear()
      ..addAll(ids.where((id) => emotionById(id) != null));
    _persist();
    notifyListeners();
  }

  void reset() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _persist();
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
      _persist();
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

  /// کاربر پنل رو با یک انتخاب بست (نه در حالت capture):
  /// رشته‌ی عصبی ساخته می‌شه و انتخاب ریست می‌شه.
  /// این معادل `dispatchEvent(echw:commit)` در نسخه‌ی وب است.
  void fireCommitClose() {
    if (_selected.isEmpty) return;
    if (isCapturing) return;
    final cb = onCommitClose;
    if (cb == null) {
      reset();
      return;
    }
    final ids = selectedIds;
    cb(ids);
    reset();
  }
}
