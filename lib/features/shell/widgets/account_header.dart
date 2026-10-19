import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/providers/language_selection_provider.dart';
import '../../../core/theme/app_theme_colors.dart';

class AccountHeader extends ConsumerWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onAvatarTap;
  final String? userName;

  const AccountHeader({
    super.key,
    required this.onMenuTap,
    required this.onAvatarTap,
    this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final sel = ref.watch(languageSelectionProvider);
    final L = context.l10n;
    // نامِ زبان‌ها به زبانِ رابط (کلیدهای lang_name_* در arb)
    String labelOf(String code) {
      switch (code) {
        case 'ar': return L.lang_name_ar;
        case 'de': return L.lang_name_de;
        case 'en': return L.lang_name_en;
        case 'es': return L.lang_name_es;
        case 'fa': return L.lang_name_fa;
        case 'fr': return L.lang_name_fr;
        case 'hi': return L.lang_name_hi;
        case 'it': return L.lang_name_it;
        case 'ja': return L.lang_name_ja;
        case 'ko': return L.lang_name_ko;
        case 'ru': return L.lang_name_ru;
        case 'tr': return L.lang_name_tr;
        case 'zh': return L.lang_name_zh;
      }
      return code.toUpperCase();
    }

    final uiCode = Localizations.localeOf(context).languageCode;
    final rtlUi = uiCode == 'fa' || uiCode == 'ar';
    final fromTo = L.phrasebook_header_from_to(
        labelOf(sel.native), sel.targets.map(labelOf).join(rtlUi ? '، ' : ', '));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.headerFrom, c.headerTo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 16, 8),
          child: Row(
            children: [
              // ═══ منوی همبرگری (تنظیمات) — بالا سمت راست ═══
              InkWell(
                onTap: onMenuTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.menu,
                    color: c.headerText,
                    size: 26,
                  ),
                ),
              ),

              // ═══ «از زبان مبدا به زبان‌های مقصد» — کنار همبرگری ═══
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    fromTo,
                    textDirection: rtlUi ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: TextAlign.start,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      height: 1.35,
                      color: c.headerText.withOpacity(0.9),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
