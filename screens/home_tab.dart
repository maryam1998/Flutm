import 'package:flutter/material.dart';
import '../widgets/web_theme_banner.dart';
import 'package:provider/provider.dart';

import '../data/gratitude_journey.dart';
import '../state/abundance_store.dart';
import '../state/gratitude_store.dart';
import '../state/emotion_store.dart';
import '../utils/money_format.dart';
import '../widgets/abundance_card.dart';
import '../widgets/abundance_settings_sheet.dart';
import '../widgets/card_edit_sheet.dart';

const _kCream = Color(0xFFF7F6F1);
const _kCard = Colors.white;
const _kGold = Color(0xFFC9A24B);
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF7C8B87);
const _kBorder = Color(0xFFE7E5DB);
const _kEmerald = Color(0xFF178A7C);

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _text = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _addGratitude() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final grat = context.read<GratitudeStore>();
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await grat.add(
        text: text,
        shared: false,
        emotions: context.read<EmotionStore>(),
      );
      _text.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ثبت شد — فقط برای خودم 🤫')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AbundanceStore>();
    final grat = context.watch<GratitudeStore>();
    final phase = computeGratitudePhase(grat.journeyDay, grat.journeyDays);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _greeting(),
            const SizedBox(height: 12),
            AbundanceCard(
              balance: store.balance,
              card: store.card,
              onEdit: () => CardEditSheet.show(
                context: context,
                initial: store.card,
                onSave: (c) => store.updateCard(c),
              ),
            ),
            const SizedBox(height: 12),
            _todayBanner(store),
            const SizedBox(height: 10),
            _settingsBtn(store),
            const SizedBox(height: 16),
            _journeyBanner(phase, grat),
            const SizedBox(height: 16),
            _quickAdd(),
            const SizedBox(height: 20),
            _recentList(grat),
          ],
        ),
      ),
    );
  }

  Widget _greeting() {
    final h = DateTime.now().hour;
    String word;
    if (h < 6) {
      word = 'شب بخیر ✦';
    } else if (h < 12) {
      word = 'صبح بخیر ✦';
    } else if (h < 17) {
      word = 'ظهر بخیر ✦';
    } else if (h < 20) {
      word = 'عصر بخیر ✦';
    } else {
      word = 'شب بخیر ✦';
    }
    return Row(
      children: [
        const Text('🌿', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Text(
          word,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: _kInk),
        ),
      ],
    );
  }

  Widget _todayBanner(AbundanceStore store) {
    final isZero = store.balance <= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _kGold,
              shape: BoxShape.circle,
            ),
            child: Text(
              toFaDigits(store.daysPassed.toString()),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isZero
                  ? '🎉 امروز همه‌ی ${formatMoney(store.todayDeposit)} رو خرج کردی؛ فردا مبلغ بزرگ‌تری منتظرته'
                  : 'امروز ${formatMoney(store.todayDeposit)} به حسابت اضافه شد ✨ — باید همین امروز خرجش کنی',
              style: const TextStyle(
                  fontSize: 11.5, color: _kInk, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsBtn(AbundanceStore store) {
    return Material(
      color: _kCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => AbundanceSettingsSheet.show(
          context: context,
          startAmount: store.settings.startAmount,
          step: store.settings.step,
          onSave: (v) => store.updateSettings(
            startAmount: v.startAmount,
            step: v.step,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: const Row(
            children: [
              Text('⚙️ ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(
                  'تنظیم مبلغ شروع بازی فراوانی',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _kInk),
                ),
              ),
              Icon(Icons.chevron_left, size: 18, color: _kMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _journeyBanner(GratitudePhaseInfo phase, GratitudeStore grat) {
    final pct = (phase.day / phase.totalDays).clamp(0.0, 1.0);
    return WebThemeBanner(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('🧭 مسیر ۲۸ روزه شکرگذاری',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xD9FFFFFF))),
              const Spacer(),
              Text(
                'روز ${toFaDigits(phase.day.toString())} / ${toFaDigits(phase.totalDays.toString())}',
                style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xBFFFFFFF)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'فاز ${toFaDigits((phase.phaseIndex + 1).toString())} — ${phase.phaseName}',
            style: const TextStyle(
                fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '🎯 ${phase.prompt}',
            style: const TextStyle(
                fontSize: 12, color: Color(0xD9FFFFFF), height: 1.7),
          ),
          const SizedBox(height: 10),
          WebBannerBar(value: pct),
        ],
      ),
    );
  }

  Widget _quickAdd() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🧠 مغزت رو تربیت کن تا داشته‌هات رو ببینه',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: _kInk),
          ),
          const SizedBox(height: 4),
          const Text(
            'طبق علم اعصاب، هر بار شکرگذاری می‌کنی، مسیرهای عصبیِ مثبت‌نگری در مغزت قوی‌تر می‌شن.',
            style: TextStyle(fontSize: 11.5, color: _kMuted, height: 1.7),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 3,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 13, color: _kInk, height: 1.7),
            decoration: InputDecoration(
              hintText: '۱ - خدایا شکرت که:',
              hintStyle: const TextStyle(color: _kMuted, fontSize: 12),
              filled: true,
              fillColor: _kCream,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kGold, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving ? null : _addGratitude,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'ثبت شکرگذاری',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentList(GratitudeStore grat) {
    final list = grat.allReversed.take(3).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '🌱 آخرین شکرگذاری‌ها',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: _kInk),
        ),
        const SizedBox(height: 8),
        ...list.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kCream,
                      shape: BoxShape.circle,
                      border: Border.all(color: _kBorder),
                    ),
                    child: Text(e.icon, style: const TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.displayText(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: _kInk, height: 1.6),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${e.day} ${e.time}',
                          style: const TextStyle(
                              fontSize: 10, color: _kMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
