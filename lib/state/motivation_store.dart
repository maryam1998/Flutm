import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import '../services/app_prefs.dart';

import '../models/motivation_item.dart';

class MotivationStore extends ChangeNotifier {
  static const _kItems = 'motiv_items';
  static const _kShowBar = 'motiv_show_bar';
  static const _kIndex = 'motiv_index';

  final List<MotivationItem> items = [];
  bool _showBar = true;
  int _index = 0;

  bool get showBar => _showBar;

  List<MotivationItem> get active =>
      items.where((e) => !e.archived).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<MotivationItem> get archived =>
      items.where((e) => e.archived).toList()
        ..sort((a, b) =>
            (b.archivedAt ?? 0).compareTo(a.archivedAt ?? 0));

  MotivationItem? get current {
    final a = active;
    if (a.isEmpty) return null;
    final i = _index.clamp(0, a.length - 1);
    return a[i];
  }

  Future<void> load() async {
    try {
      final sp = await AppPrefs.getInstance();
      final raw = sp.getString(_kItems);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          items
            ..clear()
            ..addAll(list.map(MotivationItem.fromJson));
        }
      }
      _showBar = sp.getBool(_kShowBar) ?? true;
      _index = sp.getInt(_kIndex) ?? 0;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setString(
        _kItems,
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
      await sp.setBool(_kShowBar, _showBar);
      await sp.setInt(_kIndex, _index);
    } catch (_) {}
  }

  Future<void> add(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    items.add(MotivationItem(text: t));
    _persist();
    notifyListeners();
  }

  Future<void> update(String id, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final it = items.firstWhere((e) => e.id == id, orElse: () => MotivationItem(text: ''));
    it.text = t;
    _persist();
    notifyListeners();
  }

  Future<void> archive(String id) async {
    final it = items.firstWhere((e) => e.id == id, orElse: () => MotivationItem(text: ''));
    if (it.text.isEmpty) return;
    it.archived = true;
    it.archivedAt = DateTime.now().millisecondsSinceEpoch;
    _persist();
    notifyListeners();
  }

  Future<void> unarchive(String id) async {
    final it = items.firstWhere((e) => e.id == id, orElse: () => MotivationItem(text: ''));
    if (it.text.isEmpty) return;
    it.archived = false;
    it.archivedAt = null;
    _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    items.removeWhere((e) => e.id == id);
    _persist();
    notifyListeners();
  }

  Future<void> setShowBar(bool v) async {
    _showBar = v;
    _persist();
    notifyListeners();
  }

  void nextRandom() {
    final a = active;
    if (a.length < 2) return;
    int n;
    do {
      n = math.Random().nextInt(a.length);
    } while (n == _index);
    _index = n;
    _persist();
    notifyListeners();
  }
}
