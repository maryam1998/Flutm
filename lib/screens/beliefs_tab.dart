import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/future_text_format.dart';
import '../models/future_version.dart';
import '../state/beliefs_store.dart';
import '../utils/edit_mark.dart';
import '../widgets/belief_visual_section.dart';
import '../widgets/breath_circle.dart';
import '../widgets/format_bar.dart';
import '../widgets/grat_period_calendar.dart';
import '../theme/grat_palette.dart';
import '../widgets/neural_pathway.dart';
import '../widgets/nothing_scene.dart';
import '../widgets/quantum_connect.dart';
import '../widgets/ras_mission.dart';
import '../services/quiet_snack.dart';

const Color _kEmerald = Color(0xFF178A7C);
const Color _kEmerald300 = Color(0xFF54B3A4);
const Color _kEmerald700 = Color(0xFF0F5B53);
const Color _kSky = Color(0xFF5EC8F0);
const Color _kInkSoft = Color(0xFF3D5551);
const Color _kYellow = Color(0xFFF4C542);

/// مدت تایمر تمرین (۱۵ دقیقه)
const int _kTimerTotal = 15 * 60;

class BeliefsTab extends StatefulWidget {
  const BeliefsTab({super.key});
  @override
  State<BeliefsTab> createState() => _BeliefsTabState();
}

class _BeliefsTabState extends State<BeliefsTab> {
  bool _showReminder = false;
  bool _showNotes = false;
  bool _showScience = false;
  bool _showArchive = false;
  String? _selectedDay;

  // آکاردئونِ مراحل: هر مرحله یک کارت جمع‌شونده؛ محتوای هر مرحله اولین بار که
  // باز شد ساخته می‌شود و بعد زنده می‌ماند (تایمر/یادداشت/صدا گم نمی‌شود).
  int _openStep = 0;
  final List<GlobalKey> _stepKeys =
      List<GlobalKey>.generate(6, (_) => GlobalKey());

  // هایلایت بخش ویرایش‌شده‌ی متن خواسته (مثل EditMark وب)
  final GlobalKey _futureKey = GlobalKey();
  EditRange? _futureMark;
  int _futureMarkToken = 0;

  // تایمر تمرین
  Timer? _timer;
  int _timerSeconds = _kTimerTotal;
  bool _timerRunning = false;
  String _timerLabel = 'شروع';

  // یادداشت‌ها
  final Map<String, TextEditingController> _noteCtrls = {};
  final Map<String, Timer> _noteTimers = {};

