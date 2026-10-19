import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_languages.dart';
import '../../../core/constants/level_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../models/review_item.dart';
import '../review_i18n.dart';

TextDirection textDirOf(String s) =>
    RegExp(r'[\u0600-\u06FF]').hasMatch(s) ? TextDirection.rtl : TextDirection.ltr;

/// کارت لغت — با انیمیشن flip (محور Y) بین روی کارت (لغت) و پشت کارت (جواب).
/// برای هر لغتِ جدید با یک `key` تازه ساخته شود تا وضعیت flip ریست شود.
class ReviewCard extends StatefulWidget {
  final ReviewItem item;
  final bool revealed;

  /// سطح CEFR (اگر در words.json پیدا شده باشد)
  final String? level;
  final String? example;
  final String sourceLabel;
  final VoidCallback onSpeak;

  const ReviewCard({
    super.key,
    required this.item,
    required this.revealed,
    required this.onSpeak,
    required this.sourceLabel,
    this.level,
    this.example,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.revealed ? 1.0 : 0.0,
    );
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant ReviewCard old) {
    super.didUpdateWidget(old);
    if (old.revealed != widget.revealed) {
      widget.revealed ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) {
        final angle = _curve.value * math.pi;
        final showBack = angle > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _face(c, back: true, child: _backContent(c)),
                )
              : _face(c, back: false, child: _frontContent(c)),
        );
      },
    );
  }

  Widget _face(AppThemeColorsExt c, {required bool back, required Widget child}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: back ? c.goldSoft.withOpacity(0.25) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: back ? c.gold.withOpacity(0.6) : c.cardBorder,
          width: back ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  // ───────────────────────── روی کارت ─────────────────────────
  Widget _frontContent(AppThemeColorsExt c) {
    final it = widget.item;
    final len = it.word.length;
    final size = len > 22 ? 26.0 : (len > 12 ? 36.0 : 48.0);
    final langDir = kAppLanguages[it.langCode]?.dir ?? TextDirection.ltr;

    return Column(
      children: [
        Row(
          children: [
            _pill(c, context.l10n.review_box_n(context.rvNum(it.box)), c.gold),
            const SizedBox(width: 8),
            if (widget.level != null)
              _pill(c, widget.level!, levelColor(widget.level!),
                  textColor: levelColor(widget.level!)),
            const Spacer(),
            Text(
              it.reviewCount == 0
                  ? context.l10n.rv_card_new
                  : context.l10n.rv_reviewed_n_times(context.rvNum(it.reviewCount)),
              style: TextStyle(color: c.inkSoft, fontSize: 11.5),
            ),
          ],
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                it.word,
                textAlign: TextAlign.center,
                textDirection: langDir,
                style: TextStyle(
                  color: c.ink,
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ),
        _SpeakButton(onTap: widget.onSpeak),
        const SizedBox(height: 10),
        Text(
          context.l10n.rv_recall_hint,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.inkSoft, fontSize: 12),
        ),
      ],
    );
  }

  // ───────────────────────── پشت کارت ─────────────────────────
  Widget _backContent(AppThemeColorsExt c) {
    final it = widget.item;
    final langDir = kAppLanguages[it.langCode]?.dir ?? TextDirection.ltr;
    final example = widget.example;

    return Column(
      children: [
        Text(
          it.word,
          textDirection: langDir,
          style: TextStyle(
            color: c.inkSoft,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    it.meaning.isEmpty ? '—' : it.meaning,
                    textAlign: TextAlign.center,
                    textDirection: textDirOf(it.meaning),
                    style: TextStyle(
                      color: c.ink,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                  if (example != null && example.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.cardBorder),
                      ),
                      child: Text(
                        example,
                        textAlign: TextAlign.center,
                        textDirection: textDirOf(example),
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 14.5,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline_rounded, size: 14, color: c.inkSoft),
            const SizedBox(width: 4),
            Text(
              context.l10n.rv_source_label(widget.sourceLabel),
              style: TextStyle(color: c.inkSoft, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pill(AppThemeColorsExt c, String text, Color color,
      {Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor ?? c.ink,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SpeakButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SpeakButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.gold.withOpacity(0.16),
          border: Border.all(color: c.gold.withOpacity(0.5)),
        ),
        child: Icon(Icons.volume_up_rounded, color: c.ink, size: 26),
      ),
    );
  }
}
