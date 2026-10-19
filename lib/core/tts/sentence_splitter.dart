class TextChunk {
  final int start;
  final int end;
  final String text;
  const TextChunk({required this.start, required this.end, required this.text});
}

class SentenceSplitter {
  /// [boundaries]: آفست‌های شروعِ «آیتم»ها (مثلاً هر خطِ مکالمه) — مثل
  /// sentenceBoundaries در Hope تضمین می‌کند دو آیتمِ جدا، حتی اگر علامت
  /// نگارشی وسطشان نباشد/قاطی شود، هرگز در یک جمله (chunk) ادغام نشوند.
  static List<TextChunk> split(String text, {List<int>? boundaries}) {
    if (text.isEmpty) return [];

    final re = RegExp(r'[^.!?؟。！]+[.!?؟。！]*');
    var out = <TextChunk>[];

    for (final m in re.allMatches(text)) {
      final raw = m.group(0)!;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final start = m.start + raw.indexOf(trimmed[0]);
      out.add(TextChunk(
        start: start,
        end: start + trimmed.length,
        text: trimmed,
      ));
    }

    if (out.isEmpty) {
      return [TextChunk(start: 0, end: text.length, text: text)];
    }

    if (boundaries != null && boundaries.isNotEmpty) {
      final sorted = boundaries
          .where((b) => b > 0 && b < text.length)
          .toSet()
          .toList()
        ..sort();
      if (sorted.isNotEmpty) {
        final res = <TextChunk>[];
        for (final ch in out) {
          var from = ch.start;
          for (final b in sorted) {
            if (b <= from) continue;
            if (b >= ch.end) break;
            _addPiece(res, text, from, b);
            from = b;
          }
          _addPiece(res, text, from, ch.end);
        }
        out = res;
      }
    }
    return out;
  }

  static void _addPiece(List<TextChunk> res, String text, int from, int to) {
    final raw = text.substring(from, to);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final start = from + raw.indexOf(trimmed[0]);
    res.add(TextChunk(start: start, end: start + trimmed.length, text: trimmed));
  }

  /// متن رو برای TTS تمیز می‌کنه
  static String sanitize(String s) {
    return s
        .replaceAll(RegExp(r'\bhttps?:\/\/\S+', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[\u2066-\u2069\u200B-\u200F\u061C\uFEFF]'), '')
        .replaceAll(RegExp(r'[\p{Extended_Pictographic}]', unicode: true), '')
        .replaceAll(RegExp(r'[«»‹›„‟""]'), '')
        .replaceAll(RegExp(r'[*_~`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
