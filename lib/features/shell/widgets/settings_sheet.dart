import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/bridge/linlearn_bridge.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/constants/app_languages.dart';
import '../../../core/constants/app_themes.dart';
import '../../../core/constants/supported_languages.dart';
import '../../../core/mascot/mascot_pin_provider.dart';
import '../../../core/models/text_prefs.dart';
import '../../../core/providers/app_prefs_provider.dart';
import '../../../core/providers/linlearn_provider.dart';
import '../../../core/providers/native_sync_provider.dart';
import '../../../core/providers/text_prefs_provider.dart';
import '../../../core/storage/local_storage.dart' show sharedPrefsProvider;
import '../../../core/sync/cloud_sync.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/widgets/color_palette_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tabs/_hope_panel.dart' show uiContentDirection;
import 'settings_packs.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  /// مثل Hope: یک پنل بازشونده‌ی کوچک زیر دکمه‌ی منو (نه تمام‌صفحه).
  /// ابعاد عیناً CSS پنل Hope است: width 280، maxHeight 70vh، padding 16،
  /// radius 16، سایه‌ی 0 12 30 rgba(0,0,0,.25)، فاصله‌ی ۱۶ از لبه‌ی چپ.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.l10n.import_close,
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, _, __) {
        final size = MediaQuery.of(ctx).size;
        final width = 280.0.clamp(240.0, size.width - 16).toDouble();
        return Stack(
          children: [
            Positioned(
              left: 16,
              top: size.height * 0.156,
              width: width,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: size.height * 0.70),
                // جهتِ متن‌ها طبقِ زبانِ رابط (فارسی/عربی RTL، بقیه LTR)
                child: Directionality(
                  textDirection: uiContentDirection(ctx),
                  child: const SettingsSheet(),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.cardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: const [
            _AccountSection(),
            SizedBox(height: 16),
            _LanguageSection(),
            SizedBox(height: 16),
            _ThemeSection(),
            SizedBox(height: 16),
            _FontSection(),
            SizedBox(height: 16),
            _FontSizeSection(),
            SizedBox(height: 16),
            _TargetTextSection(),
            SizedBox(height: 16),
            _CalendarSection(),
            SizedBox(height: 16),
            _HighlightSection(),
            SizedBox(height: 16),
            _MascotSection(),
            SizedBox(height: 16),
            _VoiceEngineSection(),
            _OfflineTtsSection(),
            _AudioSyncSection(),
            SizedBox(height: 10),
            _FloatingBubbleSection(),
            SizedBox(height: 14),
            _OfflineWordsButton(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// مقیاس‌های Hope (SettingsMenu.jsx) — همه‌ی اندازه‌ها عیناً همان‌هاست:
//   عنوان ۱۲/w700/inkSoft + فاصله‌ی ۸ — فاصله‌ی بین بخش‌ها ۱۶
//   چیپ: padding 5×12، شعاع ۲۰، فونت ۱۲ — سواچ: ۳۴ (هایلایت ۳۰)، شعاع ۸
// ═══════════════════════════════════════════════════════════════════
const double _kGapAfterTitle = 8;
const double _kGapSection = 16;

class _SectionTitle extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String label;

  const _SectionTitle({this.icon, this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: c.inkSoft),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            emoji != null ? '$emoji $label' : label,
            style: TextStyle(
              color: c.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// سواچ مربعیِ Hope (swatchButtonStyle): شعاع ۸، حلقه‌ی سفید+طلایی وقتی انتخاب است.
class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final double size;
  final VoidCallback onTap;
  final Widget? child;
  final String? tooltip;

  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.size = 34,
    this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final box = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        margin: selected ? const EdgeInsets.all(2) : EdgeInsets.zero,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? c.gold : Colors.black.withOpacity(0.16),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  const BoxShadow(color: Colors.white, spreadRadius: 2),
                  BoxShadow(color: c.gold, spreadRadius: 4),
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1)),
                ]
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 2,
                      offset: const Offset(0, 1)),
                ],
        ),
        child: child,
      ),
    );
    final w = (tooltip == null || tooltip!.isEmpty)
        ? box
        : Tooltip(message: tooltip!, child: box);
    // جا برای حلقه‌ی بیرونی (۴px) تا با سواچ‌های کناری نخورد
    return Padding(padding: const EdgeInsets.all(2), child: w);
  }
}

