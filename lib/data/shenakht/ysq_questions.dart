// lib/data/shenakht/ysq_questions.dart
// ۹۰ سؤال — ۱۸ طرحواره × ۵ سؤال
// مقیاس ۶ نقطه‌ای — بدون تشخیص بالینی

import 'schemas.dart';

// ═══════════════════════════════════════════════════════════
// مقیاس پاسخ (۶ نقطه‌ای)
// ═══════════════════════════════════════════════════════════
class LikertItem {
  final int value;
  final String label;
  const LikertItem(this.value, this.label);
}

const List<LikertItem> likertScale = [
  LikertItem(1, 'کاملاً مخالفم'),
  LikertItem(2, 'مخالفم'),
  LikertItem(3, 'تا حدی مخالفم'),
  LikertItem(4, 'تا حدی موافقم'),
  LikertItem(5, 'موافقم'),
  LikertItem(6, 'کاملاً موافقم'),
];

// ═══════════════════════════════════════════════════════════
// سؤال
// ═══════════════════════════════════════════════════════════
class YsqQuestion {
  final String id;
  final String schemaId;
  final String text;
  const YsqQuestion(this.id, this.schemaId, this.text);
}

// ═══════════════════════════════════════════════════════════
// ۹۰ سؤال
// ═══════════════════════════════════════════════════════════
const List<YsqQuestion> ysqQuestions = [
  // ۱. رهاشدگی
  YsqQuestion('ab_1', 'abandonment', 'نگرانم که افراد مهم زندگی‌ام به‌زودی ترکم کنند.'),
  YsqQuestion('ab_2', 'abandonment', 'وقتی کسی دیر جواب می‌دهد، فوراً به این فکر می‌کنم که دیگر نمی‌خواهد من را.'),
  YsqQuestion('ab_3', 'abandonment', 'احساس می‌کنم روابطم شکننده‌اند و ممکن است هر لحظه تمام شوند.'),
  YsqQuestion('ab_4', 'abandonment', 'برای اینکه کسی را از دست ندهم، بیش از حد به او وابسته می‌شوم.'),
  YsqQuestion('ab_5', 'abandonment', 'وقتی کسی از من فاصله می‌گیرد، احساس می‌کنم در حال از دست دادن او هستم.'),

  // ۲. بی‌اعتمادی / بدرفتاری
  YsqQuestion('mi_1', 'mistrust_abuse', 'به نیت دیگران اعتماد نمی‌کنم، حتی وقتی مهربان هستند.'),
  YsqQuestion('mi_2', 'mistrust_abuse', 'احساس می‌کنم اگر خودم را نشان دهم، ممکن است از من سوءاستفاده شود.'),
  YsqQuestion('mi_3', 'mistrust_abuse', 'معمولاً نیت دیگران را زیر سؤال می‌برم.'),
  YsqQuestion('mi_4', 'mistrust_abuse', 'حتی وقتی کسی خوبی می‌کند، به دنبال دلیل پنهانی می‌گردم.'),
  YsqQuestion('mi_5', 'mistrust_abuse', 'احساس می‌کنم اگر حواسم نباشد، دیگران به من ضربه می‌زنند.'),

  // ۳. محرومیت هیجانی
  YsqQuestion('ed_1', 'emotional_deprivation', 'احساس می‌کنم هیچ‌کس واقعاً نیازهای هیجانی من را نمی‌فهمد.'),
  YsqQuestion('ed_2', 'emotional_deprivation', 'در روابط نزدیک، باز هم احساس تنهایی می‌کنم.'),
  YsqQuestion('ed_3', 'emotional_deprivation', 'احساس می‌کنم کسی نیست که واقعاً به من اهمیت بدهد.'),
  YsqQuestion('ed_4', 'emotional_deprivation', 'دوست دارم کسی مرا عمیقاً درک کند، ولی فکر نمی‌کنم این اتفاق بیفتد.'),
  YsqQuestion('ed_5', 'emotional_deprivation', 'معمولاً احساس پوچی و کمبود عاطفی دارم.'),

  // ۴. نقص / شرم
  YsqQuestion('de_1', 'defectiveness_shame', 'احساس می‌کنم در من چیزی معیوب یا ناقص وجود دارد.'),
  YsqQuestion('de_2', 'defectiveness_shame', 'اگر دیگران واقعی من را ببینند، من را ترک می‌کنند.'),
  YsqQuestion('de_3', 'defectiveness_shame', 'بیشتر وقت‌ها احساس شرم از خودم دارم.'),
  YsqQuestion('de_4', 'defectiveness_shame', 'احساس می‌کنم ارزش دوست داشته شدن را ندارم.'),
  YsqQuestion('de_5', 'defectiveness_shame', 'خودم را درونی معیوب و ناکافی می‌دانم.'),

  // ۵. انزوای اجتماعی
  YsqQuestion('si_1', 'social_isolation', 'احساس می‌کنم با اطرافیانم متفاوت هستم و به آن‌ها تعلق ندارم.'),
  YsqQuestion('si_2', 'social_isolation', 'در جمع‌ها احساس بیگانگی می‌کنم.'),
  YsqQuestion('si_3', 'social_isolation', 'احساس می‌کنم هیچ‌جا جای من نیست.'),
  YsqQuestion('si_4', 'social_isolation', 'احساس می‌کنم دیگران چیزی دارند که من ندارم.'),
  YsqQuestion('si_5', 'social_isolation', 'معمولاً خودم را از گروه‌ها کنار می‌کشم.'),

  // ۶. وابستگی / بی‌کفایتی
  YsqQuestion('dp_1', 'dependence_incompetence', 'در تصمیم‌گیری‌های روزمره به کمک دیگران نیاز دارم.'),
  YsqQuestion('dp_2', 'dependence_incompetence', 'احساس می‌کنم بدون کمک دیگران نمی‌توانم از عهده کارها بربیایم.'),
  YsqQuestion('dp_3', 'dependence_incompetence', 'وقتی باید کاری را تنها انجام دهم، مضطرب می‌شوم.'),
  YsqQuestion('dp_4', 'dependence_incompetence', 'تصمیم‌های مهم زندگی‌ام را به دیگران می‌سپارم.'),
  YsqQuestion('dp_5', 'dependence_incompetence', 'احساس می‌کنم به‌تنهایی توانمند نیستم.'),

  // ۷. آسیب‌پذیری
  YsqQuestion('vu_1', 'vulnerability', 'نگرانم که فاجعه‌ای (جسمی، مالی، روانی) در راه باشد.'),
  YsqQuestion('vu_2', 'vulnerability', 'مدام نگران سلامتی خودم یا عزیزانم هستم.'),
  YsqQuestion('vu_3', 'vulnerability', 'احساس می‌کنم اتفاقات بد غیرقابل پیش‌بینی ممکن است هر لحظه بیفتد.'),
  YsqQuestion('vu_4', 'vulnerability', 'وقتی شرایط نامطمئن است، به بدترین حالت فکر می‌کنم.'),
  YsqQuestion('vu_5', 'vulnerability', 'احساس می‌کنم در برابر حوادث آینده بی‌دفاع هستم.'),

  // ۸. درهم‌تنیدگی
  YsqQuestion('en_1', 'enmeshment', 'حال من خیلی وابسته به حال افراد نزدیکم است.'),
  YsqQuestion('en_2', 'enmeshment', 'بدون افراد مهم زندگی‌ام احساس گم‌شدگی می‌کنم.'),
  YsqQuestion('en_3', 'enmeshment', 'نمی‌توانم از نظر هیجانی از دیگران جدا باشم.'),
  YsqQuestion('en_4', 'enmeshment', 'نظر دیگران مهم‌تر از نظر خودم برای من است.'),
  YsqQuestion('en_5', 'enmeshment', 'خودم را بیشتر از طریق دیگران می‌شناسم تا مستقل.'),

  // ۹. شکست
  YsqQuestion('fa_1', 'failure', 'احساس می‌کنم در مقایسه با دیگران شکست خورده‌ام.'),
  YsqQuestion('fa_2', 'failure', 'وقتی چالشی پیش می‌آید، پیش‌بینی می‌کنم شکست بخورم.'),
  YsqQuestion('fa_3', 'failure', 'احساس می‌کنم به‌اندازه کافی توانمند نیستم.'),
  YsqQuestion('fa_4', 'failure', 'خودم را عقب‌تر از هم‌سن و سال‌هایم می‌بینم.'),
  YsqQuestion('fa_5', 'failure', 'کارها را به‌خاطر ترس از شکست، عقب می‌اندازم.'),

  // ۱۰. استحقاق
  YsqQuestion('et_1', 'entitlement', 'احساس می‌کنم قوانین برای من متفاوت است.'),
  YsqQuestion('et_2', 'entitlement', 'وقتی چیزی طبق میل من پیش نمی‌رود، عصبانی می‌شوم.'),
  YsqQuestion('et_3', 'entitlement', 'احساس می‌کنم لایق چیزهای بیشتری هستم.'),
  YsqQuestion('et_4', 'entitlement', 'وقتی کسی من را اولویت اول قرار نمی‌دهد، برمی‌آشوبم.'),
  YsqQuestion('et_5', 'entitlement', 'به‌سختی می‌توانم محدودیت‌ها را بپذیرم.'),

  // ۱۱. خویشتن‌داری ناکافی
  YsqQuestion('sc_1', 'insufficient_self_control', 'در کنترل تکانه‌هایم ضعیف هستم.'),
  YsqQuestion('sc_2', 'insufficient_self_control', 'کارها را همیشه به بعد موکول می‌کنم.'),
  YsqQuestion('sc_3', 'insufficient_self_control', 'وقتی ناراحت یا حوصله‌ام سر می‌رود، نمی‌توانم تحمل کنم.'),
  YsqQuestion('sc_4', 'insufficient_self_control', 'به‌سختی می‌توانم به برنامه یا تعهد پایبند بمانم.'),
  YsqQuestion('sc_5', 'insufficient_self_control', 'احساساتم سریع به رفتار تبدیل می‌شوند.'),

  // ۱۲. اطاعت / تسلیم
  YsqQuestion('su_1', 'subjugation', 'احساساتم را پنهان می‌کنم تا کسی ناراحت نشود.'),
  YsqQuestion('su_2', 'subjugation', 'معمولاً به خواسته دیگران تسلیم می‌شوم.'),
  YsqQuestion('su_3', 'subjugation', 'احساس می‌کنم حق ندارم مخالفت کنم.'),
  YsqQuestion('su_4', 'subjugation', 'از ترس عواقب، نظر خودم را نمی‌گویم.'),
  YsqQuestion('su_5', 'subjugation', 'بعد از تسلیم شدن، درونم دلخور و پر از خشم می‌شوم.'),

  // ۱۳. ایثار
  YsqQuestion('ss_1', 'self_sacrifice', 'نیازهای دیگران را همیشه بر نیازهای خودم مقدم می‌کنم.'),
  YsqQuestion('ss_2', 'self_sacrifice', 'اگر کمک نکنم، احساس گناه می‌کنم.'),
  YsqQuestion('ss_3', 'self_sacrifice', 'به‌سختی می‌توانم به کسی «نه» بگویم.'),
  YsqQuestion('ss_4', 'self_sacrifice', 'خودم را برای خوشحالی دیگران فدا می‌کنم.'),
  YsqQuestion('ss_5', 'self_sacrifice', 'احساس می‌کنم مسئول حال خوب دیگران هستم.'),

  // ۱۴. تأییدطلبی
  YsqQuestion('ap_1', 'approval_seeking', 'نظر دیگران درباره من برایم بسیار مهم است.'),
  YsqQuestion('ap_2', 'approval_seeking', 'برای جلب توجه یا تحسین، کارهایی می‌کنم که واقعاً نمی‌خواهم.'),
  YsqQuestion('ap_3', 'approval_seeking', 'اگر کسی از من تعریف نکند، احساس بی‌ارزشی می‌کنم.'),
  YsqQuestion('ap_4', 'approval_seeking', 'بیشتر وقت‌ها نگرانم که دیگران درباره من چه فکری می‌کنند.'),
  YsqQuestion('ap_5', 'approval_seeking', 'خودم را با معیار تأیید دیگران می‌سنجم.'),

  // ۱۵. منفی‌گرایی
  YsqQuestion('ne_1', 'negativity', 'معمولاً به جنبه‌های منفی هر موقعیت تمرکز می‌کنم.'),
  YsqQuestion('ne_2', 'negativity', 'وقتی اتفاق خوبی می‌افتد، نگرانم که دوام نیاورد.'),
  YsqQuestion('ne_3', 'negativity', 'انتظار بدترین نتیجه را دارم.'),
  YsqQuestion('ne_4', 'negativity', 'احساس می‌کنم چیزهای خوب در زندگی‌ام زودگذر هستند.'),
  YsqQuestion('ne_5', 'negativity', 'معمولاً بیشتر بر اشتباهات و مشکلات تمرکز می‌کنم تا موفقیت‌ها.'),

  // ۱۶. بازداری هیجانی
  YsqQuestion('ei_1', 'emotional_inhibition', 'احساساتم را نشان نمی‌دهم چون فکر می‌کنم ضعف است.'),
  YsqQuestion('ei_2', 'emotional_inhibition', 'به‌سختی می‌توانم از احساساتم حرف بزنم.'),
  YsqQuestion('ei_3', 'emotional_inhibition', 'خشم یا ناراحتی‌ام را سرکوب می‌کنم.'),
  YsqQuestion('ei_4', 'emotional_inhibition', 'وقتی احساساتم بالا می‌آید، سرد و منطقی می‌شوم.'),
  YsqQuestion('ei_5', 'emotional_inhibition', 'احساس می‌کنم احساساتم برای دیگران سربار است.'),

  // ۱۷. معیارهای سختگیرانه
  YsqQuestion('us_1', 'unrelenting_standards', 'هیچ‌وقت از کار خودم راضی نیستم، حتی وقتی خوب انجام شده.'),
  YsqQuestion('us_2', 'unrelenting_standards', 'احساس می‌کنم همیشه باید سخت‌تر تلاش کنم.'),
  YsqQuestion('us_3', 'unrelenting_standards', 'استراحت کردن را اتلاف وقت می‌دانم.'),
  YsqQuestion('us_4', 'unrelenting_standards', 'استانداردهای من از توان واقعی‌ام بالاتر است.'),
  YsqQuestion('us_5', 'unrelenting_standards', 'کار را تا وقتی کامل نباشد، تحویل نمی‌دهم.'),

  // ۱۸. تنبیه‌گری
  YsqQuestion('pu_1', 'punitiveness', 'وقتی اشتباه می‌کنم، خودم را شدیداً سرزنش می‌کنم.'),
  YsqQuestion('pu_2', 'punitiveness', 'احساس می‌کنم اشتباهاتم بخشیدنی نیستند.'),
  YsqQuestion('pu_3', 'punitiveness', 'با کسانی که اشتباه می‌کنند، سرد و سختگیر می‌شوم.'),
  YsqQuestion('pu_4', 'punitiveness', 'احساس می‌کنم افراد باید به‌خاطر اشتباهاتشان عواقب سختی ببینند.'),
  YsqQuestion('pu_5', 'punitiveness', 'به‌سختی می‌توانم خودم یا دیگران را ببخشم.'),
];

