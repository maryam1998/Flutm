import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// فونت‌های قابل دانلودِ یادداشت‌های روی نقشه (مثل فهرست فونتِ ادیتورهای ویدیو).
/// اولین بار که کاربر روی فونت می‌زند دانلود و ثبت می‌شود؛ دفعه‌های بعد از کشِ مرورگر می‌آید.
class NoteFont {
  const NoteFont(this.id, this.label, this.path);
  final String id;
  final String label;

  /// مسیر داخل مخزن google/fonts
  final String path;
}

const String _kBase = 'https://cdn.jsdelivr.net/gh/google/fonts@main/';

const List<NoteFont> kNoteFonts = [
  NoteFont('arefruqaa', 'عارف رقعه', 'ofl/arefruqaa/ArefRuqaa-Regular.ttf'),
  NoteFont('amiri', 'العامری', 'ofl/amiri/Amiri-Regular.ttf'),
  NoteFont('scheherazade', 'شهرزاد',
      'ofl/scheherazadenew/ScheherazadeNew-Regular.ttf'),
  NoteFont('lalezar', 'لاله‌زار', 'ofl/lalezar/Lalezar-Regular.ttf'),
  NoteFont('katibeh', 'کاتبه', 'ofl/katibeh/Katibeh-Regular.ttf'),
  NoteFont('rakkas', 'رکّاس', 'ofl/rakkas/Rakkas-Regular.ttf'),
  NoteFont('harmattan', 'هارماتان', 'ofl/harmattan/Harmattan-Regular.ttf'),
  NoteFont('lateef', 'لطیف', 'ofl/lateef/Lateef-Regular.ttf'),
  NoteFont('jomhuria', 'جمهوریه', 'ofl/jomhuria/Jomhuria-Regular.ttf'),
  NoteFont('tajawal', 'تجوّل', 'ofl/tajawal/Tajawal-Regular.ttf'),
  NoteFont('blaka', 'بلاکا', 'ofl/blaka/Blaka-Regular.ttf'),
  NoteFont('permanentmarker', 'Permanent Marker',
      'apache/permanentmarker/PermanentMarker-Regular.ttf'),
  NoteFont('bebas', 'Bebas Neue', 'ofl/bebasneue/BebasNeue-Regular.ttf'),
];

class NoteFonts {
  NoteFonts._();

  static final Set<String> loaded = <String>{};
  static final Map<String, Future<bool>> _busy = {};
  static final Map<String, int> _failedAt = {};

  /// هر بار فونتی بارگذاری شد زیاد می‌شود (برای بازسازی UI)
  static final ValueNotifier<int> epoch = ValueNotifier<int>(0);

  static NoteFont? byId(String? id) {
    if (id == null) return null;
    for (final f in kNoteFonts) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// نام خانواده‌ی فونت برای TextStyle؛ تا وقتی دانلود نشده null
  static String? familyOf(String? id) =>
      id != null && loaded.contains(id) ? 'NF_$id' : null;

  static bool isBusy(String id) => _busy.containsKey(id);

  /// دانلود و ثبتِ فونت. موفق = true
  static Future<bool> ensure(String id) {
    if (loaded.contains(id)) return Future.value(true);
    final f = byId(id);
    if (f == null) return Future.value(false);
    final running = _busy[id];
    if (running != null) return running;
    // بعد از شکست تا ۳۰ ثانیه دوباره تلاش نکن (نقاشی هر فریم صدا می‌زند)
    final fa = _failedAt[id];
    if (fa != null &&
        DateTime.now().millisecondsSinceEpoch - fa < 30000) {
      return Future.value(false);
    }
    final fut = () async {
      try {
        final r = await http
            .get(Uri.parse('$_kBase${f.path}'))
            .timeout(const Duration(seconds: 25));
        if (r.statusCode != 200 || r.bodyBytes.isEmpty) {
          throw Exception('HTTP ${r.statusCode}');
        }
        final loader = FontLoader('NF_${f.id}')
          ..addFont(Future.value(ByteData.sublistView(
              Uint8List.fromList(r.bodyBytes))));
        await loader.load();
        loaded.add(id);
        _failedAt.remove(id);
        epoch.value++;
        return true;
      } catch (_) {
        _failedAt[id] = DateTime.now().millisecondsSinceEpoch;
        return false;
      } finally {
        _busy.remove(id);
      }
    }();
    _busy[id] = fut;
    return fut;
  }
}
