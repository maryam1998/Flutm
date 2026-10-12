import 'package:flutter/foundation.dart';
import '../models/emotion.dart';

/// انتخاب فعلی توی ویجت شناور «آدم و احساسات».
/// بعد از اینکه یک رشته‌ی عصبی ازش مصرف کرد، ریست می‌شه.
class EmotionStore extends ChangeNotifier {
  final Set<String> _selected = {};

  /// فاز بعدی «قبل / بعد» (وقتی از یه تمرین می‌آییم اینجا)
  String? capturePhase;   // 'before' | 'after' | null
  String? capturePracticeKey;
  String? captureLabel;

  /// کال‌بکی که وقتی کاربر «ثبت» رو زد صدا زده می‌شه
  void Function(List<String> ids)? _onCaptureSave;

  List<String> get selectedIds => _selected.toList();

  bool get hasSelection => _selected.isNotEmpty;
  bool get isCapturing => capturePhase != null;

  void toggle(String id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  void setSelection(List<String> ids) {
    _selected
      ..clear()
      ..addAll(ids.where((id) => emotionById(id) != null));
    notifyListeners();
  }

  void reset() {
    if (_selected.isEmpty) return;
    _selected.clear();
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
