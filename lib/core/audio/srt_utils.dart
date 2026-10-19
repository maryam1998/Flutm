// خواندن/نوشتنِ SRT — معادلِ app/srt/srtUtils.js در Hope.
class SrtEntry {
  final int index;
  final String start;
  final String end;
  final String text;
  const SrtEntry(this.index, this.start, this.end, this.text);
  SrtEntry withText(String t) => SrtEntry(index, start, end, t);
}

List<SrtEntry> parseSrt(String raw) {
  final text = raw
      .replaceAll('\uFEFF', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (text.isEmpty) return const [];
  final out = <SrtEntry>[];
  for (final block in text.split(RegExp(r'\n\s*\n'))) {
    final lines = block.split('\n');
    if (lines.isEmpty) continue;
    var idx = 0;
    var timeAt = 0;
    if (RegExp(r'^\d+$').hasMatch(lines[0].trim())) {
      idx = int.parse(lines[0].trim());
      timeAt = 1;
    }
    if (timeAt >= lines.length || !lines[timeAt].contains('-->')) continue;
    final parts = lines[timeAt].split('-->').map((s) => s.trim()).toList();
    if (parts.length < 2) continue;
    out.add(SrtEntry(
      idx == 0 ? out.length + 1 : idx,
      parts[0],
      parts[1],
      lines.sublist(timeAt + 1).join('\n'),
    ));
  }
  return out;
}

String serializeSrt(List<SrtEntry> entries) {
  final b = StringBuffer();
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    b.writeln('${i + 1}');
    b.writeln('${e.start} --> ${e.end}');
    b.writeln(e.text);
    b.writeln();
  }
  return b.toString();
}