// ═══════════════════════════════════════════════════════════
// مدل امتیاز هر طرحواره
// ═══════════════════════════════════════════════════════════
class SchemaScore {
  final String schemaId;
  final String name;
  final String domain;
  final double mean;
  final int percentage;
  final int answered;
  final int total;
  final int elevatedCount;
  final PriorityLevel priority;

  const SchemaScore({
    required this.schemaId,
    required this.name,
    required this.domain,
    required this.mean,
    required this.percentage,
    required this.answered,
    required this.total,
    required this.elevatedCount,
    required this.priority,
  });
}

// ═══════════════════════════════════════════════════════════
// مدل نتیجهٔ کامل تحلیل
// ═══════════════════════════════════════════════════════════
class YsqAnalysis {
  final List<SchemaScore> all;
  final List<SchemaScore> high;
  final List<SchemaScore> medium;
  final List<SchemaScore> low;
  final List<SchemaScore> active;
  final SchemaScore? recommended;
  final int answeredCount;
  final int totalCount;

  const YsqAnalysis({
    required this.all,
    required this.high,
    required this.medium,
    required this.low,
    required this.active,
    required this.recommended,
    required this.answeredCount,
    required this.totalCount,
  });
}

// ═══════════════════════════════════════════════════════════
// محاسبهٔ امتیاز هر طرحواره
// ═══════════════════════════════════════════════════════════
List<SchemaScore> computeSchemaScores(Map<String, int> answers) {
  final Map<String, List<int>> grouped = {};
  for (final q in ysqQuestions) {
    final val = answers[q.id];
    if (val != null && val >= 1 && val <= 6) {
      grouped.putIfAbsent(q.schemaId, () => []).add(val);
    }
  }

  final results = <SchemaScore>[];
  grouped.forEach((schemaId, values) {
    if (values.isEmpty) return;

    final sum = values.fold<int>(0, (a, b) => a + b);
    final mean = sum / values.length;
    final percentage = (((mean - 1) / 5) * 100).round();
    final elevated = values.where((v) => v >= 4).length;

    final schema = findSchemaById(schemaId);
    results.add(SchemaScore(
      schemaId: schemaId,
      name: schema?.nameFa ?? schemaId,
      domain: schema?.domain ?? 'unknown',
      mean: double.parse(mean.toStringAsFixed(2)),
      percentage: percentage,
      answered: values.length,
      total: 5,
      elevatedCount: elevated,
      priority: getPriority(percentage),
    ));
  });

  results.sort((a, b) => b.percentage.compareTo(a.percentage));
  return results;
}

