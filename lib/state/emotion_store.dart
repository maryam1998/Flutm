import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emotion.dart';

/// انتخاب فعلی توی ویجت شناور «آدم و احساسات».
/// - انتخاب بین باز/بسته شدن پنل حفظ می‌شود.
/// - فقط با شروع روز جدید ریست می‌شود.
class EmotionStore extends ChangeNotifier {
  static const _kSelected = 'echwSelectedEmotions_v5';
  static const _kDayKey = 'echwSelectedDay_v1';

  final Set<String> _selected = {};

  String? capturePhase;
  String? capturePracticeKey;
  String? captureLabel;
  String? editingEntryId;

  void Function(List<String> ids)? _onCaptureSave;
  void Function(List<String> ids)? onCommitClose;

  bool loaded = false;

  List<String> get selectedIds => _selected.toList();
  bool get hasSelection => _selected.isNotEmpty;
  bool get isCapturing => capturePhase != null;
  bool get isEditingEntry => capturePhase == 'entry';

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final storedDay = sp.getString(_kDayKey);
      final today = _todayKey();

      if (storedDay != today) {
        // روز جدید → انتخاب پاک می‌شود
        _selected.clear();
        await sp.remove(_kSelected);
        await sp.setString(_kDayKey, today);
      } else {
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
      }
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kSelected, jsonEncode(_selected.toList()));
      await sp.setString(_kDayKey, _todayKey());
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

  /// بستن پنل با یک انتخاب: یک رشته‌ی عصبی رنگ می‌گیرد.
  /// **انتخاب حفظ می‌شود** (ریست نمی‌شود).
  void fireCommitClose() {
    if (isCapturing) return;
    if (_selected.isEmpty) return;
    onCommitClose?.call(_selected.toList());
  }
}
