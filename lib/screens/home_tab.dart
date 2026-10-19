import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/gratitude_journey.dart';
import '../state/abundance_store.dart';
import '../state/gratitude_store.dart';
import '../state/theme_store.dart';
import '../theme/grat_palette.dart';
import '../utils/money_format.dart';
import '../widgets/abundance_card.dart';
import '../widgets/abundance_settings_sheet.dart';
import '../widgets/card_edit_sheet.dart';
import '../widgets/web_theme_banner.dart';
import 'gratitude_tab.dart'
    show
        GratitudePeriodCalendar,
        GratitudeQuickAdd,
        GratitudeNeuralSection,
        GratitudeRecentList;

/// تب خانه — کپی دقیق `#view-home` مغز (renderHome در tamrin-tab.js):
/// سلام → کارت بانک → بنر امروز → تنظیم فراوانی → بنر فاز → تقویم دوره →
/// خرید جدید → quick-add → «انجام این تمرین» → «لیست شکرگذاری»
class HomeTab extends StatelessWidget {
  /// دکمه‌ی «خرید جدید» → رفتن به زیرتب «بازی فراوانی»
  final VoidCallback? onOpenStore;
  const HomeTab({super.key, this.onOpenStore});

  static const double _px = 18; // margin افقی بخش‌ها در وب

  @override
  Widget build(BuildContext context) {
    final pal = GratPalette.of(context);
    final store = context.watch<AbundanceStore>();
    final grat = context.watch<GratitudeStore>();
    final phase = computeGratitudePhase(grat.journeyDay, grat.journeyDays);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            _greeting(context, pal),
            // .bank-card  margin:14px 18px 6px
            Padding(
              padding: const EdgeInsets.fromLTRB(_px, 14, _px, 6),
              child: AbundanceCard(
                balance: store.balance,
                card: store.card,
                onEdit: () => CardEditSheet.show(
                  context: context,
                  initial: store.card,
                  onSave: (c) => store.updateCard(c),
                ),
              ),
            ),
            // .today-banner  margin:12px 18px 0
            Padding(
              padding: const EdgeInsets.fromLTRB(_px, 12, _px, 0),
              child: _todayBanner(pal, store),
            ),
            // .ghost-btn  margin:-4px 18px 10px
            Padding(
              padding: const EdgeInsets.fromLTRB(_px, 8, _px, 10),
              child: _ghostBtn(
                pal,
                '⚙️ تنظیم مبلغ شروع بازی فراوانی',
                () => AbundanceSettingsSheet.show(
                  context: context,
                  startAmount: store.settings.startAmount,
                  step: store.settings.step,
                  onSave: (v) => store.updateSettings(
                    startAmount: v.startAmount,
                    step: v.step,
                  ),
                ),
              ),
            ),
            // .theme-banner  margin:14px 18px 0
            Padding(
              padding: const EdgeInsets.fromLTRB(_px, 14, _px, 0),
              child: _themeBanner(phase, grat),
            ),
            // #gratitude-mini-cal  margin:14px 18px 0
            const Padding(
              padding: EdgeInsets.fromLTRB(_px, 14, _px, 0),
              child: GratitudePeriodCalendar(),
            ),
            // .cta-buy  margin:16px 18px 4px
            Padding(
              padding: const EdgeInsets.fromLTRB(_px, 16, _px, 4),
              child: _ctaBuy(pal),
            ),
            const SizedBox(height: 4),
            // .quick-add
            const GratitudeQuickAdd(),
            const SizedBox(height: 16),
            // «انجام این تمرین» + مسیر عصبی
            const GratitudeNeuralSection(),
            const SizedBox(height: 18),
            // «لیست شکرگذاری»
            const GratitudeRecentList(),
          ],
        ),
      ),
    );
  }

  // ─── .greeting ───
  Widget _greeting(BuildContext context, GratPalette pal) {
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
    final theme = context.watch<ThemeStore>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(_px, 20, _px, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icon-192.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                color: pal.surface,
                child: const Text('🌿', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            word,
            style: TextStyle(fontSize: 13, color: pal.muted),
          ),
          const Spacer(),
          // دکمه‌ی تغییر تم (toggleAppTheme وب)
          Material(
            color: pal.surface,
            shape: CircleBorder(side: BorderSide(color: pal.line)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => theme.toggle(),
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  theme.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 19,
                  color: pal.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── .today-banner ───
  Widget _todayBanner(GratPalette pal, AbundanceStore store) {
    final isZero = store.balance <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: pal.tint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.gold300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isZero
                  ? '🎉 امروز همه‌ی ${formatMoney(store.todayDeposit)} رو خرج کردی؛ فردا مبلغ بزرگ‌تری منتظرته'
                  : 'امروز ${formatMoney(store.todayDeposit)} به حسابت اضافه شد ✨ — باید همین امروز خرجش کنی',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pal.gold600,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: pal.gold500,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'روز ${toFaDigits(store.daysPassed.toString())}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── .ghost-btn ───
  Widget _ghostBtn(GratPalette pal, String text, VoidCallback onTap) {
    return Material(
      color: pal.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pal.line),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: pal.ink,
            ),
          ),
        ),
      ),
    );
  }

  // ─── .theme-banner ───
  Widget _themeBanner(GratitudePhaseInfo phase, GratitudeStore grat) {
    final pct = (phase.day / phase.totalDays).clamp(0.0, 1.0);
    return WebThemeBanner(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '🧭 دوره‌ی ${grat.pastPeriods.isNotEmpty ? '${GratitudePeriodCalendar.ord(grat.pastPeriods.length)} — ' : ''}${toFaDigits(phase.totalDays.toString())} روزه — ${phase.phaseShort}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xD9FFFFFF)),
                ),
              ),
              Text(
                'روز ${toFaDigits(phase.day.toString())} / ${toFaDigits(phase.totalDays.toString())}',
                style: const TextStyle(
                    fontSize: 10.5, color: Color(0xBFFFFFFF)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'فاز ${toFaDigits((phase.phaseIndex + 1).toString())} — ${phase.phaseName}',
            style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '🎯 ${phase.prompt}',
            style: const TextStyle(
                fontSize: 12, color: Color(0xD9FFFFFF), height: 1.6),
          ),
          const SizedBox(height: 12),
          WebBannerBar(value: pct),
        ],
      ),
    );
  }

  // ─── .cta-buy ───
  Widget _ctaBuy(GratPalette pal) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pal.emerald700, pal.emerald500],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F5B53).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpenStore,
          child: const Padding(
            padding: EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🛍️', style: TextStyle(fontSize: 15.5)),
                SizedBox(width: 8),
                Text(
                  'خرید جدید',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
