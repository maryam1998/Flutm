// lib/data/shenakht/schemas.dart
// ۱۸ طرحواره — نسخه نهایی
// معادل SCHEMAS.js + SCHEMAS_ADDITIONS.js + TRIGGERS_EXTRA.js + CURATED_OPTIONS.js

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
        'repeated_messaging', 'قبل از ارسال پیام دوم، ۳۰ دقیقه صبر می‌کنم.'),
    ReplacementResponse(
        'checking_ab', 'قبل از چک کردن، از خودم می‌پرسم دنبال چه شواهدی هستم.'),
    ReplacementResponse(
        'clinging', 'فعلاً پیام دیگری نمی‌فرستم و به کار خودم برمی‌گردم.'),
    ReplacementResponse(
        'testing_ab', 'به جای آزمودن، نیازم را مستقیم و آرام بیان می‌کنم.'),
    ReplacementResponse(
        'preemptive_exit', 'قبل از قطع رابطه، سه شاهد واقعی می‌نویسم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'reality_vs_assumption',
      title: 'واقعیت یا برداشت؟',
      type: 'two_column',
      columns: [
        ['fact', 'چیزی که می‌دانم'],
        ['assumption', 'چیزی که حدس می‌زنم'],
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
    ['m1', 'قبل از ارسال پیام دوم ۳۰ دقیقه صبر کن.'],
    ['m2', 'یک موقعیت مبهم را بدون نتیجه‌گیری ثبت کن.'],
    ['m3', 'به جای درخواست اطمینان، یک بار احساس خودت را بیان کن.'],
  ],
  progressMetrics: [
    ['p1', 'کاهش واکنش فوری'],
    ['p2', 'افزایش تحمل عدم قطعیت'],
    ['p3', 'افزایش استفاده از پاسخ جایگزین'],
  ],
  rules: [
    SchemaRule(
        trigger: 'late_reply',
        behavior: 'checking_ab',
        then: 'showExercise:reality_vs_assumption'),
    SchemaRule(
        trigger: 'distance_ab',
        behavior: 'clinging',
        then: 'showExercise:pause_30min'),
    SchemaRule(
        trigger: 'unclear_future',
        behavior: 'testing_ab',
        then: 'showExercise:need_expression'),
    SchemaRule(
        behavior: 'preemptive_exit',
        then: 'showExercise:reality_vs_assumption'),
    SchemaRule(
        trigger: 'late_reply',
        behavior: 'repeated_messaging',
        then: 'showExercise:pause_30min'),
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
    SchemaItem('secret_call_add', 'مخفیانه تلفنی حرف زد یا با کسی پچ‌پچ کرد'),
    SchemaItem('unexpected_gift_add', 'بی‌دلیل بهم هدیه یا محبت کرد'),
  ],
  automaticThoughts: [
    SchemaItem('hidden_motive', 'حتماً یه قصدی پشتشه'),
    SchemaItem('no_trust', 'نباید به کسی اعتماد کنم'),
    SchemaItem('will_get_hurt', 'اگه اعتماد کنم، آسیب می‌بینم'),
    SchemaItem('will_be_used', 'می‌خواد ازم سوءاستفاده کنه'),
    SchemaItem('hiding_something_add', 'داره چیزی رو ازم پنهان می‌کنه یا دروغ می‌گه'),
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
    ReplacementResponse('interrogation',
        'به جای بازجویی، یک سؤال مستقیم و آرام می‌پرسم.'),
    ReplacementResponse(
        'testing', 'به جای آزمودن، انتظار واقعی‌ام را واضح می‌گویم.'),
    ReplacementResponse('controlling', 'یک بار رها می‌کنم و فقط مشاهده می‌کنم.'),
    ReplacementResponse('hiding', 'یک چیز کوچک واقعی از خودم نشان می‌دهم.'),
    ReplacementResponse('distance',
        'قبل از فاصله گرفتن، یک گفت‌وگوی مستقیم امتحان می‌کنم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'evidence_check',
      title: 'بررسی شواهد',
      type: 'three_column',
      columns: [
        ['evidence_for', 'شواهد به نفع بدگمانی'],
        ['evidence_against', 'شواهد مخالف'],
        ['neutral', 'توضیح بی‌طرفانه'],
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
    ['m1', 'در یک موقعیت کم‌خطر، بدون کنترل کردن طرف مقابل عمل کن.'],
    ['m2', 'یک برداشت مشکوک را قبل از واکنش بررسی کن.'],
  ],
  progressMetrics: [
    ['p1', 'کاهش کنترل'],
    ['p2', 'افزایش ارزیابی واقع‌بینانه'],
    ['p3', 'افزایش اعتماد تدریجی'],
  ],
  rules: [
    SchemaRule(behavior: 'interrogation', then: 'showExercise:evidence_check'),
    SchemaRule(behavior: 'testing', then: 'showExercise:evidence_check'),
    SchemaRule(behavior: 'controlling', then: 'showExercise:gradual_trust'),
    SchemaRule(
        trigger: 'ambiguous_behavior', then: 'showExercise:evidence_check'),
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
    SchemaItem('no_empathy', 'درددلم رو با سردی یا نصیحت جواب دادن'),
    SchemaItem('no_talk', 'کنار هم بودیم ولی از احساسمون حرفی نزدیم'),
    SchemaItem('no_hug_add', 'مدتیه کسی بغلم نکرده'),
    SchemaItem('alone_weekend_add', 'آخر هفته کسی سراغم رو نگرفت'),
    SchemaItem('asked_others_add', 'دیدم از بقیه احوال‌پرسی شد و از من نه'),
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
    ReplacementResponse('mind_reading', 'نیازم را واضح می‌گویم، نه با اشاره.'),
    ReplacementResponse('unavailable_pick',
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
    ['m1', 'یک نیاز کوچک را واضح بیان کن.'],
    ['m2', 'به جای سکوت، درخواست مشخصی مطرح کن.'],
  ],
  progressMetrics: [
    ['p1', 'توانایی بیان نیاز'],
    ['p2', 'کاهش انتظار ذهن‌خوانی'],
    ['p3', 'انتخاب روابط متقابل'],
  ],
  rules: [
    SchemaRule(behavior: 'silent_needs', then: 'showExercise:need_naming'),
    SchemaRule(behavior: 'mind_reading', then: 'showExercise:direct_request'),
    SchemaRule(trigger: 'ignored', then: 'showExercise:need_naming'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۴. نقص / شرم
// ═══════════════════════════════════════════════════════════
const _defectivenessShame = Schema(
  id: 'defectiveness_shame',
  nameFa: 'نقص / شرم',
  nameEn: 'Defectiveness / Shame',
  domain: 'disconnection_rejection',
  color: '#8e44ad',
  shortDescription:
      'احساس عمیق اینکه در خود فرد چیزی اساساً اشتباه، ناقص یا غیرقابل‌قبول وجود دارد.',
  coreNeed: 'پذیرش و ارزشمندی بدون نیاز به کامل بودن',
  triggers: [
    SchemaItem('mistake', 'جلوی دیگران اشتباه کردم'),
    SchemaItem('criticism', 'کسی از من انتقاد کرد یا ایراد گرفت'),
    SchemaItem('compared_ds', 'خودم رو با یکی مقایسه کردم یا مقایسه‌م کردن'),
    SchemaItem('rejection', 'ردم کردن'),
    SchemaItem('showing_weak', 'مجبور شدم ضعفم رو نشون بدم'),
    SchemaItem('mirror_add', 'خودم رو توی آینه دیدم'),
    SchemaItem('old_photo_add', 'خودم رو توی یه عکس دیدم'),
    SchemaItem('praised_add', 'کسی ازم تعریف کرد و باورم نشد'),
  ],
  automaticThoughts: [
    SchemaItem('i_am_broken', 'یه چیزی توی من اشتباهه'),
    SchemaItem('if_known', 'اگه واقعاً منو بشناسن، قبولم نمی‌کنن'),
    SchemaItem('not_good_enough', 'به اندازهٔ کافی خوب نیستم'),
    SchemaItem('not_deserve_add', 'لیاقت این چیزها رو ندارم'),
    SchemaItem('fake_person_add', 'دارم نقش بازی می‌کنم'),
  ],
  emotionalSignals: [
    SchemaItem('shame', 'شرم'),
    SchemaItem('humiliation_add', 'تحقیر شدن'),
    SchemaItem('anxiety', 'اضطراب'),
    SchemaItem('sadness', 'غم'),
    SchemaItem('self_hate_add', 'تنفر از خودم'),
  ],
  behavioralPatterns: [
    SchemaItem('hide_weakness', 'ضعف‌هام رو پنهان می‌کنم'),
    SchemaItem('over_apology', 'زیاد عذرخواهی می‌کنم'),
    SchemaItem('perfectionism_ds',
        'برای جبران، همه‌چیز رو بی‌نقص و زیاد انجام می‌دم'),
    SchemaItem('comparison', 'خودم رو با بقیه مقایسه می‌کنم'),
    SchemaItem('reject_praise_add', 'تعریف رو رد می‌کنم'),
    SchemaItem('avoid_mirror_add', 'از آینه و عکس فرار می‌کنم'),
    SchemaItem('self_criticism_add', 'خودم رو سرزنش می‌کنم'),
  ],
  avoidancePatterns: ['دیده نشدن', 'نزدیک نشدن به دیگران'],
  overcompensationPatterns: ['اثبات برتری', 'کامل بودن'],
  consequences: ['خودانتقادی', 'اجتناب', 'فرسودگی'],
  pauseQuestions: [
    'آیا یک اشتباه را با ارزش کل خودم یکی کرده‌ام؟',
    'اگر دوستم این اشتباه را می‌کرد چه می‌گفتم؟',
    'چه چیزی درباره من واقعاً قابل مشاهده است؟',
  ],
  healthyResponse: 'تفکیک رفتار یا اشتباه از ارزش کلی خود.',
  replacementResponses: [
    ReplacementResponse(
        'hide_weakness', 'یک نقص کوچک را بدون پنهان کردن تحمل می‌کنم.'),
    ReplacementResponse('over_apology',
        'قبل از عذرخواهی، از خودم می‌پرسم آیا واقعاً لازم است.'),
    ReplacementResponse(
        'perfectionism_ds', 'امروز یک کار را در سطح «کافی» رها می‌کنم.'),
    ReplacementResponse('comparison',
        'به جای مقایسه، یک چیز قابل مشاهده در خودم می‌نویسم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'inner_voice',
      title: 'صدای منتقد درونی',
      type: 'reflection',
      prompts: [
        'منتقد درونی‌ام دقیقاً چه می‌گوید؟',
        'این صدا بیشتر شبیه چه کسی است؟',
        'به یک دوست در این وضعیت چه می‌گفتم؟',
      ],
    ),
    SchemaExercise(
      id: 'real_strengths',
      title: 'توانمندی‌های واقعی',
      type: 'list',
      prompt: 'سه چیز واقعی که درباره خودت می‌دانی و مثبت است را بنویس.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'یک نقص کوچک را بدون پنهان کردن تحمل کن.'],
    ['m2', 'بعد از یک اشتباه، به جای حمله به خود فقط رفتار را اصلاح کن.'],
  ],
  progressMetrics: [
    ['p1', 'کاهش خودانتقادی'],
    ['p2', 'تحمل دیده شدن'],
    ['p3', 'کاهش شرم'],
  ],
  rules: [
    SchemaRule(behavior: 'hide_weakness', then: 'showExercise:inner_voice'),
    SchemaRule(behavior: 'comparison', then: 'showExercise:real_strengths'),
    SchemaRule(trigger: 'mistake', then: 'showExercise:inner_voice'),
    SchemaRule(trigger: 'criticism', then: 'showExercise:inner_voice'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۵. انزوای اجتماعی
// ═══════════════════════════════════════════════════════════
const _socialIsolation = Schema(
  id: 'social_isolation',
  nameFa: 'انزوای اجتماعی / بیگانگی',
  nameEn: 'Social Isolation / Alienation',
  domain: 'disconnection_rejection',
  color: '#3498db',
  shortDescription:
      'احساس متفاوت بودن، تعلق نداشتن یا بیرون بودن از گروه.',
  coreNeed: 'تعلق و ارتباط',
  triggers: [
    SchemaItem('social_gather', 'به یه مهمونی یا دورهمی دعوت شدم'),
    SchemaItem('peer_ease_si', 'دیدم بقیه چقدر راحت با هم گرم می‌گیرن'),
    SchemaItem('feeling_diff', 'حس کردم با بقیه فرق دارم'),
    SchemaItem('group_rejection', 'از یه گروه کنار گذاشته شدم'),
    SchemaItem('group_photo_si', 'عکس جمعی دیدم که توش نبودم'),
    SchemaItem('couple_invite_si', 'به جمعی دعوت شدم که همه زوج بودن'),
    SchemaItem('old_friends_meet_si',
        'دوستای قدیمی دور هم جمع شدن و من نبودم'),
    SchemaItem('new_group_si', 'وارد یه جمع جدید شدم'),
    SchemaItem('weekend_silent_si', 'آخر هفته بدون هیچ تماسی گذشت'),
  ],
  automaticThoughts: [
    SchemaItem('not_like_others', 'من مثل بقیه نیستم'),
    SchemaItem('no_belonging', 'اینجا به من تعلق نداره؛ من غریبه‌ام'),
    SchemaItem('nobody_gets_me', 'هیچ‌کس منو نمی‌فهمه'),
    SchemaItem('left_out_si', 'منو کنار می‌ذارن'),
  ],
  emotionalSignals: [
    SchemaItem('loneliness', 'تنهایی'),
    SchemaItem('alienation_si', 'بیگانگی'),
    SchemaItem('anxiety', 'اضطراب'),
    SchemaItem('embarrass', 'خجالت و معذب بودن'),
  ],
  behavioralPatterns: [
    SchemaItem('withdrawal', 'وسط جمع خودم رو کنار می‌کشم'),
    SchemaItem('silence_si', 'توی جمع ساکت می‌مونم'),
    SchemaItem('skip_gather', 'دعوت‌ها رو رد می‌کنم و از جمع دوری می‌کنم'),
    SchemaItem('leave_early_si', 'زودتر از بقیه می‌رم'),
    SchemaItem('fake_smile_si', 'الکی لبخند می‌زنم و وانمود می‌کنم راحتم'),
    SchemaItem('scroll_phone_si', 'خودم رو با گوشی مشغول می‌کنم'),
  ],
  avoidancePatterns: ['اجتناب از موقعیت اجتماعی'],
  overcompensationPatterns: ['تلاش افراطی برای پذیرفته شدن'],
  consequences: ['تنهایی بیشتر', 'تقویت احساس متفاوت بودن'],
  pauseQuestions: [
    'واقعاً چه چیزی من را متفاوت می‌کند؟',
    'آیا این تفاوت به معنی تعلق نداشتن است؟',
  ],
  healthyResponse:
      'پیدا کردن ارتباط‌های واقعی به جای تلاش برای شبیه شدن به همه.',
  replacementResponses: [
    ReplacementResponse('withdrawal', 'امروز فقط ۱۰ دقیقه در جمع می‌مانم.'),
    ReplacementResponse('silence_si', 'یک سؤال کوچک از یک نفر می‌پرسم.'),
    ReplacementResponse(
        'skip_gather', 'به یک موقعیت اجتماعی کوتاه می‌روم، بدون انتظار.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'belonging_map',
      title: 'نقشه تعلق',
      type: 'list',
      prompt: 'سه نفر یا سه فضا که در آن‌ها احساس امنیت می‌کنی را بنویس.',
    ),
    SchemaExercise(
      id: 'common_ground',
      title: 'نقطه مشترک',
      type: 'single_input',
      question: 'یک نقطه مشترک با کسی که می‌شناسی بنویس.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'یک تعامل کوتاه را آغاز کن.'],
    ['m2', 'در یک جمع، یک نفر را پیدا کن که نقطه مشترکی با تو دارد.'],
  ],
  progressMetrics: [
    ['p1', 'تعداد تعامل‌های داوطلبانه'],
    ['p2', 'کاهش اجتناب'],
  ],
  rules: [
    SchemaRule(behavior: 'withdrawal', then: 'showExercise:belonging_map'),
    SchemaRule(behavior: 'skip_gather', then: 'showExercise:common_ground'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۶. وابستگی / بی‌کفایتی
// ═══════════════════════════════════════════════════════════
const _dependenceIncompetence = Schema(
  id: 'dependence_incompetence',
  nameFa: 'وابستگی / بی‌کفایتی',
  nameEn: 'Dependence / Incompetence',
  domain: 'impaired_autonomy',
  color: '#16a085',
  shortDescription:
      'باور اینکه فرد به تنهایی از عهده تصمیم‌ها یا مسئولیت‌های مهم برنمی‌آید.',
  coreNeed: 'استقلال و اعتماد به توانایی خود',
  triggers: [
    SchemaItem('decision', 'باید تصمیم مهمی می‌گرفتم'),
    SchemaItem('new_task', 'کار جدیدی بهم سپرده شد'),
    SchemaItem('responsibility', 'مسئولیت یه کار افتاد رو دوشم'),
    SchemaItem('possible_mistake', 'ترسیدم اشتباه کنم'),
    SchemaItem('left_alone_dp', 'تنها موندم'),
    SchemaItem('no_advisor_dp', 'کسی نبود که مشورت یا کمک بگیرم'),
    SchemaItem('cook_alone_dp', 'باید خودم از پس یه کار روزمره برمی‌اومدم'),
    SchemaItem('technical_problem_dp', 'مشکل فنی پیش اومد'),
  ],
  automaticThoughts: [
    SchemaItem('cant_handle', 'از پسش برنمیام'),
    SchemaItem('need_help', 'بدون کمک نمی‌تونم؛ یکی باید کمکم کنه'),
    SchemaItem('will_ruin', 'خرابش می‌کنم'),
    SchemaItem('not_capable_dp', 'من اصلاً توانمند نیستم'),
  ],
  emotionalSignals: [
    SchemaItem('anxiety', 'اضطراب'),
    SchemaItem('fear', 'ترس'),
    SchemaItem('doubt', 'تردید'),
    SchemaItem('helplessness_dp', 'درماندگی'),
  ],
  behavioralPatterns: [
    SchemaItem('early_help', 'قبل از اینکه خودم تلاش کنم، سریع کمک می‌خوام'),
    SchemaItem('delegate', 'تصمیم رو می‌سپرم به یکی دیگه'),
    SchemaItem('reassurance_dp', 'از چند نفر می‌پرسم تا مطمئن بشم'),
    SchemaItem('wait_help_dp', 'منتظر می‌مونم یکی کمک کنه'),
    SchemaItem('postpone_dp', 'کار رو عقب می‌ندازم'),
  ],
  avoidancePatterns: ['شروع نکردن'],
  overcompensationPatterns: ['اثبات استقلال افراطی'],
  consequences: ['کاهش اعتمادبه‌نفس', 'وابستگی بیشتر'],
  pauseQuestions: [
    'کدام بخش این کار را خودم می‌توانم انجام دهم؟',
    'آیا نیاز به کمک دارم یا فقط از اشتباه می‌ترسم؟',
  ],
  healthyResponse:
      'انجام مستقل کارهای کوچک و درخواست کمک فقط در بخش لازم.',
  replacementResponses: [
    ReplacementResponse(
        'early_help', 'اول خودم ۱۰ دقیقه تلاش می‌کنم، بعد کمک می‌خواهم.'),
    ReplacementResponse('delegate', 'یک تصمیم کوچک را خودم می‌گیرم.'),
    ReplacementResponse(
        'reassurance_dp', 'به جای پرسیدن، یک بار خودم اقدام می‌کنم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'small_step',
      title: 'قدم کوچک بعدی',
      type: 'single_input',
      question: 'کوچک‌ترین قدم عملی که امروز می‌توانم بردارم چیست؟',
    ),
    SchemaExercise(
      id: 'small_wins',
      title: 'موفقیت‌های مستقل',
      type: 'list',
      prompt: 'سه کار که قبلاً خودت از عهده‌شان برآمدی را بنویس.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'یک تصمیم کوچک را بدون گرفتن تأیید دیگران بگیر.'],
    ['m2', 'یک کار که معمولاً واگذار می‌کنی، خودت انجام بده.'],
  ],
  progressMetrics: [
    ['p1', 'تعداد تصمیم‌های مستقل'],
    ['p2', 'کاهش اطمینان‌گیری'],
  ],
  rules: [
    SchemaRule(behavior: 'delegate', then: 'showExercise:small_step'),
    SchemaRule(behavior: 'early_help', then: 'showExercise:small_wins'),
    SchemaRule(behavior: 'reassurance_dp', then: 'showExercise:small_step'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۷. آسیب‌پذیری
// ═══════════════════════════════════════════════════════════
const _vulnerability = Schema(
  id: 'vulnerability',
  nameFa: 'آسیب‌پذیری نسبت به خطر',
  nameEn: 'Vulnerability to Harm or Illness',
  domain: 'impaired_autonomy',
  color: '#e67e22',
  shortDescription:
      'انتظار اینکه هر لحظه ممکن است فاجعه، بیماری، حادثه یا اتفاق جدی رخ دهد.',
  coreNeed: 'امنیت همراه با تحمل عدم قطعیت',
  triggers: [
    SchemaItem('bad_news', 'خبر بدی شنیدم؛ مثل بیماری یا حادثه'),
    SchemaItem('body_signals', 'یه درد یا علامت جسمی حس کردم'),
    SchemaItem('travel', 'قرار بود سفر برم'),
    SchemaItem('unknown', 'وارد یه موقعیت ناشناخته شدم'),
    SchemaItem('possible_danger', 'حس کردم ممکنه خطری در کار باشه'),
    SchemaItem('alone_at_night_vu', 'شب بود و تنها بودم'),
    SchemaItem('spouse_late_vu', 'یکی از عزیزانم دیر به خونه رسید'),
    SchemaItem('money_worry_vu', 'نگرانی مالی پیش اومد'),
    SchemaItem('unexpected_call_vu', 'تماس غیرمنتظره‌ای گرفتم'),
  ],
  automaticThoughts: [
    SchemaItem('disaster', 'نکنه اتفاق بدی بیفته'),
    SchemaItem('dangerous', 'ممکنه خطرناک باشه'),
    SchemaItem('must_check', 'باید مطمئن بشم'),
    SchemaItem('cant_cope_vu', 'اگه اتفاق بیفته، نمی‌تونم تحملش کنم'),
    SchemaItem('unsafe_vu', 'من در امان نیستم'),
  ],
  emotionalSignals: [
    SchemaItem('fear', 'ترس'),
    SchemaItem('anxiety', 'اضطراب'),
    SchemaItem('hyper', 'گوش‌به‌زنگی'),
    SchemaItem('tension_vu', 'تنش بدنی'),
  ],
  behavioralPatterns: [
    SchemaItem('checking', 'مدام چک می‌کنم که همه‌چیز امنه'),
    SchemaItem('reassurance', 'از بقیه اطمینان می‌گیرم'),
    SchemaItem('avoid', 'از موقعیت‌های نامطمئن دوری می‌کنم'),
    SchemaItem('google_search_vu',
        'توی اینترنت دنبال علائم و خبرها می‌گردم'),
    SchemaItem('control_vu', 'برای احتیاط، همه‌چیز رو تا آخر کنترل می‌کنم'),
  ],
  avoidancePatterns: ['دوری از موقعیت‌های نامطمئن'],
  overcompensationPatterns: ['کنترل افراطی'],
  consequences: ['افزایش اضطراب', 'محدود شدن زندگی'],
  pauseQuestions: [
    'احتمال واقعی خطر چقدر است؟',
    'آیا الان خطری فوری وجود دارد؟',
    'آیا دارم برای کاهش اضطراب چک می‌کنم؟',
  ],
  healthyResponse:
      'اقدام منطقی برای ایمنی، بدون تلاش برای حذف کامل عدم قطعیت.',
  replacementResponses: [
    ReplacementResponse(
        'checking', 'یک بار چک می‌کنم، بعد به کار خودم برمی‌گردم.'),
    ReplacementResponse('reassurance',
        'به جای پرسیدن، یک نگرانی را می‌نویسم و رها می‌کنم.'),
    ReplacementResponse(
        'avoid', 'امروز یک موقعیت نامطمئن کوچک را تجربه می‌کنم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'probability',
      title: 'احتمال واقعی',
      type: 'reflection',
      prompts: [
        'بدترین حالتی که ذهنم می‌سازد چیست؟',
        'واقعاً چقدر احتمال دارد؟',
        'اگر رخ دهد، چه منابعی برای مقابله دارم؟',
      ],
    ),
    SchemaExercise(
      id: 'one_check',
      title: 'قانون یک بار',
      type: 'timer',
      durationSeconds: 1800,
      description: '۳۰ دقیقه مکث قبل از چک کردن بعدی.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'یک چک کردن غیرضروری را حذف کن.'],
    ['m2', 'یک نگرانی را بدون اطمینان گرفتن برای مدتی تحمل کن.'],
  ],
  progressMetrics: [
    ['p1', 'کاهش چک کردن'],
    ['p2', 'کاهش اجتناب'],
    ['p3', 'تحمل عدم قطعیت'],
  ],
  rules: [
    SchemaRule(behavior: 'checking', then: 'showExercise:one_check'),
    SchemaRule(behavior: 'reassurance', then: 'showExercise:probability'),
    SchemaRule(behavior: 'avoid', then: 'showExercise:probability'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۸. درهم‌تنیدگی
// ═══════════════════════════════════════════════════════════
const _enmeshment = Schema(
  id: 'enmeshment',
  nameFa: 'درهم‌تنیدگی / خود تحول‌نیافته',
  nameEn: 'Enmeshment / Undeveloped Self',
  domain: 'impaired_autonomy',
  color: '#2ecc71',
  shortDescription:
      'مرزهای روانی ضعیف با افراد مهم و دشواری در تشخیص خواسته‌ها و هویت مستقل خود.',
  coreNeed: 'هویت مستقل و مرز سالم',
  triggers: [
    SchemaItem('independent_decision', 'خواستم مستقل تصمیم بگیرم'),
    SchemaItem('disagreement_en',
        'با خانواده یا نزدیکانم اختلاف نظر پیدا کردم'),
    SchemaItem(
        'their_displeasure', 'یکی از نزدیکانم از من ناراحت یا ناراضی بود'),
    SchemaItem('different_path', 'مسیری متفاوت از اونا انتخاب کردم'),
    SchemaItem('partner_mood_en', 'حال همسرم یا یکی از نزدیکانم بد بود'),
    SchemaItem('friend_need_en', 'دوستی به کمکم نیاز داشت'),
    SchemaItem('expected_same_en', 'ازم انتظار داشتن مثل اونا باشم'),
  ],
  automaticThoughts: [
    SchemaItem('they_upset', 'اگه مخالفت کنم، ناراحت می‌شن و تقصیر منه'),
    SchemaItem('must_agree', 'باید مثل اونا فکر کنم و موافق باشم'),
    SchemaItem('dont_know_self', 'نمی‌دونم خودم واقعاً چی می‌خوام'),
    SchemaItem('responsible_en', 'من مسئول حال اونام'),
    SchemaItem('no_self_en', 'من بدون اونا گم می‌شم'),
  ],
  emotionalSignals: [
    SchemaItem('guilt', 'گناه'),
    SchemaItem('anxiety', 'اضطراب'),
    SchemaItem('confusion', 'سردرگمی'),
    SchemaItem('emptiness_en', 'پوچی'),
  ],
  behavioralPatterns: [
    SchemaItem(
        'over_adapt', 'همیشه موافقت می‌کنم و خودم رو باهاشون وفق می‌دم'),
    SchemaItem('their_choice',
        'تصمیم‌های مهمم رو بر اساس خواستهٔ اونا می‌گیرم'),
    SchemaItem('ask_first_en', 'قبل از هر کاری از اونا می‌پرسم'),
    SchemaItem('abandon_self_en', 'خواسته‌های خودم رو فراموش می‌کنم'),
    SchemaItem('avoid_different_en', 'از متفاوت بودن با اونا فرار می‌کنم'),
  ],
  avoidancePatterns: ['اجتناب از استقلال'],
  overcompensationPatterns: ['قطع ناگهانی رابطه یا استقلال افراطی'],
  consequences: ['ضعف هویت شخصی', 'نارضایتی'],
  pauseQuestions: [
    'اگر هیچ‌کس ناراحت نمی‌شد، من چه می‌خواستم؟',
    'نظر خودم چیست؟',
    'آیا مخالفت کردن به معنی بی‌محبتی است؟',
  ],
  healthyResponse: 'شناخت ترجیحات شخصی همراه با حفظ ارتباط.',
  replacementResponses: [
    ReplacementResponse('over_adapt',
        'قبل از موافقت، ۵ ثانیه از خودم می‌پرسم: نظر خودم چیست؟'),
    ReplacementResponse('their_choice',
        'یک تصمیم کوچک را بر اساس ترجیح خودم می‌گیرم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'self_check',
      title: 'خودم چه می‌خواهم؟',
      type: 'single_input',
      question: 'در این لحظه، مستقل از دیگران، خودم چه می‌خواهم؟',
    ),
    SchemaExercise(
      id: 'my_preferences',
      title: 'ترجیحات شخصی',
      type: 'list',
      prompt: 'سه ترجیح شخصی که اخیراً نادیده گرفته‌ای را بنویس.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'یک انتخاب کوچک را صرفاً بر اساس ترجیح خودت انجام بده.'],
    ['m2', 'یک نظر متفاوت را محترمانه بیان کن.'],
  ],
  progressMetrics: [
    ['p1', 'وضوح ترجیحات'],
    ['p2', 'تصمیم‌های مستقل'],
    ['p3', 'تحمل اختلاف'],
  ],
  rules: [
    SchemaRule(behavior: 'over_adapt', then: 'showExercise:self_check'),
    SchemaRule(behavior: 'their_choice', then: 'showExercise:my_preferences'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۹. شکست
// ═══════════════════════════════════════════════════════════
const _failure = Schema(
  id: 'failure',
  nameFa: 'شکست',
  nameEn: 'Failure to Achieve',
  domain: 'impaired_autonomy',
  color: '#e74c3c',
  shortDescription:
      'انتظار یا باور اینکه فرد در حوزه‌های مهم زندگی نسبت به دیگران شکست‌خورده یا اساساً کم‌توان است.',
  coreNeed: 'احساس شایستگی و فرصت رشد',
  triggers: [
    SchemaItem('new_start', 'قرار شد کار جدیدی شروع کنم'),
    SchemaItem('peer_success_fa', 'دیدم یکی هم‌سن یا هم‌رشتهٔ من موفق شده'),
    SchemaItem('negative_feedback', 'بازخورد منفی گرفتم'),
    SchemaItem('past_failure', 'یاد شکستی که قبلاً داشتم افتادم'),
    SchemaItem('deadline_fa', 'مهلت کار نزدیک بود'),
    SchemaItem('exam_fa', 'باید امتحان می‌دادم'),
    SchemaItem('unfinished_task_fa', 'کارهای نیمه‌تمومم یادم اومد'),
    SchemaItem('birthday_fa', 'تولدم بود یا به گذشته و پیشرفتم فکر کردم'),
  ],
  automaticThoughts: [
    SchemaItem('cant', 'از پسش برنمیام'),
    SchemaItem('will_fail', 'آخرش شکست می‌خورم'),
    SchemaItem('others_better', 'بقیه از من بهترن و جلوترن'),
    SchemaItem('waste_fa', 'زندگیم داره هدر می‌ره'),
  ],
  emotionalSignals: [
    SchemaItem('shame', 'شرم'),
    SchemaItem('hopeless', 'ناامیدی'),
    SchemaItem('fear_fa', 'ترس از شکست'),
    SchemaItem('envy_fa', 'حسادت'),
  ],
  behavioralPatterns: [
    SchemaItem('procrastinate', 'کار رو مدام عقب می‌ندازم'),
    SchemaItem('not_start',
        'از ترس اینکه خوب از آب درنیاد، اصلاً شروعش نمی‌کنم'),
    SchemaItem('comparison', 'خودم رو با بقیه مقایسه می‌کنم'),
    SchemaItem('give_up_fa', 'زود ولش می‌کنم'),
    SchemaItem('self_doubt_fa', 'به توانایی خودم شک می‌کنم'),
    SchemaItem('overcompensate_fa',
        'برای جبران، بیش از حد خودم رو تحت فشار می‌ذارم'),
  ],
  avoidancePatterns: ['فرار از چالش'],
  overcompensationPatterns: ['کار بیش از حد برای اثبات خود'],
  consequences: ['از دست رفتن فرصت', 'تقویت باور شکست'],
  pauseQuestions: [
    'چه شواهدی نشان می‌دهد نمی‌توانم؟',
    'کدام مهارت را هنوز یاد نگرفته‌ام؟',
    'قدم بعدی قابل انجام چیست؟',
  ],
  healthyResponse: 'تعریف موفقیت به شکل رشد و اقدام، نه نتیجه کامل.',
  replacementResponses: [
    ReplacementResponse('procrastinate',
        'فقط ۱۰ دقیقه شروع می‌کنم، بدون انتظار کیفیت.'),
    ReplacementResponse(
        'not_start', 'قدم اول را آن‌قدر کوچک می‌کنم که قابل شروع باشد.'),
    ReplacementResponse('comparison',
        'به جای مقایسه، یک پیشرفت کوچک خودم را می‌نویسم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'small_wins',
      title: 'پیروزی‌های کوچک',
      type: 'list',
      prompt: 'سه چیز که در ۳۰ روز گذشته انجام دادی و واقعی بودند را بنویس.',
    ),
    SchemaExercise(
      id: 'ten_min_start',
      title: 'شروع ۱۰ دقیقه‌ای',
      type: 'timer',
      durationSeconds: 600,
      description: 'فقط ۱۰ دقیقه شروع کن. کافی است.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'کار را با یک قدم ۱۰ دقیقه‌ای شروع کن.'],
    ['m2', 'یک اشتباه را به یک درس مشخص تبدیل کن.'],
  ],
  progressMetrics: [
    ['p1', 'تعداد اقدام‌ها'],
    ['p2', 'کاهش تعویق'],
    ['p3', 'افزایش تحمل اشتباه'],
  ],
  rules: [
    SchemaRule(behavior: 'procrastinate', then: 'showExercise:ten_min_start'),
    SchemaRule(behavior: 'not_start', then: 'showExercise:small_wins'),
    SchemaRule(behavior: 'comparison', then: 'showExercise:small_wins'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۱۰. استحقاق / بزرگ‌منشی
// ═══════════════════════════════════════════════════════════
const _entitlement = Schema(
  id: 'entitlement',
  nameFa: 'استحقاق / بزرگ‌منشی',
  nameEn: 'Entitlement / Grandiosity',
  domain: 'impaired_limits',
  color: '#f39c12',
  shortDescription:
      'احساس اینکه فرد باید امتیازات ویژه داشته باشد یا محدودیت‌های معمول دیگران درباره او صدق نمی‌کند.',
  coreNeed: 'احترام همراه با درک مرزها و نیازهای دیگران',
  triggers: [
    SchemaItem('hearing_no', 'کسی بهم نه گفت'),
    SchemaItem('limitation', 'با یه محدودیت روبه‌رو شدم'),
    SchemaItem('waiting', 'توی صف، ترافیک یا انتظار سفارش معطل شدم'),
    SchemaItem('not_getting', 'چیزی که می‌خواستم رو نگرفتم'),
    SchemaItem('delayed_response_et', 'دیر جواب گرفتم'),
    SchemaItem('customer_service_et', 'باهام بد برخورد شد'),
    SchemaItem('not_first_et', 'نوبتم عقب افتاد و اول نبودم'),
  ],
  automaticThoughts: [
    SchemaItem('my_right', 'این حق منه'),
    SchemaItem('why_wait', 'چرا باید صبر کنم؟'),
    SchemaItem('special', 'برای من باید فرق داشته باشه'),
    SchemaItem('disrespect_et', 'بهم بی‌احترامی شد'),
    SchemaItem('not_fair_et', 'این عادلانه نیست'),
  ],
  emotionalSignals: [
    SchemaItem('anger', 'خشم'),
    SchemaItem('low_tolerance_em', 'کم‌تحملی'),
    SchemaItem('frustration', 'ناکامی'),
    SchemaItem('offense_et', 'رنجش'),
  ],
  behavioralPatterns: [
    SchemaItem('insist', 'اصرار و مطالبه می‌کنم تا حرفم پیش بره'),
    SchemaItem('ignore_others', 'نیاز و شرایط طرف مقابل رو نادیده می‌گیرم'),
    SchemaItem('low_tolerance', 'محدودیت‌ها رو تحمل نمی‌کنم'),
    SchemaItem('complain_et', 'شکایت می‌کنم'),
    SchemaItem('loud_voice_et', 'صدام رو بالا می‌برم'),
    SchemaItem('rage_quit_et', 'با عصبانیت ترک می‌کنم'),
    SchemaItem('blame_others_et', 'دیگران رو مقصر می‌دونم'),
  ],
  avoidancePatterns: ['فرار از موقعیت‌هایی که نیازمند سازگاری هستند'],
  overcompensationPatterns: ['کنترل', 'برتری‌طلبی'],
  consequences: ['تعارض', 'آسیب به روابط'],
  pauseQuestions: [
    'آیا خواسته من حق است یا ترجیح؟',
    'طرف مقابل چه نیازی دارد؟',
    'اگر جای او بودم چه انتظاری داشتم؟',
  ],
  healthyResponse:
      'حفظ نیازها و خواسته‌های شخصی همراه با احترام به مرز دیگران.',
  replacementResponses: [
    ReplacementResponse(
        'insist', 'به جای اصرار، یک بار درخواست مؤدبانه می‌کنم.'),
    ReplacementResponse(
        'ignore_others', 'قبل از تصمیم، نیاز طرف مقابل را هم می‌پرسم.'),
    ReplacementResponse('low_tolerance',
        '۵ دقیقه انتظار را تحمل می‌کنم، بعد تصمیم می‌گیرم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'perspective_swap',
      title: 'از دید او',
      type: 'reflection',
      prompts: [
        'طرف مقابل الان چه احساسی دارد؟',
        'اگر جای او بودم، از من چه می‌خواستم؟',
        'چه چیزی در این موقعیت واقعاً عادلانه است؟',
      ],
    ),
    SchemaExercise(
      id: 'right_vs_want',
      title: 'حق یا خواسته؟',
      type: 'single_choice',
      question: 'این چیزی که می‌خواهم، حق من است یا ترجیح من؟',
      options: ['حق من است', 'ترجیح من است', 'نمی‌دانم'],
    ),
  ],
  realLifeMissions: [
    ['m1', 'یک بار بدون اصرار «نه» را بپذیر.'],
    ['m2', 'در یک تصمیم، نیاز طرف مقابل را نیز وارد کن.'],
  ],
  progressMetrics: [
    ['p1', 'کاهش تعارض'],
    ['p2', 'افزایش تحمل ناکامی'],
    ['p3', 'توجه به نیاز دیگران'],
  ],
  rules: [
    SchemaRule(behavior: 'insist', then: 'showExercise:perspective_swap'),
    SchemaRule(behavior: 'ignore_others', then: 'showExercise:right_vs_want'),
    SchemaRule(trigger: 'hearing_no', then: 'showExercise:perspective_swap'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۱۱. خویشتن‌داری ناکافی
// ═══════════════════════════════════════════════════════════
const _insufficientSelfControl = Schema(
  id: 'insufficient_self_control',
  nameFa: 'خویشتن‌داری ناکافی',
  nameEn: 'Insufficient Self-Control / Self-Discipline',
  domain: 'impaired_limits',
  color: '#d35400',
  shortDescription:
      'دشواری در تحمل ناراحتی، تأخیر در پاداش و حفظ نظم برای رسیدن به هدف.',
  coreNeed: 'خودتنظیمی و تحمل ناراحتی',
  triggers: [
    SchemaItem('fatigue_sc', 'خسته بودم'),
    SchemaItem('boredom_sc', 'حوصله‌م سر رفته بود'),
    SchemaItem('hard_task', 'کار سختی جلوم بود'),
    SchemaItem('tempting_thing_sc', 'یه چیز وسوسه‌کننده در دسترس بود'),
    SchemaItem('notification_sc', 'نوتیفیکیشن گوشی اومد'),
    SchemaItem('late_night_sc', 'شب بود و باید می‌خوابیدم'),
    SchemaItem('sale_sc', 'حراج یا تخفیف آنلاین دیدم'),
  ],
  automaticThoughts: [
    SchemaItem('later', 'بعداً انجامش می‌دم'),
    SchemaItem('no_energy', 'الان حوصله‌ش رو ندارم'),
    SchemaItem('just_once', 'فقط همین یه بار'),
    SchemaItem('cant_resist_sc', 'نمی‌تونم جلوی خودم رو بگیرم'),
    SchemaItem('deserve_sc', 'الان حقمه'),
  ],
  emotionalSignals: [
    SchemaItem('boredom', 'بی‌حوصلگی'),
    SchemaItem('restless', 'کلافگی'),
    SchemaItem('craving', 'وسوسه'),
  ],
  behavioralPatterns: [
    SchemaItem('procrastinate', 'کار رو مدام عقب می‌ندازم'),
    SchemaItem('quit', 'کار رو نیمه‌کاره ول می‌کنم'),
    SchemaItem('instant_reward', 'فوری خودم رو راضی می‌کنم'),
    SchemaItem('scroll_sc', 'به‌جای کار، بی‌هدف اسکرول می‌کنم'),
    SchemaItem('eat_impulse_sc', 'بی‌فکر می‌خورم'),
    SchemaItem('spend_sc', 'بی‌فکر خرج می‌کنم'),
  ],
  avoidancePatterns: ['فرار از ناراحتی'],
  overcompensationPatterns: ['برنامه‌ریزی افراطی و سپس رها کردن'],
  consequences: ['احساس گناه', 'اهداف نیمه‌تمام'],
  pauseQuestions: [
    'آیا واقعاً نمی‌توانم یا فقط ناراحتم؟',
    'اگر فقط ۵ دقیقه انجامش دهم چه؟',
  ],
  healthyResponse: 'شروع کوچک و تحمل مقدار محدودی از ناراحتی.',
  replacementResponses: [
    ReplacementResponse('procrastinate', 'فقط ۵ دقیقه انجامش می‌دهم.'),
    ReplacementResponse('quit', 'قبل از رها کردن، ۵ دقیقه دیگر ادامه می‌دهم.'),
    ReplacementResponse(
        'instant_reward', 'پاداش را ۱۰ دقیقه به تأخیر می‌اندازم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'five_min_rule',
      title: 'قانون ۵ دقیقه',
      type: 'timer',
      durationSeconds: 300,
      description: 'فقط ۵ دقیقه کار کن، بعد تصمیم بگیر.',
    ),
    SchemaExercise(
      id: 'delay_reward',
      title: 'تأخیر پاداش',
      type: 'timer',
      durationSeconds: 600,
      description: 'قبل از پاداش، ۱۰ دقیقه صبر کن.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'قبل از پاداش مورد علاقه، ۵ دقیقه کار هدف را انجام بده.'],
    ['m2', 'یک کار نیمه‌تمام را کامل کن.'],
  ],
  progressMetrics: [
    ['p1', 'تعداد شروع‌ها'],
    ['p2', 'تعداد تکمیل‌ها'],
    ['p3', 'کاهش تعویق'],
  ],
  rules: [
    SchemaRule(behavior: 'procrastinate', then: 'showExercise:five_min_rule'),
    SchemaRule(behavior: 'instant_reward', then: 'showExercise:delay_reward'),
    SchemaRule(behavior: 'quit', then: 'showExercise:five_min_rule'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۱۲. اطاعت / تسلیم
// ═══════════════════════════════════════════════════════════
const _subjugation = Schema(
  id: 'subjugation',
  nameFa: 'اطاعت / تسلیم',
  nameEn: 'Subjugation',
  domain: 'other_directedness',
  color: '#27ae60',
  shortDescription:
      'کنار گذاشتن خواسته‌ها و احساسات شخصی برای جلوگیری از خشم، طرد یا ناراحتی دیگران.',
  coreNeed: 'حق انتخاب و بیان خود',
  triggers: [
    SchemaItem('request', 'رئیس، دوست یا همکار ازم کاری خواست'),
    SchemaItem('their_upset', 'احتمال دادم طرف مقابل ناراحت بشه'),
    SchemaItem('disagreement_su', 'نظرم با کسی فرق داشت'),
    SchemaItem('family_wants_su', 'خانواده ازم انتظاری داشتن'),
    SchemaItem('guilt_pressure_su',
        'کسی با القای احساس گناه تحت فشارم گذاشت'),
    SchemaItem('authority_figure_su', 'کسی با لحن آمرانه حرف زد'),
  ],
  automaticThoughts: [
    SchemaItem('must_accept', 'چاره‌ای ندارم، باید قبول کنم'),
    SchemaItem('they_upset_if_no', 'اگه نه بگم، ناراحت می‌شه'),
    SchemaItem('trouble', 'دردسر درست می‌شه'),
    SchemaItem('no_right_su', 'من حق ندارم نظرم رو بگم'),
    SchemaItem('peace_more_su', 'آرامش رابطه مهم‌تر از نظر منه'),
    SchemaItem('self_blame_su', 'اگه اتفاقی بیفته، تقصیر منه'),
  ],
  emotionalSignals: [
    SchemaItem('guilt', 'گناه'),
    SchemaItem('fear_su', 'ترس از مخالفت'),
    SchemaItem('suppressed_anger', 'خشم فروخورده'),
    SchemaItem('helplessness_su', 'درماندگی'),
  ],
  behavioralPatterns: [
    SchemaItem('forced_yes', 'بله می‌گم، حتی وقتی نمی‌خوام'),
    SchemaItem('silence', 'نظر و احساسم رو نمی‌گم'),
    SchemaItem('put_others_first', 'همیشه خواستهٔ دیگران رو اول می‌ذارم'),
    SchemaItem('passive_aggressive_su',
        'به‌جای گفتنش، غیرمستقیم نشون می‌دم'),
    SchemaItem('avoid_conflict_su', 'از هر تعارضی دوری می‌کنم'),
    SchemaItem('apologize_first_su', 'اول خودم عذرخواهی می‌کنم'),
  ],
  avoidancePatterns: ['اجتناب از تعارض'],
  overcompensationPatterns: ['انفجار ناگهانی', 'رفتار منفعل-پرخاشگرانه'],
  consequences: ['رنجش', 'فرسودگی', 'از دست دادن مرزها'],
  pauseQuestions: [
    'من واقعاً چه می‌خواهم؟',
    'اگر نه بگویم چه اتفاقی احتمالاً می‌افتد؟',
    'آیا مسئول احساس طرف مقابلم هستم؟',
  ],
  healthyResponse: 'بیان محترمانه خواسته و توانایی نه گفتن.',
  replacementResponses: [
    ReplacementResponse('forced_yes',
        'قبل از پاسخ، ۵ ثانیه مکث می‌کنم و بعد تصمیم می‌گیرم.'),
    ReplacementResponse('silence', 'نظرم را با یک جمله محترمانه بیان می‌کنم.'),
    ReplacementResponse(
        'put_others_first', 'امروز یک بار اولویت خودم را اول می‌گذارم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'assert_script',
      title: 'جمله محترمانه',
      type: 'single_input',
      question: 'یک جمله محترمانه بنویس که در آن نظر خودت را بیان می‌کنی.',
    ),
    SchemaExercise(
      id: 'five_sec_pause',
      title: 'مکث ۵ ثانیه‌ای',
      type: 'timer',
      durationSeconds: 5,
      description: 'قبل از پاسخ، ۵ ثانیه مکث کن.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'در یک درخواست کم‌خطر، پاسخ را فوراً قبول نکن.'],
    ['m2', 'یک ترجیح شخصی را واضح بیان کن.'],
  ],
  progressMetrics: [
    ['p1', 'تعداد مرزبندی‌ها'],
    ['p2', 'کاهش بله‌های ناخواسته'],
  ],
  rules: [
    SchemaRule(behavior: 'forced_yes', then: 'showExercise:assert_script'),
    SchemaRule(behavior: 'put_others_first', then: 'showExercise:assert_script'),
    SchemaRule(behavior: 'silence', then: 'showExercise:five_sec_pause'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۱۳. ایثار
// ═══════════════════════════════════════════════════════════
const _selfSacrifice = Schema(
  id: 'self_sacrifice',
  nameFa: 'ایثار',
  nameEn: 'Self-Sacrifice',
  domain: 'other_directedness',
  color: '#2980b9',
  shortDescription:
      'اولویت دادن مداوم به نیازهای دیگران و نادیده گرفتن نیازهای خود.',
  coreNeed: 'تعادل میان مراقبت از دیگران و خود',
  triggers: [
    SchemaItem('others_need', 'یکی از نزدیکانم به کمک نیاز داشت'),
    SchemaItem('guilt_feeling', 'احساس گناه کردم که کمک نکردم'),
    SchemaItem('others_suffer', 'دیدم کسی داره رنج می‌کشه'),
    SchemaItem('help_request', 'کسی ازم کمک خواست'),
    SchemaItem('friend_crisis_ss', 'دوستی توی بحران بود'),
    SchemaItem('no_one_else_ss', 'فکر کردم اگه من نکنم، هیچ‌کس نمی‌کنه'),
    SchemaItem('sick_relative_ss', 'یکی از عزیزانم بیمار بود'),
  ],
  automaticThoughts: [
    SchemaItem('must_help', 'باید کمک کنم'),
    SchemaItem('my_needs_last', 'نیازهای من اولویت نداره'),
    SchemaItem('bad_person', 'اگه کمک نکنم، آدم بدی‌ام'),
    SchemaItem('selfish_ss', 'اگه خودم رو اول بذارم، خودخواهم'),
    SchemaItem('no_choice_ss', 'چاره‌ای ندارم'),
  ],
  emotionalSignals: [
    SchemaItem('guilt', 'گناه'),
    SchemaItem('fatigue', 'خستگی'),
    SchemaItem('hidden_resentment', 'رنجش پنهان'),
  ],
  behavioralPatterns: [
    SchemaItem('over_help', 'بیش از توانم کمک می‌کنم'),
    SchemaItem('neglect_self', 'نیازهای خودم رو نادیده می‌گیرم'),
    SchemaItem('over_responsible',
        'مسئولیت کارهای بقیه رو هم به عهده می‌گیرم'),
    SchemaItem('yes_always_ss', 'به هر درخواستی بله می‌گم'),
    SchemaItem('silent_burnout_ss', 'در سکوت فرسوده می‌شم'),
  ],
  avoidancePatterns: ['اجتناب از درخواست کمک'],
  overcompensationPatterns: ['فداکاری نمایشی یا انتظار قدردانی'],
  consequences: ['فرسودگی', 'رنجش', 'رابطه نامتعادل'],
  pauseQuestions: [
    'من الان چه نیازی دارم؟',
    'آیا واقعاً مسئول حل این مشکل هستم؟',
    'اگر کمک نکنم چه احساسی دارم؟',
  ],
  healthyResponse: 'کمک کردن بدون حذف خود.',
  replacementResponses: [
    ReplacementResponse(
        'over_help', 'قبل از کمک، از خودم می‌پرسم آیا واقعاً توان دارم.'),
    ReplacementResponse(
        'neglect_self', 'امروز اول یک نیاز شخصی‌ام را برآورده می‌کنم.'),
    ReplacementResponse(
        'over_responsible', 'به جای حل کردن، فقط گوش می‌دهم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'my_needs',
      title: 'نیازهای من',
      type: 'list',
      prompt: 'سه نیاز شخصی که این هفته نادیده گرفته‌ای را بنویس.',
    ),
    SchemaExercise(
      id: 'ask_help',
      title: 'درخواست کمک',
      type: 'single_input',
      question: 'یک چیز کوچک که می‌توانی از کسی بخواهی را بنویس.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'امروز یک نیاز شخصی را قبل از کمک به دیگران انجام بده.'],
    ['m2', 'یک درخواست غیرضروری را نپذیر.'],
  ],
  progressMetrics: [
    ['p1', 'تعادل زمان'],
    ['p2', 'کاهش فرسودگی'],
    ['p3', 'افزایش مراقبت از خود'],
  ],
  rules: [
    SchemaRule(behavior: 'over_help', then: 'showExercise:my_needs'),
    SchemaRule(behavior: 'neglect_self', then: 'showExercise:my_needs'),
    SchemaRule(behavior: 'over_responsible', then: 'showExercise:ask_help'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۱۴. تأییدطلبی
// ═══════════════════════════════════════════════════════════
const _approvalSeeking = Schema(
  id: 'approval_seeking',
  nameFa: 'تأییدطلبی / جلب توجه',
  nameEn: 'Approval Seeking / Recognition Seeking',
  domain: 'other_directedness',
  color: '#8e44ad',
  shortDescription: 'وابستگی ارزشمندی شخصی به تأیید، توجه یا نظر دیگران.',
  coreNeed: 'ارزشمندی مستقل از تأیید دیگران',
  triggers: [
    SchemaItem('criticism', 'کسی از من انتقاد کرد یا ایراد گرفت'),
    SchemaItem('ignored_ap', 'پیامم بی‌جواب موند یا حس کردم نادیده گرفته می‌شم'),
    SchemaItem('compared_ap', 'با یکی مقایسه شدم'),
    SchemaItem('others_opinion', 'به نظر دیگران دربارهٔ خودم فکر کردم'),
    SchemaItem('posted_ap', 'چیزی پست کردم و منتظر لایک و واکنش موندم'),
    SchemaItem('no_compliment_ap', 'کسی ازم تعریف نکرد'),
    SchemaItem('social_gathering_ap', 'توی یه جمع حاضر شدم'),
    SchemaItem('disapproval_ap', 'توی نگاه یا لحن کسی نارضایتی دیدم'),
  ],
  automaticThoughts: [
    SchemaItem('must_approve', 'باید تأییدم کنن'),
    SchemaItem('not_good', 'اگه خوششون نیاد، یعنی خوب نیستم'),
    SchemaItem('must_be_seen', 'اگه دیده نشم، ارزشی ندارم'),
    SchemaItem('what_think_ap', 'دربارهٔ من چی فکر می‌کنن؟'),
    SchemaItem('be_liked_ap', 'همه باید دوستم داشته باشن'),
  ],
  emotionalSignals: [
    SchemaItem('anxiety', 'اضطراب'),
    SchemaItem('shame', 'شرم'),
    SchemaItem('insecurity', 'ناامنی'),
    SchemaItem('rejection_fear_ap', 'ترس از طرد شدن'),
  ],
  behavioralPatterns: [
    SchemaItem('change_behavior',
        'برای رضایت بقیه خودم رو تغییر می‌دم و با همه موافق می‌شم'),
    SchemaItem('comparison', 'خودم رو با بقیه مقایسه می‌کنم'),
    SchemaItem('feedback_hunt', 'مدام از بقیه بازخورد می‌گیرم'),
    SchemaItem('social_media_check_ap', 'لایک‌ها رو چک می‌کنم'),
    SchemaItem('show_off_ap', 'خودنمایی می‌کنم'),
    SchemaItem('avoid_judgment_ap', 'از قضاوت شدن فرار می‌کنم'),
  ],
  avoidancePatterns: ['انجام ندادن کاری که احتمال قضاوت دارد'],
  overcompensationPatterns: ['نمایش موفقیت', 'رقابت', 'جلب توجه'],
  consequences: ['وابستگی به نظر دیگران', 'بی‌ثباتی عزت‌نفس'],
  pauseQuestions: [
    'اگر هیچ‌کس این کار را نمی‌دید، باز هم می‌خواستم انجامش دهم؟',
    'نظر چه کسی واقعاً برای من مهم است؟',
  ],
  healthyResponse: 'انتخاب بر اساس ارزش‌ها و خواسته‌های خود.',
  replacementResponses: [
    ReplacementResponse(
        'change_behavior', 'امروز یک بار نظر واقعی‌ام را می‌گویم.'),
    ReplacementResponse(
        'comparison', 'به جای مقایسه، یک ارزش شخصی خودم را می‌نویسم.'),
    ReplacementResponse('feedback_hunt', 'امروز بازخورد نمی‌گیرم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'self_approval',
      title: 'تأیید از خودم',
      type: 'single_input',
      question:
          'اگر کسی تأییدم نمی‌کرد، من خودم چه چیزی را در خودم ارزشمند می‌دانستم؟',
    ),
    SchemaExercise(
      id: 'private_action',
      title: 'اقدام خصوصی',
      type: 'single_input',
      question:
          'یک کار که فقط برای خودت انجام می‌دهی و به کسی نشان نمی‌دهی بنویس.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'یک کار را بدون گفتن یا نشان دادن به دیگران انجام بده.'],
    ['m2', 'یک انتخاب را بدون گرفتن تأیید انجام بده.'],
  ],
  progressMetrics: [
    ['p1', 'کاهش اطمینان‌گیری'],
    ['p2', 'اقدام مستقل'],
  ],
  rules: [
    SchemaRule(behavior: 'change_behavior', then: 'showExercise:self_approval'),
    SchemaRule(behavior: 'feedback_hunt', then: 'showExercise:private_action'),
    SchemaRule(trigger: 'criticism', then: 'showExercise:self_approval'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۱۵. منفی‌گرایی / بدبینی
// ═══════════════════════════════════════════════════════════
const _negativity = Schema(
  id: 'negativity',
  nameFa: 'منفی‌گرایی / بدبینی',
  nameEn: 'Negativity / Pessimism',
  domain: 'overvigilance_inhibition',
  color: '#34495e',
  shortDescription:
      'تمرکز مداوم بر خطرها، مشکلات، شکست‌ها و جنبه‌های منفی آینده.',
  coreNeed: 'نگاه واقع‌بینانه و تحمل عدم قطعیت',
  triggers: [
    SchemaItem('unknown_future', 'به آیندهٔ نامعلوم فکر کردم'),
    SchemaItem('bad_news_ne', 'خبر بد شنیدم یا خوندم'),
    SchemaItem('risk', 'باید ریسک می‌کردم'),
    SchemaItem('big_decision', 'تصمیم مهمی جلوم بود'),
    SchemaItem('weekend_over_ne', 'آخر هفته تموم شد'),
    SchemaItem('bad_weather_ne', 'هوا بد بود'),
    SchemaItem('mistake_me_ne', 'اشتباه کردم'),
    SchemaItem('good_thing_ne', 'چیز خوبی پیش اومد و نگران شدم'),
  ],
  automaticThoughts: [
    SchemaItem('will_break', 'حتماً خراب می‌شه'),
    SchemaItem('bad_will_happen', 'آخرش اتفاق بدی می‌افته'),
    SchemaItem('useless', 'فایده‌ای نداره؛ چرا تلاش کنم؟'),
    SchemaItem('always_bad_ne', 'همیشه اوضاع من بد بوده'),
  ],
  emotionalSignals: [
    SchemaItem('anxiety', 'اضطراب'),
    SchemaItem('fear', 'ترس'),
    SchemaItem('hopeless', 'ناامیدی'),
  ],
  behavioralPatterns: [
    SchemaItem('focus_problem', 'فقط روی مشکل و بدی‌ها تمرکز می‌کنم'),
    SchemaItem('predict_disaster',
        'بدترین اتفاق رو پیش‌بینی می‌کنم و نگران می‌مونم'),
    SchemaItem('reject_opportunity', 'فرصت‌ها رو رد می‌کنم'),
    SchemaItem('complain_ne', 'شکایت می‌کنم'),
  ],
  avoidancePatterns: ['شروع نکردن'],
  overcompensationPatterns: ['آماده‌سازی افراطی برای بدترین حالت'],
  consequences: ['کاهش انگیزه', 'افزایش اضطراب'],
  pauseQuestions: [
    'بدترین حالت چیست؟',
    'محتمل‌ترین حالت چیست؟',
    'آیا امکان مثبت هم وجود دارد؟',
    'چه چیزی تحت کنترل من است؟',
  ],
  healthyResponse:
      'دیدن همزمان ریسک، احتمال موفقیت و عوامل قابل کنترل.',
  replacementResponses: [
    ReplacementResponse('focus_problem',
        'به جای تمرکز روی مشکل، یک قدم قابل کنترل می‌نویسم.'),
    ReplacementResponse('predict_disaster',
        'سه سناریو می‌نویسم: بدترین، محتمل‌ترین، بهترین.'),
    ReplacementResponse('reject_opportunity',
        'یک اقدام کوچک را بدون تضمین نتیجه امتحان می‌کنم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'three_scenarios',
      title: 'سه سناریو',
      type: 'reflection',
      prompts: [
        'بدترین حالتی که ممکن است پیش بیاید چیست؟',
        'محتمل‌ترین حالت چیست؟',
        'بهترین حالتی که ممکن است پیش بیاید چیست؟',
      ],
    ),
    SchemaExercise(
      id: 'three_good',
      title: 'سه چیز خوب',
      type: 'list',
      prompt: 'سه چیز خوب که امروز اتفاق افتاد را بنویس، حتی کوچک.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'برای یک نگرانی سه نتیجه ممکن بنویس.'],
    ['m2', 'یک اقدام کوچک را بدون تضمین نتیجه انجام بده.'],
  ],
  progressMetrics: [
    ['p1', 'کاهش پیش‌بینی فاجعه'],
    ['p2', 'افزایش اقدام'],
  ],
  rules: [
    SchemaRule(
        behavior: 'predict_disaster', then: 'showExercise:three_scenarios'),
    SchemaRule(behavior: 'focus_problem', then: 'showExercise:three_good'),
    SchemaRule(
        behavior: 'reject_opportunity', then: 'showExercise:three_scenarios'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۱۶. بازداری هیجانی
// ═══════════════════════════════════════════════════════════
const _emotionalInhibition = Schema(
  id: 'emotional_inhibition',
  nameFa: 'بازداری هیجانی',
  nameEn: 'Emotional Inhibition',
  domain: 'overvigilance_inhibition',
  color: '#7f8c8d',
  shortDescription:
      'مهار بیش از حد احساسات، خواسته‌ها یا واکنش‌های طبیعی برای کنترل خود یا جلوگیری از پیامدهای منفی.',
  coreNeed: 'بیان امن و انعطاف‌پذیر هیجان',
  triggers: [
    SchemaItem('expressing_anger', 'عصبانی شدم و چیزی نگفتم'),
    SchemaItem('crying', 'دلم می‌خواست گریه کنم ولی خودم رو کنترل کردم'),
    SchemaItem('affection', 'خواستم محبتم رو بگم ولی نگفتم'),
    SchemaItem('vulnerability', 'دلم شکست ولی ساکت موندم'),
    SchemaItem('disagreement_ei',
        'با کسی اختلاف نظر داشتم و نظرم رو نگفتم'),
    SchemaItem('tired_said_ei', 'خسته بودم ولی گفتم خوبم'),
    SchemaItem('compliment_ei', 'تعریفی شنیدم و بی‌تفاوت موندم'),
  ],
  automaticThoughts: [
    SchemaItem('dont_show', 'بهتره احساساتم رو نشون ندم'),
    SchemaItem('weakness', 'نشون دادن احساس یعنی ضعف'),
    SchemaItem('control_self', 'باید خودم رو کنترل کنم'),
    SchemaItem('burden_ei', 'برای دیگران سربار می‌شم'),
    SchemaItem('handle_alone_ei', 'باید خودم تنهایی تحملش کنم'),
  ],
  emotionalSignals: [
    SchemaItem('inner_pressure', 'فشار درونی'),
    SchemaItem('numb', 'بی‌حسی'),
    SchemaItem('tension', 'تنش بدنی'),
  ],
  behavioralPatterns: [
    SchemaItem('silence_ei', 'ساکت می‌مونم'),
    SchemaItem('hide_feeling', 'احساسم رو پنهان می‌کنم و می‌گم خوبم'),
    SchemaItem('over_logic', 'احساسم رو با منطق توضیح می‌دم'),
    SchemaItem('change_subject_ei', 'بحث رو عوض می‌کنم'),
    SchemaItem('isolate_ei', 'تنها می‌شم تا کسی نبینه'),
  ],
  avoidancePatterns: ['دوری از گفت‌وگوهای عاطفی'],
  overcompensationPatterns: ['انفجار ناگهانی'],
  consequences: ['فاصله عاطفی', 'فشار روانی', 'رنجش'],
  pauseQuestions: [
    'الان چه احساسی دارم؟',
    'اگر احساس من حرف می‌زد چه می‌گفت؟',
    'آیا بیان این احساس در این موقعیت امن است؟',
  ],
  healthyResponse: 'شناخت و بیان متناسب هیجان بدون انفجار یا سرکوب.',
  replacementResponses: [
    ReplacementResponse('silence_ei', 'یک جمله کوتاه درباره احساسم می‌گویم.'),
    ReplacementResponse(
        'hide_feeling', 'احساس واقعی‌ام را با کلمات ساده بیان می‌کنم.'),
    ReplacementResponse(
        'over_logic', 'به جای توضیح دادن، فقط نام احساس را می‌گویم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'name_feeling',
      title: 'نام‌گذاری احساس',
      type: 'single_choice',
      question: 'الان در بدنت و ذهنت چه احساسی داری؟',
      options: ['غم', 'خشم', 'ترس', 'شرم', 'تنهایی', 'بی‌حسی'],
    ),
    SchemaExercise(
      id: 'i_feel',
      title: 'جمله «من احساس ... می‌کنم»',
      type: 'single_input',
      question: 'یک جمله که با «من احساس ... می‌کنم» شروع شود بنویس.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'یک احساس را با جمله «من احساس ... می‌کنم» بیان کن.'],
    ['m2', 'به جای پنهان کردن ناراحتی، آن را محترمانه بیان کن.'],
  ],
  progressMetrics: [
    ['p1', 'توانایی نام‌گذاری احساس'],
    ['p2', 'بیان مستقیم'],
  ],
  rules: [
    SchemaRule(behavior: 'silence_ei', then: 'showExercise:name_feeling'),
    SchemaRule(behavior: 'hide_feeling', then: 'showExercise:i_feel'),
    SchemaRule(behavior: 'over_logic', then: 'showExercise:name_feeling'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۱۷. معیارهای سختگیرانه
// ═══════════════════════════════════════════════════════════
const _unrelentingStandards = Schema(
  id: 'unrelenting_standards',
  nameFa: 'معیارهای سختگیرانه / بیش‌انتظاری',
  nameEn: 'Unrelenting Standards / Hypercriticalness',
  domain: 'overvigilance_inhibition',
  color: '#2c3e50',
  shortDescription:
      'فشار مداوم برای عملکرد بسیار بالا و احساس اینکه هرگز کافی نیست.',
  coreNeed: 'تعادل میان پیشرفت، استراحت و پذیرش محدودیت',
  triggers: [
    SchemaItem('mistake_us', 'اشتباه کوچیکی کردم'),
    SchemaItem('others_perf', 'دیدم کار بقیه چقدر خوب پیش رفته'),
    SchemaItem('unfinished', 'کارم نیمه‌تموم موند'),
    SchemaItem('rest', 'وقت استراحت یا آخر هفتهٔ بی‌کار داشتم'),
    SchemaItem('work_done_us', 'کارم رو تموم کردم ولی راضی نیستم'),
    SchemaItem('checked_details_us', 'جزئیات کارم رو دوباره بازبینی کردم'),
    SchemaItem('compliment_work_us', 'از کارم تعریف شد و باور نکردم'),
  ],
  automaticThoughts: [
    SchemaItem('must_be_better', 'باید بهتر باشم'),
    SchemaItem('not_enough', 'این کافی نیست'),
    SchemaItem('no_mistake', 'نباید اشتباه کنم'),
    SchemaItem('no_rest_us', 'استراحت یعنی تنبلی'),
    SchemaItem('flaw_us', 'هنوز یه ایراد داره'),
    SchemaItem('others_better_us', 'بقیه بهتر از من انجامش می‌دن'),
  ],
  emotionalSignals: [
    SchemaItem('pressure', 'فشار'),
    SchemaItem('anxiety', 'اضطراب'),
    SchemaItem('guilt', 'گناه'),
    SchemaItem('exhaustion_us', 'فرسودگی'),
  ],
  behavioralPatterns: [
    SchemaItem('perfectionism', 'همه‌چیز رو بی‌نقص می‌خوام'),
    SchemaItem('overwork', 'بیش از حد کار می‌کنم و استراحت نمی‌کنم'),
    SchemaItem('revision', 'چند بار بازبینی و دوباره‌کاری می‌کنم'),
    SchemaItem('cant_finish_us', 'نمی‌تونم کار رو تموم‌شده اعلام کنم'),
    SchemaItem('critical_self_us', 'از خودم انتقاد می‌کنم'),
  ],
  avoidancePatterns: ['شروع نکردن به دلیل ترس از کامل نبودن'],
  overcompensationPatterns: ['کار افراطی'],
  consequences: ['فرسودگی', 'کاهش رضایت', 'کاهش انعطاف'],
  pauseQuestions: [
    'آیا این واقعاً باید کامل باشد؟',
    'نسخه کافی این کار چیست؟',
    'اگر ۸۰٪ کافی باشد چه؟',
  ],
  healthyResponse: 'تعریف استاندارد متناسب با اهمیت واقعی کار.',
  replacementResponses: [
    ReplacementResponse(
        'perfectionism', 'این کار را در سطح «کافی» تمام می‌کنم.'),
    ReplacementResponse(
        'overwork', 'امروز در ساعت مشخصی کار را متوقف می‌کنم.'),
    ReplacementResponse('revision', 'یک بازبینی غیرضروری را حذف می‌کنم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'enough_definition',
      title: 'تعریف «کافی»',
      type: 'single_input',
      question: 'برای این کار، «کافی بودن» دقیقاً یعنی چه؟',
    ),
    SchemaExercise(
      id: 'rest_without_guilt',
      title: 'استراحت بدون گناه',
      type: 'timer',
      durationSeconds: 900,
      description: '۱۵ دقیقه استراحت کن، بدون هیچ کاری.',
    ),
  ],
  realLifeMissions: [
    ['m1', 'یک کار کم‌اهمیت را عمداً در سطح «کافی» تمام کن.'],
    ['m2', 'یک بازبینی غیرضروری را حذف کن.'],
  ],
  progressMetrics: [
    ['p1', 'کاهش بازبینی'],
    ['p2', 'کاهش زمان اضافی'],
    ['p3', 'افزایش رضایت'],
  ],
  rules: [
    SchemaRule(behavior: 'revision', then: 'showExercise:enough_definition'),
    SchemaRule(behavior: 'perfectionism', then: 'showExercise:enough_definition'),
    SchemaRule(behavior: 'overwork', then: 'showExercise:rest_without_guilt'),
    SchemaRule(trigger: 'rest', then: 'showExercise:rest_without_guilt'),
  ],
);

// ═══════════════════════════════════════════════════════════
// ۱۸. تنبیه‌گری
// ═══════════════════════════════════════════════════════════
const _punitiveness = Schema(
  id: 'punitiveness',
  nameFa: 'تنبیه‌گری',
  nameEn: 'Punitiveness',
  domain: 'overvigilance_inhibition',
  color: '#7b241c',
  shortDescription:
      'باور اینکه اشتباهات باید با مجازات سخت پاسخ داده شوند و خطا نباید به آسانی بخشیده شود.',
  coreNeed: 'مسئولیت‌پذیری همراه با انعطاف و بخشش',
  triggers: [
    SchemaItem('own_mistake', 'خودم اشتباهی کردم'),
    SchemaItem('others_mistake', 'دیدم کسی اشتباه کرد'),
    SchemaItem('rule_broken', 'کسی قانون یا قراری رو زیر پا گذاشت'),
    SchemaItem('plans_failed_pu', 'کارها طبق برنامه پیش نرفت'),
    SchemaItem('late_pu', 'دیر رسیدم یا چیزی رو فراموش کردم'),
    SchemaItem('own_imperfection_pu', 'توی خودم نقصی دیدم'),
  ],
  automaticThoughts: [
    SchemaItem('must_pay', 'اون باید تاوانش رو پس بده'),
    SchemaItem('unacceptable', 'این اشتباه بخشیدنی نیست'),
    SchemaItem('cant_forgive_self', 'نباید خودمو ببخشم'),
    SchemaItem('self_blame_pu', 'من مقصرم'),
    SchemaItem('deserve_punish_pu', 'سزاوار تنبیهم'),
  ],
  emotionalSignals: [
    SchemaItem('anger', 'خشم'),
    SchemaItem('shame', 'شرم'),
    SchemaItem('guilt', 'گناه'),
    SchemaItem('self_hate_pu', 'تنفر از خودم'),
  ],
  behavioralPatterns: [
    SchemaItem('self_blame', 'خودم رو سرزنش می‌کنم'),
    SchemaItem('strictness', 'با خودم و بقیه سختگیری می‌کنم'),
    SchemaItem('harsh_criticism', 'تند و بی‌رحمانه انتقاد می‌کنم'),
    SchemaItem(
        'punish_self_pu', 'خودم رو از چیزهایی که دوست دارم محروم می‌کنم'),
    SchemaItem('cold_treatment_pu', 'سرد برخورد می‌کنم'),
    SchemaItem('grudge_pu', 'نمی‌بخشم و کینه نگه می‌دارم'),
  ],
  avoidancePatterns: ['پرهیز از موقعیت‌هایی که احتمال اشتباه دارند'],
  overcompensationPatterns: ['تنبیه خود', 'مجازات دیگران'],
  consequences: ['شرم', 'تعارض', 'کاهش یادگیری از اشتباه'],
  pauseQuestions: [
    'هدف من اصلاح است یا تنبیه؟',
    'چه مجازاتی واقعاً چیزی را بهتر می‌کند؟',
    'اگر یک انسان قابل احترام این اشتباه را می‌کرد چه می‌گفتم؟',
  ],
  healthyResponse:
      'پذیرش مسئولیت، جبران و یادگیری بدون مجازات غیرضروری.',
  replacementResponses: [
    ReplacementResponse(
        'self_blame', 'به جای سرزنش، فقط یک اقدام اصلاحی مشخص می‌کنم.'),
    ReplacementResponse(
        'strictness', 'به جای سختگیری، یک جمله مهربان به خودم می‌گویم.'),
    ReplacementResponse(
        'harsh_criticism', 'به جای انتقاد شدید، فقط رفتار را توصیف می‌کنم.'),
  ],
  exercises: [
    SchemaExercise(
      id: 'compassion',
      title: 'همدلی با خود',
      type: 'reflection',
      prompts: [
        'اگر بهترین دوستم همین اشتباه را می‌کرد، به او چه می‌گفتم؟',
        'در آن لحظه، واقعاً چه نیازی داشتم؟',
        'چه چیزی می‌توانم یاد بگیرم بدون اینکه خودم را خرد کنم؟',
      ],
    ),
    SchemaExercise(
      id: 'corrective_action',
      title: 'اقدام اصلاحی',
      type: 'single_input',
      question: 'برای این اشتباه، یک اقدام اصلاحی مشخص بنویس (نه تنبیه).',
    ),
  ],
  realLifeMissions: [
    ['m1', 'بعد از یک اشتباه، فقط یک اقدام اصلاحی تعیین کن.'],
    ['m2', 'یک اشتباه قدیمی را بدون سرزنش دوباره بررسی کن.'],
  ],
  progressMetrics: [
    ['p1', 'کاهش خودسرزنشی'],
    ['p2', 'افزایش اصلاح عملی'],
    ['p3', 'کاهش واکنش تنبیهی'],
  ],
  rules: [
    SchemaRule(behavior: 'self_blame', then: 'showExercise:compassion'),
    SchemaRule(behavior: 'harsh_criticism', then: 'showExercise:compassion'),
    SchemaRule(behavior: 'strictness', then: 'showExercise:corrective_action'),
  ],
);

// ═══════════════════════════════════════════════════════════
// لیست کامل ۱۸ طرحواره
// ═══════════════════════════════════════════════════════════
const List<Schema> schemas = [
  _abandonment,
  _mistrustAbuse,
  _emotionalDeprivation,
  _defectivenessShame,
  _socialIsolation,
  _dependenceIncompetence,
  _vulnerability,
  _enmeshment,
  _failure,
  _entitlement,
  _insufficientSelfControl,
  _subjugation,
  _selfSacrifice,
  _approvalSeeking,
  _negativity,
  _emotionalInhibition,
  _unrelentingStandards,
  _punitiveness,
];

// ═══════════════════════════════════════════════════════════
// دسترسی سریع
// ═══════════════════════════════════════════════════════════
final Map<String, Schema> _schemasById = {
  for (final s in schemas) s.id: s,
};

Schema? findSchemaById(String? id) => id == null ? null : _schemasById[id];

// ═══════════════════════════════════════════════════════════
// اولویت‌بندی
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
// موتور قوانین
// ═══════════════════════════════════════════════════════════
String? resolveExercise(String schemaId, String? triggerId, String? behaviorId) {
  final schema = findSchemaById(schemaId);
  if (schema == null) return null;

  for (final rule in schema.rules) {
    final w = rule;
    final matches = (w.trigger == null || w.trigger == triggerId) &&
        (w.behavior == null || w.behavior == behaviorId);
    if (matches) return w.then;
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
