import 'dart:convert';
import 'app_prefs.dart';

class EmotionWidgetState {
  final double left;
  final double top;
  final double? panelLeft;
  final double? panelTop;
  final double w;
  final bool open;
  final bool glass;

  const EmotionWidgetState({
    required this.left,
    required this.top,
    this.panelLeft,
    this.panelTop,
    required this.w,
    required this.open,
    required this.glass,
  });

  /// left/top = -1 یعنی هنوز مقدار پیش‌فرض را محاسبه نکرده‌ایم
  static const defaults = EmotionWidgetState(
    left: -1, top: -1, w: 250, open: false, glass: false,
  );

  Map<String, dynamic> toJson() => {
        'left': left, 'top': top,
        'panelLeft': panelLeft, 'panelTop': panelTop,
        'w': w, 'open': open, 'glass': glass,
      };

  factory EmotionWidgetState.fromJson(Map<String, dynamic> j) =>
      EmotionWidgetState(
        left: (j['left'] as num?)?.toDouble() ?? -1,
        top: (j['top'] as num?)?.toDouble() ?? -1,
        panelLeft: (j['panelLeft'] as num?)?.toDouble(),
        panelTop: (j['panelTop'] as num?)?.toDouble(),
        w: (j['w'] as num?)?.toDouble() ?? 250,
        open: j['open'] as bool? ?? false,
        glass: j['glass'] as bool? ?? false,
      );
}

class EmotionWidgetPrefs {
  static const _key = 'echwState_v15';

  Future<EmotionWidgetState> load() async {
    try {
      final sp = await AppPrefs.getInstance();
      final raw = sp.getString(_key);
      if (raw == null || raw.isEmpty) return EmotionWidgetState.defaults;
      final j = jsonDecode(raw);
      if (j is! Map) return EmotionWidgetState.defaults;
      return EmotionWidgetState.fromJson(Map<String, dynamic>.from(j));
    } catch (_) {
      return EmotionWidgetState.defaults;
    }
  }

  Future<void> save(EmotionWidgetState s) async {
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setString(_key, jsonEncode(s.toJson()));
    } catch (_) {}
  }
}