  @override
  void dispose() {
    _timer?.cancel();
    for (final t in _noteTimers.values) {
      t.cancel();
    }
    for (final c in _noteCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BeliefsStore>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _header(store),
            if (_showReminder) _reminderPanel(store),
            const SizedBox(height: 14),

            // ═══ چرا این تمرین کار می‌کند؟ + مراحل تمرین (جمع‌شونده) ═══
            _scienceSection(store),
            const SizedBox(height: 12),

            // ═══ آماده‌سازی: موسیقی + تایمر ═══
            _prepCard(),
            const SizedBox(height: 18),

            // ═══ متن خواسته و تقویم + تصاویر ═══
            _mainSteps(store),
          ],
        ),
      ),
    );
  }

  // ═══════════════ هدر + یادآوری ═══════════════
  Widget _header(BeliefsStore store) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('بازنویسی باورها',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsInk,
                  )),
              SizedBox(height: 4),
              Text(
                'سیم‌کشی مغز بر پایه‌ی RAS، نوروپلاستیسیتی و روش دکتر جو دیسپنزا',
                style: TextStyle(
                    fontSize: 11.5, color: kBeliefsMuted, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'یادآوری روزانه',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _showReminder = !_showReminder),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: store.alarmEnabled
                    ? _kEmerald.withValues(alpha: 0.10)
                    : kBeliefsCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: store.alarmEnabled ? _kEmerald : kBeliefsBorder),
              ),
              child: Icon(
                store.alarmEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_none_outlined,
                size: 22,
                color: store.alarmEnabled ? _kEmerald700 : kBeliefsMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: kBeliefsInk)),
      );

  // ═══════════════ پیشرفت امروز ═══════════════
  // ═══════════════ آماده‌سازی: موسیقی + تایمر ═══════════════
  Widget _prepCard() {
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
          const Row(
            children: [
              Text('🎧', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text('آماده‌سازی',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kBeliefsInk)),
              ),
              Text('موسیقی و زمان‌سنج ۱۵ دقیقه‌ای',
                  style: TextStyle(fontSize: 10.5, color: kBeliefsMuted)),
            ],
          ),
          const SizedBox(height: 12),
          const BeliefMeditationMusic(),
          const SizedBox(height: 10),
          _timerBlock(),
        ],
      ),
    );
  }

  Widget _reminderPanel(BeliefsStore store) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('آلارم تمرین روزانه فعال باشد',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kBeliefsInk)),
              ),
              Switch(
                value: store.alarmEnabled,
                onChanged: (val) {
                  store.setAlarm(enabled: val);
                },
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(
                child: Text('ساعت یادآوری',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kBeliefsInk)),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kBeliefsInk,
                  side: const BorderSide(color: kBeliefsBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _pickAlarmTime(store),
                child: Text(_faStr(store.alarmTime),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ساعت و وضعیت آلارم ذخیره می‌شود.',
            style: TextStyle(fontSize: 11, color: kBeliefsMuted, height: 1.7),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAlarmTime(BeliefsStore store) async {
    final parts = store.alarmTime.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 20;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: h.clamp(0, 23).toInt(),
        minute: m.clamp(0, 59).toInt(),
      ),
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    await store.setAlarm(time: '$hh:$mm');
  }

  // ═══════════════ متن علمیِ «چرا این تمرین کار می‌کند؟» ═══════════════
  // همه‌ی متن‌ها راست‌به‌چپ؛ **...** = بولد (فقط برای کلمات فارسی)
  Widget _faRich(String text, {double size = 12, Color? color}) {
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd
            ? const TextStyle(fontWeight: FontWeight.w800, color: kBeliefsInk)
            : null,
      ));
    }
    return SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: size, color: color ?? _kInkSoft, height: 1.9),
          children: spans,
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _faItem(String marker, String text) => Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(marker,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                      fontSize: 12,
                      height: 1.9,
                      fontWeight: FontWeight.w800,
                      color: _kEmerald700)),
            ),
            Expanded(child: _faRich(text)),
          ],
        ),
      );

  Widget _faBullets(List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _faItem('•', t),
            ),
        ],
      );

  Widget _faNumbered(List<String> items) {
    const fa = ['۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _faItem('${fa[i]}.', items[i]),
          ),
      ],
    );
  }

  Widget _faBox(String text, {Color? accent}) => _accentBox(
        bg: (accent ?? _kEmerald).withValues(alpha: 0.08),
        accent: accent ?? _kEmerald,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        radius: 10,
        child: _faRich(text),
      );

  Widget _sciCard(String title, List<Widget> children, {String? sub}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.7,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsInk)),
            if (sub != null) ...[
              const SizedBox(height: 6),
              Text(sub,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.7,
                      fontWeight: FontWeight.w800,
                      color: _kEmerald700)),
            ],
            const SizedBox(height: 8),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _scienceArticle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sciCard('🧠 بخش اول: چرا مغز واقعیت را فیلتر می‌کند؟', [
          _faRich(
              'مغز ما در هر لحظه با انبوهی از اطلاعات روبه‌روست، اما نمی‌تواند همه‌ی آن‌ها را با هم ببیند. پس **مثل یک فیلتر عمل می‌کند**. چیزی که ما هر روز به‌عنوان «واقعیت» تجربه می‌کنیم، در واقع **حاصل انتخاب مغز** است. علم اعصاب قبول دارد که مغز ما «واقعیت محض» را نمی‌بیند؛ مغز یک **موتور پیش‌بینی‌کننده** (Predictive Processing) است و مدام بر اساس باورهای قبلی‌اش، دنیا را فیلتر می‌کند.'),
          _faBullets([
            '**اگر باورهای ما پر از «کمبود» باشد:** مغز (به‌خصوص **شبکه‌ی سالینس** (Salience Network) و **آمیگدال** (Amygdala)) فقط شواهدِ کمبود را می‌بیند. این همان چیزی است که در علم به آن **سوگیری توجه** (Attentional Bias) می‌گویند. در این حالت، **قشر پیش‌پیشانی** (Prefrontal Cortex یا PFC) که مسئول برنامه‌ریزی است، نمی‌تواند خوب کار کند.',
            '**اگر باورهایمان را تغییر بدهیم:** یعنی مدل پیش‌بینی مغز را آپدیت کنیم. در این حالت، مغز شروع می‌کند به دیدن شواهدِ جدید. علم به این پدیده **توجه گزینشی به فرصت‌ها** (Selective Attention to Opportunities) می‌گوید؛ همان چیزی که در زبان تجربه از آن به عنوان **اتصال به قلمرو ممکن‌ها** یاد می‌شود.',
          ]),
        ]),
        _sciCard('🌪️ بخش دوم: قبل از هیچ شدن (چرا ذهنمون شلوغه؟)', sub: 'شبکه‌ای که مغز را خسته می‌کند', [
          _faRich(
              'در مغز ما شبکه‌ای وجود دارد به نام **شبکه‌ی حالت پیش‌فرض** (Default Mode Network یا DMN). این شبکه دقیقاً وقتی که کاری نمی‌کنیم و ذهن آزاد است، روشن می‌شود. کارش چیست؟ رفتن به **گذشته** (حیف که اون حرف رو زدم) و **آینده** (نکنه فردا خراب بشه). همین شبکه است که باعث می‌شود ذهن ما مدام به خاطرات برگردد و **داستانی از «خودِ» ما** بسازد.'),
          _faRich(
              'وجود DMN لازم است، چون مغز بدون یک هویت نمی‌تواند بداند کیست. اما مشکل از آنجا شروع می‌شود که **این شبکه بیش از حد فعال می‌شود**. در این حالت، **آمیگدال** (مرکز هشدار و ترس مغز) همیشه روشن است. انگار یک نگهبان همیشه بیدار است که پشت هر اتفاقی دنبال یک خطر می‌گردد. وقتی آمیگدال روشن است، **قشر پیش‌پیشانی** (PFC) نمی‌تواند خوب کار کند. نتیجه‌اش چیست؟ **اضطراب، تصمیم‌های عجولانه** و این حس که **هیچ چیز کافی نیست**.'),
        ]),
        _sciCard('🧘‍♂️ بخش سوم: هیچ شدن (خالی کردن میز)', sub: 'هیچ شدن یعنی چی؟ (از نظر علم)', [
          _faRich(
              '**«هیچ شدن»** یعنی برای مدتی از **زمان، مکان و حتی بدنِ** خودمان فاصله بگیریم. یعنی نه به گذشته فکر کنیم، نه به آینده، و نه حتی درگیر احساسات فیزیکی بدن باشیم. در این سکوت و خالی بودن، **فعالیت** DMN **آرام‌تر می‌شود** و جلوی داستان‌های تکراری ذهن را می‌گیرد.'),
          _faRich(
              'علم اعصاب می‌گوید وقتی «هیچ» می‌شویم و از زمان، مکان، بدن و هویت فاصله می‌گیریم، در واقع **فعالیت چند شبکه‌ی خاص در مغز را کاهش می‌دهیم:**'),
          _faNumbered([
            '**هویت:** مربوط به شبکه‌ی حالت پیش‌فرض (DMN) و بخشی به نام قشر پیش‌پیشانی میانی (Medial Prefrontal Cortex یا mPFC) است. وقتی «هیچ» می‌شویم، این شبکه خاموش می‌شود و «منِ داستانی» فروکش می‌کند.',
            '**بدن:** مربوط به **اینسولا** (Insula) است. اینسولا حال درونی بدن را حس می‌کند و در این حالت به ما می‌گوید «الان بدنم آرومه، خطری نیست».',
            '**زمان:** مربوط به مخچه (Cerebellum) و عقده‌های قاعده‌ای (Basal Ganglia) است. وقتی ذهن آرام می‌شود، حس گذر زمان برایمان کندتر یا متوقف می‌شود.',
            '**مکان:** مربوط به هیپوکامپ (Hippocampus) و لوب آهیانه‌ای (Parietal Lobe) است. در حالت خالی شدن ذهن، حس مرزهای فیزیکی کم‌رنگ می‌شود.',
          ]),
          _faBox(
              '**نکته:** این بخش‌ها خاموش نمی‌شوند، بلکه **فعالیتشان متعادل می‌شود**. به همین دلیل است که حس «وحدت» و «آرامش عمیق» به وجود می‌آید.',
              accent: kBeliefsGold),
          _faRich(
              'حالا ذهن مثل **یک میز کار خالی و مرتب** شده است. مغز از حالت «بقا و مرور گذشته» خارج می‌شود و فضا برای **بازسازی الگوهای توجه** باز می‌گردد. حالا وقتشه که روی این میز خالی، **چیزی که می‌خواهیم** رو بذاریم.'),
        ]),
        _sciCard('📡 بخش چهارم: قدم اول بعد از هیچ شدن (فرستادن سیگنال امکان)', sub: 'به مغزت بگو «امکانش هست»', [
          _faRich(
              '«هیچ شدن» فقط میز را خالی می‌کند. اگر بعد از خالی شدن، به کمبودها فکر کنیم، **آمیگدال دوباره روشن می‌شود** و میز پر از ترس می‌شود. اما اگر در همین فضای خالی، روزانه روی **یک خواسته‌ی جدید** تمرکز کنیم (مثلاً با نوشتن یا تجسم)، داریم **«مدل پیش‌بینی» مغز را آپدیت می‌کنیم**. یعنی به قشر پیش‌پیشانی (PFC) می‌گوییم: «حالا به جای دنبال کردن خطرها، برو دنبال شواهدی بگرد که این خواسته را ممکن می‌کنند.»'),
          _faBox('**تمرین:** یک خواسته رو انتخاب کن و ۵ دقیقه با تمرکز روی اون بنویس یا تجسم کن.'),
        ]),
        _sciCard('📻 بخش پنجم: قدم دوم (تنظیم آنتن‌های توجه)', sub: 'تنظیم گیرنده‌های رادیو', [
          _faRich(
              'در مغز ما شبکه‌ای به اسم **شبکه‌ی برجستگی یا سالینس** (Salience Network) وجود دارد. کارش این است که **تصمیم می‌گیرد به چه چیزی توجه کنیم**. وقتی «هیچ» می‌شویم، این شبکه از حالت «شکار خطر» خارج می‌شود.'),
          _faRich(
              'در همین مسیر، سیستمی به نام RAS (**سیستم فعال‌ساز شبکه‌ای** / Reticular Activating System) در ساقه‌ی مغز نقش دارد. وقتی ذهن را «هیچ» و آرام می‌کنیم، این سیستم **سطح کلیِ هوشیاری و بیداری** را تنظیم می‌کند. اما **این** RAS **نیست که تصمیم می‌گیرد چه چیزی را ببینیم!** این **شبکه‌های توجه و پردازش قشری** مغز هستند که با یادگیری‌های جدید، مثل یک فیلتر عمل می‌کنند و به جای تمرکز روی تهدیدها، **به فرصت‌ها توجه می‌کنند**.'),
          _faRich(
              'حالا وقتشه که سالینس را روی خواسته‌ی جدید تنظیم کنیم. مثل **یک گیرنده رادیو** که روی یک ایستگاه خاص تنظیم می‌شود. در اینجا «فرکانس» یعنی **هماهنگی بین فکر، احساس و عمل**.'),
          _faBox('**تمرین:** هر روز صبح، به خودت یادآوری کن که امروز می‌خواهی به چه چیزی توجه کنی (نه به چه چیزی نگران باشی).'),
        ]),
        _sciCard('🛤️ بخش ششم: قدم سوم (هم‌ترازی شناختی و نوروپلاستیسیتی)', sub: 'ساختن مسیرهای جدید در مغز', [
          _faRich(
              'این همان **هم‌ترازی شناختی** (Cognitive Alignment) است. یعنی **فکر، احساس و عمل با هم هماهنگ شوند**. مغز در ابتدا مقاومت می‌کند، چون مسیرهای عصبی قدیمی (مثل ترس و کمبود) برایش راحت‌ترند. اما علم اعصاب می‌گوید مغز ما قابلیت **نوروپلاستیسیتی** (Neuroplasticity یا انعطاف‌پذیری عصبی) دارد. یعنی **با تمرین و تکرار، مسیرهای عصبی جدیدی ساخته می‌شوند**.'),
          _faBox(
              '**تمرین:** وقتی فکر را روی خواسته تنظیم کردیم، بلافاصله **یک قدم کوچک و فیزیکی** برمی‌داریم. این قدم به **دوپامین** (Dopamine یا نوروترنسمیتر انگیزه) سیگنال می‌دهد که «ما داریم به سمت هدف می‌رویم».'),
        ]),
        _sciCard('بخش هفتم: جمع‌بندی (چطور این تغییرات را در زندگی روزمره پیاده کنیم؟)', sub: 'از دانستن به انجام دادن', [
          _faRich(
              'حالا که فهمیدیم مغز چطور کار می‌کند، سؤال اصلی این است: چطور این‌ها را در زندگی واقعی پیاده کنیم؟ علم می‌گوید **جادویی در کار نیست؛ همه‌چیز به تمرین و تکرار بستگی دارد**. برای اینکه مغزت را از حالت «شکار خطر» به حالت «دیدن فرصت‌ها» ببری، این تمرین‌های ساده و روزمره را انجام بده:'),
          _faNumbered([
            '**تمرین نوشتن (۵ دقیقه در روز):** یک دفترچه بردار و هر روز صبح، فقط یک جمله درباره خواسته‌ات بنویس. مثلاً: «امروز چه قدم کوچکی می‌توانم برای نزدیک‌تر شدن به این هدف بردارم؟» همین نوشتن ساده، به مغزت سیگنال می‌دهد که این هدف برایت مهم است و باید به دنبال راه‌های رسیدن به آن بگردد.',
            '**تمرین خواندن (بازخوانی باور جدید):** جمله‌ای که نوشتی را یک بار با صدای بلند برای خودت بخوان. وقتی می‌خوانی، مغزت آن را به عنوان یک «واقعیت» ثبت می‌کند و کم‌کم مقاومتش را در برابر باورهای قدیمی کم می‌کند.',
            '**تمرین تجسم (۳۰ ثانیه):** چشمانت را ببند و ۳۰ ثانیه تجسم کن که به آن خواسته رسیده‌ای. چه حسی داری؟ این حسِ خوب، همان **دوپامین** است که ترشح می‌شود و به تو انگیزه می‌دهد.',
            '**قدم کوچک فیزیکی:** بلافاصله بعد از این تمرین‌ها، یک کار خیلی کوچک انجام بده. مثلاً یک پیام بفرست، یک صفحه کتاب بخوان، یا یک وسیله را آماده کن. این قدم به مغزت ثابت می‌کند که خواسته‌ات واقعی است.',
          ]),
          _faRich(
              'اگر این چرخه‌ی **«نوشتن، خواندن، تجسم و عمل کردن»** را روزانه تکرار کنی، مغزت مسیرهای عصبی جدیدی می‌سازد (نوروپلاستیسیتی). کم‌کم این باور جدید برای مغزت عادی می‌شود، **اضطرابش کم می‌شود** و توجهت به‌طور طبیعی روی فرصت‌هایی می‌رود که قبلاً از دیدت پنهان بودند.'),
          _faBox(
              'این یک جادوی بیرونی نیست؛ **یک مهارت مغزی است** که با «هیچ شدن» شروع می‌شود و با تمرین‌های ساده روزانه در درون تو شکل می‌گیرد.',
              accent: kBeliefsGold),
        ]),
      ],
    );
  }

  // ═══════════════ آکاردئونِ مراحل ═══════════════
  /// مراحل داخل بخش «چرا این تمرین کار می‌کند؟»:
  /// رهاسازی، هیچ شدن، اتصال، مأموریت ذهن
  Widget _practiceSteps(BeliefsStore store) {
    final steps = store.todaySteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _accordion(
          index: 0,
          title: 'رهاسازی',
          subtitle: 'تنفس و آرام‌سازی بدن',
          isDone: steps.contains('breath'),
          body: () => _breathBody(store),
        ),
        _accordion(
          index: 1,
          title: 'هیچ شدن',
          subtitle: 'رها کردن پنج لایه‌ی هویت',
          isDone: steps.contains('nothing'),
          body: () => _nothingBody(store),
        ),
        _accordion(
          index: 2,
          title: 'اتصال به قلمرو ممکن‌ها',
          subtitle: 'باز کردن کانال توجه',
          isDone: steps.contains('connection'),
          body: () => _connectionBody(store),
        ),
        _imagesIntro(),
        const SizedBox(height: 12),
        _accordion(
          index: 5,
          emoji: '🎯',
          title: 'مأموریت ذهن',
          subtitle: store.rasMission != null && store.rasMission!.label.isNotEmpty
              ? store.rasMission!.label
              : 'آموزش RAS برای دیدن نشانه‌ها',
          body: () => _missionStep(store),
        ),
      ],
    );
  }

  /// مراحل بیرونِ صفحه: «متن خواسته و تقویم» و «تصاویر»
  Widget _mainSteps(BeliefsStore store) {
    final steps = store.todaySteps;
    final v = store.activeVersion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _accordion(
          index: 3,
          title: 'متن خواسته و تقویم',
          subtitle: store.hasReadToday
              ? 'امروز ثبت شد ✓'
              : (v == null
                  ? 'متن خواسته‌ات را بنویس'
                  : 'بخوان و برای امروز ثبت کن'),
          isDone: steps.contains('seed'),
          body: () => _seedStep(store, steps),
        ),
        _accordion(
          index: 4,
          title: 'تصاویر',
          subtitle: 'تجسم و حسِ واقعیت دلخواه',
          isDone: steps.contains('images'),
          body: () => _imagesStep(store, steps),
        ),
      ],
    );
  }

  Widget _accordion({
    required int index,
    required String title,
    required String subtitle,
    required Widget Function() body,
    bool? isDone,
    String? emoji,
  }) {
    final open = _openStep == index;
    final done = isDone ?? false;
    return Container(
      key: _stepKeys[index],
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: open
              ? _kEmerald.withValues(alpha: 0.55)
              : (done ? _kEmerald300.withValues(alpha: 0.6) : kBeliefsBorder),
          width: open ? 1.5 : 1,
        ),
        boxShadow: open
            ? [
                BoxShadow(
                  color: _kEmerald.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  _stepBadge(index, done, emoji),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: kBeliefsInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: done ? _kEmerald700 : kBeliefsMuted,
                            fontWeight:
                                done ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (done)
                    Container(
                      margin: const EdgeInsetsDirectional.only(end: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kEmerald.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text('انجام شد',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _kEmerald700)),
                    ),
                ],
              ),
            ),
          ),
          // همه‌ی مراحل همیشه باز و قابل‌مشاهده‌اند (بدون کرکره)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
            child: body(),
          ),
        ],
      ),
    );
  }

  Widget _stepBadge(int index, bool done, String? emoji) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? _kEmerald : kBeliefsCream,
        border: Border.all(color: done ? _kEmerald : kBeliefsBorder),
      ),
      child: done
          ? const Icon(Icons.check, size: 19, color: Colors.white)
          : (emoji != null
              ? Text(emoji, style: const TextStyle(fontSize: 16))
              : Text(
                  _toFa(index + 1),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsMuted,
                  ),
                )),
    );
  }

  // ─── محتوای مرحله‌ها ───
  Widget _breathBody(BeliefsStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _whyBox([
          _defChip('رهاسازی (Relaxation):',
              'بدنت رو عمیقاً آروم کن تا از حالت آماده‌باش و تنش فاصله بگیری.'),
          _bodyText(
              'وقتی بدن آروم می‌شه، توجهت از فشارها و فکرهای روزمره جدا می‌شه. ذهنت آماده می‌شه برای تمرکز، تجسم و تجربه‌ی درونی.'),
        ]),
        const SizedBox(height: 14),
        const BreathCircle(),
      ],
    );
  }

  Widget _nothingBody(BeliefsStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _whyBox([
          _defChip('هیچ شدن (Becoming Nothing):',
              'برای مدتی از زمان، مکان، بدن و هویتِ خودمان فاصله می‌گیریم؛ نه به گذشته فکر می‌کنیم، نه به آینده، و نه درگیر احساسات فیزیکی بدن می‌شویم.'),
          _faRich(
              'در این سکوت و خالی بودن، **فعالیت** DMN **آرام‌تر می‌شود** و جلوی داستان‌های تکراری ذهن را می‌گیرد. با فاصله گرفتن از **هویت، بدن، زمان و مکان**، فعالیت چند شبکه‌ی خاص مغز متعادل می‌شود؛ این بخش‌ها خاموش نمی‌شوند، برای همین حس «وحدت» و «آرامش عمیق» پیدا می‌کنیم.',
              size: 11.5),
          const SizedBox(height: 6),
          _faRich(
              'حالا ذهن مثل **یک میز کار خالی و مرتب** است و وقتشه روی این میز، چیزی که می‌خواهیم را بگذاریم.',
              size: 11.5),
        ]),
        const SizedBox(height: 14),
        const Text(
          'پنج لایه رو یکی‌یکی رها کن — با هر تیک، غبار کمتر و آگاهی روشن‌تر:',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: kBeliefsInk),
        ),
        const SizedBox(height: 10),
        NothingScene(
          doneLayers: store.todayNothingLayers,
          onToggle: (key) {
            store.toggleNothingLayer(key);
          },
        ),
        const SizedBox(height: 12),
        _accentBox(
          bg: _kYellow.withValues(alpha: 0.08),
          accent: kBeliefsGold,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          radius: 8,
          child: _faRich(
              'این «هیچ» منفی نیست — **میز خالی** است؛ مثل صفحه‌ی سفیدی که همه‌چیز را در خودش جا می‌دهد.',
              size: 11),
        ),
      ],
    );
  }

  Widget _connectionBody(BeliefsStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _whyBox([
          _defChip('اتصال (Connection):',
              'در این حالت خالی و آروم، RAS مغزت دوباره تنظیم می‌شه و می‌تونه فرصت‌ها و نشانه‌هایی رو ببینه که قبلاً از فیلتر توجهت رد می‌شدن.'),
          _bodyText(
              'این یه تمرین ذهن‌آگاهی برای بازکردن کانال توجهه — نه ارسال سیگنال به یک میدان بیرونی.'),
        ]),
        const SizedBox(height: 10),
        const QuantumConnect(),
      ],
    );
  }

  // ═══════════════ پشتوانه‌ی علمی ═══════════════
  Widget _scienceSection(BeliefsStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _showScience = !_showScience),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kBeliefsCream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBeliefsBorder),
            ),
            child: Row(
              children: [
                const Text('📖', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('چرا این تمرین کار می‌کند؟',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: kBeliefsInk)),
                      SizedBox(height: 2),
                      Text('نوروپلاستیسیتی، RAS و معنای «هیچ شدن»',
                          style: TextStyle(
                              fontSize: 11, color: kBeliefsMuted)),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _showScience ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more,
                      size: 24, color: kBeliefsMuted),
                ),
              ],
            ),
          ),
        ),
        // محتوا همیشه ساخته می‌شود و فقط پنهان می‌شود، تا تایمر/یادداشت/صدای
        // مراحل با بستن کرکره گم نشود.
        Offstage(
          offstage: !_showScience,
          child: TickerMode(
            enabled: _showScience,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                _scienceArticle(),
                const SizedBox(height: 8),
                _sectionLabel('مراحل تمرین'),
                const SizedBox(height: 8),
                _practiceSteps(store),
              ],
            ),
          ),
        ),
      ],
    );
  }

