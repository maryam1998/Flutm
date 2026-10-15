// lib/screens/shenakht/acceptance_screen.dart
import 'package:flutter/material.dart';

import 'shenakht_tab.dart';

class AcceptanceScreen extends StatefulWidget {
  final VoidCallback onBack;
  const AcceptanceScreen({super.key, required this.onBack});

  @override
  State<AcceptanceScreen> createState() => _AcceptanceScreenState();
}

class _AcceptanceScreenState extends State<AcceptanceScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ShenakhtShell(
      title: 'پذیرش',
      onBack: widget.onBack,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _tabBtn('استعاره', 0, '🪢'),
                const SizedBox(width: 6),
                _tabBtn('چیست/نیست', 1, '🧭'),
                const SizedBox(width: 6),
                _tabBtn('مراحل', 2, '🪜'),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              children: [
                if (_tab == 0) ..._metaphorTab(),
                if (_tab == 1) ..._distinctionsTab(),
                if (_tab == 2) ..._stagesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int i, String emoji) {
    final active = _tab == i;
    return Expanded(
      child: Material(
        color: active ? SK.primary : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => _tab = i),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: active ? SK.primary : const Color(0xFFE5E5E5),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '$emoji $label',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── تب استعاره ───────────────────────────────
  List<Widget> _metaphorTab() => [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: SK.grad,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Text('🪢', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              const Text(
                'استعاره‌ی طناب',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const Text(
                'تصور کن توی یه اتاق، به یه طناب محکم بسته‌ای. طناب به دیوار وصله. تو تمام عمرت داری طناب رو می‌کشی — می‌خوای دیوار رو جابه‌جا کنی. هرچی بیشتر می‌کشی، خسته‌تر می‌شی. دیوار تکون نمی‌خوره.\n\n'
                'پذیرش یعنی: «دیوار اینجاست. طناب هم هست. من طناب رو رها می‌کنم.» تو دیوار رو عوض نکردی. طناب هم خودش باز نمی‌شه. ولی تو دیگه اون رو نمی‌کشی.\n\n'
                'حالا دستت آزاده که کار دیگه‌ای بکنی.',
                style: TextStyle(
                    color: Colors.white, fontSize: 14, height: 2.1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            border: Border.all(color: const Color(0xFFA7F3D0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            '💡 پذیرش، نه تغییر واقعیته، نه تسلیم به اون. فقط دست برداشتن از کشیدن طنابه.',
            style: TextStyle(
                fontSize: 14,
                height: 1.95,
                color: Color(0xFF065F46),
                fontWeight: FontWeight.w600),
          ),
        ),
      ];

  // ── تب چیست/نیست ─────────────────────────────
  List<Widget> _distinctionsTab() {
    final items = [
      (
        'پذیرش ≠ تأیید',
        'پذیرش یعنی قبول کنی «این اتفاق افتاده». یعنی دست از جنگیدن با گذشته برداری.',
        'پذیرش یعنی نگویی «خوب بود» یا «مهم نبود». قرار نیست رفتار خانواده‌ات رو تأیید کنی.',
        'پذیرش: «پدر من همینه — سرد و کم‌حرف. این واقعیته.» تأیید: «سردی پدرم درست بود.»'
      ),
      (
        'پذیرش ≠ تسلیم',
        'پذیرش یعنی از جنگیدن با چیزی که نمی‌تونی عوض کنی، دست برداری.',
        'پذیرش یعنی بشینی و بگی «همینه که هست، کاری نمی‌شه کرد». این افسردگیه، نه پذیرش.',
        'پذیرش: «گذشته‌ام رو عوض نمی‌کنم، ولی امروز رو می‌سازم.»'
      ),
      (
        'پذیرش ≠ فراموشی',
        'پذیرش یعنی گذشته رو یادت میاد، ولی دیگه زخمِ امروزت نیست.',
        'پذیرش یعنی سرکوب خاطرات، یا گفتن «فراموش کن». فراموشی، انکاره.',
        'پذیرش: «یادم میاد چی شد. یادم میاد درد داشت. ولی الان تصمیم‌هام رو از اون درد نمی‌گیرم.»'
      ),
      (
        'پذیرش ≠ دوست داشتن',
        'پذیرش یعنی واقعیت رو همون‌طور که هست، ببینی.',
        'پذیرش یعنی مجبور بشی خانواده‌ات رو دوست داشته باشی.',
        'می‌تونی خانواده‌ات رو نه دوست داشته باشی، نه ازشون متنفر باشی. مثل آب‌وهوا — نه دوستش داری، نه ازش متنفری. فقط هست.'
      ),
      (
        'پذیرش ≠ سرزنش',
        'پذیرش یعنی از «تقصیر کی بود؟» رد بشی و بری سراغ «الان چی کار کنم؟»',
        'پذیرش یعنی نگویی «تقصیر من بود» یا «تقصیر اونا بود». سرزنش، بخشی از چرخه‌ست — نه راه‌حل.',
        'سرزنش: «تقصیر پدرم بود که این‌طور شدم.» پذیرش: «پدرم همین بود. حالا من بزرگسالم و مسئول زندگی امروزم.»'
      ),
    ];

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          border: Border.all(color: const Color(0xFFFDE68A)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '💡 خیلی‌ها نمی‌توانند بپذیرند چون فکر می‌کنند «پذیرش = تسلیم = تأیید». این‌ها کاملاً متفاوتند.',
          style: TextStyle(
              fontSize: 13, color: Color(0xFF92400E), height: 1.9),
        ),
      ),
      const SizedBox(height: 12),
      for (final it in items) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF0F0F0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(it.$1,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    right: BorderSide(
                        color: Color(0xFF10B981), width: 3),
                  ),
                ),
                child: Text('هست: ${it.$2}',
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.9,
                        color: Color(0xFF065F46))),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    right: BorderSide(
                        color: Color(0xFFEF4444), width: 3),
                  ),
                ),
                child: Text('نیست: ${it.$3}',
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.9,
                        color: Color(0xFF991B1B))),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('مثال: ${it.$4}',
                    style:
                        const TextStyle(fontSize: 12.5, height: 1.9)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  // ── تب مراحل ─────────────────────────────────
  List<Widget> _stagesTab() {
    final stages = [
      (
        'اعتراف به خشم',
        'قبل از پذیرش، باید خشم رو ببینی و تأییدش کنی.',
        [
          'بنویس: از چی توی خانواده‌ام عصبانی‌ام؟',
          'بنویس: از چی توی جغرافیای زندگی‌ام ناراحتم؟',
          'بذار بدون قضاوت، خشم رو بنویسی.',
          'به خودت بگو: «خشم من درسته.»',
        ],
        '⚠️ بیشتر از چند هفته توی خشم نمون — تبدیل به تلخی می‌شه.',
      ),
      (
        'تفکیک چی می‌تونم عوض کنم',
        'ذهن توی خشم، همه‌چیز رو «غیرقابل تغییر» می‌بینه. باید تفکیک کنی.',
        [
          'یه کاغذ بردار و دو ستون بکش.',
          'ستون اول: تولد توی این خانواده، گذشته، رفتار والدین.',
          'ستون دوم: واکنش امروزم، مرزهام، شغل، مکان زندگی.',
          'به ستون دوم نگاه کن — همه‌ی اینا دست توئه.',
        ],
        null,
      ),
      (
        'سوگ چیزی که نداشتم',
        'برای خانواده‌ی ایده‌آل، جغرافیای ایده‌آل، کودکی ایده‌آل — عزاداری کن.',
        [
          'یه نامه‌ی خداحافظی بنویس به «خانواده‌ای که آرزو داشتم».',
          'بنویس: چی رو از دست دادم؟ چی رو هرگز نداشتم؟',
          'بنویس: چطور دلم می‌خواست باشه؟',
          'بذار گریه کنی. این اشک، نشونه‌ی حرکته، نه ضعف.',
        ],
        null,
      ),
      (
        'رها کردن سؤال «چرا من؟»',
        'سؤال «چرا من؟» جواب نداره. تا ادامه‌اش بدی، توی گذشته قفل می‌مونی.',
        [
          'هر وقت ذهنت گفت «چرا من؟»، بگو: «این سؤال جواب نداره. ولی چی می‌تونم بکنم؟»',
          'سؤال رو عوض کن. از «چرا من؟» به «حالا چی کار کنم؟»',
          'روزی یه بار، وقتی این فکر اومد، بگو: «نمی‌دونم. و اشکالی نداره.»',
        ],
        'این مرحله معمولاً سخت‌ترینه. پذیرشِ بی‌عدالتی، کار راحتی نیست. ولی ممکنه.',
      ),
      (
        'پذیرش بدون تأیید',
        'یاد بگیر بگی «این‌طوره» بدون اینکه بگی «این خوبه».',
        [
          'جمله بساز: «پدر من سرده. این رو می‌پذیرم. و از او فاصله می‌گیرم.»',
          'به خودت یاد بده: پذیرش یه واقعیت، تأییدش نیست.',
          'بنویس: چه چیزهایی رو از خانواده‌ام می‌پذیرم که تأیید نمی‌کنم؟',
        ],
        null,
      ),
      (
        'ساختن زندگی بزرگسال',
        'خانواده‌ی انتخابی، مکان انتخابی، و زندگی‌ای که خودت انتخاب می‌کنی.',
        [
          'فهرست کن: چه کسایی توی زندگی امروزم، «خانواده‌ی انتخابی» من هستن؟',
          'اگه نداری، بنویس: چه نوع آدم‌هایی رو می‌خوام توی زندگی‌ام داشته باشم؟',
          'بنویس: چه مکانی منو آروم می‌کنه؟',
          'هر هفته یه قدم کوچیک به سمت ساختن این زندگی بردار.',
        ],
        null,
      ),
    ];

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          border: Border.all(color: const Color(0xFFFDE68A)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '💡 نمی‌شود از مرحله‌ی ۱ پرید به مرحله‌ی ۶. هر مرحله زمان می‌خواهد. سوگ، مرحله‌ی حیاتی است که اکثر آدم‌ها ردش می‌کنند — چون فکر می‌کنند ضعف است.',
          style: TextStyle(
              fontSize: 13, color: Color(0xFF92400E), height: 1.9),
        ),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < stages.length; i++) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF0F0F0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: SK.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(_faNum(i + 1),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(stages[i].$1,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(stages[i].$2,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.9,
                      color: Color(0xFF444444))),
              const SizedBox(height: 10),
              for (final s in stages[i].$3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•',
                          style: TextStyle(
                              color: SK.primary,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 13, height: 1.9)),
                      ),
                    ],
                  ),
                ),
              if (stages[i].$4 != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(stages[i].$4!,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.9,
                          color: Color(0xFF991B1B))),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
