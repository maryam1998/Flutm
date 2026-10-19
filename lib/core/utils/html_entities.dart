/// کاراکترهای HTML-entity (مثل `&#39;` و `&amp;`) را که بعضی سرویس‌های
/// ترجمه/AI داخلِ متن برمی‌گردانند به کاراکترِ واقعی تبدیل می‌کند؛
/// وگرنه هم در صفحه زشت دیده می‌شوند و هم TTS «اند هش ۳۹» می‌خواند.
String decodeHtmlEntities(String s) {
  if (!s.contains('&')) return s;
  const named = <String, String>{
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'rsquo': '\u2019',
    'lsquo': '\u2018',
    'rdquo': '\u201D',
    'ldquo': '\u201C',
    'hellip': '\u2026',
    'ndash': '\u2013',
    'mdash': '\u2014',
  };
  return s.replaceAllMapped(
    RegExp(r'&(?:#(\d{1,6})|#[xX]([0-9a-fA-F]{1,6})|([a-zA-Z]{2,8}));'),
    (m) {
      try {
        if (m.group(1) != null) {
          return String.fromCharCode(int.parse(m.group(1)!));
        }
        if (m.group(2) != null) {
          return String.fromCharCode(int.parse(m.group(2)!, radix: 16));
        }
        return named[m.group(3)!.toLowerCase()] ?? m.group(0)!;
      } catch (_) {
        return m.group(0)!;
      }
    },
  );
}
