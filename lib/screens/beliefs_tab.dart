import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/breath_circle.dart';
import '../widgets/nothing_scene.dart';
import '../models/future_text_format.dart';
import '../models/future_version.dart';
import '../state/beliefs_store.dart';
import '../widgets/format_bar.dart';
import '../widgets/mini_calendar_90.dart';

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
            // هدر
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

            const SizedBox(height: 16),

            // ═══ کارت تمرین روزانه ═══
            _dailyPracticeCard(),
          ],
        ),
      ),
    );
  }

  // ---------- کارت متن آینده ----------

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
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
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

  // ---------- ردیف اکشن‌ها ----------

  Widget _actionsRow(BeliefsStore store, FutureVersion? v) {
    final hasText = v != null && v.text.trim().isNotEmpty;
    final readToday = store.hasReadToday;
    final finished = store.cycleFinished;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // نوار دوره
        if (hasText)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  'روز ${_toFa(store.currentDay)} از ${_toFa(store.cycleDays)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kBeliefsInk,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_toFa(store.readDayCount)} روز خونده',
                  style: const TextStyle(fontSize: 11, color: kBeliefsMuted),
                ),
              ],
            ),
          ),

        // دکمه‌ی اصلی ثبت
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: readToday ? kBeliefsCard : kBeliefsGold,
              foregroundColor: readToday ? kBeliefsInk : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: readToday ? kBeliefsGold : Colors.transparent,
                    width: 1.5),
              ),
            ),
            onPressed: !hasText
                ? null
                : (readToday ? null : () => _markRead(store)),
            icon: Icon(readToday ? Icons.check_circle : Icons.menu_book,
                size: 18),
            label: Text(
              readToday ? '✓ امروز ثبت شد' : '📖 امروز خوندم',
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),

        if (finished && hasText)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kBeliefsGold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: kBeliefsGold.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎉 دوره‌ی ${_toFa(store.cycleDays)} روزه تموم شد — ${_toFa(store.readDayCount)} روز از ${_toFa(store.cycleDays)} رو خوندی.',
                    style: const TextStyle(
                        fontSize: 12, color: kBeliefsInk, height: 1.8),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: kBeliefsGold,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _resetCalendar(store),
                          child: const Text('▶ شروع دوره‌ی تازه',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        if (hasText && !finished)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kBeliefsInk,
                      side: const BorderSide(color: kBeliefsBorder),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _openCycleDaysDialog(store),
                    icon: const Icon(Icons.settings, size: 15),
                    label: Text(
                      'روزهای دوره (الان ${_toFa(store.cycleDays)})',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kBeliefsInk,
                      side: const BorderSide(color: kBeliefsBorder),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _confirmResetCalendar(store),
                    icon: const Icon(Icons.refresh, size: 15),
                    label: const Text('ریست تقویم',
                        style: TextStyle(fontSize: 11.5)),
                  ),
                ),
              ],
            ),
          ),

        // آرشیو
        if (store.versions.length > 1 || hasText)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kBeliefsInk,
                side: const BorderSide(color: kBeliefsBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _openArchive(store),
              icon: const Icon(Icons.history, size: 16),
              label: Text(
                '📚 آرشیو نسخه‌ها (${_toFa(store.versions.length)})',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- handlers ----------

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
          const SnackBar(content: Text('ثبت شد ✓ — یک روز دیگه به مسیرت اضافه شد')),
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
            const Text(
              'بین ۱ تا ۳۶۵ روز',
              style: TextStyle(fontSize: 12, color: kBeliefsMuted),
            ),
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
        const SnackBar(content: Text('تقویم ریست شد — دوره‌ی تازه از امروز 🌱')),
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

  // ═══════════════════════════════════════════
  // کارت تمرین روزانه (دیسپنزا)
  // ═══════════════════════════════════════════
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
                '${_doneLayers.length} از ۵ مرحله',
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

          // ═══ مرحله ۱: رهاسازی ═══
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
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF8),
              border: const Border(
                right: BorderSide(color: Color(0xFF54C9B8), width: 3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📖 رهاسازی (Relaxation): بدنت رو عمیقاً آروم کن تا از حالت آماده‌باش و تنش فاصله بگیری.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F5B53),
                    height: 1.75,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'وقتی بدن آروم می‌شه، توجهت از فشارها و فکرهای روزمره جدا می‌شه.',
                  style: TextStyle(fontSize: 11.5, color: kBeliefsMuted, height: 1.8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const BreathCircle(),
          const SizedBox(height: 18),

          // ═══ مرحله ۲: هیچ شدن ═══
          _stepHeader(
            number: '۲',
            title: 'هیچ شدن',
            isDone: _doneLayers.length >= 5,
            onToggle: () {},
            trailing: const Text('🔔', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF8),
              border: const Border(
                right: BorderSide(color: Color(0xFF54C9B8), width: 3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📖 هیچ شدن (Becoming Nothing): توجهت رو از بدن، محیط و هویت «من» برمی‌داری.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F5B53),
                    height: 1.75,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '«هیچ شدن» یعنی رها کردن هویت‌های شرطی‌شده.',
                  style: TextStyle(fontSize: 11.5, color: kBeliefsMuted, height: 1.8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'پنج لایه رو یکی‌یکی رها کن:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBeliefsInk),
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
}

// ============================================================
// ویرایشگر متن
// ============================================================
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

                // نوار فرمت
                FormatBar(
                  format: _fmt,
                  onChange: (f) {
                    setState(() => _fmt = f);
                    widget.onFormatChange(f);
                  },
                ),
                const SizedBox(height: 10),

                // textarea
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
                      borderSide: const BorderSide(color: kBeliefsGold, width: 1.5),
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

// ============================================================
// شیت آرشیو
// ============================================================
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
              const Text(
                '📚 آرشیو نسخه‌ها',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kBeliefsInk,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'هر بار متن رو عوض می‌کنی، نسخه‌ی قبلی اینجا نگه داشته می‌شه.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: kBeliefsMuted),
              ),
              const SizedBox(height: 14),

              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final v = list[i];
                    final isActive = v.id == store.activeVersionId;
                    return _versionTile(context, v, isActive);
                  },
                ),
              ),

              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kBeliefsInk,
                  side: const BorderSide(color: kBeliefsBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('بستن'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _versionTile(BuildContext context, FutureVersion v, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBeliefsCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? kBeliefsGold : kBeliefsBorder,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'نسخه ${_toFa(store.versions.indexOf(v) + 1)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kBeliefsInk,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kBeliefsGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'فعال',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: kBeliefsGold),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${_toFa(v.readDays.length)} روز',
                style: const TextStyle(fontSize: 10.5, color: kBeliefsMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${v.startDate} تا ${v.endDate ?? "اکنون"}',
            style: const TextStyle(fontSize: 10, color: kBeliefsMuted),
          ),
          if (v.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kBeliefsCream,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '«${v.text.length > 120 ? "${v.text.substring(0, 120)}…" : v.text}»',
                style: const TextStyle(
                  fontSize: 11,
                  color: kBeliefsInk,
                  fontStyle: FontStyle.italic,
                  height: 1.7,
                ),
              ),
            ),
          ],
          if (!isActive) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: kBeliefsGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await store.activateVersion(v.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('فعال کردن',
                        style: TextStyle(fontSize: 11.5)),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE5484D),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0x33E5484D)),
                    ),
                  ),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: kBeliefsCard,
                        content: const Text(
                          'این نسخه برای همیشه حذف بشه؟',
                          style: TextStyle(color: kBeliefsInk),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('نه'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE5484D)),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await store.deleteVersion(v.id);
                  },
                  child: const Icon(Icons.delete_outline, size: 16),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _toFa(int n) => n.toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
      );
}