// ═══════════════ تایمر ═══════════════
Widget _timerBlock() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: kBeliefsCream,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Text('⏱ زمان تمرین',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: kBeliefsInk)),
        const Spacer(),
        Text(_fmtTimer(_timerSeconds),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: kBeliefsInk,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(width: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: kBeliefsInk,
            side: const BorderSide(color: kBeliefsBorder),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _toggleTimer,
          child: Text(_timerLabel, style: const TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );
}

void _toggleTimer() {
  if (_timerRunning) {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _timerLabel = 'ادامه';
    });
    return;
  }
  if (_timerSeconds <= 0) {
    _timerSeconds = _kTimerTotal;
  }
  setState(() {
    _timerRunning = true;
    _timerLabel = 'توقف';
  });
  _timer?.cancel();
  _timer = Timer.periodic(const Duration(seconds: 1), (t) {
    if (!mounted) {
      t.cancel();
      return;
    }
    if (_timerSeconds <= 1) {
      t.cancel();
      HapticFeedback.heavyImpact();
      setState(() {
        _timerSeconds = 0;
        _timerRunning = false;
        _timerLabel = 'پایان';
      });
      return;
    }
    setState(() => _timerSeconds--);
  });
}

// ═══════════════ مرحله‌ی متن خواسته + تقویم ═══════════════
Widget _seedStep(BeliefsStore store, Set<String> steps) {
  final v = store.activeVersion;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _whyBox([
        _bodyText(
            'متن خواسته‌ات رو یک بار با حس بخون (بلند یا توی ذهن) و بعد «امروز خوندم» رو بزن تا تقویم و رشته‌ی عصبی‌ات جلو بره.'),
      ]),
      const SizedBox(height: 12),
      _futureBox(store),
      const SizedBox(height: 10),
      _actionsRow(store),
      const SizedBox(height: 10),
      _registerButton(store, v),
      const SizedBox(height: 12),
      if (_showArchive) ...[
        _archiveBox(store),
        const SizedBox(height: 10),
      ],
      _calendarSection(store, v),
      if (_showNotes) ...[
        const SizedBox(height: 12),
        _notesBox(store),
      ],
    ],
  );
}

