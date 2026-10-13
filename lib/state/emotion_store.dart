import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emotion.dart';

class EmotionStore extends ChangeNotifier {
  static const _kSelected = 'echwSelectedEmotions_v5';

  final Set<String> _selected = {};

  /// 'before' | 'after' | 'entry' | null
  String? capturePhase;
  String? capturePracticeKey;
  String? captureLabel;

  /// در فاز 'entry': شناسه‌ی GratitudeEntry که داریم ویرایش می‌کنیم
  String? editingEntryId;

  void Function(List<String> ids)? _onCaptureSave;
  void Function(List<String> ids)? onCommitClose;

  bool loaded = false;

  List<String> get selectedIds => _selected.toList();
  bool get hasSelection => _selected.isNotEmpty;
  bool get isCapturing => capturePhase != null;
  bool get isEditingEntry => capturePhase == 'entry';

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
    String? entryId,
    void Function(List<String> ids)? onSave,
  }) {
    capturePhase = phase;
    capturePracticeKey = practiceKey;
    captureLabel = label;
    editingEntryId = entryId;
    _onCaptureSave = onSave;
    _selected
      ..clear()
      ..addAll((initial ?? const [])
          .where((id) => emotionById(id) != null));
    _persist();
    notifyListeners();
  }

  void endCapture() {
    capturePhase = null;
    capturePracticeKey = null;
    captureLabel = null;
    editingEntryId = null;
    _onCaptureSave = null;
    notifyListeners();
  }

  void saveCapture() {
    final ids = selectedIds;
    final cb = _onCaptureSave;
    _onCaptureSave = null;
    endCapture();
    cb?.call(ids);
  }

  void cancelCapture() {
    _onCaptureSave = null;
    endCapture();
  }

  /// بستن پنل با انتخاب (معادل رویداد `echw:commit` در وب)
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
