import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/future_text_format.dart';
import '../models/future_version.dart';
import '../state/beliefs_store.dart';
import '../widgets/breath_circle.dart';
import '../widgets/format_bar.dart';
import '../widgets/mini_calendar_90.dart';
import '../widgets/nothing_scene.dart';
import '../widgets/quantum_connect.dart';
import '../widgets/ras_mission.dart';

class BeliefsTab extends StatefulWidget {
  const BeliefsTab({super.key});
  @override
  State<BeliefsTab> createState() => _BeliefsTabState();
}

class _BeliefsTabState extends State<BeliefsTab> {
  final Set<String> _doneLayers = {};

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BeliefsStore>();
    final v = store.activeVersion;

    return Scaffold(
      backgroundColor: kBeliefsCream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text('بازنویسی باورها',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kBeliefsInk,
                )),
            const SizedBox(height: 4),
            const Text(
              'سیم‌کشی مغز بر پایه‌ی RAS، نوروپلاستیسیتی و روش دکتر جو دیسپنزا',
              style: TextStyle(fontSize: 11.5, color: kBeliefsMuted, height: 1.7),
            ),
            const SizedBox(height: 16),

            // متن آینده
            _textCard(store, v),
            const SizedBox(height: 16),

            // دکمه‌های ثبت
            _actionsRow(store, v),
            const SizedBox(height: 16),

            // ═══ کارت قلمرو ممکن‌ها ═══
            _quantumFieldCard(),
            const SizedBox(height: 14),

            // ═══ کارت چرا باید هیچ شوی؟ ═══
            _whyNothingCard(),
            const SizedBox(height: 14),

            // ═══ کارت تمرین روزانه ═══
            _dailyPracticeCard(),
            const SizedBox(height: 16),

