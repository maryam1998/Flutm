import 'package:flutter/foundation.dart';
import 'emotion.dart';

/// انتخاب فعلی توی ویجت شناور «آدم و احساسات».
/// بعد از اینکه یک رشته‌ی عصبی ازش مصرف کرد، ریست می‌شه.
class EmotionStore extends ChangeNotifier {
  final Set<String> _selected = {};

  /// فاز بعدی «قبل / بعد» (وقتی از یه تمرین می‌آییم اینجا)
  String? capturePhase;   // 'before' | 'after' | null
  String? capturePracticeKey;
  String? captureLabel;

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
  }) {
    capturePhase = phase;
    capturePracticeKey = practiceKey;
    captureLabel = label;
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
    notifyListeners();
  }
}
