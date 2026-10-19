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
    'یک صدای آشنا که امروز شنیدی',
    'یک جای بدنت که قوی‌تر از چند سال پیش است',
    'یک نفس عمیق که امروز آگاهانه کشیدی',
    'یک لحظه که بدنت بهت سیگنال آرامش داد',
  ]),
  GratitudePhase('پیوند و دیگران', 'mentalizing', [
    'یک نفر که امروز بدون این‌که بخواهی، حواسش بهت بود',
    'یک نفر که در گذشته بهت کمک کرد',
    'یک غریبه که امروز یک کار کوچک برات کرد',
    'یک نفر از خانواده‌ات — و چرا این کار را برات کرد؟',
    'یک نفر که امروز به او کمک کردی',
    'یک دوست که مدتیه ندیدیش ولی حضورش را حس می‌کنی',
    'یک نفر که نیتش برای کمکت، از نتیجه مهم‌تر بود',
  ]),
  GratitudePhase('چالش و رشد', 'بازآرزیابی', [
    'یک مشکل که امروز داشتی ولی ازش یاد گرفتی',
    'یک اشتباه قدیمی که امروز می‌بینی به نفعت شد',
    'یک «نه» که بهت گفتن و بعداً فهمیدی چرا',
    'یک سختی که از پسش براومدی',
    'یک چیز که از دست دادی و بعدش فضای بهتری باز شد',
    'یک انتقاد که شنیدی و بعداً دیدی درست بود',
    'یک روز بد که یک چیز کوچک توش نجاتت داد',
  ]),
  GratitudePhase('هویت و وجود', 'DMN', [
    'یک استعدادی که داری و به آن عادت کردی',
    'یک انتخاب که در گذشته کردی و امروزت را ساختی',
    'یک لحظه که امروز از خودت راضی بودی',
    'یک بخش از شخصیتت که دوستش داری',
    'یک بار که به خودت سخت گرفتی و بعد بخشیدی',
    'این مسیر — برای این‌که ادامه دادی',
    'خودِ زندگی — بدون هیچ دلیل خاصی',
  ]),
];

const kGratitudeAllPrompts = <String>[
  // flatten
  'یک بخش از بدنت که امروز بدون درد کار کرد',
  'یک لحظه که در آن احساس امنیت کردی',
  'یک غذایی که امروز خوردی و بهت انرژی داد',
  'یک صدای آشنا که امروز شنیدی',
  'یک جای بدنت که قوی‌تر از چند سال پیش است',
  'یک نفس عمیق که امروز آگاهانه کشیدی',
  'یک لحظه که بدنت بهت سیگنال آرامش داد',
  'یک نفر که امروز بدون این‌که بخواهی، حواسش بهت بود',
  'یک نفر که در گذشته بهت کمک کرد',
  'یک غریبه که امروز یک کار کوچک برات کرد',
  'یک نفر از خانواده‌ات — و چرا این کار را برات کرد؟',
  'یک نفر که امروز به او کمک کردی',
  'یک دوست که مدتیه ندیدیش ولی حضورش را حس می‌کنی',
  'یک نفر که نیتش برای کمکت، از نتیجه مهم‌تر بود',
  'یک مشکل که امروز داشتی ولی ازش یاد گرفتی',
  'یک اشتباه قدیمی که امروز می‌بینی به نفعت شد',
  'یک «نه» که بهت گفتن و بعداً فهمیدی چرا',
  'یک سختی که از پسش براومدی',
  'یک چیز که از دست دادی و بعدش فضای بهتری باز شد',
  'یک انتقاد که شنیدی و بعداً دیدی درست بود',
  'یک روز بد که یک چیز کوچک توش نجاتت داد',
  'یک استعدادی که داری و به آن عادت کردی',
  'یک انتخاب که در گذشته کردی و امروزت را ساختی',
  'یک لحظه که امروز از خودت راضی بودی',
  'یک بخش از شخصیتت که دوستش داری',
  'یک بار که به خودت سخت گرفتی و بعد بخشیدی',
  'این مسیر — برای این‌که ادامه دادی',
  'خودِ زندگی — بدون هیچ دلیل خاصی',
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

GratitudePhaseInfo computeGratitudePhase(int daysPassed, int totalDays) {
  final d = daysPassed < 1 ? 1 : daysPassed;
  final idxInCycle = (d - 1) % kGratitudeAllPrompts.length;
  final phaseIdx = (idxInCycle ~/ 7) % kGratitudePhases.length;
  final dayInPhase = idxInCycle % 7;
  final phase = kGratitudePhases[phaseIdx];
  return GratitudePhaseInfo(
    day: d,
    totalDays: totalDays,
    phaseName: phase.name,
    phaseShort: phase.short,
    phaseIndex: phaseIdx,
    dayInPhase: dayInPhase + 1,
    prompt: phase.prompts[dayInPhase],
  );
}
