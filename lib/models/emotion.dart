import 'dart:ui' show Color;

class Emotion {
  final String id;
  final String fa;
  final int freq;
  final String color; // hex

  const Emotion({
    required this.id,
    required this.fa,
    required this.freq,
    required this.color,
  });
}

const List<Emotion> kEmotions = [
  Emotion(id: 'shame',       fa: 'شرم',           freq: 20,  color: '#5c0404'),
  Emotion(id: 'guilt',       fa: 'گناه',          freq: 30,  color: '#7a0a0a'),
  Emotion(id: 'despair',     fa: 'ناامیدی',       freq: 50,  color: '#8a0808'),
  Emotion(id: 'sadness',     fa: 'غم',            freq: 75,  color: '#a01010'),
  Emotion(id: 'fear',        fa: 'ترس',           freq: 100, color: '#b31000'),
  Emotion(id: 'lack',        fa: 'کمبود',         freq: 125, color: '#d81800'),
  Emotion(id: 'anger',       fa: 'خشم',           freq: 150, color: '#f22a00'),
  Emotion(id: 'pride',       fa: 'غرور',          freq: 175, color: '#f4470a'),
  Emotion(id: 'courage',     fa: 'شجاعت',         freq: 200, color: '#f2650a'),
  Emotion(id: 'neutral',     fa: 'خنثی بودن',     freq: 250, color: '#f08c00'),
  Emotion(id: 'readiness',   fa: 'آمادگی',        freq: 310, color: '#f0c400'),
  Emotion(id: 'acceptance',  fa: 'پذیرش',         freq: 350, color: '#f5e600'),
  Emotion(id: 'selfmastery', fa: 'تسلط بر خود',   freq: 400, color: '#9ee600'),
  Emotion(id: 'love',        fa: 'عشق',           freq: 500, color: '#12c93a'),
  Emotion(id: 'joy',         fa: 'شادی',          freq: 540, color: '#00c2c4'),
  Emotion(id: 'peace',       fa: 'آرامش',         freq: 600, color: '#1a2be8'),
  Emotion(id: 'beyond',      fa: 'فراتر از خود',  freq: 700, color: '#9b1fb0'),
];

Emotion? emotionById(String id) {
  for (final e in kEmotions) if (e.id == id) return e;
  return null;
}

/// از بین چند حس انتخاب‌شده، اونی که بالاترین فرکانس رو داره برمی‌گردونه
Emotion? dominantEmotion(Iterable<String> ids) {
  Emotion? dom;
  for (final id in ids) {
    final e = emotionById(id);
    if (e != null && (dom == null || e.freq > dom.freq)) dom = e;
  }
  return dom;
}

/// '#rrggbb' -> Color
Color hexToColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}