Widget _futureBox(BeliefsStore store) {
  final text = (store.activeVersion?.text ?? '').trim();

  return GestureDetector(
    key: _futureKey,
    onTap: () => _openEditor(store),
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: text.isNotEmpty
          ? SizedBox(
              width: double.infinity,
              child: EditMarkedText(
                text: text,
                range: _futureMark,
                prefix: '«',
                suffix: '»',
                style: store.format.buildStyle(color: kBeliefsInk),
                textAlign: store.format.textAlign,
              ),
            )
          : const Column(
              children: [
                SizedBox(height: 6),
                Text(
                  'هنوز چیزی ثبت نکردی.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: kBeliefsMuted),
                ),
                SizedBox(height: 4),
                Text(
                  'روی همین کادر بزن و بنویس.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: kBeliefsMuted),
                ),
                SizedBox(height: 6),
              ],
            ),
    ),
  );
}

/// دکمه‌های «ویرایش» و «آرشیو»
Widget _actionsRow(BeliefsStore store) {
  return Row(
    children: [
      Expanded(
        child: _tinyBtn('ویرایش', () => _openEditor(store)),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: _tinyBtn(
          '📚 آرشیو (${_toFa(store.versions.length)})',
          () => setState(() => _showArchive = !_showArchive),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: _tinyBtn(
          _showNotes ? '📝 بستن یادداشت' : '📝 یادداشت',
          () => setState(() => _showNotes = !_showNotes),
          gold: _showNotes,
        ),
      ),
    ],
  );
}

Widget _registerButton(BeliefsStore store, FutureVersion? v) {
  final read = store.hasReadToday;
  var label = '✅ امروز خوندم — ثبت کن';
  if (read && v != null) {
    final ms = v.readTimes[_dayKey(DateTime.now())];
    label = ms == null
        ? '✓ امروز ثبت شد'
        : '✓ امروز ثبت شد — ساعت ${_fmtTime(ms)}';
  }
  final shape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  const labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w800);

  if (read) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _kEmerald700,
        side: const BorderSide(color: _kEmerald, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: shape,
      ),
      onPressed: () => _registerToday(store),
      child: Text(label, style: labelStyle),
    );
  }
  return FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: _kEmerald700,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: shape,
    ),
    onPressed: () => _registerToday(store),
    child: Text(label, style: labelStyle),
  );
}

