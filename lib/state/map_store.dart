import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/map_models.dart';
import '../services/storage.dart';

class MapStore extends ChangeNotifier {
  MapStore(this._storage);
  final StorageService _storage;

  MapState state = MapState();
  Timer? _timer;
  bool loadedFromFile = false;

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

  /// بعد از هر تغییر صدا بزن: UI رو آپدیت می‌کنه و ذخیره رو (با تأخیر ۴۰۰ms) زمان‌بندی می‌کنه
  void changed() {
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), flush);
  }

  Future<void> flush() async {
    _timer?.cancel();
    try {
      await _storage.write(jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('save failed: $e');
    }
  }

  Future<String> exportJson() async {
    await flush();
    return jsonEncode(state.toJson());
  }

  /// ورودی بکاپ. فرمت‌های قابل قبول:
  /// - خود JSON نقشه (کلید frequencyMapData در مرورگر)
  /// - رکورد IndexedDB به شکل {t, json}
  /// - آبجکتی که کلید frequencyMapData داره
  Future<void> importJson(String raw) async {
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
}