// ═══════════════════════════════════════════════════════════════════
// Account — مثل Hope: آواتار ۳۰، نام ۱۳، ایمیل ۱۱، «خروج» متنیِ قرمز
// ═══════════════════════════════════════════════════════════════════
class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final L = context.l10n;

    final isGuest = ref.watch(guestModeProvider);
    String displayName = isGuest ? L.auth_guest_name : L.settings_guest_user;
    String displayEmail = '';
    bool isSignedIn = false;

    try {
      final repo = ref.read(authRepositoryProvider);
      final user = repo.currentSession?.user;
      if (user != null) {
        isSignedIn = true;
        displayEmail = user.email ?? '';
        final meta = user.userMetadata;
        displayName = ((meta?['name'] ?? meta?['full_name']) as String?) ??
            (displayEmail.contains('@')
                ? displayEmail.split('@').first
                : (displayEmail.isEmpty ? displayName : displayEmail));
      }
    } catch (_) {}

    final initial = displayName.trim().isNotEmpty
        ? displayName.trim().characters.first.toUpperCase()
        : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(label: L.settings_account),
        const SizedBox(height: _kGapAfterTitle),
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.gold, shape: BoxShape.circle),
              child: Text(
                initial,
                style: TextStyle(
                  color: c.paper,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (displayEmail.isNotEmpty)
                    Text(
                      displayEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.inkSoft, fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (!isSignedIn && isGuest) ...[
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              // حالت مهمان تمام می‌شود ← روتر به صفحه‌ی ورود می‌رود
              await ref.read(guestModeProvider.notifier).leave();
              if (context.mounted) Navigator.pop(context);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_sync_outlined, size: 14, color: c.teal),
                const SizedBox(width: 8),
                Text(L.settings_sign_in_to_sync,
                    style: TextStyle(color: c.teal, fontSize: 12)),
              ],
            ),
          ),
        ],
        if (isSignedIn) ...[
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              try {
                // آخرین تغییرات قبل از خروج در حساب ذخیره شود
                await ref
                    .read(cloudSyncProvider)
                    .push()
                    .timeout(const Duration(seconds: 8));
              } catch (_) {}
              try {
                await ref.read(authRepositoryProvider).signOut();
              } catch (_) {}
              if (context.mounted) Navigator.pop(context);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout, size: 14, color: c.rose),
                const SizedBox(width: 8),
                Text(L.settings_logout,
                    style: TextStyle(color: c.rose, fontSize: 12)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Language — منوی کشویی: فونت ۱۳، padding 8×10، شعاع ۱۲
// ═══════════════════════════════════════════════════════════════════
class _LanguageSection extends ConsumerWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPrefsProvider);
    final notifier = ref.read(appPrefsProvider.notifier);
    final c = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            icon: Icons.language, label: context.l10n.settings_language_title),
        const SizedBox(height: _kGapAfterTitle),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: prefs.uiLang,
              isExpanded: true,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down, size: 18, color: c.inkSoft),
              dropdownColor: Colors.white,
              style: TextStyle(color: c.ink, fontSize: 13),
              items: kAppLanguages.values
                  .map((l) => DropdownMenuItem(
                        value: l.code,
                        child: Text(l.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) notifier.setUiLang(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Theme — سواچ‌های ۳۴×۳۴ با رنگِ swatch (نه گرادیانِ هدر)، فاصله‌ی ۸
// ═══════════════════════════════════════════════════════════════════
class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPrefsProvider);
    final notifier = ref.read(appPrefsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            icon: Icons.palette_outlined,
            label: context.l10n.settings_theme_title),
        const SizedBox(height: _kGapAfterTitle),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: kAppThemes.values
              .map((t) => _Swatch(
                    color: t.swatch,
                    selected: t.key == prefs.theme,
                    onTap: () => notifier.setTheme(t.key),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Font
// ═══════════════════════════════════════════════════════════════════
class _FontSection extends ConsumerWidget {
  const _FontSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPrefsProvider);
    final notifier = ref.read(appPrefsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            icon: Icons.text_fields, label: context.l10n.settings_font_title),
        const SizedBox(height: _kGapAfterTitle),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kAppFonts.values.map((f) {
            return _ChoiceChip(
              label: f.label[prefs.uiLang] ?? f.label['en'] ?? f.label['fa'] ?? f.key,
              selected: f.key == prefs.font,
              onTap: () => notifier.setFont(f.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Font Size
// ═══════════════════════════════════════════════════════════════════
class _FontSizeSection extends ConsumerWidget {
  const _FontSizeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPrefsProvider);
    final notifier = ref.read(appPrefsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(label: context.l10n.settings_font_size_title),
        const SizedBox(height: _kGapAfterTitle),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kAppFontSizes.values.map((s) {
            return _ChoiceChip(
              label: s.label[prefs.uiLang] ?? s.label['en'] ?? s.label['fa'] ?? s.key,
              selected: s.key == prefs.fontSize,
              onTap: () => notifier.setFontSize(s.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// چیپ انتخاب — Hope: padding 5×12، شعاع ۲۰، فونت ۱۲، انتخاب‌شده = goldSoft
// ═══════════════════════════════════════════════════════════════════
class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// داخل Expanded: متن وسط‌چین و در صورت طولانی بودن با «…» کوتاه می‌شود.
  final bool expand;
  final double hPad;
  final FontWeight? weight;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
    this.hPad = 12,
    this.weight,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: expand ? Alignment.center : null,
        padding: EdgeInsets.symmetric(horizontal: expand ? 4 : hPad, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.goldSoft : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.gold : c.cardBorder),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(fontSize: 12, color: c.ink, fontWeight: weight),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Target Text — مقیاس ۷۰..۱۶۰ (گام ۵، دکمه‌ها ±۱۰) و حالت بولد
// ═══════════════════════════════════════════════════════════════════
class _TargetTextSection extends ConsumerWidget {
  const _TargetTextSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrefs = ref.watch(textPrefsProvider);
    final notifier = ref.read(textPrefsProvider.notifier);
    final c = context.appColors;
    final L = context.l10n;
    final scale = textPrefs.scale.clamp(70, 160).toInt();

    Widget stepBtn(String t, String tip, VoidCallback onTap) => Tooltip(
          message: tip,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: c.cardBorder),
              ),
              child: Text(t,
                  style: TextStyle(
                      color: c.ink, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            icon: Icons.text_fields, label: L.settings_target_font_size),
        const SizedBox(height: _kGapAfterTitle),
        Row(
          children: [
            stepBtn('−', L.settings_decrease,
                () => notifier.setScale((scale - 10).clamp(70, 160))),
            const SizedBox(width: 12),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: c.gold,
                  inactiveTrackColor: c.cardBorder,
                  thumbColor: c.gold,
                  overlayColor: c.gold.withOpacity(0.15),
                  trackHeight: 4,
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: scale.toDouble(),
                  min: 70,
                  max: 160,
                  divisions: 18,
                  onChanged: (v) => notifier.setScale(v.round()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            stepBtn('+', L.settings_increase,
                () => notifier.setScale((scale + 10).clamp(70, 160))),
            const SizedBox(width: 12),
            SizedBox(
              width: 36,
              child: Text(
                '$scale%',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.inkSoft, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: _kGapSection),
        _SectionTitle(label: L.settings_bold_target_title),
        const SizedBox(height: _kGapAfterTitle),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BoldChip(
              label: L.settings_bold_none,
              value: TargetBoldMode.none,
              current: textPrefs.bold,
              onTap: () => notifier.setBold(TargetBoldMode.none),
            ),
            _BoldChip(
              label: L.settings_bold_original,
              value: TargetBoldMode.text,
              current: textPrefs.bold,
              onTap: () => notifier.setBold(TargetBoldMode.text),
            ),
            _BoldChip(
              label: L.settings_bold_translation,
              value: TargetBoldMode.translation,
              current: textPrefs.bold,
              onTap: () => notifier.setBold(TargetBoldMode.translation),
            ),
            _BoldChip(
              label: L.settings_bold_both,
              value: TargetBoldMode.both,
              current: textPrefs.bold,
              onTap: () => notifier.setBold(TargetBoldMode.both),
            ),
          ],
        ),
        const SizedBox(height: _kGapSection),
        Row(
          children: [
            Expanded(
              child: _SectionTitle(
                  icon: Icons.format_line_spacing,
                  label: L.settings_spacing_title),
            ),
            TextButton(
              onPressed: notifier.resetGaps,
              style: TextButton.styleFrom(
                foregroundColor: c.gold,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(L.settings_spacing_reset),
            ),
          ],
        ),
        const SizedBox(height: _kGapAfterTitle),
        _GapSlider(
          label: L.settings_spacing_sentences,
          value: textPrefs.sentenceGap,
          min: TargetTextPrefs.minSentenceGap,
          max: TargetTextPrefs.maxSentenceGap,
          onChanged: notifier.setSentenceGap,
        ),
        const SizedBox(height: 4),
        _GapSlider(
          label: L.settings_spacing_languages,
          value: textPrefs.langGap,
          min: TargetTextPrefs.minLangGap,
          max: TargetTextPrefs.maxLangGap,
          onChanged: notifier.setLangGap,
        ),
      ],
    );
  }
}

/// اسلایدرِ فاصله (۱ واحد = ۱ پیکسل منطقی) با برچسب و مقدار
class _GapSlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _GapSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: c.ink, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Text('$value',
                style: TextStyle(color: c.inkSoft, fontSize: 12)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: c.gold,
            inactiveTrackColor: c.cardBorder,
            thumbColor: c.gold,
            overlayColor: c.gold.withOpacity(0.15),
            trackHeight: 4,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

class _BoldChip extends StatelessWidget {
  final String label;
  final TargetBoldMode value;
  final TargetBoldMode current;
  final VoidCallback onTap;

  const _BoldChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ChoiceChip(
      label: label,
      selected: value == current,
      onTap: onTap,
      weight: value == TargetBoldMode.none ? FontWeight.w400 : FontWeight.w700,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Calendar — padding 5×14
// ═══════════════════════════════════════════════════════════════════
class _CalendarSection extends ConsumerWidget {
  const _CalendarSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(appPrefsProvider.select((p) => p.calendarSystem));
    final notifier = ref.read(appPrefsProvider.notifier);
    final L = context.l10n;
    final labels = <CalendarSystem, String>{
      CalendarSystem.gregorian: L.settings_calendar_gregorian,
      CalendarSystem.jalali: L.settings_calendar_jalali,
      CalendarSystem.both: L.settings_calendar_both,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(emoji: '📅', label: L.settings_calendar_title),
        const SizedBox(height: _kGapAfterTitle),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: labels.entries
              .map((e) => _ChoiceChip(
                    label: e.value,
                    hPad: 14,
                    selected: e.key == current,
                    onTap: () => notifier.setCalendarSystem(e.key),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Mascot — «نمایش / محو» (padding 6×14، w700) + دکمه‌ی ریست
// (در Hope انتخابِ کاراکتر/لباس/پس‌زمینه/ترتیب تب‌ها با فلگ خاموش است)
// ═══════════════════════════════════════════════════════════════════
class _MascotSection extends ConsumerWidget {
  const _MascotSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(appPrefsProvider.select((p) => p.mascotEnabled));
    final notifier = ref.read(appPrefsProvider.notifier);
    final c = context.appColors;
    final L = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(label: L.settings_mascot_walking_title),
        const SizedBox(height: _kGapAfterTitle),
        Row(
          children: [
            _ChoiceChip(
              label: L.settings_mascot_visible_show,
              selected: enabled,
              hPad: 14,
              weight: FontWeight.w700,
              onTap: () => notifier.setMascotEnabled(true),
            ),
            const SizedBox(width: 8),
            _ChoiceChip(
              label: L.settings_mascot_visible_fade,
              selected: !enabled,
              hPad: 14,
              weight: FontWeight.w700,
              onTap: () => notifier.setMascotEnabled(false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: GestureDetector(
            onTap: () {
              ref.read(mascotPinProvider.notifier).reset();
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text(L.settings_mascot_reset_done)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.cardBorder),
              ),
              child: Text(
                '↺ ${L.settings_mascot_reset_button}',
                style: TextStyle(
                    color: c.ink, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Highlight color — سواچ‌های ۳۰×۳۰ (همان پالت Hope)
// ═══════════════════════════════════════════════════════════════════
const List<String> _kHighlightPalette = [
  '#F7E98E', '#FBD9AE', '#F7C48C', '#F1968E',
  '#DCE07E', '#9AD98A', '#8DE0BE', '#A6DEE9',
  '#A9C7F0', '#C7B6EC', '#F0AEEC', '#F4AAC0',
];

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

class _HighlightSection extends ConsumerWidget {
  const _HighlightSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final current =
        ref.watch(appPrefsProvider.select((p) => p.highlightColor));
    final notifier = ref.read(appPrefsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(label: context.l10n.settings_highlight_color_title),
        const SizedBox(height: _kGapAfterTitle),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _Swatch(
              color: Colors.white,
              size: 30,
              selected: current == 'none',
              tooltip: context.l10n.settings_highlight_none,
              onTap: () => notifier.setHighlightColor('none'),
              child: Icon(Icons.close, size: 14, color: c.inkSoft),
            ),
            for (final hex in _kHighlightPalette)
              _Swatch(
                color: _hexToColor(hex),
                size: 30,
                selected: current.toUpperCase() == hex,
                tooltip: hex,
                onTap: () => notifier.setHighlightColor(hex),
              ),
            // رنگِ دلخواهِ قبلی (اگر از پالت پیشرفته انتخاب شده)
            if (current != 'none' &&
                RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(current) &&
                !_kHighlightPalette.contains(current.toUpperCase()))
              _Swatch(
                color: _hexToColor(current),
                size: 30,
                selected: true,
                tooltip: current,
                onTap: () {},
              ),
            // 🎨 پالتِ پیشرفته
            _Swatch(
              color: Colors.white,
              size: 30,
              selected: false,
              tooltip: context.l10n.settings_bubble_color_custom,
              onTap: () async {
                final v = await showColorPaletteDialog(
                  context,
                  initial: current == 'none' ? '#F7E98E' : current,
                  title: context.l10n.settings_highlight_color_title,
                );
                if (v != null) notifier.setHighlightColor(v);
              },
              child: const Icon(Icons.palette_outlined, size: 16),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Floating bubble — حباب شناور (ذره‌بین / ترجمه‌ی زنده) — فقط اندروید
// چیدمان دقیقاً مثل Hope: عنوان ← سه دکمه‌ی نوع ← رنگ ← ذره‌بین ←
// ترجمه‌ی زنده‌ی صدا (زبان صدا، بسته‌ی آفلاین، حالت آهنگ، نمایش، شروع، یوتیوب)
// ═══════════════════════════════════════════════════════════════════
class _FloatingBubbleSection extends ConsumerStatefulWidget {
  const _FloatingBubbleSection();

  @override
  ConsumerState<_FloatingBubbleSection> createState() =>
      _FloatingBubbleSectionState();
}

class _FloatingBubbleSectionState
    extends ConsumerState<_FloatingBubbleSection> {
  static const String _kKindKey = 'phrasebook-bubble-kind';
  static const String _kSrcKey = 'phrasebook-live-src-lang';
  static const String _kSrcMigKey = 'phrasebook-live-src-auto-v2';
  static const String _kScreenInfoKey = 'phrasebook-screenrec-info-seen';
  static const String _kDispKey = 'phrasebook-live-display-mode';
  static const String _kColorKey = 'phrasebook-bubble-panel-color';

  static const String _defaultColor = '#1C2541';
  static const List<String> _colors = [
    '#1C2541', '#14342B', '#3A1F2B', '#2B2B33', '#2E2352', '#0F3A44',
  ];

  static const List<String> _kinds = ['magnifier', 'live', 'both'];
  static const List<String> _displayModes = ['both', 'translation', 'original'];

  static const Map<String, String> _srcLangs = {
    'en': 'English', 'de': 'Deutsch', 'fr': 'Français', 'es': 'Español',
    'it': 'Italiano', 'tr': 'Türkçe', 'ar': 'العربية', 'ru': 'Русский',
    'ja': '日本語', 'ko': '한국어', 'zh': '中文', 'hi': 'हिन्दी',
    'pt': 'Português', 'nl': 'Nederlands', 'ur': 'اردو', 'fa': 'فارسی',
  };

  late String _kind;
  late String _src;
  late String _disp;
  late String _color;
  bool _busy = false;
  int _packEpoch = 0;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    final sp = ref.read(sharedPrefsProvider);
    final kind = sp.getString(_kKindKey);
    var src = sp.getString(_kSrcKey);
    // 🌐 «زبان صدا» پیش‌فرض = تشخیص خودکار؛ مقدارِ قدیمیِ «en» (پیش‌فرضِ قبلی) یک‌بار به خودکار تبدیل می‌شود
    if (sp.getBool(_kSrcMigKey) != true) {
      sp.setBool(_kSrcMigKey, true);
      if (src == null || src == 'en') {
        src = 'auto';
        sp.setString(_kSrcKey, 'auto');
      }
    }
    final disp = sp.getString(_kDispKey);
    final color = sp.getString(_kColorKey);
    _kind = _kinds.contains(kind) ? kind! : 'both';
    _src = (src == 'auto' || _srcLangs.containsKey(src)) ? src! : 'auto';
    _disp = _displayModes.contains(disp) ? disp! : 'both';
    _color = (color != null && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color))
        ? color.toUpperCase()
        : _defaultColor;
  }

  Future<void> _save(String key, String value) async {
    await ref.read(sharedPrefsProvider).setString(key, value);
  }

  String _kindLabel(AppLocalizations L, String k) {
    switch (k) {
      case 'magnifier':
        return L.settings_bubble_kind_magnifier;
      case 'live':
        return L.settings_bubble_kind_live;
      default:
        return L.settings_bubble_kind_both;
    }
  }

  Map<String, String> _displayMap(AppLocalizations L) => {
        'both': L.settings_display_both,
        'translation': L.settings_display_translation_only,
        'original': L.settings_display_original_only,
      };

  /// رنگ‌های روشن را تیره می‌کند تا متن سفیدِ حباب خوانا بماند (مثل Hope).
  String _ensureDark(String hex) {
    try {
      var r = int.parse(hex.substring(1, 3), radix: 16);
      var g = int.parse(hex.substring(3, 5), radix: 16);
      var b = int.parse(hex.substring(5, 7), radix: 16);
      final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
      if (lum > 0.42) {
        final k = 0.42 / lum;
        r = (r * k).round();
        g = (g * k).round();
        b = (b * k).round();
      }
      String h(int x) => x.toRadixString(16).padLeft(2, '0');
      return '#${h(r)}${h(g)}${h(b)}'.toUpperCase();
    } catch (_) {
      return _defaultColor;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  /// رنگ/حالت نمایش را (اگر سمت نیتیو پشتیبانی کند) به حباب می‌فرستد.
  Future<void> _pushOptions() =>
      LinLearnBridge.setBubbleOptions(panelColor: _color, displayMode: _disp);

  void _setColor(String hex) {
    final v = _ensureDark(hex);
    setState(() => _color = v);
    _save(_kColorKey, v);
    _pushOptions();
  }

  Future<void> _pickCustomColor() async {
    final v = await showColorPaletteDialog(
      context,
      initial: _color,
      title: context.l10n.settings_bubble_color_title,
    );
    if (v != null) _setColor(v);
  }

  /// یک‌بار توضیح ← صفحه‌ی تنظیمات ← با برگشت، خودکار ادامه می‌دهد (بدونِ «دوباره امتحان کن»).
  Future<bool> _ensureOverlay() async {
    if (await LinLearnBridge.canDrawOverlays()) return true;
    if (!mounted) return false;
    final ml = MaterialLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => _dirDialog(ctx, AlertDialog(
        title: Text(context.l10n.st_overlay_title),
        content: Text(context.l10n.st_overlay_body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ml.cancelButtonLabel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ml.continueButtonLabel)),
        ],
      )),
    );
    if (go != true) return false;
    await LinLearnBridge.requestOverlayPermission();
    for (var i = 0; i < 90 && mounted; i++) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (await LinLearnBridge.canDrawOverlays()) return true;
    }
    return false;
  }

  /// توضیحِ شفافِ «ضبط صفحه» (MediaProjection) پیش از اولین ذره‌بین / ترجمه‌ی زنده؛ فقط یک‌بار.
  Future<bool> _ensureScreenRecordInfo() async {
    final sp = ref.read(sharedPrefsProvider);
    if (sp.getBool(_kScreenInfoKey) == true) return true;
    if (!mounted) return false;
    final ml = MaterialLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => _dirDialog(ctx, AlertDialog(
        title: Text(context.l10n.st_screenrec_title),
        content: SingleChildScrollView(
            child: Text(context.l10n.st_screenrec_body)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ml.cancelButtonLabel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ml.continueButtonLabel)),
        ],
      )),
    );
    if (go != true) return false;
    await sp.setBool(_kScreenInfoKey, true);
    return true;
  }

  Future<void> _toggleBubble() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final notifier = ref.read(bubbleProvider.notifier);
      if (ref.read(bubbleProvider).running) {
        await notifier.stop();
      } else {
        if (!await _ensureOverlay()) return;
        if (_kind != 'live' && !await _ensureScreenRecordInfo()) return;
        await ref.read(nativeSyncProvider).pushLangs();
        await _pushOptions();
        await notifier.start(mode: _kind == 'live' ? 'translator' : _kind);
      }
    } catch (e) {
      _toast(context.l10n.st_error('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLive() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final notifier = ref.read(liveTranslatorProvider.notifier);
      if (ref.read(liveTranslatorProvider)) {
        await notifier.stop();
      } else {
        if (!await _ensureOverlay()) return;
        if (!await _ensureScreenRecordInfo()) return;
        // ترجمه‌ی زنده فقط آفلاین کار می‌کند: بسته‌ی زبانِ صدا باید روی گوشی باشد.
        if (!await _ensureSpeechPack(
            afterDownload: context.l10n.st_live_download_started)) {
          return;
        }
        await ref.read(nativeSyncProvider).pushLangs();
        await _pushOptions();
        await notifier.start(
          sourceLang: _src,
          targetLang: ref.read(appPrefsProvider).uiLang,
        );
      }
    } catch (e) {
      _toast(context.l10n.st_error('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// مثل ensureOfflineSpeechModel در Hope: اگر بسته‌ی آفلاینِ «زبان صدا» دانلود نشده، یک‌بار می‌پرسد و
  /// دانلود را شروع می‌کند. true = می‌شود ادامه داد، false = اول باید بسته دانلود شود.
  Future<bool> _ensureSpeechPack({required String afterDownload}) async {
    // 🌐 «تشخیص خودکار»: موتورِ چندزبانه‌ی Whisper لازم است (هر کدام از tiny / base / small کافی است)
    if (_src == 'auto') return _ensureAutoPack(afterDownload: afterDownload);
    final pack = await LinLearnBridge.packStatus('speech', _src);
    if (pack == null || pack['downloaded'] == true) return true;
    if (!mounted) return false;
    if (pack['downloading'] == true) {
      _toast(context.l10n.st_pack_wait);
      return false;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => _dirDialog(ctx, AlertDialog(
        title: Text(context.l10n.st_speech_pack_title),
        content: Text(
            context.l10n.st_speech_pack_body('${_srcLangs[_src]}')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.st_no)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.settings_download)),
        ],
      )),
    );
    if (yes == true) {
      await LinLearnBridge.packDownload('speech', _src);
      _toast(afterDownload);
      if (mounted) setState(() => _packEpoch++);
    }
    return false;
  }

  /// حالتِ «تشخیص خودکار»: اگر هیچ مدلِ Whisper روی گوشی نیست یک‌بار می‌پرسد و «base» را دانلود می‌کند.
  Future<bool> _ensureAutoPack({required String afterDownload}) async {
    Map<String, dynamic>? baseSt;
    for (final id in const ['base', 'small', 'tiny']) {
      final st = await LinLearnBridge.packStatus('song', id);
      if (st == null) return true; // پشتیبانی نمی‌شود/خطا: مانعِ شروع نشو
      if (st['downloaded'] == true) return true;
      if (id == 'base') baseSt = st;
      if (st['downloading'] == true) {
        if (mounted) _toast(context.l10n.st_pack_wait);
        return false;
      }
    }
    if (baseSt == null || !mounted) return false;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => _dirDialog(ctx, AlertDialog(
        title: Text(context.l10n.st_speech_pack_title),
        content: Text(context.l10n.st_speech_pack_body(
            context.l10n.settings_lang_auto.replaceFirst('🌐 ', ''))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.st_no)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.settings_download)),
        ],
      )),
    );
    if (yes == true) {
      await LinLearnBridge.packDownload('song', 'base');
      _toast(afterDownload);
      if (mounted) setState(() => _packEpoch++);
    }
    return false;
  }

  /// زیرنویس زنده‌ی یوتیوب برای تشخیصِ ویدیوی در حال پخش و زمانِ پخش، «دسترسی به اعلان‌ها» می‌خواهد
  /// (دقیقاً مثل Hope: ytCheckAccess ← ytRequestAccess + پیام). با برگشت از تنظیمات خودکار ادامه می‌دهد.
  Future<bool> _ensureNotificationAccess() async {
    if (await LinLearnBridge.ytCheckAccess()) return true;
    if (!mounted) return false;
    final ml = MaterialLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => _dirDialog(ctx, AlertDialog(
        title: Text(context.l10n.st_notif_title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.st_notif_trust),
              const SizedBox(height: 10),
              Text(context.l10n.settings_notification_access_needed),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ml.cancelButtonLabel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ml.continueButtonLabel)),
        ],
      )),
    );
    if (go != true) return false;
    await LinLearnBridge.ytRequestAccess();
    for (var i = 0; i < 90 && mounted; i++) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (await LinLearnBridge.ytCheckAccess()) return true;
    }
    return false;
  }

  /// ▶ زیرنویس زنده‌ی یوتیوب: مجوزِ نمایش روی برنامه‌ها ← دسترسی به اعلان‌ها ← حباب ← ytSetEnabled.
  /// زیرنویسِ یوتیوب به بسته‌ی تشخیصِ گفتار (STT) نیازی ندارد؛ پس هیچ پرسش/دانلودی جلوی آن گرفته نمی‌شود
  /// و دانلودِ بسته‌ها (در تنظیمات) هم‌زمان با پخشِ یوتیوب آزادانه ادامه دارد.
  /// بعد از اولین بار، با باز بودنِ حباب هر ویدیوی یوتیوب خودکار شناسایی و زیرنویسش باز می‌شود.
  Future<void> _startYoutube() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await _ensureOverlay()) return;
      if (!await _ensureNotificationAccess()) return;
      await ref.read(nativeSyncProvider).pushLangs();
      await _pushOptions();
      if (!ref.read(bubbleProvider).running) {
        await ref.read(bubbleProvider.notifier).start(mode: 'translator');
      }
      await _pushOptions();
      await LinLearnBridge.ytSetEnabled(true);
    } catch (e) {
      _toast(context.l10n.st_error('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final L = context.l10n;
    final bubbleRunning = ref.watch(bubbleProvider.select((s) => s.running));
    final liveRunning = ref.watch(liveTranslatorProvider);
    final showMagnifier = _kind != 'live';
    final showLive = _kind != 'magnifier';
    final note = TextStyle(color: c.inkSoft, fontSize: 11.5, height: 1.7);
    final small = TextStyle(
        color: c.inkSoft, fontSize: 12, fontWeight: FontWeight.w700);

    // کادر: border 1، شعاع ۱۶، padding 12/12/12/4، پس‌زمینه‌ی سفیدِ ۴۵٪
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: !_isAndroid
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                L.settings_android_only,
                style: TextStyle(color: c.inkSoft, fontSize: 12.5),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '🫧 ${L.settings_floating_title}',
                    style: TextStyle(
                        color: c.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                // سه دکمه‌ی نوع: grid ۳ ستون، gap 6، padding 7×4
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      for (var i = 0; i < _kinds.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _KindChip(
                            label: _kindLabel(L, _kinds[i]),
                            selected: _kind == _kinds[i],
                            onTap: () {
                              setState(() => _kind = _kinds[i]);
                              _save(_kKindKey, _kinds[i]);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // رنگ کادر حباب
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('🎨 ${L.settings_bubble_color_title}',
                      style: small),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final hex in _colors)
                        GestureDetector(
                          onTap: () => _setColor(hex),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _hexToColor(hex),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color == hex ? c.gold : c.cardBorder,
                                width: 2,
                              ),
                              boxShadow: _color == hex
                                  ? [
                                      BoxShadow(
                                          color: c.goldSoft, spreadRadius: 2),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: _pickCustomColor,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 30,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: c.cardBorder),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _hexToColor(_color),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(L.settings_bubble_color_custom,
                                style: TextStyle(
                                    color: c.inkSoft, fontSize: 11.5)),
                          ],
                        ),
                      ),
                      if (_color.toUpperCase() != _defaultColor)
                        GestureDetector(
                          onTap: () => _setColor(_defaultColor),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.cardBorder),
                            ),
                            child: Text(
                              L.settings_bubble_color_reset,
                              style: TextStyle(
                                  color: c.ink,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // دکمه‌های شروع — درست زیر رنگ (مثل Hope)، نه ته کادر
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showMagnifier) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '🔍 ${L.settings_magnifier_title}',
                            style: TextStyle(
                                color: c.ink,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        _BubbleButton(
                          emoji: '🔍',
                          label: bubbleRunning
                              ? L.settings_magnifier_stop
                              : L.settings_magnifier_start,
                          busy: _busy,
                          onTap: _toggleBubble,
                        ),
                      ],
                      if (showLive) ...[
                        _BubbleButton(
                          emoji: '🎙',
                          label: liveRunning
                              ? L.settings_stop
                              : L.settings_live_audio_start,
                          busy: _busy,
                          onTap: _toggleLive,
                        ),
                        _BubbleButton(
                          emoji: '▶️',
                          label: L.settings_youtube_start,
                          busy: _busy,
                          onTap: _startYoutube,
                        ),
                        _BubbleButton(
                          emoji: '🔑',
                          label: 'ورود به یوتیوب (برای دریافت زیرنویس)',
                          busy: _busy,
                          onTap: () async {
                            await LinLearnBridge.ytLoginOpen();
                          },
                        ),
                        // «نمایش: متن اصلی + ترجمه‌ها» درست زیرِ دکمه‌ی زیرنویس یوتیوب
                        _LabeledDrop(
                          label: L.settings_display_mode_label,
                          value: _disp,
                          items: _displayMap(L),
                          onChanged: (v) {
                            setState(() => _disp = v);
                            _save(_kDispKey, v);
                            _pushOptions();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                if (showLive) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text('🎙 ${L.settings_live_audio_title}',
                        style: small),
                  ),
                  _LabeledDrop(
                    label: L.settings_audio_language,
                    value: _src,
                    items: <String, String>{
                      'auto': L.settings_lang_auto,
                      ..._srcLangs,
                    },
                    onChanged: (v) {
                      setState(() => _src = v);
                      _save(_kSrcKey, v);
                      // مثل Hope: به حبابِ در حال اجرا هم خبر بده (setLanguages)
                      Future<void>.microtask(
                          () => ref.read(nativeSyncProvider).pushLangs());
                    },
                  ),
                  PackTile(
                    key: ValueKey('speech-$_src-$_packEpoch'),
                    // 🌐 خودکار: مدلِ چندزبانه‌ی Whisper (base)؛ وگرنه بسته‌ی زبانِ انتخابی
                    kind: _src == 'auto' ? 'sync' : 'speech',
                    id: _src == 'auto' ? 'base' : _src,
                    title: '',
                    bare: true,
                    approxMb: _src == 'auto' ? 160 : 70,
                  ),
                  const _SongModeSection(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(L.settings_live_audio_description, style: note),
                  ),
                ],
              ],
            ),
    );
  }
}

/// دکمه‌ی نوع حباب (ذره‌بین / ترجمه / هر دو): padding 7×4، شعاع ۲۰، فونت ۱۲/w700.
class _KindChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.goldSoft : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.gold : c.cardBorder),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: c.ink, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// حالت آهنگ (آفلاین) — کیفیت: سریع / متعادل / دقیق‌تر
// ═══════════════════════════════════════════════════════════════════
class _SongModeSection extends ConsumerStatefulWidget {
  const _SongModeSection();

  @override
  ConsumerState<_SongModeSection> createState() => _SongModeSectionState();
}

class _SongModeSectionState extends ConsumerState<_SongModeSection> {
  static const String _key = 'phrasebook-song-quality';
  static const List<String> _tiers = ['fast', 'balanced', 'accurate'];
  static const Map<String, int> _mb = {
    'fast': 100,
    'balanced': 160,
    'accurate': 360,
  };
  // «متعادل» همان بسته‌ی قبلی (base) است تا با سمت نیتیو سازگار بماند.
  static const Map<String, String> _packId = {
    'fast': 'fast',
    'balanced': 'base',
    'accurate': 'accurate',
  };

  late String _tier;
  bool _installed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final v = ref.read(sharedPrefsProvider).getString(_key);
    _tier = _tiers.contains(v) ? v! : 'balanced';
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final st = await LinLearnBridge.packStatus('song', _packId[_tier]!);
    if (!mounted) return;
    final v = st?['downloaded'] == true;
    if (v != _installed) setState(() => _installed = v);
  }

  String _name(AppLocalizations L, String t) {
    switch (t) {
      case 'fast':
        return L.settings_song_model_fast;
      case 'accurate':
        return L.settings_song_model_accurate;
      default:
        return L.settings_song_model_balanced;
    }
  }

  String _hint(AppLocalizations L, String t) {
    switch (t) {
      case 'fast':
        return L.settings_song_hint_fast;
      case 'accurate':
        return L.settings_song_hint_accurate;
      default:
        return L.settings_song_hint_balanced;
    }
  }

  Widget _tierCard(BuildContext context, String t) {
    final c = context.appColors;
    final L = context.l10n;
    final sel = _tier == t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _tier = t);
          ref.read(sharedPrefsProvider).setString(_key, t);
          _poll();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? c.gold : c.cardBorder,
              width: sel ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t == 'balanced'
                          ? '${_name(L, t)} ${L.settings_song_recommended_badge}'
                          : _name(L, t),
                      style: TextStyle(
                          color: c.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(_hint(L, t),
                        style: TextStyle(
                            color: c.inkSoft, fontSize: 11.5, height: 1.6)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '~${_mb[t]}MB',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                    color: c.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final L = context.l10n;
    final note = TextStyle(color: c.inkSoft, fontSize: 11.5, height: 1.7);
    final body = TextStyle(color: c.ink, fontSize: 12, height: 1.7);
    final name = _name(L, _tier);
    final mb = _mb[_tier]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('🎵 ${L.settings_song_title}',
                  style: TextStyle(
                      color: c.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: c.cardBorder),
              ),
              child: Text(
                _installed ? '✅ ${L.settings_tts_offline}' : L.settings_not_installed,
                style: TextStyle(color: c.ink, fontSize: 11.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.gold.withOpacity(0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(L.settings_song_intro, style: body),
              const SizedBox(height: 10),
              Text('✅ ${L.settings_song_on_title}',
                  style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              Text(L.settings_song_on_list, style: body),
              const SizedBox(height: 10),
              Text('⛔ ${L.settings_song_off_title}',
                  style: const TextStyle(
                      color: Color(0xFFB3261E),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              Text(L.settings_song_off_list, style: body),
              const SizedBox(height: 10),
              Text(L.settings_song_on_note, style: body),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(L.settings_quality,
            style: TextStyle(
                color: c.ink, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final t in _tiers) _tierCard(context, t),
        PackTile(
          key: ValueKey('song-$_tier'),
          kind: 'song',
          id: _packId[_tier]!,
          title: '',
          bare: true,
          filled: true,
          approxMb: mb,
          toggleTitle: L.settings_song_use,
          downloadLabel: (m) => L.settings_song_download(name, '$m'),
          resumeLabel: (have, m) => L.settings_song_resume(name, have, '$m'),
        ),
        const SizedBox(height: 10),
        Text(L.settings_song_tip, style: note),
      ],
    );
  }
}

class _BubbleButton extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool busy;
  final VoidCallback onTap;

  const _BubbleButton({
    required this.label,
    required this.busy,
    required this.onTap,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: Opacity(
          opacity: busy ? 0.6 : 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: c.goldSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.gold),
            ),
            child: Row(
              children: [
                if (emoji != null) ...[
                  Text(emoji!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: c.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
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

/// دکمه‌ی ساده با کادر (بدون رنگ طلایی) — مثل «دانلودِ همه‌ی صداها».
class _PlainButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PlainButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: c.ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// منوی کشویی کوچک Hope: فونت ۱۲٫۵، padding 6×8، شعاع ۱۰.
class _DropBox extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _DropBox({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.containsKey(value) ? value : null,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down, size: 18, color: c.inkSoft),
          dropdownColor: Colors.white,
          style: TextStyle(color: c.ink, fontSize: 12.5),
          items: items.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// «برچسب + لیست کشویی» در یک ردیف (زبان صدا، کیفیت، نمایش) — برچسب ۱۲/w700/inkSoft.
class _LabeledDrop extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _LabeledDrop({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: c.inkSoft, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: _DropBox(value: value, items: items, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// صدای خوانش / صدای آفلاین باکیفیت / همگام‌سازی متن و صوت — معادل Hope
// پیش‌فرض: صدای خودِ گوشی. بسته‌های باکیفیت فقط با دکمه‌ی خودِ کاربر دانلود
// می‌شوند (هیچ دانلود خودکاری وجود ندارد).
// ═══════════════════════════════════════════════════════════════════
bool get _isAndroidApp =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class _VoiceEngineSection extends ConsumerStatefulWidget {
  const _VoiceEngineSection();

  @override
  ConsumerState<_VoiceEngineSection> createState() =>
      _VoiceEngineSectionState();
}

class _VoiceEngineSectionState extends ConsumerState<_VoiceEngineSection> {
  static const String _key = 'voiceEnginePref';
  late String _pref;

  @override
  void initState() {
    super.initState();
    // پیش‌فرض = صدای گوشی؛ فقط اگر کاربر خودش «صدای اپ» را زده باشد 'model' است.
    _pref = ref.read(sharedPrefsProvider).getString(_key) == 'model'
        ? 'model'
        : 'phone';
  }

  void _set(String v) {
    setState(() => _pref = v);
    ref.read(sharedPrefsProvider).setString(_key, v);
  }

  Widget _option(BuildContext context, String label, bool selected,
      VoidCallback onTap) {
    final c = context.appColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? c.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.cardBorder),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAndroidApp) return const SizedBox.shrink();
    final c = context.appColors;
    final L = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(emoji: '🔈', label: L.settings_voice_engine_title),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _option(context, L.settings_voice_engine_app,
                    _pref == 'model', () => _set('model')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _option(context, L.settings_voice_engine_phone,
                    _pref == 'phone', () => _set('phone')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            L.settings_voice_engine_hint,
            style: TextStyle(color: c.inkSoft, fontSize: 11, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _OfflineTtsSection extends StatefulWidget {
  const _OfflineTtsSection();

  @override
  State<_OfflineTtsSection> createState() => _OfflineTtsSectionState();
}

class _OfflineTtsSectionState extends State<_OfflineTtsSection> {
  /// زبان‌هایی که بسته‌ی صدای آفلاین دارند (ترتیب مثل Hope).
  static const List<String> _downloadable = [
    'fa', 'en', 'it', 'hi', 'tr', 'ar', 'es', 'de', 'fr', 'zh',
  ];
  static const List<String> _extraDownloadable = ['ru'];
  static const List<String> _phoneOnly = ['ko'];

  bool _allRunning = false;
  bool _allCancel = false;
  String? _current;
  int _epoch = 0;

  List<String> get _all => [
        ..._downloadable,
        ..._phoneOnly,
        ..._extraDownloadable,
      ];

  List<String> get _toDownload => [..._downloadable, ..._extraDownloadable];

  String _label(BuildContext context, String code) {
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    for (final l in kSupportedLanguages) {
      if (l.code == code) return fa ? l.faLabel : l.enLabel;
    }
    return code.toUpperCase();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// فقط با دکمه‌ی خودِ کاربر: بسته‌ها یکی‌یکی دانلود می‌شوند.
  Future<void> _downloadAll() async {
    if (_allRunning) {
      _allCancel = true;
      final cur = _current;
      if (cur != null) await LinLearnBridge.packCancel('tts', cur);
      return;
    }
    setState(() {
      _allRunning = true;
      _allCancel = false;
    });
    try {
      for (final code in _toDownload) {
        if (_allCancel || !mounted) break;
        final st = await LinLearnBridge.packStatus('tts', code);
        if (st == null) {
          _toast(context.l10n.st_download_failed);
          break;
        }
        if (st['downloaded'] == true) continue;
        _current = code;
        final ok = await LinLearnBridge.packDownload('tts', code);
        if (!ok) {
          _toast(context.l10n.st_download_failed);
          break;
        }
        if (mounted) setState(() => _epoch++);
        while (mounted && !_allCancel) {
          await Future<void>.delayed(const Duration(seconds: 2));
          final s = await LinLearnBridge.packStatus('tts', code);
          if (s == null || s['downloading'] != true) break;
        }
      }
    } finally {
      _current = null;
      if (mounted) {
        setState(() {
          _allRunning = false;
          _epoch++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAndroidApp) return const SizedBox.shrink();
    final c = context.appColors;
    final L = context.l10n;
    final n = '${_toDownload.length}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(emoji: '🔊', label: L.settings_tts_title),
          const SizedBox(height: 8),
          Text(
            L.settings_tts_intro,
            style: TextStyle(color: c.inkSoft, fontSize: 11.5, height: 1.7),
          ),
          const SizedBox(height: 12),
          _PlainButton(
            label: _allRunning
                ? '⏹ ${L.settings_tts_stop_all(n)}'
                : '📥 ${L.settings_tts_download_all(n)}',
            onTap: _downloadAll,
          ),
          for (final code in _all)
            TtsPackRow(
              key: ValueKey('tts-$code-$_epoch'),
              code: code,
              label: _label(context, code),
              phoneOnly: _phoneOnly.contains(code),
            ),
        ],
      ),
    );
  }
}

class _AudioSyncSection extends ConsumerStatefulWidget {
  const _AudioSyncSection();

  @override
  ConsumerState<_AudioSyncSection> createState() => _AudioSyncSectionState();
}

class _AudioSyncSectionState extends ConsumerState<_AudioSyncSection> {
  static const String _key = 'syncModelSize';
  late String _size;

  @override
  void initState() {
    super.initState();
    final v = ref.read(sharedPrefsProvider).getString(_key);
    _size = (v == 'fast' || v == 'balanced') ? v! : 'balanced';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAndroidApp) return const SizedBox.shrink();
    final c = context.appColors;
    final L = context.l10n;
    final sizes = {
      'fast': '${L.settings_sync_model_fast} ~100MB',
      'balanced': '${L.settings_sync_model_balanced} ~160MB',
    };
    final mb = _size == 'fast' ? 100 : 160;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(emoji: '🎧', label: L.settings_sync_title),
          const SizedBox(height: 6),
          _LabeledDrop(
            label: L.settings_quality,
            value: _size,
            items: sizes,
            onChanged: (v) {
              setState(() => _size = v);
              ref.read(sharedPrefsProvider).setString(_key, v);
            },
          ),
          PackTile(
            kind: 'sync',
            id: _size,
            title: '',
            bare: true,
            approxMb: mb,
            downloadLabel: (m) => L.settings_sync_download('$m'),
          ),
          const SizedBox(height: 8),
          Text(
            L.settings_sync_description,
            style: TextStyle(color: c.inkSoft, fontSize: 12, height: 1.7),
          ),
        ],
      ),
    );
  }
}

class _OfflineWordsButton extends StatelessWidget {
  const _OfflineWordsButton();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => OfflineWordsDialog.show(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined, size: 14, color: c.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.settings_offline_download,
                style: TextStyle(
                    color: c.ink, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// دیالوگ‌های تنظیمات هم طبقِ زبانِ رابط جهت می‌گیرند.
Widget _dirDialog(BuildContext ctx, Widget child) =>
    Directionality(textDirection: uiContentDirection(ctx), child: child);