Future<void> _registerToday(BeliefsStore store) async {
  final v = store.activeVersion;
  if (v == null || v.text.trim().isEmpty) {
    _toast('اول متن خواسته‌ات را بنویس');
    return;
  }
  final already = store.hasReadToday;
  await store.markReadToday();
  if (!mounted) return;
  final tk = _dayKey(DateTime.now());
  setState(() => _selectedDay = tk);
  if (!already) {
    final ms = v.readTimes[tk];
    final timeTxt = ms == null ? '' : ' — ساعت ${_fmtTime(ms)}';
    _toast('✓ امروز ثبت شد$timeTxt');
  }
}

// ─── آرشیو نسخه‌ها ───
Widget _archiveBox(BeliefsStore store) {
  final list = store.versions;

  return Container(
    padding: const EdgeInsets.all(10),
    constraints: const BoxConstraints(maxHeight: 300),
    decoration: BoxDecoration(
      color: kBeliefsCream,
      borderRadius: BorderRadius.circular(12),
    ),
    child: list.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'هنوز نسخه‌ای ذخیره نشده.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: kBeliefsMuted),
            ),
          )
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('📚 همه‌ی نسخه‌های تو',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kBeliefsInk)),
                ),
                for (var i = list.length - 1; i >= 0; i--)
                  _versionTile(store, list[i], i),
              ],
            ),
          ),
  );
}