            // تقویم
            MiniCalendar90(
              version: v,
              totalDays: store.cycleDays,
              dayKeyOf: (d) => '${d.year}-${d.month}-${d.day}',
              isFuture: (d) {
                final now = DateTime.now();
                final t = DateTime(now.year, now.month, now.day);
                return d.isAfter(t);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ کارت متن آینده ═══════════════
  Widget _textCard(BeliefsStore store, FutureVersion? v) {
    final hasText = v != null && v.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('✍️ ', style: TextStyle(fontSize: 14)),
              const Expanded(
                child: Text(
                  'متن خواسته‌ات',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsInk,
                  ),
                ),
              ),
              if (hasText)
                TextButton(
                  onPressed: () => _openEditor(store),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('ویرایش',
                      style: TextStyle(fontSize: 12, color: kBeliefsGold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasText)
            GestureDetector(
              onTap: () => _openEditor(store),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
                decoration: BoxDecoration(
                  color: kBeliefsCream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBeliefsBorder),
                ),
                child: const Column(
                  children: [
                    Text(
                      'هنوز متن خواسته‌ات رو ننوشتی.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: kBeliefsInk),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'با «بسیار خوشحال و سپاسگزارم حالا که…» شروع کن.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5, color: kBeliefsMuted, height: 1.7),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '＋ همین‌جا بزن و بنویس',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kBeliefsGold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => _openEditor(store),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kBeliefsCream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBeliefsBorder),
                ),
                child: Text(
                  '«${v.text}»',
                  style: store.format.buildStyle(color: kBeliefsInk),
                  textAlign: store.format.textAlign,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════ کارت قلمرو ممکن‌ها ═══════════════
  Widget _quantumFieldCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFF2BBFAB).withValues(alpha: 0.08),
            const Color(0xFF5EC8F0).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2BBFAB).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🌌 قلمرو ممکن‌ها',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: kBeliefsInk,
              margin: EdgeInsets.only(bottom: 8),
            ),
          ),
          const SizedBox(height: 8),
          _p('تصور کن در ذهنِ تو فضایی شبیه به یک «میدان احتمالات» وجود دارد. علم اعصاب به ما می‌گوید مغز ثابت نیست — از خاصیت نوروپلاستیسیتی (انعطاف‌پذیری عصبی) برخوردار است؛ مثل زمینی که آماده‌ی کشت است. هر قصد و حسِ متمرکزی، اتصالات عصبی‌ات را از نظر فیزیکی بازسازی می‌کند.'),
          const SizedBox(height: 6),
          _p('واقعیت امروز تو، فقط عادت‌ترین مسیرِ عصبیِ فعلی توست. استعاره‌ی «موج احتمالات» — که از فیزیک کوانتوم وام گرفته‌ایم — یادآوری می‌کند: تا وقتی آن احتمال را با باور و احساس واقعی «انتخاب» نکرده‌ای، سایر مسیرها در ذهنت به‌صورت بالقوه باقی می‌مانند.'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2BBFAB).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: const Border(
                right: BorderSide(color: Color(0xFF2BBFAB), width: 3),
              ),
            ),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                    fontSize: 12, color: kBeliefsInk, height: 1.9),
                children: [
                  TextSpan(
                    text: 'یه نکته: ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text:
                        'تو این تمرین‌ها چیز جدیدی از بیرون «نمی‌سازی» — فقط مسیرهای عصبیِ تازه‌ای را در ذهن خودت تقویت می‌کنی که تا حالا فعال نبودند.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════ کارت چرا باید هیچ شوی؟ ═══════════════
  Widget _whyNothingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🕳️ چرا باید «هیچ» شوی؟',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: kBeliefsInk,
            ),
          ),
          const SizedBox(height: 8),
          _p('اگر از «منِ قدیمی» شروع کنی، مغزت همون الگوهای عصبیِ قدیمی رو دوباره اجرا می‌کنه. باید اول «هیچ» شی — یعنی موقتاً از هویت قدیمی، از ترس‌ها و از داستان‌های تکرارشونده فاصله بگیری. در اون سکوت و خالی بودن، شبکه‌ی حالت پیش‌فرض مغز (DMN) — همون بخشی که مدام با خودش حرف می‌زنه — آروم می‌شه.'),
          const SizedBox(height: 6),
          _p('وقتی «هیچ» می‌شی، RAS (سیستم فعال‌ساز شبکه‌ای مغزت) دوباره تنظیم می‌شه و می‌تونه اون نشانه‌ها و فرصت‌هایی رو ببینه که قبلاً از فیلتر توجهت رد می‌شدن. این یعنی گفت‌وگو با انعطاف‌پذیری مغزت — نه با کائنات.'),
        ],
      ),
    );
  }

  Widget _p(String text) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontSize: 12, color: kBeliefsMuted, height: 1.9),
        children: [
          TextSpan(text: text),
        ],
      ),
    );
  }

  // ═══════════════ کارت تمرین روزانه ═══════════════
  Widget _dailyPracticeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // هدر
          Row(
            children: [
              const Text('🌌 ', style: TextStyle(fontSize: 14)),
              const Expanded(
                child: Text(
                  'تمرین روزانه',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsInk,
                  ),
                ),
              ),
              Text(
                '۰ جلسه',
                style: const TextStyle(fontSize: 10.5, color: kBeliefsMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'شش مرحله. هر کدوم رو جدا تیک بزن. لازم نیست یه‌جا انجام بدی.',
            style: TextStyle(fontSize: 11, color: kBeliefsMuted, height: 1.7),
          ),
          const SizedBox(height: 14),

          // ─── موسیقی مدیتیشن ───
          const Text(
            '🎵 موسیقی مدیتیشن (اختیاری)',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: kBeliefsInk),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: kBeliefsMuted,
              side: const BorderSide(color: kBeliefsBorder),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {},
            icon: const Icon(Icons.add, size: 14),
            label: const Text('افزودن موسیقی',
                style: TextStyle(fontSize: 11)),
          ),
          const Divider(height: 24),

          // ─── تایمر ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kBeliefsCream,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('⏱️ زمان تمرین',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: kBeliefsInk)),
                const Spacer(),
                const Text('۱۵:۰۰',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kBeliefsInk,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBeliefsInk,
                    side: const BorderSide(color: kBeliefsBorder),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {},
                  child: const Text('شروع', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── مرحله ۱: رهاسازی ───
          _stepHeader(
            number: '۱',
            title: 'رهاسازی — آرام شدن',
            isDone: _doneLayers.contains('breath'),
            onToggle: () => setState(() {
              if (_doneLayers.contains('breath')) {
                _doneLayers.remove('breath');
              } else {
                _doneLayers.add('breath');
              }
            }),
          ),
          const SizedBox(height: 10),
          _whyBox(
            def: '📖 رهاسازی (Relaxation): بدنت رو عمیقاً آروم کن تا از حالت آماده‌باش و تنش فاصله بگیری.',
            body:
                'وقتی بدن آروم می‌شه، توجهت از فشارها و فکرهای روزمره جدا می‌شه. ذهنت آماده می‌شه برای تمرکز، تجسم و تجربه‌ی درونی.',
          ),
          const SizedBox(height: 14),
          const BreathCircle(),
          const SizedBox(height: 18),

          // ─── مرحله ۲: هیچ شدن ───
          _stepHeader(
            number: '۲',
            title: 'هیچ شدن',
            isDone: _doneLayers
                    .where((k) => !const {'connection', 'seed', 'images'}.contains(k))
                    .length >=
                5,
            onToggle: () {},
            trailing: const Icon(Icons.notifications_outlined,
                size: 18, color: kBeliefsMuted),
          ),
          const SizedBox(height: 10),
          _whyBox(
            def:
                '📖 هیچ شدن (Becoming Nothing): توجهت رو از بدن، محیط و هویت «من» برمی‌داری و به آگاهی محض اجازه می‌دی گسترش پیدا کنه.',
            body:
                'وقتی خودت رو با اسم، شغل، بدن، خاطرات گذشته و نگرانی‌های آینده تعریف می‌کنی، داری سیگنالی از «گذشته» به میدان می‌فرستی. «هیچ شدن» یعنی رها کردن این هویت‌های شرطی‌شده.',
          ),
          const SizedBox(height: 14),
          const Text(
            'پنج لایه رو یکی‌یکی رها کن — با هر تیک، غبار کمتر و آگاهی روشن‌تر:',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: kBeliefsInk),
          ),
          const SizedBox(height: 10),
          NothingScene(
            doneLayers: _doneLayers,
            onToggle: (key) {
              setState(() {
                if (_doneLayers.contains(key)) {
                  _doneLayers.remove(key);
                } else {
                  _doneLayers.add(key);
                }
              });
            },
          ),
          const SizedBox(height: 18),

          // ═══ مرحله ۳: اتصال به قلمرو ممکن‌ها ═══
          _stepHeader(
            number: '۳',
            title: 'اتصال به قلمرو ممکن‌ها',
            isDone: _doneLayers.contains('connection'),
            onToggle: () => setState(() {
              if (_doneLayers.contains('connection')) {
                _doneLayers.remove('connection');
              } else {
                _doneLayers.add('connection');
              }
            }),
          ),
          const SizedBox(height: 10),
          _whyBox(
            def: '📖 اتصال (Connection): در این حالت خالی و آروم، RAS مغزت دوباره تنظیم می‌شه و می‌تونه فرصت‌ها و نشانه‌هایی رو ببینه که قبلاً از فیلتر توجهت رد می‌شدن.',
            body: 'این یه تمرین ذهن‌آگاهی برای بازکردن کانال توجهه — نه ارسال سیگنال به یک میدان بیرونی.',
          ),
          const QuantumConnect(),
          const SizedBox(height: 18),

          // ═══ مرحله ۴: بذر ═══
          _stepHeader(
            number: '۴',
            title: 'کاشتن بذر',
            isDone: _doneLayers.contains('seed'),
            onToggle: () => setState(() {
              if (_doneLayers.contains('seed')) {
                _doneLayers.remove('seed');
              } else {
                _doneLayers.add('seed');
              }
            }),
          ),
          const SizedBox(height: 18),

          // ═══ مرحله ۵: تصاویر ═══
          _stepHeader(
            number: '۵',
            title: 'تصاویر',
            isDone: _doneLayers.contains('images'),
            onToggle: () => setState(() {
              if (_doneLayers.contains('images')) {
                _doneLayers.remove('images');
              } else {
                _doneLayers.add('images');
              }
            }),
          ),
          const SizedBox(height: 10),
          _whyBox(
            def: '📖 کاشتن بذر (Seeding): یه تصویر واضح از واقعیت دلخواهت توی ذهن می‌کاری — بدون حس نیاز یا کمبود.',
            body: 'خودت رو توی صحنه‌ای ببین که به خواسته‌ات رسیدی. هر تعداد عکس یا ویدیو که دوست داری اضافه کن.',
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: kBeliefsCream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBeliefsBorder),
            ),
            child: const Column(
              children: [
                Text('✨', style: TextStyle(fontSize: 28)),
                SizedBox(height: 6),
                Text('هنوز تصویری اضافه نکردی',
                    style: TextStyle(fontSize: 12, color: kBeliefsMuted)),
                SizedBox(height: 4),
                Text('عکس یا ویدیوی مورد دلخواهت رو اضافه کن',
                    style: TextStyle(fontSize: 10.5, color: kBeliefsMuted)),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ═══ مأموریت ذهن ═══
          _stepHeader(
            number: '🎯',
            title: 'مأموریت ذهن',
            isDone: false,
            onToggle: () {},
          ),
          const SizedBox(height: 10),
          const Text(
            'ذهنت رو برای دیدن چیزی که تا حالا ازش رد می‌شدی، آموزش بده.',
            style: TextStyle(fontSize: 11.5, color: kBeliefsMuted, height: 1.75),
          ),
          const SizedBox(height: 12),
          const RasMission(),
        ],
      ),
    );
  }

  Widget _whyBox({required String def, required String body}) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF8),
        border: const Border(
          right: BorderSide(color: Color(0xFF54C9B8), width: 3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            def,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F5B53),
              height: 1.75,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
                fontSize: 11.5, color: kBeliefsMuted, height: 1.8),
          ),
        ],
      ),
    );
  }

  Widget _stepHeader({
    required String number,
    required String title,
    required bool isDone,
    required VoidCallback onToggle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFF2BBFAB) : kBeliefsCard,
              border: Border.all(
                color: isDone ? const Color(0xFF2BBFAB) : kBeliefsBorder,
                width: 2,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              isDone ? '✓' : '○',
              style: TextStyle(
                fontSize: 14,
                color: isDone ? Colors.white : kBeliefsMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFFBF6EA),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: kBeliefsMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kBeliefsInk,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ═══════════════ handlers ═══════════════
  Future<void> _openEditor(BeliefsStore store) async {
    final cur = store.activeVersion;
    final initial = cur?.text ?? '';
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextEditor(
        initial: initial,
        format: store.format,
        onFormatChange: store.setFormat,
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await store.saveText(result);
    }
  }

  Future<void> _markRead(BeliefsStore store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBeliefsCard,
        content: const Text(
          'امروز متنت رو خوندی؟ ثبت کنم؟',
          style: TextStyle(color: kBeliefsInk, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('نه', style: TextStyle(color: kBeliefsMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kBeliefsGold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بله'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await store.markReadToday();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ثبت شد ✓ — یک روز دیگه به مسیرت اضافه شد')),
        );
      }
    }
  }

  Future<void> _openCycleDaysDialog(BeliefsStore store) async {
    final ctrl = TextEditingController(text: store.cycleDays.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBeliefsCard,
        title: const Text('تعداد روزهای دوره',
            style: TextStyle(fontSize: 15, color: kBeliefsInk)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('بین ۱ تا ۳۶۵ روز',
                style: TextStyle(fontSize: 12, color: kBeliefsMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لغو', style: TextStyle(color: kBeliefsMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kBeliefsGold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final n = int.tryParse(ctrl.text) ?? store.cycleDays;
      await store.setCycleDays(n);
    }
  }

  Future<void> _confirmResetCalendar(BeliefsStore store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBeliefsCard,
        content: const Text(
          'تقویم از امروز از نو شروع بشه؟\nثبت‌های این دوره در تاریخچه‌ی همین نسخه نگه داشته می‌شن.',
          style: TextStyle(color: kBeliefsInk, fontSize: 13, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('نه', style: TextStyle(color: kBeliefsMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kBeliefsGold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بله'),
          ),
        ],
      ),
    );
    if (ok == true) await _resetCalendar(store);
  }

  Future<void> _resetCalendar(BeliefsStore store) async {
    await store.resetCalendar();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تقویم ریست شد — دوره‌ی تازه از امروز 🌱')),
      );
    }
  }

  Future<void> _openArchive(BeliefsStore store) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ArchiveSheet(store: store),
    );
  }

  static String _toFa(int n) => n.toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
      );
}

