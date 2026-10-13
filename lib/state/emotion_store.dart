import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emotion.dart';

/// انتخاب فعلی توی ویجت شناور «آدم و احساسات».
/// انتخاب‌ها بین باز/بسته شدن پنل حفظ می‌شوند.
/// فقط وقتی انتخاب با آخرین commit فرق داشته باشد، رشته‌ی عصبی رنگ می‌گیرد.
class EmotionStore extends ChangeNotifier {
  static const _kSelected = 'echwSelectedEmotions_v5';

  final Set<String> _selected = {};

  /// آخرین انتخابی که commit شده — برای جلوگیری از commit تکراری
  Set<String> _lastCommitted = {};

  /// فاز فعلی: 'before' | 'after' | 'entry' | null
  String? capturePhase;
  String? capturePracticeKey;
  String? captureLabel;

  /// در فاز 'entry': شناسه‌ی GratitudeEntry/روز که داریم ویرایش می‌کنیم
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

  /// پاک کردن اجباری انتخاب (مثلاً بعد از ریست دستی توسط کاربر)
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

  /// بستن پنل با یک انتخاب (معادل رویداد `echw:commit` در وب).
  /// - اگر انتخاب با آخرین commit یکسان باشد، هیچ کاری نمی‌کند.
  /// - انتخاب حفظ می‌شود (ریست نمی‌شود).
  void fireCommitClose() {
    if (isCapturing) return;
    if (_selected.isEmpty) return;

    // مقایسه با آخرین commit
    final cur = _selected.toList()..sort();
    final last = _lastCommitted.toList()..sort();
    bool same = cur.length == last.length;
    if (same) {
      for (int i = 0; i < cur.length; i++) {
        if (cur[i] != last[i]) {
          same = false;
          break;
        }
      }
    }
    if (same) return;

    _lastCommitted = Set.of(_selected);
    onCommitClose?.call(_selected.toList());
    // انتخاب حفظ می‌شود — کاربر می‌خواهد دفعه‌ی بعد هم ببیند
  }

  /// پاک‌کردن «آخرین commit» — مثلاً بعد از ویرایش یک روز مشخص
  void clearLastCommit() {
    _lastCommitted.clear();
  }
}