// ═══════════════════════════════════════════════════════════
// تحلیل کامل
// ═══════════════════════════════════════════════════════════
YsqAnalysis analyzeYsq(Map<String, int> answers) {
  final all = computeSchemaScores(answers);
  final high = all.where((s) => s.priority.level == 'high').toList();
  final medium = all.where((s) => s.priority.level == 'medium').toList();
  final low = all.where((s) => s.priority.level == 'low').toList();

  SchemaScore? recommended;
  if (high.isNotEmpty) {
    recommended = high.first;
  } else if (medium.isNotEmpty) {
    recommended = medium.first;
  } else if (all.isNotEmpty) {
    recommended = all.first;
  }

  return YsqAnalysis(
    all: all,
    high: high,
    medium: medium,
    low: low,
    active: [...high, ...medium],
    recommended: recommended,
    answeredCount: answers.length,
    totalCount: ysqQuestions.length,
  );
}

// ═══════════════════════════════════════════════════════════
// اعتبارسنجی
// ═══════════════════════════════════════════════════════════
class YsqValidation {
  final bool valid;
  final List<String> missing;
  final int progress;
  const YsqValidation({
    required this.valid,
    required this.missing,
    required this.progress,
  });
}

YsqValidation validateAnswers(Map<String, int> answers) {
  final missing = <String>[];
  for (final q in ysqQuestions) {
    final v = answers[q.id];
    if (v == null || v < 1 || v > 6) missing.add(q.id);
  }
  return YsqValidation(
    valid: missing.isEmpty,
    missing: missing,
    progress: (((ysqQuestions.length - missing.length) / ysqQuestions.length) *
            100)
        .round(),
  );
}

// ═══════════════════════════════════════════════════════════
// خروجی قابل ذخیره (برای بکاپ JSON — سازگار با وب)
// ═══════════════════════════════════════════════════════════
Map<String, dynamic> buildYsqResultPayload(
  Map<String, int> answers, {
  String? userId,
}) {
  final analysis = analyzeYsq(answers);
  return {
    'version': '2.0',
    'completedAt': DateTime.now().toIso8601String(),
    'userId': userId,
    'answers': answers,
    'scores': analysis.all
        .map((r) => {
              'schemaId': r.schemaId,
              'percentage': r.percentage,
              'mean': r.mean,
              'priority': r.priority.level,
              'elevatedCount': r.elevatedCount,
            })
        .toList(),
    'recommendedSchemaId': analysis.recommended?.schemaId,
  };
}
