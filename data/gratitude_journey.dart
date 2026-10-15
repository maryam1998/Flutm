/// فازها و پرامپت‌های مسیر شکرگذاری — کپی دقیق GRATITUDE_PHASES در js/tamrin-tab.js وب
class GratitudePhase {
  final String name;
  final String short;
  final List<String> prompts;
  const GratitudePhase(this.name, this.short, this.prompts);
}

const kGratitudePhases = <GratitudePhase>[
  GratitudePhase('ایمنی و بدن', 'آمیگدال', [
    'یک بخش از بدنت که امروز بدون درد کار کرد',
    'یک لحظه که در آن احساس امنیت کردی',
    'یک غذایی که امروز خوردی و بهت انرژی داد',
    'یک صدای آشنا که امروز شنیدی (باران، بچه‌ها، موسیقی)',
    'یک جای بدنت که قوی‌تر از چند سال پیش است',
    'یک نفس عمیق که امروز آگاهانه کشیدی',
    'یک لحظه که بدنت بهت سیگنال آرامش داد (خمیازه، کشش، گرم شدن)',
  ]),
  GratitudePhase('پیوند و دیگران', 'mentalizing', [
    'یک نفر که امروز بدون این‌که بخواهی، حواسش بهت بود',
    'یک نفر که در گذشته بهت کمک کرد و هنوز فکرش را می‌کنی',
    'یک غریبه که امروز یک کار کوچک برات کرد (نگه‌داشتن در، لبخند، راهنمایی)',
    'یک نفر از خانواده‌ات — و چرا این کار را برات کرد؟ نیتش چه بود؟',
    'یک نفر که امروز به او کمک کردی و از این کار حس خوبی گرفتی',
    'یک دوست که مدتیه ندیدیش ولی حضورش را در زندگی‌ات حس می‌کنی',
    'یک نفر که نیتش برای کمکت، حتی از نتیجه‌اش مهم‌تر بود',
  ]),
  GratitudePhase('چالش و رشد', 'بازآرزیابی', [
    'یک مشکل که امروز داشتی ولی ازش یاد گرفتی',
    'یک اشتباه قدیمی که امروز می‌بینی به نفعت تمام شد',
    'یک «نه» که بهت گفتن و بعداً فهمیدی چرا بهتر بود',
    'یک سختی که از پسش براومدی و الان قوی‌ترت کرد',
    'یک چیز که از دست دادی و بعدش فضای چیز بهتری باز شد',
    'یک انتقاد که شنیدی و بعداً دیدی درست بود',
    'یک روز بد که یک چیز کوچک توش نجاتت داد',
  ]),
  GratitudePhase('هویت و وجود', 'DMN', [
    'یک استعدادی که داری و به آن عادت کردی',
    'یک انتخاب که در گذشته کردی و امروزت را ساختی',
    'یک لحظه که امروز از خودت راضی بودی',
    'یک بخش از شخصیتت که دوستش داری',
    'یک بار که به خودت سخت گرفتی و بعد بخشیدی',
    'این مسیر ۲۷ روزه — برای این‌که ادامه دادی',
    'خودِ زندگی — بدون هیچ دلیل خاصی',
  ]),
];

/// GRATITUDE_ALL_PROMPTS وب: همه‌ی پرامپت‌ها پشت‌سرهم (۴×۷ = ۲۸)
final List<String> kGratitudeAllPrompts = <String>[
  for (final p in kGratitudePhases) ...p.prompts,
];

class GratitudePhaseInfo {
  final int day;
  final int totalDays;
  final String phaseName;
  final String phaseShort;
  final int phaseIndex;
  final int dayInPhase;
  final String prompt;
  const GratitudePhaseInfo({
    required this.day,
    required this.totalDays,
    required this.phaseName,
    required this.phaseShort,
    required this.phaseIndex,
    required this.dayInPhase,
    required this.prompt,
  });
}

/// getGratitudePhaseInfo وب:
///   day = بین ۱ و totalDays (کلمپ می‌شود)،
///   idxInCycle = (day-1) % ۲۸ ،  فاز = idxInCycle ~/ ۷
GratitudePhaseInfo computeGratitudePhase(int daysPassed, int totalDays) {
  final total = totalDays < 1 ? 28 : totalDays;
  final d = daysPassed < 1 ? 1 : (daysPassed > total ? total : daysPassed);
  final idxInCycle = (d - 1) % kGratitudeAllPrompts.length;
  final phaseIdx = (idxInCycle ~/ 7) % kGratitudePhases.length;
  final dayInPhase = idxInCycle % 7;
  final phase = kGratitudePhases[phaseIdx];
  return GratitudePhaseInfo(
    day: d,
    totalDays: total,
    phaseName: phase.name,
    phaseShort: phase.short,
    phaseIndex: phaseIdx,
    dayInPhase: dayInPhase + 1,
    prompt: phase.prompts[dayInPhase],
  );
}

/// MONTH_ORDINALS_FA وب
const kPeriodOrdinals = <String>[
  'اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم',
  'هفتم', 'هشتم', 'نهم', 'دهم', 'یازدهم', 'دوازدهم',
];

/// periodOrdFa وب
String periodOrdFa(int i) {
  if (i >= 0 && i < kPeriodOrdinals.length) return kPeriodOrdinals[i];
  return (i + 1).toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
      );
}
