// lib/data/shenakht/schemas.dart
// ۱۸ طرحواره — نسخه نهایی (بعد از اعمال CURATED_OPTIONS)
// معادل SCHEMAS.js + SCHEMAS_ADDITIONS.js + TRIGGERS_EXTRA.js + CURATED_OPTIONS.js
// در وب اینها در زمان اجرا روی هم merge میشن؛ اینجا از قبل merge شده.

import '../../models/shenakht/schema.dart';

// ═══════════════════════════════════════════════════════════
// ۱. رهاشدگی
// ═══════════════════════════════════════════════════════════
const _abandonment = Schema(
  id: 'abandonment',
  nameFa: 'رهاشدگی / بی‌ثباتی',
  nameEn: 'Abandonment / Instability',
  domain: 'disconnection_rejection',
  color: '#e74c3c',
  shortDescription:
      'ترس از اینکه افراد مهم زندگی ناگهان بروند، تغییر کنند یا دیگر در دسترس نباشند.',
  coreNeed: 'امنیت عاطفی و احساس ثبات در رابطه',
  triggers: [
    SchemaItem('late_reply', 'کسی که برام مهمه دیر جواب داد'),
    SchemaItem('seen_not_replied', 'پیامم دیده شد ولی جوابی نیومد'),
    SchemaItem('less_attention', 'کمتر زنگ می‌زنه و کمتر پیام می‌ده'),
    SchemaItem('distance_ab', 'حس کردم رفتارش عوض شده و داره فاصله می‌گیره'),
    SchemaItem('conflict', 'بحث یا دلخوری پیش اومد'),
    SchemaItem('unclear_future', 'نمی‌دونستم این رابطه قراره به کجا برسه'),
    SchemaItem('friend_busy_add', 'کسی که بهش نزدیکم سرش شلوغ بود و وقت نذاشت'),
    SchemaItem('weekend_alone_add', 'آخر هفته تنها موندم'),
    SchemaItem('photos_group_add', 'عکس جمعی دیدم که توش نبودم'),
  ],
  automaticThoughts: [
    SchemaItem('moving_away', 'داره ازم دور می‌شه'),
    SchemaItem('not_important', 'دیگه براش مهم نیستم'),
    SchemaItem('will_leave', 'آخرش منو ول می‌کنه'),
    SchemaItem('tired_of_me_add', 'از من خسته شده'),
    SchemaItem('busy_with_other_add', 'حتماً یکی دیگه جای منو گرفته'),
    SchemaItem('something_bad', 'حتماً اتفاقی افتاده یا از دستم ناراحته'),
    SchemaItem('not_worth_add', 'من ارزش وقت گذاشتن ندارم'),
    SchemaItem('must_act', 'باید کاری کنم که نره'),
  ],
  emotionalSignals: [
    SchemaItem('anxiety', 'اضطراب'),
    SchemaItem('fear_ab', 'ترس از دست دادن'),
    SchemaItem('anger', 'خشم'),
    SchemaItem('longing', 'دلتنگی'),
    SchemaItem('emptiness_add', 'پوچی'),
    SchemaItem('jealousy_add', 'حسادت'),
    SchemaItem('betrayal_add', 'احساس خیانت'),
  ],
  behavioralPatterns: [
    SchemaItem('repeated_messaging', 'پشت‌سرهم پیام می‌دم'),
    SchemaItem('checking_ab', 'مدام آنلاین بودنش و صفحه‌هاش رو چک می‌کنم'),
    SchemaItem('clinging', 'بیش از حد بهش می‌چسبم'),
    SchemaItem('testing_ab', 'امتحانش می‌کنم ببینم واقعاً دوستم داره یا نه'),
    SchemaItem('preemptive_exit', 'قبل از اینکه منو ترک کنه، خودم رابطه رو تموم می‌کنم'),
    SchemaItem('ask_friends_add', 'از دوستای مشترک درباره‌ش می‌پرسم'),
    SchemaItem('silent_treatment_add', 'قهر می‌کنم'),
    SchemaItem('pretend_busy_add', 'وانمود می‌کنم سرم شلوغه'),
  ],
  avoidancePatterns: [
    'وارد نشدن به رابطه',
    'فاصله گرفتن',
    'بی‌تفاوت نشان دادن خود',
  ],
  overcompensationPatterns: [
    'کنترل کردن رابطه',
    'نیاز شدید به اطمینان گرفتن',
    'وابستگی شدید',
  ],
  consequences: [
    'افزایش اضطراب',
    'فشار روی رابطه',
    'تفسیر اشتباه رفتار دیگران',
  ],
  pauseQuestions: [
    'الان چه چیزی را واقعاً می‌دانم؟',
    'چه چیزی فقط برداشت من است؟',
    'آیا این اتفاق حتماً به معنی ترک شدن است؟',
    'اگر الان واکنش نشان ندهم چه می‌شود؟',
  ],
  healthyResponse:
      'تحمل مقدار کمی از عدم قطعیت و بررسی واقعیت قبل از واکنش.',
  replacementResponses: [
    ReplacementResponse(
      'repeated_messaging',
      'قبل از ارسال پیام دوم، ۳۰ دقیقه صبر می‌کنم.',
    ),
    ReplacementResponse(
      'checking_ab',
      'قبل از چک کردن، از خودم می‌پرسم دنبال چه شواهدی هستم.',
    ),
    ReplacementResponse(
      'clinging',
      'فعلاً پیام دیگری نمی‌فرستم و به کار خودم برمی‌گردم.',
    ),
    ReplacementResponse(
      'testing_ab',
      'به جای آزمودن، نیازم را مستقیم و آرام بیان می‌کنم.',
    ),
    ReplacementResponse(
      'preemptive_exit',
      'قبل از قطع رابطه، سه شاهد واقعی می‌نویسم.',
    ),
  ],
  exercises: [
    SchemaExercise(
      id: 'reality_vs_assumption',
      title: 'واقعیت یا برداشت؟',
      type: 'two_column',
      columns: [
        SchemaExerciseColumn('fact', 'چیزی که می‌دانم'),
        SchemaExerciseColumn('assumption', 'چیزی که حدس می‌زنم'),
      ],
      question: 'آیا برای واکنش فوری شواهد کافی دارم؟',
      answers: ['بله', 'خیر'],
      ifNo: 'فعلاً هیچ اقدامی نمی‌کنم.',
    ),
    SchemaExercise(
      id: 'pause_30min',
      title: 'مکث ۳۰ دقیقه‌ای',
      type: 'timer',
      durationSeconds: 1800,
      description: 'قبل از هر واکنشی، ۳۰ دقیقه مکث کن. فقط باش.',
    ),
    SchemaExercise(
      id: 'need_expression',
      title: 'بیان مستقیم نیاز',
      type: 'single_input',
      question:
          'به جای درخواست اطمینان، جمله‌ای بنویس که نیاز واقعی‌ات را بیان کند.',
    ),
  ],
  realLifeMissions: [
    RealLifeMission('m1', 'قبل از ارسال پیام دوم ۳۰ دقیقه صبر کن.'),
    RealLifeMission('m2', 'یک موقعیت مبهم را بدون نتیجه‌گیری ثبت کن.'),
    RealLifeMission(
        'm3', 'به جای درخواست اطمینان، یک بار احساس خودت را بیان کن.'),
  ],
  progressMetrics: [
    ProgressMetric('p1', 'کاهش واکنش فوری'),
    ProgressMetric('p2', 'افزایش تحمل عدم قطعیت'),
    ProgressMetric('p3', 'افزایش استفاده از پاسخ جایگزین'),
  ],
  rules: [
    SchemaRule(
      const SchemaRuleWhen(trigger: 'late_reply', behavior: 'checking_ab'),
      'showExercise:reality_vs_assumption',
    ),
    SchemaRule(
      const SchemaRuleWhen(trigger: 'distance_ab', behavior: 'clinging'),
      'showExercise:pause_30min',
    ),
    SchemaRule(
      const SchemaRuleWhen(trigger: 'unclear_future', behavior: 'testing_ab'),
      'showExercise:need_expression',
    ),
    SchemaRule(
      const SchemaRuleWhen(behavior: 'preemptive_exit'),
      'showExercise:reality_vs_assumption',
    ),
    SchemaRule(
      const SchemaRuleWhen(
          trigger: 'late_reply', behavior: 'repeated_messaging'),
      'showExercise:pause_30min',
    ),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۲. بی‌اعتمادی / بدرفتاری
// ═══════════════════════════════════════════════════════════
const _mistrustAbuse = Schema(
  id: 'mistrust_abuse',
  nameFa: 'بی‌اعتمادی / بدرفتاری',
  nameEn: 'Mistrust / Abuse',
  domain: 'disconnection_rejection',
  color: '#c0392b',
  shortDescription:
      'انتظار اینکه دیگران ممکن است آسیب بزنند، سوءاستفاده کنند، فریب دهند یا از اعتماد فرد استفاده کنند.',
  coreNeed: 'امنیت و اعتماد سالم',
  triggers: [
    SchemaItem('ambiguous_behavior', 'رفتار یا جوابش مبهم بود'),
    SchemaItem('broken_promise', 'قولی که داده بود عمل نشد'),
    SchemaItem('lie', 'فهمیدم دروغ گفته'),
    SchemaItem('criticism', 'کسی از من انتقاد کرد یا ایراد گرفت'),
    SchemaItem('dependence', 'مجبور شدم به کسی تکیه کنم'),
    SchemaItem('phone_hidden_add', 'گوشی‌ش رو ازم پنهان کرد'),
    SchemaItem('late_night_add', 'دیروقت بیرون بود و توضیحی نداد'),
    SchemaItem('password_changed_add', 'رمزهاش رو عوض کرد'),
    SchemaItem(
        'secret_call_add', 'مخفیانه تلفنی حرف زد یا با کسی پچ‌پچ کرد'),
    SchemaItem('unexpected_gift_add', 'بی‌دلیل بهم هدیه یا محبت کرد'),
  ],
  automaticThoughts: [
    SchemaItem('hidden_motive', 'حتماً یه قصدی پشتشه'),
    SchemaItem('no_trust', 'نباید به کسی اعتماد کنم'),
    SchemaItem('will_get_hurt', 'اگه اعتماد کنم، آسیب می‌بینم'),
    SchemaItem('will_be_used', 'می‌خواد ازم سوءاستفاده کنه'),
    SchemaItem('hiding_something_add',
        'داره چیزی رو ازم پنهان می‌کنه یا دروغ می‌گه'),
    SchemaItem('cheating_add', 'داره بهم خیانت می‌کنه'),
  ],
  emotionalSignals: [
    SchemaItem('fear', 'ترس'),
    SchemaItem('anger', 'خشم'),
    SchemaItem('pessimism', 'بدبینی'),
    SchemaItem('hyper_vigil', 'گوش‌به‌زنگی دائم'),
    SchemaItem('distrust_add', 'بی‌اعتمادی'),
    SchemaItem('vulnerability_add', 'آسیب‌پذیری'),
  ],
  behavioralPatterns: [
    SchemaItem('interrogation', 'سؤال‌پیچش می‌کنم'),
    SchemaItem('testing', 'پنهانی امتحانش می‌کنم ببینم راست می‌گه یا نه'),
    SchemaItem('controlling', 'رفت‌وآمد و کارهاش رو کنترل می‌کنم'),
    SchemaItem('hiding', 'چیزی از خودم بروز نمی‌دم'),
    SchemaItem('distance', 'ازش فاصله می‌گیرم'),
    SchemaItem('check_phone_add', 'گوشی‌ش رو چک می‌کنم'),
    SchemaItem('search_online_add', 'دنبال ردی ازش توی اینترنت می‌گردم'),
    SchemaItem('confront_accuse_add', 'رودررو متهمش می‌کنم'),
  ],
  avoidancePatterns: ['اعتماد نکردن', 'صمیمی نشدن'],
  overcompensationPatterns: [
    'کنترل دیگران',
    'حمله قبل از آسیب دیدن',
    'مشکوک بودن دائمی',
  ],
  consequences: ['کاهش صمیمیت', 'تنهایی', 'تفسیر تهدیدآمیز رفتارهای خنثی'],
  pauseQuestions: [
    'چه شواهدی برای خطر دارم؟',
    'آیا این فرد واقعاً همین رفتار را انجام داده؟',
    'آیا تجربه گذشته را روی موقعیت فعلی قرار داده‌ام؟',
  ],
  healthyResponse:
      'اعتماد تدریجی بر اساس رفتار واقعی، نه اعتماد کور یا بی‌اعتمادی مطلق.',
  replacementResponses: [
    ReplacementResponse(
        'interrogation', 'به جای بازجویی، یک سؤال مستقیم و آرام می‌پرسم.'),
    ReplacementResponse(
        'testing', 'به جای آزمودن، انتظار واقعی‌ام را واضح می‌گویم.'),
    ReplacementResponse('controlling', 'یک بار رها می‌کنم و فقط مشاهده می‌کنم.'),
    ReplacementResponse('hiding', 'یک چیز کوچک واقعی از خودم نشان می‌دهم.'),
    ReplacementResponse(
        'distance', 'قبل از فاصله گرفتن، یک گفت‌وگوی مستقیم امتحان می‌کنم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'evidence_check',
      title: 'بررسی شواهد',
      type: 'three_column',
      columns: [
        SchemaExerciseColumn('evidence_for', 'شواهد به نفع بدگمانی'),
        SchemaExerciseColumn('evidence_against', 'شواهد مخالف'),
        SchemaExerciseColumn('neutral', 'توضیح بی‌طرفانه'),
      ],
    ),
    SchemaExercise(
      id: 'gradual_trust',
      title: 'اعتماد تدریجی',
      type: 'list',
      prompt: 'سه رفتار قابل اعتماد که این فرد در گذشته نشان داده را بنویس.',
    ),
  ],
  realLifeMissions: [
    RealLifeMission(
        'm1', 'در یک موقعیت کم‌خطر، بدون کنترل کردن طرف مقابل عمل کن.'),
    RealLifeMission(
        'm2', 'یک برداشت مشکوک را قبل از واکنش بررسی کن.'),
  ],
  progressMetrics: [
    ProgressMetric('p1', 'کاهش کنترل'),
    ProgressMetric('p2', 'افزایش ارزیابی واقع‌بینانه'),
    ProgressMetric('p3', 'افزایش اعتماد تدریجی'),
  ],
  rules: [
    SchemaRule(
      const SchemaRuleWhen(behavior: 'interrogation'),
      'showExercise:evidence_check',
    ),
    SchemaRule(
      const SchemaRuleWhen(behavior: 'testing'),
      'showExercise:evidence_check',
    ),
    SchemaRule(
      const SchemaRuleWhen(behavior: 'controlling'),
      'showExercise:gradual_trust',
    ),
    SchemaRule(
      const SchemaRuleWhen(trigger: 'ambiguous_behavior'),
      'showExercise:evidence_check',
    ),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۳. محرومیت هیجانی
// ═══════════════════════════════════════════════════════════
const _emotionalDeprivation = Schema(
  id: 'emotional_deprivation',
  nameFa: 'محرومیت هیجانی',
  nameEn: 'Emotional Deprivation',
  domain: 'disconnection_rejection',
  color: '#9b59b6',
  shortDescription:
      'انتظار اینکه نیازهای عاطفی مهم مانند توجه، همدلی، حمایت یا درک شدن به اندازه کافی دریافت نشوند.',
  coreNeed: 'دیده شدن، درک شدن و حمایت عاطفی',
  triggers: [
    SchemaItem('ignored', 'حالم بد بود و کسی نپرسید چی شده'),
    SchemaItem('talked_ignored_add', 'حرف زدم ولی کسی واقعاً گوش نداد'),
    SchemaItem(
        'no_empathy', 'درددلم رو با سردی یا نصیحت جواب دادن'),
    SchemaItem('no_talk', 'کنار هم بودیم ولی از احساسمون حرفی نزدیم'),
    SchemaItem('no_hug_add', 'مدتیه کسی بغلم نکرده'),
    SchemaItem('alone_weekend_add', 'آخر هفته کسی سراغم رو نگرفت'),
    SchemaItem(
        'asked_others_add', 'دیدم از بقیه احوال‌پرسی شد و از من نه'),
    SchemaItem('busy_all_add', 'همه سرشون شلوغ بود و جایی برای من نبود'),
  ],
  automaticThoughts: [
    SchemaItem('not_understood', 'کسی منو نمی‌فهمه'),
    SchemaItem('needs_ignored', 'برای هیچ‌کس مهم نیستم'),
    SchemaItem('expect_nothing', 'نباید انتظار چیزی داشته باشم'),
    SchemaItem('always_alone_add', 'همیشه تنهام'),
    SchemaItem('waste_add', 'نباید وقت کسی رو بگیرم'),
    SchemaItem('why_try_add', 'چرا اصلاً بگم؟ فایده‌ای نداره'),
  ],
  emotionalSignals: [
    SchemaItem('loneliness', 'تنهایی'),
    SchemaItem('sadness', 'غم'),
    SchemaItem('emptiness', 'خلأ'),
    SchemaItem('hopeless', 'ناامیدی'),
    SchemaItem('longing_add', 'دلتنگی'),
  ],
  behavioralPatterns: [
    SchemaItem('silent_needs', 'نیازهام رو نمی‌گم'),
    SchemaItem('mind_reading', 'منتظرم خودشون بفهمن'),
    SchemaItem('unavailable_pick',
        'سراغ آدم‌هایی می‌رم که از نظر عاطفی در دسترس نیستن'),
    SchemaItem('withdrawal_add', 'کنار می‌کشم و خودم رو جدا می‌کنم'),
    SchemaItem('passive_sad_add', 'توی خودم غصه می‌خورم'),
  ],
  avoidancePatterns: ['درخواست نکردن حمایت'],
  overcompensationPatterns: ['نیاز شدید به توجه', 'گلایه مداوم'],
  consequences: ['احساس تنهایی', 'روابط یک‌طرفه'],
  pauseQuestions: [
    'نیاز من دقیقاً چیست؟',
    'آیا آن را واضح بیان کرده‌ام؟',
    'آیا دارم انتظار دارم دیگری ذهنم را بخواند؟',
  ],
  healthyResponse: 'شناخت نیاز و بیان مستقیم و محترمانه آن.',
  replacementResponses: [
    ReplacementResponse(
        'silent_needs', 'به جای سکوت، یک درخواست مشخص و کوچک می‌کنم.'),
    ReplacementResponse(
        'mind_reading', 'نیازم را واضح می‌گویم، نه با اشاره.'),
    ReplacementResponse(
        'unavailable_pick',
        'به رابطه‌ای که در آن پاسخ می‌گیرم، وقت بیشتری می‌دهم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'need_naming',
      title: 'نام‌گذاری نیاز',
      type: 'single_choice',
      question: 'الان دقیقاً چه نیازی داری؟',
      options: ['دیده شدن', 'درک شدن', 'حمایت', 'همدلی', 'نزدیکی'],
    ),
    SchemaExercise(
      id: 'direct_request',
      title: 'درخواست مستقیم',
      type: 'single_input',
      question:
          'یک درخواست مستقیم و کوچک بنویس که می‌توانی همین امروز مطرح کنی.',
    ),
  ],
  realLifeMissions: [
    RealLifeMission('m1', 'یک نیاز کوچک را واضح بیان کن.'),
    RealLifeMission('m2', 'به جای سکوت، درخواست مشخصی مطرح کن.'),
  ],
  progressMetrics: [
    ProgressMetric('p1', 'توانایی بیان نیاز'),
    ProgressMetric('p2', 'کاهش انتظار ذهن‌خوانی'),
    ProgressMetric('p3', 'انتخاب روابط متقابل'),
  ],
  rules: [
    SchemaRule(
      const SchemaRuleWhen(behavior: 'silent_needs'),
      'showExercise:need_naming',
    ),
    SchemaRule(
      const SchemaRuleWhen(behavior: 'mind_reading'),
      'showExercise:direct_request',
    ),
    SchemaRule(
      const SchemaRuleWhen(trigger: 'ignored'),
      'showExercise:need_naming',
    ),
  ],
);

// ═══════════════════════════════════════════════════════════
// لیست کامل — بقیه در ادامه
// ═══════════════════════════════════════════════════════════
const List<Schema> schemas = [
  _abandonment,
  _mistrustAbuse,
  _emotionalDeprivation,
  // TODO: defectiveness_shame, social_isolation,
  //       dependence_incompetence, vulnerability, enmeshment,
  //       failure, entitlement, insufficient_self_control,
  //       subjugation, self_sacrifice, approval_seeking,
  //       negativity, emotional_inhibition,
  //       unrelenting_standards, punitiveness
];

// ═══════════════════════════════════════════════════════════
// ایندکس + دسترسی سریع
// ═══════════════════════════════════════════════════════════
final Map<String, Schema> _schemasById = {
  for (final s in schemas) s.id: s,
};

Schema? findSchemaById(String? id) => id == null ? null : _schemasById[id];

// ═══════════════════════════════════════════════════════════
// دسته‌بندی دامنه‌ها
// ═══════════════════════════════════════════════════════════
class Domain {
  final String id;
  final String name;
  final List<String> schemaIds;
  const Domain({
    required this.id,
    required this.name,
    required this.schemaIds,
  });
}

const List<Domain> domains = [
  Domain(
    id: 'disconnection_rejection',
    name: 'قطع ارتباط و طردشدگی',
    schemaIds: [
      'abandonment',
      'mistrust_abuse',
      'emotional_deprivation',
      'defectiveness_shame',
      'social_isolation',
    ],
  ),
  Domain(
    id: 'impaired_autonomy',
    name: 'خودمختاری مختل',
    schemaIds: [
      'dependence_incompetence',
      'vulnerability',
      'enmeshment',
      'failure',
    ],
  ),
  Domain(
    id: 'impaired_limits',
    name: 'محدودیت‌های مختل',
    schemaIds: ['entitlement', 'insufficient_self_control'],
  ),
  Domain(
    id: 'other_directedness',
    name: 'دیگرجهت‌یابی',
    schemaIds: ['subjugation', 'self_sacrifice', 'approval_seeking'],
  ),
  Domain(
    id: 'overvigilance_inhibition',
    name: 'گوش‌به‌زنگی افراطی و بازداری',
    schemaIds: [
      'negativity',
      'emotional_inhibition',
      'unrelenting_standards',
      'punitiveness',
    ],
  ),
];

// ═══════════════════════════════════════════════════════════
// اولویت‌بندی — معادل PRIORITY_LEVELS.js
// ═══════════════════════════════════════════════════════════
class PriorityLevel {
  final int min;
  final String level;
  final String label;
  final String emoji;
  final String color;
  const PriorityLevel({
    required this.min,
    required this.level,
    required this.label,
    required this.emoji,
    required this.color,
  });
}

const List<PriorityLevel> priorityLevels = [
  PriorityLevel(
      min: 70, level: 'high', label: 'بالا', emoji: '🔴', color: '#e74c3c'),
  PriorityLevel(
      min: 40, level: 'medium', label: 'متوسط', emoji: '🟠', color: '#f39c12'),
  PriorityLevel(
      min: 0, level: 'low', label: 'پایین', emoji: '🟢', color: '#27ae60'),
];

PriorityLevel getPriority(int percentage) {
  for (final p in priorityLevels) {
    if (percentage >= p.min) return p;
  }
  return priorityLevels.last;
}

// ═══════════════════════════════════════════════════════════
// موتور قوانین — معادل resolveExercise در SCHEMAS.js
// ═══════════════════════════════════════════════════════════
String? resolveExercise(String schemaId, String? triggerId, String? behaviorId) {
  final schema = findSchemaById(schemaId);
  if (schema == null) return null;

  for (final rule in schema.rules) {
    final w = rule.when;
    final matches = (w.trigger == null || w.trigger == triggerId) &&
        (w.behavior == null || w.behavior == behaviorId);
    if (matches) return rule.then;
  }
  if (schema.exercises.isNotEmpty) {
    return 'showExercise:${schema.exercises.first.id}';
  }
  return null;
}

String? getReplacementResponse(String schemaId, String? behaviorId) {
  final schema = findSchemaById(schemaId);
  if (schema == null) return null;
  for (final r in schema.replacementResponses) {
    if (r.behaviorId == behaviorId) return r.text;
  }
  return null;
}
