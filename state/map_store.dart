import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../map/map_ops.dart';
import '../models/map_models.dart';
import '../services/media_db.dart';
import '../services/storage.dart';

class MapStore extends ChangeNotifier {
  MapStore(this._storage);
  final StorageService _storage;

  MapState state = MapState();
  Timer? _timer;
  bool loadedFromFile = false;

  /// زمان آخرین ذخیره‌ی موفق — برای نمایش نشانگر «ذخیره شد»
  final ValueNotifier<int> lastSaved = ValueNotifier<int>(0);

  /// پیام کوتاه برای کاربر (تب نقشه SnackBar نشون میده)
  void Function(String message)? toast;

  Future<void> load() async {
    try {
      final raw = await _storage.read();
      if (raw != null) {
        state = MapState.fromJson(jsonDecode(raw));
        loadedFromFile = true;
      }
    } catch (_) {
      await _storage.keepCorruptCopy();
      state = MapState();
    }
  }

  /// فقط ذخیره‌ی با تأخیر (بدون بازسازی UI). موقع درگ استفاده میشه چون painter خودش هر فریم دوباره می‌کشه
  void touch() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), flush);
  }

  /// بعد از هر تغییر ساختاری صدا بزن: لینک خودکار حلقه‌ها، آپدیت UI و ذخیره
  void changed() {
    for (final m in autoLinkRings(state)) {
      toast?.call(m);
    }
    notifyListeners();
    touch();
  }

  Future<void> flush() async {
    _timer?.cancel();
    try {
      await _storage.write(jsonEncode(state.toJson()));
      lastSaved.value = DateTime.now().millisecondsSinceEpoch;
    } catch (e) {
      debugPrint('save failed: $e');
    }
  }

  Future<String> exportJson() async {
    await flush();
    // بکاپ باید قابل‌حمل باشه: ارجاع‌ها دوباره به data URL تبدیل می‌شن
    return MediaDb.inlineJson(jsonEncode(state.toJson()));
  }

  /// ورودی بکاپ. فرمت‌های قابل قبول:
  /// - خود JSON نقشه (کلید frequencyMapData در مرورگر)
  /// - رکورد IndexedDB به شکل {t, json}
  /// - آبجکتی که کلید frequencyMapData داره
  Future<void> importJson(String raw) async {
    raw = await MediaDb.externalizeJson(raw);
    dynamic d = jsonDecode(raw);
    for (var i = 0; i < 3; i++) {
      if (d is Map && d['frequencyMapData'] != null) {
        d = d['frequencyMapData'];
      } else if (d is Map && d['json'] is String && d['goals'] == null) {
        d = d['json'];
      }
      if (d is String) d = jsonDecode(d);
    }
    if (d is! Map || (d['goals'] is! List && d['me'] is! Map)) {
      throw const FormatException('فایل نقشه‌ی معتبر نیست');
    }
    state = MapState.fromJson(d);
    await flush();
    notifyListeners();
  }

  // ---------- افزودن ----------

  Goal addGoal({required String name, String icon = '🎯', required String color}) {
    final spot = pickGoalSpot(state);
    final g = Goal(
      name: name,
      icon: icon.trim().isEmpty ? '🎯' : icon.trim(),
      color: color,
      x: spot.dx,
      y: spot.dy,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    state.goals.add(g);
    changed();
    return g;
  }

  Ring addRing() {
    final r = newRingNearMe(state);
    state.ringsCollapsed = false;
    state.rings.add(r);
    changed();
    toast?.call('نشانه اضافه شد — روی مسیر یک هدف ببرش تا خودکار زیرمجموعه‌اش شود');
    return r;
  }

  ActionNode addBranch(MapHost host) {
    final a = newAction(radius: 12);
    host.actions.add(a);
    host.collapsed = false;
    host.lastActivity = DateTime.now().millisecondsSinceEpoch;
    changed();
    return a;
  }

  ActionNode addSubBranch(MapHost host, ActionNode parent) {
    final c = newAction(radius: 10);
    parent.children.add(c);
    host.collapsed = false;
    changed();
    return c;
  }

  // ---------- حذف ----------

  void deleteGoal(String id) {
    for (final r in state.rings) {
      if (r.goalId == id) r.goalId = '';
    }
    state.goals.removeWhere((g) => g.id == id);
    changed();
  }

  void deleteRing(String id) {
    state.rings.removeWhere((r) => r.id == id);
    changed();
  }

  void deleteAction(String hostId, String actionId) {
    final h = state.findHost(hostId);
    if (h is! MapHost) return;
    final f = findActionNode(h.actions, actionId);
    if (f == null) return;
    f.list.remove(f.node);
    changed();
  }

  // ---------- جمع / باز ----------

  void toggleGoalCollapse(String id) {
    final h = state.findHost(id);
    if (h is! MapHost) return;
    h.collapsed = !h.collapsed;
    changed();
  }

  /// true اگه حداقل یک مسیر بازه (دکمه‌ی «جمع همه»)، false یعنی دکمه «باز همه» باشه
  bool get anyOpen {
    final goals = state.goals.where((g) => goalBranchCount(state, g) > 0);
    final orphans = state.rings.where((r) => ringIsOrphan(state, r) && r.actions.isNotEmpty);
    return goals.any((g) => !g.collapsed) || orphans.any((r) => !r.collapsed);
  }

  bool get hasCollapsible =>
      state.goals.any((g) => goalBranchCount(state, g) > 0) ||
      state.rings.any((r) => ringIsOrphan(state, r) && r.actions.isNotEmpty);

  void collapseAll(bool collapse) {
    for (final g in state.goals) {
      if (goalBranchCount(state, g) > 0) g.collapsed = collapse;
    }
    for (final r in state.rings) {
      if (ringIsOrphan(state, r) && r.actions.isNotEmpty) r.collapsed = collapse;
    }
    state.ringsCollapsed = false;
    changed();
  }
}