// ═══════════════ ویرایشگر متن ═══════════════
class _TextEditor extends StatefulWidget {
  final String initial;
  final FutureTextFormat format;
  final ValueChanged<FutureTextFormat> onFormatChange;

  const _TextEditor({
    required this.initial,
    required this.format,
    required this.onFormatChange,
  });

  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final TextEditingController _ctrl;
  late FutureTextFormat _fmt;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
    _fmt = widget.format;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kBeliefsCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'متن خواسته‌ات',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsInk,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'با «بسیار خوشحال و سپاسگزارم حالا که…» شروع کن',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: kBeliefsMuted),
                ),
                const SizedBox(height: 12),
                FormatBar(
                  format: _fmt,
                  onChange: (f) {
                    setState(() => _fmt = f);
                    widget.onFormatChange(f);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ctrl,
                  maxLines: null,
                  minLines: 5,
                  textAlign: _fmt.textAlign,
                  textDirection: TextDirection.rtl,
                  style: _fmt.buildStyle(color: kBeliefsInk),
                  decoration: InputDecoration(
                    hintText: 'بسیار خوشحال و سپاسگزارم حالا که…',
                    hintStyle: const TextStyle(
                        color: kBeliefsMuted, fontSize: 12, height: 1.8),
                    filled: true,
                    fillColor: kBeliefsCard,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBeliefsBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBeliefsBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: kBeliefsGold, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kBeliefsMuted,
                          side: const BorderSide(color: kBeliefsBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: kBeliefsGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final t = _ctrl.text.trim();
                          if (t.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('متن نمی‌تونه خالی باشه')),
                            );
                            return;
                          }
                          Navigator.pop(context, t);
                        },
                        child: const Text('💾 ذخیره',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════ آرشیو ═══════════════
class _ArchiveSheet extends StatelessWidget {
  final BeliefsStore store;
  const _ArchiveSheet({required this.store});

  @override
  Widget build(BuildContext context) {
    final list = store.versions.reversed.toList();
    return Container(
      decoration: const BoxDecoration(
        color: kBeliefsCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📚 آرشیو نسخه‌ها',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kBeliefsInk)),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kBeliefsCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBeliefsBorder),
                    ),
                    child: Text(
                      list[i].text,
                      style: const TextStyle(
                          fontSize: 11.5, color: kBeliefsInk, height: 1.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('بستن'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
