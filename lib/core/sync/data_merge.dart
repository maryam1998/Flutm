// 📁 مسیر: lib/core/sync/data_merge.dart
//
// ادغامِ داده‌ی محلی و ابری: هیچ‌وقت «کل مقدار» یک کلید با نسخه‌ی دیگر عوض
// نمی‌شود؛ فهرست‌ها (items / ids / sessions / records ...) اجتماع گرفته می‌شوند
// تا دو دستگاه یا یک نصبِ جدید داده‌ی همدیگر را پاک نکنند.

import 'dart:convert';

/// مقدارِ نهایی یک کلید از روی نسخه‌ی محلی و ابری.
String mergeSyncValue(String local, String cloud) {
  if (local == cloud) return local;
  if (local.trim().isEmpty) return cloud;
  if (cloud.trim().isEmpty) return local;
  try {
    final l = jsonDecode(local);
    final c = jsonDecode(cloud);
    if (l is! Map || c is! Map) return cloud;
    final out = <String, dynamic>{};
    for (final e in c.entries) {
      out[e.key.toString()] = e.value;
    }
    for (final e in l.entries) {
      final k = e.key.toString();
      final lv = e.value;
      final cv = out[k];
      if (!out.containsKey(k) || cv == null) {
        out[k] = lv;
      } else if (lv is List && cv is List) {
        out[k] = _unionLists(lv, cv);
      } else if (lv is Map && cv is Map) {
        out[k] = _unionMaps(lv, cv);
      }
      // غیر از این‌ها (تنظیمات ساده): مقدارِ ابری
    }
    return jsonEncode(out);
  } catch (_) {
    return cloud;
  }
}

String _identity(dynamic it) {
  if (it is Map) {
    final id = it['id'];
    if (id != null && '$id'.isNotEmpty) return 'id:$id';
    final w = it['word'];
    if (w != null) {
      return 'w:${it['langCode'] ?? ''}:${'$w'.trim().toLowerCase()}';
    }
    return 'j:${jsonEncode(it)}';
  }
  return 's:$it';
}

dynamic _pickBetter(dynamic l, dynamic c) {
  if (l is Map && c is Map) {
    final lr = l['reviewCount'];
    final cr = c['reviewCount'];
    if (lr is num && cr is num && lr != cr) return lr > cr ? l : c;
    final ls = jsonEncode(l).length;
    final cs = jsonEncode(c).length;
    return cs > ls ? c : l;
  }
  return l;
}

List<dynamic> _unionLists(List<dynamic> local, List<dynamic> cloud) {
  final out = <dynamic>[];
  final index = <String, int>{};
  for (final it in local) {
    final k = _identity(it);
    if (index.containsKey(k)) continue;
    index[k] = out.length;
    out.add(it);
  }
  for (final it in cloud) {
    final k = _identity(it);
    final i = index[k];
    if (i == null) {
      index[k] = out.length;
      out.add(it);
    } else {
      out[i] = _pickBetter(out[i], it);
    }
  }
  return out;
}

Map<String, dynamic> _unionMaps(Map<dynamic, dynamic> local, Map<dynamic, dynamic> cloud) {
  final out = <String, dynamic>{};
  for (final e in cloud.entries) {
    out[e.key.toString()] = e.value;
  }
  for (final e in local.entries) {
    final k = e.key.toString();
    final lv = e.value;
    if (!out.containsKey(k)) {
      out[k] = lv;
      continue;
    }
    final cv = out[k];
    if (lv is String && cv is String) {
      // زمان‌های ISO: دیرتر برنده است
      if (lv.compareTo(cv) > 0) out[k] = lv;
    } else if (lv is Map && cv is Map) {
      out[k] = _pickBetter(lv, cv);
    }
  }
  return out;
}
