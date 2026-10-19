import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/app_prefs.dart';

import '../models/emotion.dart';

class EmotionStore extends ChangeNotifier {
  static const _kSelected = 'emotion_selected_v5';

  final Set<String> _selected = {};
  Set<String> get selectedIds => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;
  int get selectedCount => _selected.length;

  // ─── capture ───
  bool _capturing = false;
  bool get isCapturing => _capturing;

  String? _capturePhase; // 'before' | 'after' | 'entry'
  String? get capturePhase => _capturePhase;

  String? _captureLabel;
  String? get captureLabel => _captureLabel;

  String? _capturePracticeKey;
  String? get capturePracticeKey => _capturePracticeKey;

  String? _captureDayKey;
  String? get captureDayKey => _captureDayKey;

  /// کال‌بکِ ثبت — از `main.dart` ست می‌شود.
  Future<void> Function(List<String> ids, String dayKey)? onEmotionsCommitted;

  /// «ثبت حس» هنگام بستنِ ادمک با حسِ انتخاب‌شده (echw:commit وب).
  /// اگه حداقل یک تمرین حس رو گرفت `true` برمی‌گرده و انتخاب ریست می‌شه؛
  /// وگرنه (هیچ تمرینی امروز انجام نشده) انتخاب می‌مونه تا ثبت بعدی مصرفش کنه.
  Future<bool> Function(List<String> ids)? onCommitClose;

  EmotionStore() {
    _load();
  }

  Future<void> _load() async {
    try {
      final sp = await AppPrefs.getInstance();
      final raw = sp.getString(_kSelected);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          _selected.addAll(list.map((e) => e.toString()));
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setString(_kSelected, jsonEncode(_selected.toList()));
    } catch (_) {}
  }

  void toggle(String id) {
    if (emotionById(id) == null) return;
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    _persist();
    notifyListeners();
  }

  void setSelected(Iterable<String> ids) {
    _selected
      ..clear()
      ..addAll(ids.where((id) => emotionById(id) != null));
    _persist();
    notifyListeners();
  }

  void clear() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _persist();
    notifyListeners();
  }

  void reset() => clear();

  /// شروع یک sessionِ ثبت (قبل/بعد/ویرایش)
  Future<void> beginCapture({
    required String practiceKey,
    required String phase,
    String? label,
    List<String> initial = const [],
    String? dayKey,
  }) async {
    _capturing = true;
    _capturePracticeKey = practiceKey;
    _capturePhase = phase;
    _captureLabel = label;
    _captureDayKey = dayKey ?? _todayKey();
    _selected
      ..clear()
      ..addAll(initial.where((id) => emotionById(id) != null));
    _persist();
    notifyListeners();
  }

  /// ذخیره‌ی captureِ فعلی و پاک کردن state
  Future<void> saveCapture() async {
    if (!_capturing) return;
    final ids = _selected.toList();
    final dayKey = _captureDayKey ?? _todayKey();

    _capturing = false;
    _capturePhase = null;
    _captureLabel = null;
    _capturePracticeKey = null;
    _captureDayKey = null;

    if (ids.isNotEmpty && onEmotionsCommitted != null) {
      await onEmotionsCommitted!(ids, dayKey);
    }

    _persist();
    notifyListeners();
  }

  Future<void> cancelCapture() async {
    _capturing = false;
    _capturePhase = null;
    _captureLabel = null;
    _capturePracticeKey = null;
    _captureDayKey = null;
    notifyListeners();
  }

  /// وقتی کاربر دکمه‌ی شناور رو می‌بندد و انتخاب دارد، این صدا زده می‌شود.
  Future<void> fireCommitClose() async {
    if (_selected.isEmpty) return;
    if (_capturing) {
      await saveCapture();
      return;
    }
    final ids = _selected.toList();
    var consumed = false;
    if (onCommitClose != null) {
      consumed = await onCommitClose!(ids);
    } else if (onEmotionsCommitted != null) {
      await onEmotionsCommitted!(ids, _todayKey());
      consumed = true;
    }
    if (consumed) {
      _selected.clear();
      _persist();
      notifyListeners();
    }
  }

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int get emotionQuality {
    if (_selected.isEmpty) return 0;
    int max = 0;
    for (final id in _selected) {
      final e = emotionById(id);
      if (e != null && e.freq > max) max = e.freq;
    }
    return max;
  }
}