Widget _versionTile(BeliefsStore store, FutureVersion v, int index) {
  final isActive = v.id == store.activeVersionId;
  final activeTxt = isActive ? ' • فعال' : '';
  final end = v.endDate ?? 'اکنون';
  final preview =
      v.text.length > 100 ? '${v.text.substring(0, 100)}...' : v.text;

  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: isActive ? _kEmerald.withValues(alpha: 0.06) : kBeliefsCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: isActive ? _kEmerald : kBeliefsBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('نسخه ${_toFa(index + 1)}$activeTxt',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsInk)),
            const Spacer(),
            Text('${_toFa(v.readDays.length)} روز',
                style:
                    const TextStyle(fontSize: 9.5, color: kBeliefsMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Text('${v.startDate} تا $end',
            style: const TextStyle(fontSize: 10, color: kBeliefsMuted)),
        if (v.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: kBeliefsCream,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('«$preview»',
                style: const TextStyle(
                    fontSize: 11,
                    color: _kInkSoft,
                    height: 1.6,
                    fontStyle: FontStyle.italic)),
          ),
        ],
        if (!isActive) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _tinyBtn('فعال کردن', () async {
                  await store.activateVersion(v.id);
                  if (!mounted) return;
                  setState(() => _selectedDay = null);
                  _toast('نسخه فعال شد ✓');
                }),
              ),
              const SizedBox(width: 6),
              _tinyBtn('🗑 حذف', () async {
                final ok = await _confirm(
                    'این نسخه از آرشیو برای همیشه حذف شود؟');
                if (!ok) return;
                await store.deleteVersion(v.id);
                if (!mounted) return;
                _toast('نسخه حذف شد');
              }, color: const Color(0xFFC0392B)),
            ],
          ),
        ],
      ],
    ),
  );
}
    // ─── تقویم پیشرفت ───
  Widget _calendarSection(BeliefsStore store, FutureVersion? v) {
    // تقویم همیشه دیده می‌شه؛ قبل از نوشتن متن، با یک نسخه‌ی خالیِ موقت (از امروز) نشون داده می‌شه.
    final noText = v == null;
    final cal = v ?? FutureVersion(startDate: _dayKey(DateTime.now()));

    final total = store.cycleDays;

    return BeliefsPeriodCalendar(
      pal: GratPalette.of(context),
      startKey: cal.startDate,
      total: total,
      readDays: cal.readDays.toSet(),
      readTimes: cal.readTimes,
      cycles: cal.cycles,
      finished: store.cycleFinished,
      noText: noText,
      onDays: () => _openCycleDaysDialog(store),
      onReset: () => _confirmResetCalendar(store),
    );
  }

  // ─── یادداشت‌های بذر امروز ───
  Widget _notesBox(BeliefsStore store) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBeliefsCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'بذری که امروز می‌کاری رو این‌جا بنویس. با «همین حالا...» شروع کن.',
            style: TextStyle(fontSize: 11.5, color: kBeliefsMuted, height: 1.7),
          ),
          const SizedBox(height: 10),
          _labeledNote(store, 'main', 'بذر اصلی امروز:', 3),
          const SizedBox(height: 10),
          _labeledNote(
              store, 'feel', 'چطور حسش می‌کنم اگه همین حالا حقیقت داشت؟', 2),
          const SizedBox(height: 10),
          _labeledNote(store, 'release', 'چی رو رها می‌کنم؟', 2),
        ],
      ),
    );
  }

  Widget _labeledNote(
      BeliefsStore store, String key, String label, int lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11.5, color: kBeliefsInk)),
        const SizedBox(height: 4),
        _noteField(store, key, lines: lines),
      ],
    );
  }

  TextEditingController _noteCtrl(BeliefsStore store, String key) {
    return _noteCtrls.putIfAbsent(
      key,
      () => TextEditingController(text: store.seedNotes[key] ?? ''),
    );
  }

  Widget _noteField(BeliefsStore store, String key,
      {String? hint, int lines = 2}) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextField(
      controller: _noteCtrl(store, key),
      minLines: lines,
      maxLines: null,
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontSize: 12.5, color: kBeliefsInk, height: 1.8),
      onChanged: (val) {
        store.seedNotes[key] = val;
        _noteTimers[key]?.cancel();
        _noteTimers[key] = Timer(const Duration(milliseconds: 500), () {
          store.setSeedNote(key, val);
        });
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kBeliefsMuted, fontSize: 12),
        filled: true,
        fillColor: kBeliefsCard,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: border(kBeliefsBorder, 1),
        enabledBorder: border(kBeliefsBorder, 1),
        focusedBorder: border(kBeliefsGold, 1.5),
      ),
    );
  }

  // ═══════════════ مرحله‌ی تصاویر ═══════════════
  /// توضیحات مرحله‌ی «تصاویر» (داخل بخش «چرا این تمرین کار می‌کند؟»)
  Widget _imagesIntro() {
    return _whyBox([
      _defChip('کاشتن بذر (Seeding):',
          'یه تصویر واضح از واقعیت دلخواهت توی ذهن می‌کاری — بدون حس نیاز یا کمبود.'),
      _bodyText(
          'خودت رو توی صحنه‌ای ببین که به خواسته‌ات رسیدی. هر تعداد عکس یا ویدیو که دوست داری اضافه کن.'),
      const SizedBox(height: 8),
      _defChip('احساس فراوانی (Embodying):',
          'حسِ اون واقعیت رو توی بدنت بساز — شادی، سلامتی، آرامش — تا فرکانست هماهنگ شه.'),
      _bodyText(
          'وقتی خودت رو «کسی که رسیده» می‌بینی و حسش می‌کنی، رفتارهایت خودبه‌خود با همون هویت هم‌راستا می‌شن.'),
    ]);
  }

  Widget _imagesStep(BeliefsStore store, Set<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // یادداشت (ذخیره/لغو) + ضبط صدا + ویدیو + عکس با برش + اسلایدشو
        const BeliefVisualSection(),
        const SizedBox(height: 14),
        const Divider(height: 1, color: kBeliefsBorder),
        const SizedBox(height: 12),
        const Text('🧠 مدار عصبی تمرین',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: kBeliefsInk)),
        const SizedBox(height: 8),
        NeuralPathway(
          container: store.neural,
          label: 'تمرین',
          showDayButtons: false,
          onChange: () {
            store.saveNeural();
          },
        ),
      ],
    );
  }

  // ═══════════════ مأموریت ذهن ═══════════════
  Widget _missionStep(BeliefsStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ذهنت رو برای دیدن چیزی که تا حالا ازش رد می‌شدی، آموزش بده.',
          style: TextStyle(fontSize: 11.5, color: kBeliefsMuted, height: 1.75),
        ),
        const SizedBox(height: 14),
        const RasMission(),
        const SizedBox(height: 14),
        const Divider(height: 1, color: kBeliefsBorder),
        const SizedBox(height: 12),
        const Text('🧠 مدار عصبی مأموریت',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: kBeliefsInk)),
        const SizedBox(height: 8),
        NeuralPathway(
          container: store.missionNeural,
          label: 'ردیابی RAS',
          showDayButtons: false,
          onChange: () {
            store.saveNeural();
          },
        ),
      ],
    );
  }

  // ═══════════════ اجزای مشترک ═══════════════
  Widget _whyBox(List<Widget> children) {
    return _accentBox(
      bg: _kEmerald.withValues(alpha: 0.06),
      accent: _kEmerald300,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      radius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _accentBox({
    required Color bg,
    required Color accent,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(12),
    double radius = 8,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          border: Border(right: BorderSide(color: accent, width: 3)),
        ),
        child: child,
      ),
    );
  }

  Widget _defChip(String title, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _kYellow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kYellow.withValues(alpha: 0.4)),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kEmerald700,
            height: 1.75,
          ),
          children: [
            const TextSpan(text: '📖 '),
            TextSpan(
              text: title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: ' $text'),
          ],
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11.5, color: _kInkSoft, height: 1.8),
    );
  }

  Widget _rich(String text) {
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd
            ? const TextStyle(fontWeight: FontWeight.w800, color: kBeliefsInk)
            : null,
      ));
    }
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12, color: _kInkSoft, height: 1.9),
        children: spans,
      ),
    );
  }

  Widget _tinyBtn(String label, VoidCallback onTap,
      {Color? color, bool gold = false}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? kBeliefsInk,
        backgroundColor:
            gold ? kBeliefsGold.withValues(alpha: 0.12) : kBeliefsCard,
        side: BorderSide(color: gold ? kBeliefsGold : kBeliefsBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ═══════════════ handlers ═══════════════
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).quietSnack(
      SnackBar(content: Text(msg)),
    );
  }

  Future<bool> _confirm(String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBeliefsCard,
        content: Text(
          msg,
          style: const TextStyle(color: kBeliefsInk, fontSize: 13, height: 1.7),
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
    return ok == true;
  }

  Future<void> _openEditor(BeliefsStore store) async {
    final cur = store.activeVersion;
    final hadVersion = cur != null;
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
    if (result == null || result.trim().isEmpty) return;
    if (result.trim() == initial.trim()) return;
    await store.saveText(result);
    if (!mounted) return;
    // بخش تغییرکرده را هایلایت کن و صفحه را روی همان‌جا ببر
    final range = hadVersion ? diffEditRange(initial.trim(), result.trim()) : null;
    final token = ++_futureMarkToken;
    setState(() => _futureMark = range);
    if (range != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _futureKey.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx,
              alignment: 0.3, duration: const Duration(milliseconds: 400));
        }
      });
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && token == _futureMarkToken) {
          setState(() => _futureMark = null);
        }
      });
    }
    _toast(hadVersion
        ? 'متن ویرایش شد ✏ (دوره و تقویم همان‌طور ماند)'
        : 'متن خواسته‌ات ثبت شد ✨');
  }

  Future<void> _openCycleDaysDialog(BeliefsStore store) async {
    final ctrl = TextEditingController(text: _toFa(store.cycleDays));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBeliefsCard,
        title: const Text('دوره‌ی خواندن چند روزه باشه؟',
            style: TextStyle(fontSize: 15, color: kBeliefsInk)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('بین ۱ تا ${_toFa(kFutureMaxDays)} روز',
                style: const TextStyle(fontSize: 12, color: kBeliefsMuted)),
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
        // راست‌چین: اولین دکمه سمت راست می‌افتد → ذخیره راست، لغو چپ
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kBeliefsGold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ذخیره'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لغو', style: TextStyle(color: kBeliefsMuted)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final n = int.tryParse(_normDigits(ctrl.text.trim()));
    if (n == null || n < 1 || n > kFutureMaxDays) {
      _toast('یه عدد بین ۱ تا ${_toFa(kFutureMaxDays)} وارد کن');
      return;
    }

    final changed = n != store.cycleDays;
    await store.setCycleDays(n);
    if (!mounted) return;

    if (changed && store.activeVersion != null) {
      final restart = await _confirm(
        'دوره از امروز از نو شروع بشه؟\nثبت‌های این دوره در تاریخچه‌ی همین نسخه نگه داشته می‌شن.',
      );
      if (!mounted) return;
      if (restart) {
        await store.resetCalendar();
        if (!mounted) return;
        setState(() => _selectedDay = null);
      }
    }
    _toast('دوره روی ${_toFa(n)} روز تنظیم شد 🌱');
  }

  Future<void> _confirmResetCalendar(BeliefsStore store) async {
    if (store.activeVersion == null) {
      _toast('اول متن خواسته‌ات را بنویس');
      return;
    }
    final ok = await _confirm(
      'تقویم از امروز از نو شروع بشه؟\nثبت‌های این دوره در تاریخچه‌ی همین نسخه نگه داشته می‌شن. متن و مسیر عصبی دست نمی‌خورن.',
    );
    if (!ok) return;
    await store.resetCalendar();
    if (!mounted) return;
    setState(() => _selectedDay = null);
    _toast('تقویم ریست شد — دوره‌ی تازه از امروز 🌱');
  }
}

// ═══════════════ توابع کمکی ═══════════════
String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

DateTime _parseDayKey(String k) {
  final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
  if (p.length != 3) return DateTime.now();
  return DateTime(p[0], p[1], p[2]);
}

bool _isFutureDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return d.isAfter(today);
}

String _faStr(String s) => s.replaceAllMapped(
      RegExp(r'\d'),
      (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
    );

String _toFa(int n) => _faStr(n.toString());

String _normDigits(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = fa.indexOf(ch);
    final j = ar.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (j >= 0) {
      b.write(j);
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

String _fmtTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return _faStr('$hh:$mm');
}

String _fmtTimer(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return _faStr('$m:$s');
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
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
                        style:
                            TextStyle(fontSize: 11.5, color: kBeliefsMuted),
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
                            borderSide:
                                const BorderSide(color: kBeliefsBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: kBeliefsBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: kBeliefsGold, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // دکمه‌های لغو / ذخیره همیشه پایین و در دسترس می‌مانند
              Row(
                children: [
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
                          ScaffoldMessenger.of(context).quietSnack(
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kBeliefsMuted,
                        backgroundColor: kBeliefsCard,
                        side: const BorderSide(color: kBeliefsBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('لغو'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
