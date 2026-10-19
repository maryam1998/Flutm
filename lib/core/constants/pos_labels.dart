/// برچسب‌های نقش دستوری — معادلِ POS_FA/POS_EN.
const Map<String, String> kPosFa = {
  'noun': 'اسم',
  'verb': 'فعل',
  'adjective': 'صفت',
  'adverb': 'قید',
  'preposition': 'حرف اضافه',
  'pronoun': 'ضمیر',
  'conjunction': 'حرف ربط',
  'article': 'حرف تعریف',
  'interjection': 'صوت',
  'numeral': 'عدد',
  'auxiliary': 'فعل کمکی',
  'other': 'سایر',
  'determiner': 'حرف تعیین‌کننده',
  'exclamation': 'صوت',
  'modal verb': 'فعل وجهی',
  'number': 'عدد',
  'ordinal number': 'عدد ترتیبی',
  'indefinite article': 'حرف تعریف نکره',
  'definite article': 'حرف تعریف معرفه',
  'linking verb': 'فعل ربطی',
  'infinitive marker': 'نشانه‌ی مصدر',
  'idiom': 'اصطلاح',
  'slang': 'اصطلاح عامیانه (مدرن)',
};

const Map<String, String> kPosEn = {
  'noun': 'noun',
  'verb': 'verb',
  'adjective': 'adjective',
  'adverb': 'adverb',
  'preposition': 'preposition',
  'pronoun': 'pronoun',
  'conjunction': 'conjunction',
  'article': 'article',
  'interjection': 'interjection',
  'numeral': 'numeral',
  'auxiliary': 'auxiliary verb',
  'other': 'other',
  'determiner': 'determiner',
  'exclamation': 'exclamation',
  'modal verb': 'modal verb',
  'number': 'number',
  'ordinal number': 'ordinal number',
  'indefinite article': 'indefinite article',
  'definite article': 'definite article',
  'linking verb': 'linking verb',
  'infinitive marker': 'infinitive marker',
  'idiom': 'idiom',
  'slang': 'slang',
};

String posLabel(String pos, String uiLang) {
  final table = uiLang == 'en' ? kPosEn : kPosFa;
  return table[pos] ?? pos;
}
