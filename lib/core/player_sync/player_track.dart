import '../tts/tts_config.dart';

/// یک آیتم قابل‌خواندن (یک لغت، یک خط مکالمه، یک جمله‌ی داستان، ...)
class SyncItem {
  final String id;
  final String text;
  const SyncItem(this.id, this.text);
}

/// شکل ساختنِ متنِ کامل از آیتم‌ها — دقیقاً مثل Hope:
///  • [words]: لغت‌ها بدون علامت نگارشی‌اند → بینشان «. » می‌گذاریم تا
///    هر لغت یک «جمله»ی مستقل حساب شود (WordList.jsx)
///  • [lines]: هر خط با ensureSentenceEnd تمام می‌شود و با یک فاصله به هم
///    می‌چسبند (DailyConversationsTab.jsx)
enum TrackMode { words, lines }

/// بازه‌ی یک آیتم داخل متنِ کامل
class TrackSpan {
  final String id;
  final int start;
  final int end;
  const TrackSpan(this.id, this.start, this.end);
}

/// معادلِ {fullText, offsets} در Hope — متنِ کاملِ یک زبان + جای هر آیتم در آن.
class PlayerTrack {
  final String code;
  final String fullText;
  final List<TrackSpan> spans;
  final Map<String, TrackSpan> byId;
  final String key;

  PlayerTrack._(this.code, this.fullText, this.spans, this.byId, this.key);

  List<int> get boundaries => [for (final s in spans) s.start];

  /// کلیدی که SpeechController برای همین متن می‌سازد
  static String keyFor(String code, String fullText) =>
      '${TtsConfig.locale[code] ?? 'en-US'}::$fullText';

  static String ensureSentenceEnd(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return RegExp(r'[.!?؟。！…]$').hasMatch(t) ? t : '$t.';
  }

  static PlayerTrack build(
      String code, List<SyncItem> items, TrackMode mode) {
    final buf = StringBuffer();
    final spans = <TrackSpan>[];
    var offset = 0;

    if (mode == TrackMode.words) {
      for (var i = 0; i < items.length; i++) {
        final t = items[i].text;
        final start = offset;
        buf.write(t);
        offset += t.length;
        spans.add(TrackSpan(items[i].id, start, offset));
        if (i < items.length - 1) {
          buf.write('. ');
          offset += 2;
        } else {
          buf.write('.');
          offset += 1;
        }
      }
    } else {
      for (var i = 0; i < items.length; i++) {
        final t = ensureSentenceEnd(items[i].text);
        if (t.isEmpty) continue;
        if (spans.isNotEmpty) {
          buf.write(' ');
          offset += 1;
        }
        final start = offset;
        buf.write(t);
        offset += t.length;
        spans.add(TrackSpan(items[i].id, start, offset));
      }
    }

    final full = buf.toString();
    return PlayerTrack._(
      code,
      full,
      spans,
      {for (final s in spans) s.id: s},
      keyFor(code, full),
    );
  }

  /// آیتمی که این آفست داخلِ آن است (همان حلقه‌ی «found» در Hope:
  /// آخرین آیتمی که start ≤ offset؛ اگر هیچ، اولین آیتم).
  TrackSpan? spanAt(int offset) {
    if (spans.isEmpty) return null;
    // جستجوی دودویی روی start (spans به ترتیب صعودی است)
    var lo = 0, hi = spans.length - 1, found = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (offset >= spans[mid].start) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return spans[found];
  }
}
